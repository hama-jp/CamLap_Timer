import 'package:camera/camera.dart';
import 'package:flutter/cupertino.dart';

class CameraService {
  CameraController? controller;
  final int maxRetries = 3;  // 再試行の最大回数
  final int retryDelay = 2;  // 再試行までの待機時間（秒）

  Future<void> initializeCamera() async {
    int retries = 0;
    while (retries < maxRetries) {
      try {
        final cameras = await availableCameras();
        if (cameras.isEmpty) {
          debugPrint('利用可能なカメラが見つかりません。');
          // UIに適切なメッセージを表示する処理をここに追加
          return;
        }
        final firstCamera = cameras.first;

        controller = CameraController(
          firstCamera,
          ResolutionPreset.low,
          imageFormatGroup: ImageFormatGroup.yuv420,
          enableAudio: false,
        );
        await controller?.initialize();
        return; // 初期化が成功したらループを抜ける
      } on CameraException catch (e) {
        debugPrint('カメラの初期化に失敗しました: ${e.code}\n${e.description}');
        retries++;
        if (retries < maxRetries) {
          await Future.delayed(Duration(seconds: retryDelay));
        }
      } catch (e) {
        // その他のエラーをハンドリング
        debugPrint('予期せぬエラーが発生しました: $e');
        return; // 予期せぬエラーの場合は再試行しない
      }
    }
    debugPrint('カメラの初期化に失敗し、再試行の最大回数に達しました。');
    // 必要に応じて、エラーをUIに表示したり、状態を更新したりする
  }
}
