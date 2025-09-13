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

  String get _unitId {
    if (defaultTargetPlatform == TargetPlatform.iOS) return _rewardedUnitIOS;
    return _rewardedUnitAndroid;
  }

  /// 🔹 Precarga el anuncio recompensado en memoria
  Future<void> preload() async {
    if (kIsWeb) return;
    if (_rewarded != null || _isLoading) return;
    _isLoading = true;

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
  }

  /// 🔹 Muestra el anuncio y devuelve true si el usuario ganó la recompensa
  Future<bool> showRewardedAd() async {
    if (kIsWeb) return false;
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

    _rewarded!.setImmersiveMode(true);

    _rewarded!.show(onUserEarnedReward: (ad, reward) {
      rewarded = true;
    });

    return completer.future;
  }
}
