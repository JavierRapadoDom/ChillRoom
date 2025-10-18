// lib/games/card_game/widgets/hand_view.dart
import 'package:flutter/material.dart';
import '../theme/card_theme.dart';

class HandView extends StatefulWidget {
  /// Textos de cartas blancas en mano (solo los textos para la UI).
  final List<String> whiteTexts;

  /// Número de cartas que hay que seleccionar para jugar (1, 2, ...).
  final int mustPick;

  /// Callback cuando el usuario confirma la jugada con exactamente [mustPick] cartas.
  final ValueChanged<List<String>> onSubmit;

  const HandView({
    super.key,
    required this.whiteTexts,
    required this.mustPick,
    required this.onSubmit,
  });

  @override
  State<HandView> createState() => _HandViewState();
}

class _HandViewState extends State<HandView> {
  /// Copia local editable de los textos (permite renombrar o añadir personalizados).
  late List<String> _texts;

  /// Índices seleccionados.
  final Set<int> _selected = <int>{};

  @override
  void initState() {
    super.initState();
    _texts = List<String>.from(widget.whiteTexts);
  }

  @override
  void didUpdateWidget(covariant HandView oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Si cambian las cartas (p.ej. se reparten nuevas), reseteamos la copia y la selección.
    if (oldWidget.whiteTexts != widget.whiteTexts) {
      _texts = List<String>.from(widget.whiteTexts);
      _selected.clear();
      setState(() {}); // fuerza rebuild ante cambios en RT
    }
  }

  bool get _canSubmit =>
      _texts.isNotEmpty &&
          widget.mustPick > 0 &&
          _selected.length == widget.mustPick;

  void _toggle(int i) {
    if (i < 0 || i >= _texts.length) return;
    setState(() {
      if (_selected.contains(i)) {
        _selected.remove(i);
      } else {
        if (_selected.length < widget.mustPick) _selected.add(i);
      }
    });
  }

  void _clear() {
    if (_selected.isEmpty) return;
    setState(_selected.clear);
  }

  void _submit() {
    if (!_canSubmit) return;
    final picks = _selected.map((i) => _texts[i]).toList(growable: false);
    widget.onSubmit(picks);
    // Limpiamos selección local tras enviar (la mano se refresca desde RT)
    setState(_selected.clear);
  }

  Future<void> _showEditDialog({
    required String initial,
    required ValueChanged<String> onSave,
    String title = 'Editar carta',
    String hint = 'Escribe tu texto…',
  }) async {
    final controller = TextEditingController(text: initial);
    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          maxLines: null,
          autofocus: true,
          textInputAction: TextInputAction.done,
          onSubmitted: (v) {
            final trimmed = v.trim();
            if (trimmed.isNotEmpty) {
              Navigator.of(context).pop();
              onSave(trimmed);
            }
          },
          decoration: InputDecoration(
            hintText: hint,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancelar'),
          ),
          FilledButton.icon(
            onPressed: () {
              final v = controller.text.trim();
              if (v.isEmpty) return;
              Navigator.of(context).pop();
              onSave(v);
            },
            icon: const Icon(Icons.check),
            label: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  Future<void> _addCustomCard() async {
    await _showEditDialog(
      initial: '',
      title: 'Nueva carta personalizada',
      hint: 'Escribe tu mejor ocurrencia…',
      onSave: (value) {
        setState(() {
          _texts.add(value);
          // Si hay hueco de selección, seleccionar automáticamente la nueva.
          if (_selected.length < widget.mustPick) {
            _selected.add(_texts.length - 1);
          }
        });
      },
    );
  }

  Future<void> _editCard(int index) async {
    if (index < 0 || index >= _texts.length) return;
    await _showEditDialog(
      initial: _texts[index],
      onSave: (value) {
        setState(() {
          _texts[index] = value;
        });
      },
    );
  }

  void _preview(String text) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        insetPadding: const EdgeInsets.all(18),
        shape: CardThemeX.shape,
        child: Padding(
          padding: CardThemeX.cardPadding,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Vista previa', style: CardThemeX.titleLg(context)),
              const SizedBox(height: 10),
              Text(text,
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, height: 1.25)),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cerrar'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final total = _texts.length;
    final mustPick = widget.mustPick.clamp(1, 10); // límite razonable

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Encabezado de estado + acciones
        Row(
          children: [
            Icon(Icons.pan_tool_alt_rounded, color: CardThemeX.accent),
            const SizedBox(width: 8),
            Text(
              'Elige $mustPick carta${mustPick == 1 ? '' : 's'}',
              style: CardThemeX.title(context),
            ),
            const Spacer(),
            Text(
              '${_selected.length}/$mustPick',
              style: CardThemeX.monoSmall(context),
            ),
            const SizedBox(width: 8),
            Tooltip(
              message: 'Añadir carta personalizada',
              child: IconButton(
                onPressed: _addCustomCard,
                icon: const Icon(Icons.add_comment_rounded),
              ),
            ),
            Tooltip(
              message: 'Limpiar selección',
              child: IconButton(
                onPressed: _selected.isNotEmpty ? _clear : null,
                icon: const Icon(Icons.clear_all_rounded),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        if (total == 0)
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Text(
                'Sin cartas en mano…',
                style: CardThemeX.subtitleMuted(context),
              ),
            ),
          )
        else
          LayoutBuilder(
            builder: (ctx, constraints) {
              // Tamaño de tarjeta responsivo
              final maxW = constraints.maxWidth;
              // Mínimo 150, máximo 240
              double itemWidth = 180;
              if (maxW > 1100) {
                itemWidth = 240;
              } else if (maxW > 900) {
                itemWidth = 220;
              } else if (maxW < 360) {
                itemWidth = 150;
              }

              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: List.generate(total, (i) {
                  final picked = _selected.contains(i);
                  final text = _texts[i];

                  return Semantics(
                    button: true,
                    selected: picked,
                    label: 'Carta ${i + 1}',
                    hint: picked ? 'Seleccionada' : 'No seleccionada',
                    child: AnimatedScale(
                      duration: const Duration(milliseconds: 120),
                      scale: picked ? 0.96 : 1.0,
                      child: InkWell(
                        onTap: () => _toggle(i),
                        onLongPress: () => _preview(text),
                        borderRadius: BorderRadius.circular(CardThemeX.radius),
                        child: Stack(
                          children: [
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 150),
                              width: itemWidth,
                              padding: CardThemeX.cardPaddingTight,
                              decoration: CardThemeX.whiteCard(context).copyWith(
                                border: Border.all(
                                  color: picked
                                      ? CardThemeX.accent
                                      : Colors.black.withOpacity(.08),
                                  width: picked ? 2 : 1,
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Texto de la carta
                                  Text(
                                    text,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                      height: 1.2,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  // Acción de edición (visible siempre)
                                  Align(
                                    alignment: Alignment.bottomRight,
                                    child: TextButton.icon(
                                      style: TextButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 6),
                                        minimumSize: Size.zero,
                                        tapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                      ),
                                      onPressed: () => _editCard(i),
                                      icon: const Icon(Icons.edit, size: 16),
                                      label: const Text(
                                        'Editar',
                                        style: TextStyle(fontSize: 12),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            // Badge de selección
                            if (picked)
                              Positioned(
                                right: 10,
                                top: 10,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 4),
                                  decoration:
                                  CardThemeX.badge(CardThemeX.accent),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.check,
                                          size: 14, color: Colors.white),
                                      SizedBox(width: 4),
                                      Text('Elegida',
                                          style: TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.w900,
                                              fontSize: 11)),
                                    ],
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
              );
            },
          ),

        const SizedBox(height: 14),

        // CTA enviar jugada
        Align(
          alignment: Alignment.centerRight,
          child: Tooltip(
            message: _canSubmit
                ? 'Enviar tu jugada'
                : 'Selecciona exactamente $mustPick',
            child: FilledButton.icon(
              onPressed: _canSubmit ? _submit : null,
              icon: const Icon(Icons.send_rounded),
              label: Text('Jugar (${_selected.length}/$mustPick)'),
            ),
          ),
        ),
      ],
    );
  }
}
