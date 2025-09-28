import 'package:flutter/material.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  ThemeMode _mode = ThemeMode.system;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('設定')),
      body: ListView(
        children: [
          const ListTile(title: Text("テーマ")),
          RadioListTile<ThemeMode>(
            value: ThemeMode.system,
            groupValue: _mode,
            onChanged: (v) => setState(() => _mode = v!),
            title: const Text("システムに合わせる"),
          ),
          RadioListTile<ThemeMode>(
            value: ThemeMode.light,
            groupValue: _mode,
            onChanged: (v) => setState(() => _mode = v!),
            title: const Text("ライト"),
          ),
          RadioListTile<ThemeMode>(
            value: ThemeMode.dark,
            groupValue: _mode,
            onChanged: (v) => setState(() => _mode = v!),
            title: const Text("ダーク"),
          ),
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text("※ 本スターターでは ThemeMode の保存と全体反映は簡略化。後続で Riverpod 連携して恒久保存します。"),
          ),
        ],
      ),
    );
  }
}
