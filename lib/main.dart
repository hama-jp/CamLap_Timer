import 'dart:collection';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'tts.dart';
import 'object_detector_service.dart';
import 'settings_page.dart';
import 'camera_service.dart';

void main() => runApp(const CamLapTimerApp());

class CamLapTimerApp extends StatelessWidget {
  const CamLapTimerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'CameLap Timer',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const MainPage(),
    );
  }
}

class MainPage extends StatefulWidget {
  const MainPage({super.key});

  @override
  _MainPageState createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> with WidgetsBindingObserver {
  final CameraService _cameraService = CameraService();
  final ObjectDetectorService _objectDetectorService = ObjectDetectorService();
  final TextToSpeechService _ttsService = TextToSpeechService();
  final ScrollController _scrollController = ScrollController();

  bool _isAppForeground = true;
  bool _isTimerRunning = false;
  DateTime? _startTime;
  DateTime? _lastDetectionTime;
  final List<String> _lapTimes = [];
  final List<FlSpot> _graphData = List.generate(20, (index) => FlSpot((index + 1).toDouble(), 0));

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeCamera();
    _loadSettingsAndSetLanguage();
  }

  Future<void> _loadSettingsAndSetLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    final language = prefs.getString('language') ?? 'Japanese';
    final threshold = prefs.getDouble('detectionSensitivity') ?? 0.005;

    await _ttsService.setLanguage(language);
    _objectDetectorService.setThreshold(threshold);
  }

  // カメラの初期化
  Future<void> _initializeCamera() async {
    await _cameraService.initializeCamera();
    _cameraService.controller!.startImageStream((cameraImage) {
      _processCameraImage(cameraImage);
    });
    setState(() {});
  }

  void _processCameraImage(CameraImage cameraImage) async {
    final now = DateTime.now();

    if (!_isTimerRunning) {
      return; // タイマーが停止している場合は処理を行わない
    }

    // 検出のチャタリング防止のためタイマを設定
    if (_isTimerRunning && _lastDetectionTime == null ||
        now.difference(_lastDetectionTime!).inSeconds >= 1) {
      final isDetect =
          await _objectDetectorService.detectObjectsFromImage(cameraImage);
      if (isDetect) {
        _recordLapTime();
        _lastDetectionTime = now;
      }
    }
  }

  // タイマー機能
  void _clearLapTimes() {
    setState(() {
      _lapTimes.clear();

      // _graphDataを初期化
      _graphData.clear();
      for (int i = 1; i <= 20; i++) {
        _graphData.add(FlSpot(i.toDouble(), 0));
      }
    });
  }

  void _startTimer() {
    setState(() {
      _isTimerRunning = true;
      _startTime = DateTime.now();
    });
  }

  void _stopTimer() {
    setState(() {
      _isTimerRunning = false;
    });
  }

  Future<void> _recordLapTime() async {
    final now = DateTime.now();
    final lapDuration = now.difference(_startTime!);
    final prefs = await SharedPreferences.getInstance();
    final language = prefs.getString('language') ?? 'Japanese';

    // setStateの呼び出しを最小限にする
    if (_lapTimes.isEmpty || _lapTimes.last != _formatDuration(lapDuration)) {
      setState(() {
        _lapTimes.add(_formatDuration(lapDuration));

        _updateGraphData();
        _startTime = now;
      });
    }


    // ラップタイムを読み上げる
    if (_isAppForeground && language != 'None') {
      _ttsService.setLanguage(language);
      _ttsService.speak(_ttsFormatDuration(lapDuration, language));
    }

    // リストの最後までスクロール
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 100),
          curve: Curves.easeOut,
        );
      }
    });
  }

  String _formatDuration(Duration duration) {
    return '${duration.inMinutes.remainder(60).toString().padLeft(2, '0')}:${duration.inSeconds.remainder(60).toString().padLeft(2, '0')}.${(duration.inMilliseconds.remainder(1000) / 10).round().toString().padLeft(2, '0')}';
  }

  // ラップタイム文字列からDurationを取得するヘルパーメソッド
  Duration _lapDurationFromString(String lapTime) {
    final parts = lapTime.split(':');
    final minutes = int.parse(parts[0]);
    final secondsAndMillis = parts[1].split('.');
    final seconds = int.parse(secondsAndMillis[0]);
    final millis = int.parse(secondsAndMillis[1]);
    return Duration(minutes: minutes, seconds: seconds, milliseconds: millis);
  }

  String _ttsFormatDuration(Duration duration, String language) {
    final seconds = duration.inSeconds.remainder(60);
    final tenths = (duration.inMilliseconds.remainder(1000) / 100).floor();

    if (language == 'Japanese') {
      return "$seconds秒$tenths";
    } else if (language == 'English') {
      return "$seconds point $tenths";
    } else {
      return ''; // 言語が設定されていない、または音声なしの場合
    }
  }

  // グラフ表示
  void _updateGraphData() {
    double time = _parseDuration(_lapTimes.last);
    int lapNumber = _lapTimes.length;

    // _graphDataの更新
    if (lapNumber <= 20) {
      // ラップ数が20以下の場合、対応する位置のデータを更新
      _graphData[lapNumber - 1] = FlSpot(lapNumber.toDouble(), time);
    } else {
      // ラップ数が20を超える場合、最初のデータを削除し新しいデータを追加
      _graphData.removeAt(0);
      _graphData.add(FlSpot(lapNumber.toDouble(), time));
    }
  }

  LineChartData _lapTimeChartData() {
    double minX = _graphData.first.x;
    double maxX = _lapTimes.length < 20 ? 20 : _lapTimes.length.toDouble();

    return LineChartData(
      gridData: const FlGridData(show: false),
      titlesData: const FlTitlesData(
        // タイトルデータの設定...
      ),
      borderData: FlBorderData(
        show: true,
        border: Border.all(color: const Color(0xff37434d), width: 1),
      ),
      minX: minX,
      maxX: maxX,
      minY: 0,
      maxY: _graphData.isNotEmpty ? _graphData.map((spot) => spot.y).reduce(max).ceilToDouble() : 1,
      lineBarsData: [
        LineChartBarData(
          spots: _graphData.toList(),
          isCurved: false,
          barWidth: 2,
          color: Colors.blue,
          dotData: const FlDotData(show: true),
          belowBarData: BarAreaData(show: false),
        ),
      ],
    );
  }

  double _parseDuration(String formattedTime) {
    var parts = formattedTime.split(':');
    var minutes = double.parse(parts[0]);
    var secondsAndMilliseconds = parts[1].split('.');
    var seconds = double.parse(secondsAndMilliseconds[0]);
    var milliseconds = double.parse(secondsAndMilliseconds[1]) / 100;
    return minutes * 60 + seconds + milliseconds;
  }

  // UIのbuild
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: Container(
          padding: const EdgeInsets.all(8.0),
          child:Image.asset('assets/icon.png'),
          ),
        title: const Text('CamLap Timer'),
        actions: <Widget>[
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => SettingsPage()),
              );
            },
          ),
        ],
        elevation: 10,
      ),
      body: Column(
        children: <Widget>[
          const SizedBox(
            height: 15,
          ),
          // カメラビュー
          Expanded(
            child: _cameraService.controller == null
                ? const Center(child: CircularProgressIndicator())
                : CameraPreview(_cameraService.controller!),
          ),
          // スタート・ストップボタン
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton(
                onPressed: _isTimerRunning ? null : _startTimer,
                child: const Text('Start'),
              ),
              const SizedBox(width: 20),
              ElevatedButton(
                onPressed: _isTimerRunning ? _stopTimer : null,
                child: const Text('Stop'),
              ),
              const SizedBox(width: 20),
              ElevatedButton(
                onPressed: _clearLapTimes,
                child: const Text('Clear Laps'),
              ),
            ],
          ),
          // ラップタイムの表示
          Expanded(
            child: Row(
              children: [
                Expanded(
                  child:ListView.builder(
                  controller: _scrollController,
                  itemCount: _lapTimes.length,
                  itemBuilder: (context, index) {
                    // ラップタイムの色設定
                    Color iconColor = Colors.black;
                    if (index > 0) {
                      final previousDuration =
                          _lapDurationFromString(_lapTimes[index - 1]);
                      final currentDuration =
                          _lapDurationFromString(_lapTimes[index]);
                      if (currentDuration < previousDuration) {
                        // ラップタイムが短くなった場合
                        iconColor = Colors.green;
                      } else if (currentDuration > previousDuration) {
                        // ラップタイムが長くなった場合
                        iconColor = Colors.red;
                      }
                    }
                    return Card(
                      child: ListTile(
                        title: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: <Widget>[
                            Icon(Icons.timer, color: iconColor), // Your icon
                            const SizedBox(width: 10), // Space between icon and text
                            Text(
                              'Lap ${index + 1}: ${_lapTimes[index]}',
                              style: const TextStyle(
                                  fontSize: 18.0,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                  ),
                ),
                Expanded(
                    child: LineChart(
                      _lapTimeChartData(),
                    ))
               ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.paused) {
      // アプリがバックグラウンドに移行
      _isAppForeground = false;
    } else if (state == AppLifecycleState.resumed) {
      // アプリがフォアグラウンドに戻る
      _isAppForeground = true;
      _initializeCamera();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cameraService.controller?.dispose();
    _scrollController.dispose();
    _ttsService.dispose();
    super.dispose();
  }
}
