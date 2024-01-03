import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

class AdService {
  // バナー広告のインスタンス
  BannerAd? _bannerAd;

  // バナー広告がロードされたかの状態
  bool isBannerAdLoaded = false;

  // バナー広告の初期化とロードを行うメソッド
  void initializeBannerAd() {
    _bannerAd = BannerAd(
      adUnitId: 'ca-app-pub-7332804652351227/2031636502',
      size: AdSize.banner,
      request: const AdRequest(
        keywords: <String>['rc', 'rc car','radio control car'],
        contentUrl: 'https://www.tamiya.com/',
        nonPersonalizedAds: true,
      ),
      listener: BannerAdListener(
        onAdLoaded: (Ad ad) {
          // 広告がロードされた際の処理
          isBannerAdLoaded = true;
        },
        onAdFailedToLoad: (Ad ad, LoadAdError error) {
          // 広告のロードに失敗した際の処理
          ad.dispose();
        },
        // 他のイベントリスナー...
      ),
    );

    _bannerAd!.load();
  }

  // バナー広告のWidgetを取得するメソッド
  Widget getBannerAdWidget() {
    if (!isBannerAdLoaded || _bannerAd == null) {
      return const SizedBox.shrink(); // 広告がロードされていない場合は空のウィジェットを返す
    }
    return Container(
      alignment: Alignment.center,
      width: _bannerAd!.size.width.toDouble(),
      height: _bannerAd!.size.height.toDouble(),
      child: AdWidget(ad: _bannerAd!),
    );
  }

  // リソースの解放
  void dispose() {
    _bannerAd?.dispose();
  }
}
