import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'tts.dart';
import 'object_detector_service.dart';
import 'settings_page.dart';
import 'camera_service.dart';
import 'ad_service.dart';

void main() {
  //AdMobの初期化処理
  WidgetsFlutterBinding.ensureInitialized();
  MobileAds.instance.initialize();

  runApp(const CamLapTimerApp());
}

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
  final AdService _adService = AdService();
  final TextToSpeechService _ttsService = TextToSpeechService();
  final ScrollController _scrollController = ScrollController();

  bool _isAppForeground = true;
  bool _isTimerRunning = false;
  bool _isBestLap = false;
  DateTime? _startTime;
  DateTime? _lastDetectionTime;

  // // 最小記録時間
  int _minMeasurementTime = 5;

  // 経過時間の表示用
  Duration _currentDuration = Duration.zero;
  String _currentLapTime = '';
  Timer? _timer;

  final List<String> _lapTimes = [];
  String _bestLapTime = '';
  List<String> _bestLapTimesStack = [];

  final List<FlSpot> _graphData = List.generate(20, (index) => FlSpot((index + 1).toDouble(), 0));

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeCamera();
    _loadSettingsAndSetLanguage();
    _adService.initializeBannerAd();
    _startPeriodicTimer();
  }

  Future<void> _loadSettingsAndSetLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    final language = prefs.getString('language') ?? 'Japanese';
    final threshold = prefs.getDouble('detectionSensitivity') ?? 0.005;
    _minMeasurementTime = prefs.getInt('minMeasurementTime')!;

    await _ttsService.setLanguage(language);
    _objectDetectorService.setThreshold(threshold);
  }

  // カメラの初期化
  Future<void> _initializeCamera() async {
    try {
      await _cameraService.initializeCamera();
      if (_cameraService.controller != null) {
        await _cameraService.controller!.startImageStream((cameraImage) {
          _processCameraImage(cameraImage);
        });
        setState(() {});  // カメラが正常に初期化されたことを反映
      } else {
        // カメラが利用不可能な場合の処理
        // 例: UIにエラーメッセージを表示する
        debugPrint('カメラが利用不可能です。');
        // エラー状態を反映するためにUIを更新する
        setState(() {});
      }
    } catch (e) {
      // カメラの初期化中にエラーが発生した場合の処理
      debugPrint('カメラの初期化に失敗: $e');
      // エラーメッセージをUIに表示するために状態を更新する
      setState(() {});
    }
  }

  // カメラによるタイム計測の心臓部
  void _processCameraImage(CameraImage cameraImage) async {
    final now = DateTime.now();

    if (!_isTimerRunning) {
      return; // タイマーが停止している場合は処理を行わない
    }

    // 検出のチャタリング防止のためタイマを設定
    if (_isTimerRunning && _lastDetectionTime == null ||
        now.difference(_lastDetectionTime!).inSeconds >= _minMeasurementTime) {
      final isDetect =
      await _objectDetectorService.detectObjectsFromImage(cameraImage);
      if (isDetect) {
        _lastDetectionTime = now;
        _recordLapTime();
      }
    }
  }

  // 経過時間の表示用タイマー
  void _startPeriodicTimer() {
    _timer = Timer.periodic(const Duration(microseconds: 20), (Timer timer) {
      if (_isTimerRunning && _currentLapTime.isEmpty) {
        setState(() {
          _currentDuration = DateTime.now().difference(_startTime!);
        });
      }
    });
  }

  void _startTimer() {
    setState(() {
      _isTimerRunning = true;
      _startTime = DateTime.now();
    });
  }

  void _clearLapTimes() {
    setState(() {
      _lapTimes.clear();
      _bestLapTime = '';
      _bestLapTimesStack = [];

      // _graphDataを初期化
      _graphData.clear();
      for (int i = 1; i <= 20; i++) {
        _graphData.add(FlSpot(i.toDouble(), 0));
      }
    });
  }

  void _stopTimer() {
    setState(() {
      _isTimerRunning = false;
    });
  }

  // ラップタイムの記録
  Future<void> _recordLapTime() async {
    // final now = DateTime.now();
    final lapDuration = _lastDetectionTime?.difference(_startTime!);
    final prefs = await SharedPreferences.getInstance();
    final language = prefs.getString('language') ?? 'Japanese';
    _minMeasurementTime = prefs.getInt('minMeasurementTime')!;

    // setStateの呼び出しを最小限にする
    if (_lapTimes.isEmpty || _lapTimes.last != _formatDuration(lapDuration!)) {
      setState(() {
        _currentLapTime = _formatDuration(lapDuration!);
        _lapTimes.add(_currentLapTime);
        // _lapTimes.add(_formatDuration(lapDuration!));

        // ベストラップの更新
        if (_bestLapTime.isEmpty || _lapDurationFromString(_lapTimes.last) < _lapDurationFromString(_bestLapTime)) {
          _bestLapTime = _lapTimes.last;
          _bestLapTimesStack.add(_bestLapTime);
          _isBestLap = true;
        }

        _updateGraphData();
        _startTime = _lastDetectionTime;
      });

      // 一定時間、前のラップタイムを表示する
      Future.delayed(const Duration(seconds: 3), () {
        setState(() {
          _currentLapTime = '';
        });
      });
    }

    // ラップタイムを読み上げる
    if (_isAppForeground && language != 'None') {
      _ttsService.setLanguage(language);
      _ttsService.speak(_ttsFormatDuration(lapDuration!, language, _isBestLap));
      _isBestLap = false;
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

  void _removeBestLapTime() {
    setState(() {
      if(_bestLapTimesStack.isNotEmpty) {
        _bestLapTimesStack.removeLast();
        _bestLapTime = _bestLapTimesStack.isNotEmpty ? _bestLapTimesStack.last : '';
      }
    });
  }

  String _formatDuration(Duration duration) {
    return '${duration.inMinutes.remainder(60).toString().padLeft(2, '0')}:${duration.inSeconds.remainder(60).toString().padLeft(2, '0')}.${(duration.inMilliseconds.remainder(1000) / 10).floor().toString().padLeft(2, '0')}';
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

  String _ttsFormatDuration(Duration duration, String language, bool isBestLap) {
    final seconds = duration.inSeconds.remainder(60);
    final tenths = (duration.inMilliseconds.remainder(1000) / 100).floor();
    String prefix = '';

    if (isBestLap) {
      if (language == 'Japanese') {
        prefix = 'ベストラップ！！';
      } else if (language == 'English') {
        prefix = 'best lap';
      }
    }

    if (language == 'Japanese') {
      return "$prefix $seconds秒$tenths";
    } else if (language == 'English') {
      return "$prefix $seconds point $tenths";
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
      gridData: const FlGridData(
        show: true,
      ),
      titlesData: const FlTitlesData(
        show: true,
        bottomTitles: AxisTitles(            // 下側に表示するタイトル設定
          axisNameWidget: Text("Laps",      // タイトル名
            style: TextStyle(
              color: Colors.black,
            ),
          ),
          axisNameSize: 22.0,                     // タイトルの表示エリアの幅
          sideTitles: SideTitles(                 // サイドタイトル設定
            showTitles: true,                     // サイドタイトルの有無
            // interval: 1.0,                        // サイドタイトルの表示間隔
            reservedSize: 25.0,                   // サイドタイトルの表示エリアの幅
            // getTitlesWidget: bottomTitleWidgets,  // サイドタイトルの表示内容
          ),
        ),
        // leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
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
    String displayTime = _currentLapTime.isEmpty ? _formatDuration(_currentDuration) : _currentLapTime;
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
                MaterialPageRoute(builder: (context) => const SettingsPage()),
              );
            },
          ),
        ],
        elevation: 10,
      ),
      body: Column(
        children: <Widget>[
          _adService.getBannerAdWidget(),
          // 最新のラップタイムとベストラップタイムの表示
          Card(
            child: FittedBox(
              fit: BoxFit.fitWidth,
              child: Text(
                // '  Latest Lap:  ${_lapTimes.isNotEmpty ? _lapTimes.last : '00:00:00'} \n  Best Lap:     $_bestLapTime',
                '  Latest Lap:  $displayTime \n  Best Lap:     $_bestLapTime',
                style: const TextStyle(
                  fontSize: 64, // フォントサイズ調整
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                  fontFamily: 'Arial',
                ),
              ),
            ),
          ),

          const SizedBox(height: 15,),
          Card(
            child: FittedBox(
                fit: BoxFit.fitWidth,
                child: Row(
                  children: [
                    const SizedBox(width: 50,),
                    SizedBox(
                    height: 100,
                    child: _cameraService.controller == null
                        ? const Center(child: CircularProgressIndicator())
                        : CameraPreview(_cameraService.controller!),
                  ),
                  IconButton(
                    icon: const Icon(Icons.play_arrow),
                    onPressed: _isTimerRunning ? null : _startTimer,
                    iconSize: 80.0,
                    color: Colors.blueAccent,
                  ),
                  const SizedBox(width: 20),
                  IconButton(
                    icon: const Icon(Icons.stop),
                    onPressed: _isTimerRunning ? _stopTimer : null,
                    iconSize: 80.0,
                    color: Colors.red,
                  ),
                    const SizedBox(width: 20),
                   ElevatedButton(
                    onPressed: _clearLapTimes,
                    child: const Text('Clear Lap List'),
                  ),
                    const SizedBox(width: 20,),
                   ElevatedButton(
                    onPressed: _removeBestLapTime,
                    child: const Text('Remove Best Lap'),
                    ),
                    const SizedBox(width: 50,),
                ],
              ),
            ),
          ),
          const SizedBox(height: 15,),
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
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _cameraService.controller?.dispose();
    _scrollController.dispose();
    _ttsService.dispose();
    _adService.dispose();
    super.dispose();
  }
}
