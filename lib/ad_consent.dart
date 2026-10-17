import 'dart:async';
import 'package:google_mobile_ads/google_mobile_ads.dart';

/// Check Google UMP before any ad request; fail closed if consent cannot be checked.
class WhatSoundAdConsent {
  static Future<bool> request() async {
    final result = Completer<bool>();
    ConsentInformation.instance.requestConsentInfoUpdate(
      ConsentRequestParameters(),
      () async {
        try {
          await ConsentForm.loadAndShowConsentFormIfRequired((_) async {
            final canRequest = await ConsentInformation.instance.canRequestAds();
            if (!result.isCompleted) result.complete(canRequest);
          });
        } catch (_) {
          if (!result.isCompleted) result.complete(false);
        }
      },
      (_) {
        if (!result.isCompleted) result.complete(false);
      },
    );
    return result.future.timeout(const Duration(seconds: 25), onTimeout: () => false);
  }
}
