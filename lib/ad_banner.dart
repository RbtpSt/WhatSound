import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

// Google-provided Android test ad unit. Replace only after AdMob setup,
// consent flow and Play Console privacy declarations are complete.
class WhatSoundAdBanner extends StatefulWidget {
  const WhatSoundAdBanner({super.key});

  @override
  State<WhatSoundAdBanner> createState() => _WhatSoundAdBannerState();
}

class _WhatSoundAdBannerState extends State<WhatSoundAdBanner> {
  BannerAd? _ad;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    final ad = BannerAd(
      adUnitId: 'ca-app-pub-3940256099942544/6300978111',
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          if (mounted) setState(() => _loaded = true);
        },
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
          if (mounted) setState(() { _loaded = false; _ad = null; });
        },
      ),
    );
    _ad = ad;
    ad.load();
  }

  @override
  void dispose() {
    _ad?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ad = _ad;
    if (!_loaded || ad == null) return const SizedBox.shrink();
    return SizedBox(
      width: ad.size.width.toDouble(),
      height: ad.size.height.toDouble(),
      child: AdWidget(ad: ad),
    );
  }
}
