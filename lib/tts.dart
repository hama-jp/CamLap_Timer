import 'package:flutter_tts/flutter_tts.dart';

class TextToSpeechService {
  final FlutterTts _flutterTts = FlutterTts();

  TextToSpeechService() {
    // その他の設定（音声の高さ、速度など）はここで行う
  }

  Future<void> setLanguage(String language) async {
    if (language == 'Japanese') {
      await _flutterTts.setLanguage('ja-JP');
    } else if (language == 'English') {
      await _flutterTts.setLanguage('en-US');
    }
  }

  Future<void> speak(String text) async {
    _flutterTts.speak(text);
  }

  void dispose() {
    _flutterTts.stop(); // 現在の読み上げを停止
  }
}
