// import 'dart:ui';
//
// import 'package:camera/camera.dart';
// import 'package:flutter/foundation.dart';
// import 'package:google_ml_kit/google_ml_kit.dart';
//
// class ObjectDetectorService {
//
//   final objectDetector = GoogleMlKit.vision.objectDetector(
//       options: ObjectDetectorOptions(
//           mode: DetectionMode.stream,
//           classifyObjects: false,
//           multipleObjects: false));
//   Size? _cachedImageSize;
//   InputImageFormat? _cachedImageFormat;
//
//
//   Future<List<DetectedObject>> detectObjectsFromImage(CameraImage cameraImage) async {
//     try {
//       // cameraImageの諸元をキャッシュ
//       if (_cachedImageSize == null) {
//         final double width = cameraImage.width.toDouble();
//         final double height = cameraImage.height.toDouble();
//         _cachedImageSize = Size(width, height);
//       }
//       _cachedImageFormat ??= InputImageFormatValue.fromRawValue(cameraImage.format.raw) ?? InputImageFormat.nv21;
//
//       final WriteBuffer allBytes = WriteBuffer();
//       for (Plane plane in cameraImage.planes) {
//         allBytes.putUint8List(plane.bytes);
//       }
//       final bytes = allBytes
//           .done()
//           .buffer
//           .asUint8List();
//
//       final InputImageRotation imageRotation = InputImageRotationValue
//           .fromRawValue(cameraImage.format.raw) ??
//           InputImageRotation.rotation0deg;
//
//       final inputImage = InputImage.fromBytes(
//           bytes: bytes,
//           metadata: InputImageMetadata(
//             size: _cachedImageSize!,
//             rotation: imageRotation,
//             format: _cachedImageFormat!,
//             bytesPerRow: 0,
//           )
//       );
//
//       return await objectDetector.processImage(inputImage);
//     }  catch (e) {
//       debugPrint('Error detecting objects: $e');
//       return []; // 空のリストを返す
//     }
//   }
//
//   void dispose() {
//     objectDetector.close();
//   }
// }

import 'dart:async';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';

class ObjectDetectorService {
  final List<CameraImage> frameBuffer = [];
  final int bufferSize = 10; // 移動平均のフレーム数　TODO: チューニングが必要
  double detectionThreshold = 0.005; // 変化を検出するための閾値
  bool detecting = false; // 検出中かどうかを示すフラグ
  final Duration resetDelay = const Duration(milliseconds: 50); // リセットまでの遅延時間

  void setThreshold(double threshold) {
    detectionThreshold = threshold;
  }

  Future<bool> detectObjectsFromImage(CameraImage cameraImage) async {
    if (detecting) {
      return false; // 検出中の場合は何もしない
    }

    frameBuffer.add(cameraImage);

    if (frameBuffer.length >= bufferSize) {
      final double diff = calculateFrameDifference(frameBuffer);
      frameBuffer.removeAt(0);

      if (diff > detectionThreshold) {
        detecting = true; // 検出中フラグをセット
        frameBuffer.clear(); // バッファーをクリア
        // if (kDebugMode) {
        //   print("Detected!: $diff");
        //   // 一定時間後にdetectingをfalseにリセット
        // }
        Timer(resetDelay, () {
          detecting = false;
        });
        return true; // 変化がある場合、trueを返す
      }
    }
    return false; // 変化がない場合、falseを返す
  }

  double calculateFrameDifference(List<CameraImage> buffer) {
    double sum = 0.0;

    for (int i = 1; i < buffer.length; i++) {
      final double diff = calculateImageDifference(buffer[i - 1], buffer[i]);
      sum += diff;
    }

    return sum / buffer.length;
  }

  // double calculateImageDifference(CameraImage prevImage, CameraImage currImage) {
  //   final Uint8List prevBytes = prevImage.planes[0].bytes;
  //   final Uint8List currBytes = currImage.planes[0].bytes;
  //
  //   double diff = 0.0;
  //   for (int i = 0; i < prevBytes.length; i++) {
  //     diff += (prevBytes[i] - currBytes[i]).abs().toDouble();
  //   }
  //
  //   return diff / (prevBytes.length * 255.0);
  // }
  double calculateImageDifference(
      CameraImage prevImage, CameraImage currImage) {
    // Y成分のみを取得 (YUV420フォーマットの場合)
    final Uint8List prevY = prevImage.planes[0].bytes;
    final Uint8List currY = currImage.planes[0].bytes;

    double diff = 0.0;
    // ピクセルのサブサンプリング設定
    const int samplingInterval = 10;

    // Y成分のみを使用してサブセットピクセル比較を行う
    for (int i = 0; i < prevY.length; i += samplingInterval) {
      diff += (prevY[i] - currY[i]).abs().toDouble();
    }

    // 全体のピクセル数で割る前に、サンプリング間隔で除算
    return diff / ((prevY.length / samplingInterval) * 255.0);
  }
}
