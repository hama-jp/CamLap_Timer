import 'package:fl_chart/fl_chart.dart';

class TimerService {
  bool _isTimerRunning = false;
  DateTime? _startTime;
  DateTime? _lastDetectionTime;
  final List<String> _lapTimes = [];
  String _bestLapTime = '';
  List<FlSpot> _graphData = List.generate(20, (index) => FlSpot((index + 1).toDouble(), 0));

  bool get isTimerRunning => _isTimerRunning;
  List<String> get lapTimes => _lapTimes;
  String get bestLapTime => _bestLapTime;
  List<FlSpot> get graphData => _graphData;

  void startTimer() {
    _isTimerRunning = true;
    _startTime = DateTime.now();
    _lastDetectionTime = DateTime.now();
  }

  void stopTimer() {
    _isTimerRunning = false;
  }

  void clearLapTimes() {
    _lapTimes.clear();
    _bestLapTime = '';
    _graphData = List.generate(20, (index) => FlSpot((index + 1).toDouble(), 0));
  }

  void recordLapTime() {
    if (!_isTimerRunning || _startTime == null) return;

    final lapDuration = DateTime.now().difference(_startTime!);
    _lastDetectionTime = DateTime.now();
    final formattedLapTime = _formatDuration(lapDuration);

    if (_lapTimes.isEmpty || _lapTimes.last != formattedLapTime) {
      _lapTimes.add(formattedLapTime);

      if (_bestLapTime.isEmpty || _lapDurationFromString(_lapTimes.last) < _lapDurationFromString(_bestLapTime)) {
        _bestLapTime = _lapTimes.last;
      }

      _updateGraphData();
      _startTime = _lastDetectionTime;
    }
  }

  String _formatDuration(Duration duration) {
    return '${duration.inMinutes.remainder(60).toString().padLeft(2, '0')}:${duration.inSeconds.remainder(60).toString().padLeft(2, '0')}.${(duration.inMilliseconds.remainder(1000) / 10).floor().toString().padLeft(2, '0')}';
  }

  Duration _lapDurationFromString(String lapTime) {
    final parts = lapTime.split(':');
    final minutes = int.parse(parts[0]);
    final secondsAndMillis = parts[1].split('.');
    final seconds = int.parse(secondsAndMillis[0]);
    final millis = int.parse(secondsAndMillis[1]);
    return Duration(minutes: minutes, seconds: seconds, milliseconds: millis);
  }

  void _updateGraphData() {
    final double time = _parseDuration(_lapTimes.last);
    final int lapNumber = _lapTimes.length;

    if (lapNumber <= 20) {
      _graphData[lapNumber - 1] = FlSpot(lapNumber.toDouble(), time);
    } else {
      _graphData.removeAt(0);
      _graphData.add(FlSpot(lapNumber.toDouble(), time));
    }
  }

  double _parseDuration(String formattedTime) {
    var parts = formattedTime.split(':');
    var minutes = double.parse(parts[0]);
    var secondsAndMilliseconds = parts[1].split('.');
    var seconds = double.parse(secondsAndMilliseconds[0]);
    var milliseconds = double.parse(secondsAndMilliseconds[1]) / 100;
    return minutes * 60 + seconds + milliseconds;
  }
}
