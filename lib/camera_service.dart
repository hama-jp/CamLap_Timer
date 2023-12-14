import 'package:camera/camera.dart';
import 'package:flutter/cupertino.dart';

class CameraService {
  CameraController? controller;

  Future<void> initializeCamera() async {
    try {
      final cameras = await availableCameras();
      final firstCamera = cameras.first;

      controller = CameraController(
          firstCamera,
          ResolutionPreset.low,
          imageFormatGroup: ImageFormatGroup.yuv420,
          enableAudio: false,
      );
      await controller?.initialize();
    } on CameraException catch (e) {
      // カメラのエラーをハンドリング
      debugPrint('カメラの初期化に失敗しました: ${e.code}\n${e.description}');
      // 必要に応じて、エラーをUIに表示したり、状態を更新したりする
    } catch (e) {
      // その他のエラーをハンドリング
      debugPrint('予期せぬエラーが発生しました: $e');
      // 必要に応じて、エラーをUIに表示したり、状態を更新したりする
    }
  }
}
