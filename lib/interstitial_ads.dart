import 'package:google_mobile_ads/google_mobile_ads.dart';

/// Interstitials are only eligible after user-initiated navigation.
/// They are not shown on a timer, during audio playback or sharing.
class WhatSoundInterstitialAds {
  static const adUnitId = 'ca-app-pub-3940256099942544/1033173712';
  InterstitialAd? _ready;
  int _navigationCount = 0;
  DateTime? _lastShown;
  bool _loading = false;
  bool _showing = false;

  void preload() {
    if (_loading || _ready != null || _showing) return;
    _loading = true;
    InterstitialAd.load(
      adUnitId: adUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _loading = false;
          _ready = ad;
        },
        onAdFailedToLoad: (_) => _loading = false,
      ),
    );
  }

  void onNavigation({required bool isAudioPlaying, required bool isSharing}) {
    _navigationCount++;
    if (_navigationCount < 6 || isAudioPlaying || isSharing || _showing) return;
    final now = DateTime.now();
    if (_lastShown != null && now.difference(_lastShown!) < const Duration(minutes: 10)) return;
    final ad = _ready;
    if (ad == null) { preload(); return; }
    _ready = null;
    _navigationCount = 0;
    _showing = true;
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        _showing = false;
        ad.dispose();
        preload();
      },
      onAdFailedToShowFullScreenContent: (ad, _) {
        _showing = false;
        ad.dispose();
        preload();
      },
    );
    _lastShown = now;
    ad.show();
  }

  void dispose() => _ready?.dispose();
}
