// lib/services/reward_ads_service.dart
import 'dart:async';
import 'package:flutter/foundation.dart' show defaultTargetPlatform, TargetPlatform, kIsWeb;
import 'package:stack_appodeal_flutter/stack_appodeal_flutter.dart';

/// Servicio centrado en Rewarded + Interstitial de Appodeal
/// - Mantiene caché manual (autocache desactivado)
/// - Expone los mismos métodos que ya usa tu UI: preload() y showRewardedAd()
class RewardAdsService {
  RewardAdsService._();
  static final instance = RewardAdsService._();

  bool _sdkReady = false;
  bool _initInProgress = false;

  // Flags de cache
  bool _rewardedLoaded = false;
  bool _interstitialLoaded = false;

  // Soporte de plataforma
  bool get _adsSupported =>
      !kIsWeb &&
          (defaultTargetPlatform == TargetPlatform.android ||
              defaultTargetPlatform == TargetPlatform.iOS);

  /// Llama una vez al arrancar la app (p.ej. en main.dart)
  Future<void> ensureInitialized({
    required String appodealAppKey,
    bool testing = false,
    bool verboseLogs = true,
  }) async {
    if (!_adsSupported) return;
    if (_sdkReady || _initInProgress) return;

    _initInProgress = true;
    try {
      // Config global: desactivar autocache para controlar manualmente
      Appodeal.setAutoCache(AppodealAdType.Interstitial, false);
      Appodeal.setAutoCache(AppodealAdType.RewardedVideo, false);

      // Modo test y logs
      Appodeal.setTesting(testing);
      Appodeal.setLogLevel(verboseLogs ? Appodeal.LogLevelVerbose : Appodeal.LogLevelNone);

      // Callbacks persistentes (mantienen estados de cache)
      _attachPersistentRewardedCallbacks();
      _attachPersistentInterstitialCallbacks();

      // Inicializar SDK
      await Appodeal.initialize(
        appKey: appodealAppKey,
        adTypes: const [
          AppodealAdType.Interstitial,
          AppodealAdType.RewardedVideo,
        ],
        onInitializationFinished: (errors) {
          // Puedes loggear 'errors' si quieres
        },
      );

      _sdkReady = true;

      // Precargar ambos formatos
      cacheRewarded();
      cacheInterstitial();
    } finally {
      _initInProgress = false;
    }
  }

  // ------------------ REWARDED ------------------

  void _attachPersistentRewardedCallbacks() {
    Appodeal.setRewardedVideoCallbacks(
      onRewardedVideoLoaded: (isPrecache) {
        _rewardedLoaded = true;
      },
      onRewardedVideoFailedToLoad: () {
        _rewardedLoaded = false;
      },
      onRewardedVideoShown: () {},
      onRewardedVideoShowFailed: () {
        _rewardedLoaded = false;
      },
      onRewardedVideoFinished: (amount, reward) {
        // La recompensa “de verdad” la resolvemos en showRewardedAd mediante callbacks temporales.
      },
      onRewardedVideoClosed: (isFinished) {
        // Tras cierre: invalida flag y recachea
        _rewardedLoaded = false;
        cacheRewarded();
      },
      onRewardedVideoExpired: () {
        _rewardedLoaded = false;
      },
      onRewardedVideoClicked: () {},
    );
  }

  /// Hace cache del Rewarded
  void cacheRewarded() {
    if (!_adsSupported || !_sdkReady) return;
    if (!_rewardedLoaded) {
      Appodeal.cache(AppodealAdType.RewardedVideo);
    }
  }

  /// Espera hasta que el Rewarded esté listo (con timeout)
  Future<bool> _ensureRewardedReady({Duration timeout = const Duration(seconds: 8)}) async {
    if (!_adsSupported || !_sdkReady) return false;
    if (_rewardedLoaded) return true;

    cacheRewarded();
    final sw = Stopwatch()..start();
    while (!_rewardedLoaded && sw.elapsed < timeout) {
      await Future.delayed(const Duration(milliseconds: 120));
    }
    return _rewardedLoaded;
  }

  /// API usada por tu UI actual. Devuelve true si el usuario ganó la recompensa
  Future<bool> showRewardedAd() async {
    if (!_adsSupported || !_sdkReady) return false;
    if (!await _ensureRewardedReady()) return false;

    final completer = Completer<bool>();
    var rewarded = false;

    // Callbacks temporales solo para esta presentación
    Appodeal.setRewardedVideoCallbacks(
      onRewardedVideoLoaded: (isPrecache) {
        _rewardedLoaded = true;
      },
      onRewardedVideoFailedToLoad: () {
        _rewardedLoaded = false;
      },
      onRewardedVideoShown: () {},
      onRewardedVideoShowFailed: () {
        _rewardedLoaded = false;
        if (!completer.isCompleted) completer.complete(false);
      },
      onRewardedVideoFinished: (amount, reward) {
        rewarded = true;
      },
      onRewardedVideoClosed: (isFinished) {
        _rewardedLoaded = false;
        cacheRewarded(); // recachear para siguiente
        if (!completer.isCompleted) completer.complete(rewarded);
      },
      onRewardedVideoExpired: () {
        _rewardedLoaded = false;
      },
      onRewardedVideoClicked: () {},
    );

    // Mostrar
    Appodeal.show(AppodealAdType.RewardedVideo);

    // Timeout de seguridad
    Future.delayed(const Duration(seconds: 30), () {
      if (!completer.isCompleted) completer.complete(false);
    });

    final ok = await completer.future;

    // Restaurar callbacks persistentes
    _attachPersistentRewardedCallbacks();

    return ok;
  }

  // ------------------ INTERSTITIAL ------------------

  void _attachPersistentInterstitialCallbacks() {
    Appodeal.setInterstitialCallbacks(
      onInterstitialLoaded: (isPrecache) {
        _interstitialLoaded = true;
      },
      onInterstitialFailedToLoad: () {
        _interstitialLoaded = false;
      },
      onInterstitialShown: () {},
      onInterstitialShowFailed: () {
        _interstitialLoaded = false;
      },
      onInterstitialClicked: () {},
      onInterstitialClosed: () {
        _interstitialLoaded = false;
        cacheInterstitial();
      },
      onInterstitialExpired: () {
        _interstitialLoaded = false;
      },
    );
  }

  /// Hace cache del Interstitial
  void cacheInterstitial() {
    if (!_adsSupported || !_sdkReady) return;
    if (!_interstitialLoaded) {
      Appodeal.cache(AppodealAdType.Interstitial);
    }
  }

  Future<bool> _ensureInterstitialReady({Duration timeout = const Duration(seconds: 6)}) async {
    if (!_adsSupported || !_sdkReady) return false;
    if (_interstitialLoaded) return true;

    cacheInterstitial();
    final sw = Stopwatch()..start();
    while (!_interstitialLoaded && sw.elapsed < timeout) {
      await Future.delayed(const Duration(milliseconds: 120));
    }
    return _interstitialLoaded;
  }

  /// Útil si quieres mostrar interstitial bajo ciertas condiciones (cada 5 swipes, etc.)
  Future<bool> showInterstitial() async {
    if (!_adsSupported || !_sdkReady) return false;
    if (!await _ensureInterstitialReady()) return false;

    final completer = Completer<bool>();
    var opened = false;

    Appodeal.setInterstitialCallbacks(
      onInterstitialLoaded: (isPrecache) {
        _interstitialLoaded = true;
      },
      onInterstitialFailedToLoad: () {
        _interstitialLoaded = false;
        if (!completer.isCompleted) completer.complete(false);
      },
      onInterstitialShown: () {
        opened = true;
      },
      onInterstitialShowFailed: () {
        _interstitialLoaded = false;
        if (!completer.isCompleted) completer.complete(false);
      },
      onInterstitialClicked: () {},
      onInterstitialClosed: () {
        _interstitialLoaded = false;
        cacheInterstitial();
        if (!completer.isCompleted) completer.complete(opened);
      },
      onInterstitialExpired: () {
        _interstitialLoaded = false;
      },
    );

    Appodeal.show(AppodealAdType.Interstitial);

    // Timeout de seguridad
    Future.delayed(const Duration(seconds: 20), () {
      if (!completer.isCompleted) completer.complete(false);
    });

    final ok = await completer.future;

    // Restaurar callbacks persistentes
    _attachPersistentInterstitialCallbacks();

    return ok;
  }

  // ------------------ API que ya usas en HomeScreen ------------------

  /// Tu `home_screen` llama a preload(): aquí precargamos ambos
  Future<void> preload() async {
    cacheRewarded();
    cacheInterstitial();
  }
}
