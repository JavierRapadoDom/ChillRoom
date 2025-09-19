// lib/services/reward_ads_service.dart
import 'dart:async';
import 'package:flutter/foundation.dart' show defaultTargetPlatform, TargetPlatform, kIsWeb;
import 'package:google_mobile_ads/google_mobile_ads.dart';

class RewardAdsService {
  RewardAdsService._();
  static final instance = RewardAdsService._();

  // ⚠️ Tu bloque de anuncio recompensado (Android)
  static const String _rewardedUnitAndroid = 'ca-app-pub-8588628678375129/8215251849';
  // Si más adelante usas iOS, define su ID aquí:
  static const String _rewardedUnitIOS = 'YOUR_IOS_REWARDED_UNIT_ID';

  RewardedAd? _rewarded;
  bool _isLoading = false;
  bool _sdkInited = false;

  // Solo soportado en Android/iOS nativos (no Web ni Desktop)
  bool get _adsSupported =>
      !kIsWeb &&
          (defaultTargetPlatform == TargetPlatform.android ||
              defaultTargetPlatform == TargetPlatform.iOS);

  String get _unitId {
    if (defaultTargetPlatform == TargetPlatform.iOS) return _rewardedUnitIOS;
    return _rewardedUnitAndroid;
  }

  Future<void> _ensureInit() async {
    if (!_adsSupported) return; // Evita MissingPlugin en PC/web
    if (_sdkInited) return;
    try {
      await MobileAds.instance.initialize();
      _sdkInited = true;
    } catch (_) {
      // Si el plugin no está disponible en este build/plataforma, no romper el arranque
      _sdkInited = false;
    }
  }

  /// 🔹 Precarga el anuncio recompensado en memoria
  Future<void> preload() async {
    if (!_adsSupported) return; // <-- clave para PC
    await _ensureInit();
    if (!_sdkInited) return;

    if (_rewarded != null || _isLoading) return;
    _isLoading = true;

    try {
      await RewardedAd.load(
        adUnitId: _unitId,
        request: const AdRequest(),
        rewardedAdLoadCallback: RewardedAdLoadCallback(
          onAdLoaded: (ad) {
            _rewarded = ad;
            _isLoading = false;
          },
          onAdFailedToLoad: (err) {
            _rewarded = null;
            _isLoading = false;
            // Reintenta tras 10 segundos
            Future.delayed(const Duration(seconds: 10), preload);
          },
        ),
      );
    } catch (_) {
      // Si algo va mal (plugin ausente, etc.), no lances excepción en PC
      _rewarded = null;
      _isLoading = false;
    }
  }

  /// 🔹 Muestra el anuncio y devuelve true si el usuario ganó la recompensa
  Future<bool> showRewardedAd() async {
    if (!_adsSupported) return false; // <-- clave para PC
    await _ensureInit();
    if (!_sdkInited) return false;

    if (_rewarded == null) {
      await preload();
      if (_rewarded == null) return false;
    }

    final completer = Completer<bool>();
    bool rewarded = false;

    _rewarded!.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _rewarded = null;
        preload(); // vuelve a precargar
        if (!completer.isCompleted) completer.complete(rewarded);
      },
      onAdFailedToShowFullScreenContent: (ad, err) {
        ad.dispose();
        _rewarded = null;
        preload();
        if (!completer.isCompleted) completer.complete(false);
      },
    );

    try {
      _rewarded!.setImmersiveMode(true);
      await _rewarded!.show(onUserEarnedReward: (ad, reward) {
        rewarded = true;
      });
    } catch (_) {
      _rewarded?.dispose();
      _rewarded = null;
      preload();
      if (!completer.isCompleted) completer.complete(false);
    }

    return completer.future;
  }
}
