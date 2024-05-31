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

  double _calculateDetectionThreshold(double sensitivity) {
    return 0.1 - (sensitivity * 0.00095);
  }

  double _calculateSensitivityFromThreshold(double threshold) {
    return (0.1 - threshold) / 0.00095;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: <Widget>[
          _buildSectionTitle('Language Setting: 言語設定'),
          _buildLanguageOption('Japanese: 日本語', 'Japanese'),
          _buildLanguageOption('English: 英語', 'English'),
          _buildLanguageOption('None: 音声なし', 'None'),
          const SizedBox(height: 24),
          _buildSectionTitle('Sensitivity Setting: 感度設定'),
          _buildSensitivitySlider(),
          const SizedBox(height: 24),
          _buildSectionTitle('Minimum Measurement Time: 最小記録時間'),
          _buildMeasurementTimeField(),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Center(
      child: ListTile(
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  Widget _buildLanguageOption(String title, String value) {
    return Center(
      child: ListTile(
        title: Text(
          title,
          textAlign: TextAlign.center,
        ),
        trailing: Radio<String>(
          value: value,
          groupValue: _selectedLanguage,
          onChanged: (String? newValue) {
            setState(() {
              _selectedLanguage = newValue!;
            });
            _saveSettings(newValue!, _detectionSensitivity, _minMeasurementTime);
          },
        ),
      ),
    );
  }

  Widget _buildSensitivitySlider() {
    return Center(
      child: ListTile(
        title: Text(
          'Detection Sensitivity: 検出感度: ${_detectionSensitivity.round()} %',
          textAlign: TextAlign.center,
        ),
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
    );
  }

  Widget _buildMeasurementTimeField() {
    return Center(
      child: ListTile(
        title: const Text(
          'Minimum Measurement Time (seconds): 最小記録時間',
          textAlign: TextAlign.center,
        ),
        trailing: SizedBox(
          width: 100,
          child: TextFormField(
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
    );
  }
}

