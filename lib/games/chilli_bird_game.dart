// lib/games/chilli_bird_game.dart
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flame/camera.dart';
import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flutter/painting.dart' show TextStyle, FontWeight;
// SFX opcional; si no lo usas, borra esta import y las llamadas try{FlameAudio...}
import 'package:flame_audio/flame_audio.dart';
import 'package:audioplayers/audioplayers.dart' show AudioPool, AssetSource;


/// Chilli Bird — Flame 1.32.x
/// - Assets fijos: background.png y bird.png
/// - Movimiento inicial y física pulidos
/// - Colisiones sólidas y scoring consistente
/// - Auto-envío de récord al perder (via callback onNewRecord)
class ChilliBirdGame extends FlameGame
    with HasCollisionDetection, TapDetector {
  final Future<void> Function(int newBest)? onNewRecord;
  ChilliBirdGame({this.onNewRecord});

  // Mundo/dificultad
  final _rng = Random();
  double gravity = 2400; // caída clara y natural
  double _pipeSpeed = 190;
  double _spawnEvery = 1.15;
  double _time = 0;
  double _sinceSpawn = 0;

  // Hueco dinámico entre tubos
  static const double _pillarWidth = 64;
  static const double _gapStart = 172;
  static const double _gapMin = 112;

  // Suelo
  static const double _groundH = 96;

  // Estado
  late Chilli chilli;
  GameState state = GameState.ready;
  int score = 0;
  int best = 0;

  // Para notificar récord solo al perder
  int _runStartBest = 0;

  // Multiplicador (lo dejamos listo por si más tarde lo quieres reactivar)
  double _scoreMultiplier = 1.0;
  double _multEndsAt = 0;

  // Estética
  late Sky _sky;
  late GroundScroller _ground;

  // HUD
  late ScoreHud _hud;
  late HudMessage _hudMsg;

  // Spawn vertical suave
  double? _lastMid;

  AudioPool? _fxFlap, _fxScore, _fxHit;

  // color de las barras laterales del FixedResolutionViewport
  @override
  ui.Color backgroundColor() => const ui.Color(0xFFD9F3FF);

  @override
  void onRemove() {
    _fxFlap?.dispose();
    _fxScore?.dispose();
    _fxHit?.dispose();
    super.onRemove();
  }


  @override
  Future<void> onLoad() async {
    await super.onLoad();

    // Hacemos que Sprite.load busque bajo assets/
    images.prefix = 'assets/';
    FlameAudio.audioCache.prefix = 'assets/audio/';

    // Carga anticipada de imágenes (si fallan, Sky/Chilli caen a fallback)
    try {
      _fxFlap  = await AudioPool.create(source: AssetSource('sfx/flap.wav'),  maxPlayers: 3);
      _fxScore = await AudioPool.create(source: AssetSource('sfx/score.wav'), maxPlayers: 2);
      _fxHit   = await AudioPool.create(source: AssetSource('sfx/hit.wav'),   maxPlayers: 1);


    } catch (_) {
      // si faltan audios, no crashea
    }

    // Carga opcional de SFX (si faltan, play() se ignora con try/catch)
    try {
      await FlameAudio.audioCache.loadAll([
        'sfx/flap.wav',
        'sfx/score.wav',
        'sfx/hit.wav',
      ]);


    } catch (_) {}

    // Viewport fijo tipo mobile (barras si no coincide el ratio)
    camera.viewport = FixedResolutionViewport(
      resolution: Vector2(360, 640),
    );

    // Fondo
    _sky = Sky()..size = size;
    add(_sky..priority = -1000);

    // Suelo
    _ground = GroundScroller(
      groundHeight: _groundH,
      speedPxPerSec: _pipeSpeed,
    )
      ..size = Vector2(size.x, _groundH)
      ..position = Vector2(0, size.y - _groundH)
      ..priority = 100;
    add(_ground);

    // Jugador
    chilli = Chilli()
      ..position = Vector2(100, size.y * 0.45)
      ..priority = 10;
    add(chilli);

    // HUD score
    _hud = ScoreHud()
      ..priority = 1000
      ..position = Vector2(size.x / 2, 40);
    add(_hud);

    // HUD mensajes de estado
    _hudMsg = HudMessage()
      ..priority = 1001
      ..position = Vector2(size.x / 2, size.y * 0.32);
    add(_hudMsg);

    // Spawns iniciales, separados y centrados
    for (var i = 0; i < 3; i++) {
      _spawnPipes(x: size.x + i * 220);
    }

    // Record base de la carrera
    _runStartBest = best;
  }

  @override
  void update(double dt) {
    super.update(dt);

    _time += dt;

    // HUD
    if (_scoreMultiplier > 1 && _time >= _multEndsAt) {
      _scoreMultiplier = 1.0;
    }
    _hud.setScore(score);
    _hud.setMultiplier(_scoreMultiplier,
        remaining: (_multEndsAt - _time).clamp(0, 999));
    _hudMsg.setState(state);

    if (state != GameState.playing) return;

    _sinceSpawn += dt;

    // Dificultad: más rápido y más frecuente con el tiempo
    if (_sinceSpawn >= _spawnEvery) {
      _sinceSpawn = 0;
      _spawnPipes();
      _pipeSpeed *= 1.012;
      _spawnEvery = (_spawnEvery * 0.99).clamp(0.90, 999);
    }

    // Sincroniza velocidad del suelo
    _ground.setSpeed(_pipeSpeed);
  }

  @override
  void onTapDown(TapDownInfo info) {
    if (state == GameState.ready) {
      state = GameState.playing;
      chilli.flap(stronger: true);
      _fxFlap?.start(volume: 0.6);
      return;
    }
    if (state == GameState.dead) {
      _restart();
      return;
    }
    chilli.flap();
    _fxFlap?.start(volume: 0.6);
  }

  void _spawnPipes({double? x}) {
    // gap en función del score (más pequeño con más puntos)
    final progress = (score / 40).clamp(0.0, 1.0);
    final gap = (ui.lerpDouble(_gapStart, _gapMin, progress) ?? _gapMin);

    // centro suave respecto al último par
    final minMid = 80 + gap / 2;
    final maxMid = size.y - _groundH - 80 - gap / 2;
    final last = _lastMid ?? (size.y * 0.5);
    const maxDelta = 105.0;
    var candidate = last + (_rng.nextDouble() * 2 - 1) * maxDelta;
    candidate = candidate.clamp(minMid, maxMid);
    _lastMid = candidate;

    final px = x ?? (size.x + 40);
    add(PillarPair(
      pillarWidth: _pillarWidth,
      centerY: candidate,
      gap: gap,
      speedPxPerSec: _pipeSpeed,
    )
      ..position = Vector2(px, 0)
      ..priority = 5);
  }

  // Puntuación
  void addScore(int base) {
    score += (base * _scoreMultiplier).round();
    if (score > best) {
      best = score;
    }
    _hud.pop();
    _fxScore?.start(volume: 0.5);
  }

  void activateMultiplier({double factor = 2, double duration = 7}) {
    _scoreMultiplier = factor;
    _multEndsAt = _time + duration;
    _hud.flashMultiplier();
  }

  // Game over
  void gameOver() {
    if (state == GameState.dead) return;
    state = GameState.dead;

    // Nuevo record solo si supera el que tenías al inicio de la partida
    if (score > _runStartBest) {
      best = score;
      onNewRecord?.call(best);
    }

    // Parar movimiento
    children.whereType<_MovesLeft>().forEach((m) => m.freeze());
    _ground.freeze();

    // Sonido y giro final
    _fxHit?.start(volume: 0.7);
    chilli.crashSpin();
  }

  void _restart() {
    // Limpiar obstáculos y sensores
    children.whereType<PillarPair>().forEach((c) => c.removeFromParent());
    children.whereType<MultiplierPowerUp>().forEach((c) => c.removeFromParent());
    children.whereType<ScoreGate>().forEach((c) => c.removeFromParent());

    // Reset generador
    _pipeSpeed = 190;
    _spawnEvery = 1.15;
    _sinceSpawn = 0;
    _lastMid = null;

    // Suelo y jugador
    _ground.unfreeze();
    chilli.resetAt(Vector2(100, size.y * 0.45));

    // Puntuación
    score = 0;
    _scoreMultiplier = 1;
    _multEndsAt = 0;

    // Spawns iniciales
    for (var i = 0; i < 3; i++) {
      _spawnPipes(x: size.x + i * 220);
    }

    _runStartBest = best;
    state = GameState.ready;
  }


}

enum GameState { ready, playing, dead }

/// Fondo: usa background.png si existe; si no, degradado
class Sky extends PositionComponent with HasGameRef<ChilliBirdGame> {
  SpriteComponent? _sprite;

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    try {
      final spr = await Sprite.load(
        'game/chilli_bird/background.png',
        images: gameRef.images,
      );
      _sprite =
          SpriteComponent(sprite: spr, size: size, anchor: Anchor.topLeft);
      add(_sprite!);
    } catch (_) {
      // fallback a degradado
    }
  }

  @override
  void onGameResize(Vector2 s) {
    super.onGameResize(s);
    size = s;
    _sprite?.size = s;
  }

  @override
  void render(ui.Canvas canvas) {
    if (_sprite != null) return; // lo pinta el child
    // degradado
    final rect = ui.Rect.fromLTWH(0, 0, size.x, size.y);
    final shader = ui.Gradient.linear(
      const ui.Offset(0, 0),
      ui.Offset(0, size.y),
      [const ui.Color(0xFF8AD0FF), const ui.Color(0xFFD9F3FF)],
      const [0.0, 1.0],
    );
    final paint = ui.Paint()..shader = shader;
    canvas.drawRect(rect, paint);
  }
}

/// Suelo con hitbox
class GroundScroller extends PositionComponent
    with CollisionCallbacks, _MovesLeft {
  final double groundHeight;
  final double _tileW = 180;
  bool _frozen = false;

  GroundScroller({
    required this.groundHeight,
    required double speedPxPerSec,
  }) {
    worldSpeed = speedPxPerSec;
  }

  void setSpeed(double s) {
    if (_frozen) return;
    worldSpeed = s;
  }

  void freeze() => _frozen = true;
  void unfreeze() => _frozen = false;

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    // Hitbox del suelo
    add(RectangleHitbox(collisionType: CollisionType.passive));

    // Más baldosas y 1px de solape para evitar huecos visuales
    final tiles = (size.x / _tileW).ceil() + 3;
    for (var i = 0; i < tiles; i++) {
      add(_GroundTile(
        w: _tileW,
        h: groundHeight,
        x0: i * _tileW.toDouble(),
      ));
    }
  }

  @override
  void moveLeft(double dt) {
    if (_frozen) return;
    final tiles = children.whereType<_GroundTile>().toList();
    for (final c in tiles) {
      c.x -= worldSpeed * dt;
      if (c.x + c.width <= 0) {
        final rightmost = tiles.map((t) => t.x).reduce(max) + _tileW;
        c.x = rightmost - 1; // solape 1px
      }
    }
  }
}

class _GroundTile extends PositionComponent {
  _GroundTile({required double w, required double h, required double x0}) {
    size = Vector2(w, h);
    position = Vector2(x0, 0);
    priority = 100;
  }

  @override
  void render(ui.Canvas canvas) {
    final rect = ui.Rect.fromLTWH(0, 0, size.x, size.y);
    final dirt = ui.Paint()..color = const ui.Color(0xFFB57F4A);
    canvas.drawRect(rect, dirt);
    const grassH = 18.0;
    final grassRect = ui.Rect.fromLTWH(0, 0, size.x, grassH);
    final grass = ui.Paint()..color = const ui.Color(0xFF6CCB5F);
    canvas.drawRect(grassRect, grass);
    final deco = ui.Paint()..color = const ui.Color(0xFF5AB24E);
    const r = 6.0;
    for (double x = 6; x < size.x; x += 18) {
      canvas.drawCircle(ui.Offset(x, grassH), r, deco);
    }
  }
}

/// Pájaro con sprite bird.png y fallback vectorial
class Chilli extends PositionComponent
    with CollisionCallbacks, HasGameRef<ChilliBirdGame> {
  // Física
  Vector2 vel = Vector2.zero();
  final double jumpImpulse = -520;
  final double maxFall = 980;

  // Visual
  BirdVisual? _visual;
  late final _Wing wing; // fallback
  late final _Eye eye;
  final ui.Paint body = ui.Paint()..color = const ui.Color(0xFFE3A62F);
  final ui.Paint beak = ui.Paint()..color = const ui.Color(0xFFEF6C00);

  // “hover” en estado ready
  double _readyT = 0;
  double? _readyBaseY;

  @override
  Future<void> onLoad() async {
    super.onLoad();
    size = Vector2(36, 28);
    anchor = Anchor.center;

    // Hitbox del pájaro
    add(CircleHitbox(
      radius: min(width, height) * 0.38,
      anchor: Anchor.center,
      collisionType: CollisionType.active,
    ));


    // Sprite bird.png
    _visual = BirdVisual.tryCreate(size);
    if (_visual != null) {
      add(_visual!);
    } else {
      // Fallback vectorial
      wing = _Wing()..position = Vector2(-6, 2);
      eye = _Eye()..position = Vector2(size.x * .18, -4);
      addAll([wing, eye]);
    }
  }

  void flap({bool stronger = false}) {
    vel.y = stronger ? jumpImpulse * 1.08 : jumpImpulse;
    _visual?.flap();
    if (_visual == null) {
      children.whereType<_Wing>().firstOrNull?.flap();
    }
  }

  void crashSpin() {
    add(RotateEffect.by(0.6, EffectController(duration: 0.25)));
  }

  void resetAt(Vector2 p) {
    position = p;
    angle = 0;
    vel.setZero();
    _visual?.reset();
    children.whereType<_Wing>().firstOrNull?.reset();
    _readyT = 0;
    _readyBaseY = null;
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (game.state == GameState.ready) {
      // Hover estable sin deriva: y = base + A*sin(w*t)
      _readyT += dt;
      _readyBaseY ??= y;
      const amp = 6.0;
      const w = 2.2; // rad/s
      y = _readyBaseY! + sin(_readyT * w) * amp;
      angle = 0;
      return;
    }

    // Física de juego
    vel.y += game.gravity * dt;
    vel.y = vel.y.clamp(-1000, maxFall);
    y += vel.y * dt;

    // Inclinación dependiente de velocidad
    angle = (vel.y * 0.00135).clamp(-0.5, 0.72);

    // Suelo
    final floorY = game.size.y - ChilliBirdGame._groundH - height / 2;
    if (y >= floorY) {
      y = floorY;
      game.gameOver();
    }

    // Arriba fuera
    if (y < height / 2) {
      y = height / 2;
      game.gameOver();
    }
  }

  @override
  void render(ui.Canvas canvas) {
    if (_visual != null) {
      super.render(canvas);
      return;
    }
    // Fallback vectorial
    final r = ui.RRect.fromRectAndRadius(
      ui.Rect.fromCenter(center: ui.Offset.zero, width: size.x, height: size.y),
      const ui.Radius.circular(12),
    );
    canvas.drawRRect(r, body);
    final path = ui.Path()
      ..moveTo(size.x * 0.4, -2)
      ..lineTo(size.x * 0.62, 3)
      ..lineTo(size.x * 0.4, 8)
      ..close();
    canvas.drawPath(path, beak);
    super.render(canvas);
  }

  @override
  void onCollisionStart(
      Set<Vector2> intersectionPoints, PositionComponent other) {
    if (other is PillarBlock || other is GroundScroller) {
      game.gameOver();
    } else if (other is MultiplierPowerUp) {
      other.collect();
    }
    super.onCollisionStart(intersectionPoints, other);
  }
}

/// Sprite bird.png (sin anim por frames)
class BirdVisual extends PositionComponent with HasGameRef {
  final Vector2 logicalSize;
  SpriteComponent? _single;
  double _flapT = 0;

  BirdVisual._(this.logicalSize);

  static BirdVisual? tryCreate(Vector2 size) => BirdVisual._(size);

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    size = logicalSize;
    anchor = Anchor.center;

    try {
      final s =
      await Sprite.load('game/chilli_bird/bird.png', images: gameRef.images);
      _single = SpriteComponent(sprite: s, size: size, anchor: Anchor.center);
      add(_single!);
    } catch (_) {
      removeFromParent(); // Chilli hará fallback
    }
  }

  void flap() {
    _flapT = 0.22; // pequeño squash-stretch
  }

  void reset() {
    _flapT = 0;
    scale = Vector2.all(1);
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (_flapT > 0) {
      _flapT -= dt;
      final s =
      (ui.lerpDouble(1.0, 1.08, (_flapT / 0.22).clamp(0.0, 1.0))!);
      scale = Vector2.all(s);
    } else {
      scale = Vector2.all(1);
    }
  }
}

/// Par de tubos y puerta de puntuación
class PillarPair extends PositionComponent
    with _MovesLeft, HasGameRef<ChilliBirdGame> {
  final double pillarWidth;
  final double centerY;
  final double gap;
  double speedPxPerSec;

  late final PillarBlock _top;
  late final PillarBlock _bottom;
  late final ScoreGate _gate;

  PillarPair({
    required this.pillarWidth,
    required this.centerY,
    required this.gap,
    required this.speedPxPerSec,
  }) {
    worldSpeed = speedPxPerSec;
  }

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    size = Vector2(pillarWidth, gameRef.size.y);
    anchor = Anchor.topLeft;

    final topH = max(0.0, centerY - gap / 2);
    final bottomY = centerY + gap / 2;
    final bottomH =
    max(0.0, gameRef.size.y - ChilliBirdGame._groundH - bottomY);

    _top = PillarBlock(w: pillarWidth, h: topH, isTop: true)
      ..position = Vector2(0, 0);
    _bottom = PillarBlock(w: pillarWidth, h: bottomH, isTop: false)
      ..position = Vector2(0, bottomY);

    // Sensor más ancho para evitar saltos por frame
    _gate = ScoreGate(width: 24, height: gap * 0.9)
      ..position = Vector2(pillarWidth / 2, centerY);

    addAll([_top, _bottom, _gate]);
  }

  @override
  void moveLeft(double dt) {
    x -= worldSpeed * dt;
    if (x + width < 0) {
      removeFromParent();
    }
  }

  @override
  void freeze() {
    super.freeze();
    _top.freeze();
    _bottom.freeze();
    _gate.freeze();
  }
}

class PillarBlock extends PositionComponent
    with CollisionCallbacks, _MovesLeft {
  final bool isTop;
  PillarBlock({
    required double w,
    required double h,
    required this.isTop,
  }) {
    size = Vector2(w, h);
    anchor = Anchor.topLeft;
  }

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    add(RectangleHitbox(collisionType: CollisionType.passive));
  }

  @override
  void render(ui.Canvas canvas) {
    if (size.y <= 0) return;
    final rect = ui.Rect.fromLTWH(0, 0, size.x, size.y);
    final shadow = ui.Paint()..color = const ui.Color(0x33000000);
    canvas.drawRect(rect.shift(const ui.Offset(4, 0)), shadow);

    final body = ui.Paint()..color = const ui.Color(0xFF2ECC71);
    final dark = ui.Paint()..color = const ui.Color(0xFF27AE60);
    final light = ui.Paint()..color = const ui.Color(0xFF87E8A8);

    canvas.drawRect(rect, body);
    canvas.drawRect(ui.Rect.fromLTWH(6, 0, 10, size.y), dark);
    canvas.drawRect(ui.Rect.fromLTWH(size.x - 8, 0, 6, size.y), light);

    const capH = 14.0;
    final capRect = isTop
        ? ui.Rect.fromLTWH(-6, size.y - capH, size.x + 12, capH)
        : ui.Rect.fromLTWH(-6, 0, size.x + 12, capH);
    final cap = ui.Paint()..color = const ui.Color(0xFF28B463);
    canvas.drawRect(capRect, cap);
    final capEdge = ui.Paint()
      ..color = const ui.Color(0xFF239B56)
      ..style = ui.PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawRect(capRect, capEdge);
  }
}

/// Sensor que suma puntuación al cruzar
class ScoreGate extends PositionComponent
    with CollisionCallbacks, _MovesLeft {
  bool _done = false;
  ScoreGate({double width = 24, double height = 140}) {
    size = Vector2(width, height);
    anchor = Anchor.center;
  }

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    add(RectangleHitbox(collisionType: CollisionType.passive));
  }

  @override
  void onCollisionStart(
      Set<Vector2> intersectionPoints, PositionComponent other) {
    if (_done) return;
    if (other is Chilli) {
      _done = true;
      other.game.addScore(1);
      final fx = _FloatingText('+1')..position = Vector2.zero();
      add(fx);
      add(TimerComponent(
        period: 0.6,
        onTick: () => fx.removeFromParent(),
        removeOnFinish: true,
      ));
    }
    super.onCollisionStart(intersectionPoints, other);
  }

  @override
  void render(ui.Canvas canvas) {
    // invisible
  }
}

/// Power-up opcional (mantener por si lo quieres reactivar luego)
class MultiplierPowerUp extends PositionComponent
    with CollisionCallbacks, _MovesLeft, HasGameRef<ChilliBirdGame> {
  final double speedPx;
  final double factor;
  final double duration;
  bool _collected = false;

  MultiplierPowerUp({
    required this.speedPx,
    this.factor = 2,
    this.duration = 7,
  }) {
    worldSpeed = speedPx;
    size = Vector2.all(26);
    anchor = Anchor.center;
  }

  @override
  Future<void> onLoad() async {
    super.onLoad();
    add(RectangleHitbox(collisionType: CollisionType.passive));
  }

  @override
  void render(ui.Canvas canvas) {
    final glow = ui.Paint()
      ..color = const ui.Color(0x8834D058)
      ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 8);
    canvas.drawCircle(ui.Offset.zero, size.x * .7, glow);

    final p = ui.Paint()..color = const ui.Color(0xFF2DCC70);
    canvas.drawCircle(ui.Offset.zero, size.x * .5, p);

    final star = ui.Path();
    const R = 8.0, r = 3.2;
    for (var i = 0; i < 10; i++) {
      final a = i * pi / 5;
      final rr = (i % 2 == 0) ? R : r;
      star.lineTo(rr * cos(a), rr * sin(a));
    }
    star.close();
    canvas.drawPath(star, ui.Paint()..color = const ui.Color(0xFFFFFFFF));
  }

  @override
  void moveLeft(double dt) {
    x -= worldSpeed * dt;
    if (x < -width) removeFromParent();
  }

  void collect() {
    if (_collected) return;
    _collected = true;
    gameRef.activateMultiplier(factor: factor, duration: duration);
    removeFromParent();
  }

  @override
  void onCollisionStart(Set<Vector2> points, PositionComponent other) {
    if (other is Chilli) {
      collect();
    }
    super.onCollisionStart(points, other);
  }
}

/// HUD marcador
class ScoreHud extends PositionComponent {
  int _score = 0;
  double _mult = 1;
  double _remaining = 0;
  double _popT = 0;

  final TextComponent _shadow = TextComponent();
  final TextComponent _text = TextComponent();
  final TextComponent _multText = TextComponent();

  bool _initialized = false;

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    anchor = Anchor.topCenter;

    final tp = TextPaint(
      style: const TextStyle(
        fontSize: 36,
        fontWeight: FontWeight.w900,
        color: ui.Color(0xFF1B1B1B),
      ),
    );
    final tpShadow = TextPaint(
      style: const TextStyle(
        fontSize: 36,
        fontWeight: FontWeight.w900,
        color: ui.Color(0x33000000),
      ),
    );
    final tpMult = TextPaint(
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w800,
        color: ui.Color(0xFF2ECC71),
      ),
    );

    _shadow
      ..textRenderer = tpShadow
      ..text = '$_score'
      ..position = Vector2(2, 2);
    _text
      ..textRenderer = tp
      ..text = '$_score';
    _multText
      ..textRenderer = tpMult
      ..anchor = Anchor.topCenter
      ..position = Vector2(0, 32)
      ..text = '';

    addAll([_shadow, _text, _multText]);
    _initialized = true;
  }

  void setScore(int s) {
    _score = s;
    if (_initialized) {
      _shadow.text = '$s';
      _text.text = '$s';
    }
  }

  void setMultiplier(double mult, {required double remaining}) {
    _mult = mult;
    _remaining = remaining;
    if (_initialized) {
      _multText.text =
      mult > 1 ? '×${mult.toStringAsFixed(0)} · ${_remaining.toStringAsFixed(0)}s' : '';
    }
  }

  void pop() => _popT = 0.18;
  void flashMultiplier() => _popT = 0.24;

  @override
  void update(double dt) {
    super.update(dt);
    if (_popT > 0) {
      _popT -= dt;
      final s =
      (ui.lerpDouble(1.0, 1.18, (_popT / 0.18).clamp(0.0, 1.0))!);
      scale = Vector2.all(s);
    } else {
      scale = Vector2.all(1.0);
    }
  }
}

/// Mensaje de estado: Tap to start / Tap to restart
class HudMessage extends PositionComponent {
  final TextComponent _label = TextComponent();
  GameState _state = GameState.ready;
  double _blinkT = 0;

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    anchor = Anchor.center;

    _label
      ..anchor = Anchor.center
      ..textRenderer = TextPaint(
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w800,
          color: ui.Color(0xFF1B1B1B),
        ),
      );
    add(_label);
    _updateText();
  }

  void setState(GameState s) {
    if (_state == s) return;
    _state = s;
    _updateText();
  }

  void _applyAlpha(double a) {
    final base = (_label.textRenderer as TextPaint).style;
    _label.textRenderer = TextPaint(
      style: TextStyle(
        fontSize: base?.fontSize ?? 18,
        fontWeight: base?.fontWeight ?? FontWeight.w800,
        color: (base?.color ?? const ui.Color(0xFF1B1B1B)).withOpacity(a.clamp(0, 1).toDouble()),
      ),
    );
  }

  void _updateText() {
    switch (_state) {
      case GameState.ready:
        _label.text = 'Tap to start';
        _applyAlpha(1);
        _blinkT = 0;
        break;
      case GameState.playing:
        _label.text = '';
        _applyAlpha(0);
        break;
      case GameState.dead:
        _label.text = 'Game Over - Tap to restart';
        _applyAlpha(1);
        _blinkT = 0;
        break;
    }
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (_state == GameState.ready) {
      _blinkT += dt;
      final k = 0.5 + 0.5 * sin(_blinkT * 4.0);
      _applyAlpha(k);
    } else if (_state == GameState.dead) {
      _blinkT += dt;
      final k = 0.6 + 0.4 * sin(_blinkT * 3.2);
      _applyAlpha(k);
    }
  }
}


/// Texto flotante corto (+1)
class _FloatingText extends PositionComponent {
  final String value;
  final TextComponent _label = TextComponent();
  double _t = 0;
  final double _dur = 0.6;

  _FloatingText(this.value);

  @override
  Future<void> onLoad() async {
    super.onLoad();
    anchor = Anchor.center;

    _label
      ..text = value
      ..anchor = Anchor.center
      ..textRenderer = TextPaint(
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w800,
          color: ui.Color(0xFF2ECC71),
        ),
      );

    add(_label);

    add(MoveByEffect(
      Vector2(0, -18),
      EffectController(duration: _dur),
    ));
  }

  @override
  void update(double dt) {
    super.update(dt);
    _t += dt;
    final k = (1 - (_t / _dur)).clamp(0.0, 1.0);
    final base = (_label.textRenderer as TextPaint).style;
    _label.textRenderer = TextPaint(
      style: TextStyle(
        fontSize: base?.fontSize ?? 12,
        fontWeight: base?.fontWeight ?? FontWeight.w800,
        color: (base?.color ?? const ui.Color(0xFF2ECC71)).withOpacity(k),
      ),
    );
    if (_t >= _dur) {
      removeFromParent();
    }
  }
}

class _Wing extends PositionComponent {
  double _t = 0;
  bool _flapping = false;

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    size = Vector2(16, 10);
    anchor = Anchor.center;
  }

  void flap() {
    _flapping = true;
    _t = 0;
  }

  void reset() {
    _flapping = false;
    _t = 0;
  }

  @override
  void update(double dt) {
    super.update(dt);
    _t += dt;
    if (_flapping && _t > 0.25) _flapping = false;
  }

  @override
  void render(ui.Canvas canvas) {
    final h = size.y * (_flapping ? 0.6 : 1.0);
    final r = ui.RRect.fromRectAndRadius(
      ui.Rect.fromCenter(center: ui.Offset.zero, width: size.x, height: h),
      const ui.Radius.circular(6),
    );
    final p = ui.Paint()..color = const ui.Color(0xFF2B2B2B);
    canvas.drawRRect(r, p);
  }
}

class _Eye extends PositionComponent {
  @override
  Future<void> onLoad() async {
    await super.onLoad();
    size = Vector2.all(8);
    anchor = Anchor.center;
  }

  @override
  void render(ui.Canvas canvas) {
    final white = ui.Paint()..color = const ui.Color(0xFFFFFFFF);
    final black = ui.Paint()..color = const ui.Color(0xFF000000);
    canvas.drawCircle(ui.Offset.zero, size.x / 2, white);
    canvas.drawCircle(const ui.Offset(1.2, -0.5), size.x / 4, black);
  }
}


/// Utilidad: mover a la izquierda y poder congelar
mixin _MovesLeft on PositionComponent {
  double worldSpeed = 0;
  bool _frozen = false;

  void moveLeft(double dt) {}
  void freeze() => _frozen = true;

  @override
  void update(double dt) {
    super.update(dt);
    if (_frozen) return;
    moveLeft(dt);
  }
}

// Helper
extension _FirstOrNull<E> on Iterable<E> {
  E? get firstOrNull => isEmpty ? null : first;
}
