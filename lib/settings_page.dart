// import 'package:flutter/material.dart';
// import 'package:shared_preferences/shared_preferences.dart';
//
// class SettingsPage extends StatefulWidget {
//   @override
//   _SettingsPageState createState() => _SettingsPageState();
// }
//
// class _SettingsPageState extends State<SettingsPage> {
//   String _selectedLanguage = 'Japanese'; // 初期値は日本語
//
//   @override
//   void initState() {
//     super.initState();
//     _loadSettings();
//   }
//
//   Future<void> _loadSettings() async {
//     final prefs = await SharedPreferences.getInstance();
//     setState(() {
//       _selectedLanguage = prefs.getString('language') ?? 'Japanese';
//     });
//   }
//
//   Future<void> _saveSettings(String language) async {
//     final prefs = await SharedPreferences.getInstance();
//     await prefs.setString('language', language);
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: const Text('Language Setting'),
//       ),
//       body: ListView(
//         children: <Widget>[
//           ListTile(
//             title: const Text('Japanese'),
//             leading: Radio<String>(
//               value: 'Japanese',
//               groupValue: _selectedLanguage,
//               onChanged: (String? value) {
//                 setState(() {
//                   _selectedLanguage = value!;
//                 });
//                 _saveSettings(value!);
//               },
//             ),
//           ),
//           ListTile(
//             title: const Text('English'),
//             leading: Radio<String>(
//               value: 'English',
//               groupValue: _selectedLanguage,
//               onChanged: (String? value) {
//                 setState(() {
//                   _selectedLanguage = value!;
//                 });
//                 _saveSettings(value!);
//               },
//             ),
//           ),
//           ListTile(
//             title: const Text('None'),
//             leading: Radio<String>(
//               value: 'None',
//               groupValue: _selectedLanguage,
//               onChanged: (String? value) {
//                 setState(() {
//                   _selectedLanguage = value!;
//                 });
//                 _saveSettings(value!);
//               },
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }
//
// import 'package:flutter/material.dart';
// import 'package:shared_preferences/shared_preferences.dart';
//
// class SettingsPage extends StatefulWidget {
//   @override
//   _SettingsPageState createState() => _SettingsPageState();
// }
//
// class _SettingsPageState extends State<SettingsPage> {
//   String _selectedLanguage = 'Japanese'; // 初期値は日本語
//   double _detectionSensitivity = 50; // 検出感度の初期設定
//
//   @override
//   void initState() {
//     super.initState();
//     _loadSettings();
//   }
//
//   Future<void> _loadSettings() async {
//     final prefs = await SharedPreferences.getInstance();
//     setState(() {
//       _selectedLanguage = prefs.getString('language') ?? 'Japanese';
//       _detectionSensitivity = prefs.getDouble('detectionSensitivity') ?? 50;
//     });
//   }
//
//   Future<void> _saveSettings(String language, double detectionSensitivity) async {
//     final prefs = await SharedPreferences.getInstance();
//     await prefs.setString('language', language);
//     await prefs.setDouble('detectionSensitivity', detectionSensitivity);
//   }
//
//   // 検出感度に基づいてdetectionThresholdを計算するメソッド
//   double _calculateDetectionThreshold(double sensitivity) {
//     return 0.1 - (sensitivity * 0.00095);
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: const Text('Settings'),
//       ),
//       body: ListView(
//         children: <Widget>[
//           ListTile(
//             title: const Text('Japanese'),
//             leading: Radio<String>(
//               value: 'Japanese',
//               groupValue: _selectedLanguage,
//               onChanged: (String? value) {
//                 setState(() {
//                   _selectedLanguage = value!;
//                 });
//                 _saveSettings(value!, _detectionSensitivity);
//               },
//             ),
//           ),
//           ListTile(
//             title: const Text('English'),
//             leading: Radio<String>(
//               value: 'English',
//               groupValue: _selectedLanguage,
//               onChanged: (String? value) {
//                 setState(() {
//                   _selectedLanguage = value!;
//                 });
//                 _saveSettings(value!, _detectionSensitivity);
//               },
//             ),
//           ),
//           ListTile(
//             title: const Text('None'),
//             leading: Radio<String>(
//               value: 'None',
//               groupValue: _selectedLanguage,
//               onChanged: (String? value) {
//                 setState(() {
//                   _selectedLanguage = value!;
//                 });
//                 _saveSettings(value!, _detectionSensitivity);
//               },
//             ),
//           ),
//           // 検出感度のスライダー
//           ListTile(
//             title: Text('Detection Sensitivity: ${_detectionSensitivity.round()}'),
//             subtitle: Slider(
//               min: 0,
//               max: 100,
//               divisions: 100,
//               value: _detectionSensitivity,
//               onChanged: (double value) {
//                 setState(() {
//                   _detectionSensitivity = value;
//                 });
//                 _saveSettings(_selectedLanguage, _calculateDetectionThreshold(value));
//               },
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsPage extends StatefulWidget {
  @override
  _SettingsPageState createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  String _selectedLanguage = 'Japanese'; // 初期値は日本語
  double _detectionSensitivity = 50; // 検出感度の初期設定

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    double savedThreshold =
        prefs.getDouble('detectionSensitivity') ?? 0.05; // 0.05は中間の閾値
    // マッピングを使用してスライダーの値を計算
    double savedSensitivity =
        _calculateSensitivityFromThreshold(savedThreshold).clamp(0, 100);
    if (kDebugMode) {
      print("Loaded detectionSensitivity: $savedSensitivity");
    }
    setState(() {
      _selectedLanguage = prefs.getString('language') ?? 'Japanese';
      _detectionSensitivity = savedSensitivity;
    });
  }

  Future<void> _saveSettings(
      String language, double detectionSensitivity) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('language', language);
    await prefs.setDouble('detectionSensitivity', detectionSensitivity);
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
              title: Text('Language Setting',
                  style: TextStyle(fontWeight: FontWeight.bold))),
          ListTile(
            title: const Text('Japanese'),
            leading: Radio<String>(
              value: 'Japanese',
              groupValue: _selectedLanguage,
              onChanged: (String? value) {
                setState(() {
                  _selectedLanguage = value!;
                });
                _saveSettings(value!, _detectionSensitivity);
              },
            ),
          ),
          ListTile(
            title: const Text('English'),
            leading: Radio<String>(
              value: 'English',
              groupValue: _selectedLanguage,
              onChanged: (String? value) {
                setState(() {
                  _selectedLanguage = value!;
                });
                _saveSettings(value!, _detectionSensitivity);
              },
            ),
          ),
          ListTile(
            title: const Text('None'),
            leading: Radio<String>(
              value: 'None',
              groupValue: _selectedLanguage,
              onChanged: (String? value) {
                setState(() {
                  _selectedLanguage = value!;
                });
                _saveSettings(value!, _detectionSensitivity);
              },
            ),
          ),
          const SizedBox(
            height: 24,
          ),
          // 検出感度のスライダー
          const ListTile(
              title: Text('Sensitivity Setting',
                  style: TextStyle(fontWeight: FontWeight.bold))),
          ListTile(
            title: Text(
                '   Detection Sensitivity: ${_detectionSensitivity.round()}'),
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
                    _selectedLanguage, _calculateDetectionThreshold(value));
              },
            ),
          ),
        ],
      ),
    );
  }
}
