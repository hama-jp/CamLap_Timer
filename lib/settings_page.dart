import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  _SettingsPageState createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  String _selectedLanguage = 'Japanese'; // 初期値は日本語
  double _detectionSensitivity = 50; // 検出感度の初期設定
  int _minMeasurementTime = 5; // 最短計測時間の初期値
  late TextEditingController _measurementTimeController;

  @override
  void initState() {
    super.initState();
    _measurementTimeController = TextEditingController();
    _loadSettings();
  }

  @override
  void dispose() {
    _measurementTimeController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    double savedThreshold =
        prefs.getDouble('detectionSensitivity') ?? 0.05; // 0.05は中間の閾値
    // マッピングを使用してスライダーの値を計算
    double savedSensitivity =
        _calculateSensitivityFromThreshold(savedThreshold).clamp(0, 100);
    int savedMinMeasurementTime = prefs.getInt('minMeasurementTime') ?? 5;
    if (kDebugMode) {
      print("Loaded detectionSensitivity: $savedSensitivity");
      print("Loaded minMeasurementTime: $savedMinMeasurementTime");
    }

    setState(() {
      _selectedLanguage = prefs.getString('language') ?? 'Japanese';
      _detectionSensitivity = savedSensitivity;
      _minMeasurementTime = prefs.getInt('minMeasurementTime') ?? 5;

      // TextEditingControllerを更新
      _measurementTimeController.text = _minMeasurementTime.toString();
    });
  }

  Future<void> _saveSettings(
      String language, double detectionSensitivity, int minMeasurementTime) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('language', language);
    await prefs.setDouble('detectionSensitivity', detectionSensitivity);
    await prefs.setInt('minMeasurementTime', minMeasurementTime);
  }

  // 検出感度に基づいてdetectionThresholdを計算するメソッド
  double _calculateDetectionThreshold(double sensitivity) {
    return 0.1 - (sensitivity * 0.00095);
  }

  double _calculateSensitivityFromThreshold(double threshold) {
    // threshold を 0.005 から 0.1 の範囲にマッピング
    return (0.1 - threshold) / 0.00095;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: ListView(
        children: <Widget>[
          const ListTile(
              title: Text('Language Setting: 言語設定',
                  style: TextStyle(fontWeight: FontWeight.bold))),
          ListTile(
            title: const Text('Japanese: 日本語'),
            leading: Radio<String>(
              value: 'Japanese',
              groupValue: _selectedLanguage,
              onChanged: (String? value) {
                setState(() {
                  _selectedLanguage = value!;
                });
                _saveSettings(value!, _detectionSensitivity, _minMeasurementTime);
              },
            ),
          ),
          ListTile(
            title: const Text('English: 英語'),
            leading: Radio<String>(
              value: 'English',
              groupValue: _selectedLanguage,
              onChanged: (String? value) {
                setState(() {
                  _selectedLanguage = value!;
                });
                _saveSettings(value!, _detectionSensitivity, _minMeasurementTime);
              },
            ),
          ),
          ListTile(
            title: const Text('None: 音声なし'),
            leading: Radio<String>(
              value: 'None',
              groupValue: _selectedLanguage,
              onChanged: (String? value) {
                setState(() {
                  _selectedLanguage = value!;
                });
                _saveSettings(value!, _detectionSensitivity, _minMeasurementTime);
              },
            ),
          ),
          const SizedBox(
            height: 24,
          ),
          // 検出感度のスライダー
          const ListTile(
              title: Text('Sensitivity Setting: 感度設定',
                  style: TextStyle(fontWeight: FontWeight.bold))),
          ListTile(
            title: Text(
                '   Detection Sensitivity: 検出感度:   ${_detectionSensitivity.round()} %'),
            subtitle: Slider(
              min: 0,
              max: 100,
              divisions: 100,
              value: _detectionSensitivity,
              onChanged: (double value) {
                setState(() {
                  _detectionSensitivity = value;
                });
                _saveSettings(
                    _selectedLanguage, _calculateDetectionThreshold(value), _minMeasurementTime);
              },
            ),
          ),
          ListTile(
            title: const Text('   Minimum Measurement Time (seconds): 最小記録時間'),
            trailing: SizedBox(
              width: 100,
              child: TextFormField(
                // initialValue: '$_minMeasurementTime',
                controller: _measurementTimeController,
                keyboardType: TextInputType.number,
                onFieldSubmitted: (String value) {
                  int? enteredTime = int.tryParse(value);
                  if (enteredTime == null || enteredTime < 2) {
                    showDialog(
                      context: context,
                      builder: (BuildContext context) {
                        return AlertDialog(
                          title: const Text('Invalid Value'),
                          content: const Text('Please enter a value of 2 or more.: 2秒以上を設定してください。'),
                          actions: <Widget>[
                            TextButton(
                              child: const Text('OK'),
                              onPressed: () {
                                Navigator.of(context).pop();
                                setState(() {
                                  _minMeasurementTime = 2;
                                  _measurementTimeController.text = '2';
                                });
                              },
                            ),
                          ],
                        );
                      },
                    );
                  } else {
                    setState(() {
                      _minMeasurementTime = enteredTime;
                      _measurementTimeController.text = value;
                    });
                    _saveSettings(_selectedLanguage, _detectionSensitivity, _minMeasurementTime);
                  }
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
