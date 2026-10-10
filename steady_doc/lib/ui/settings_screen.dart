import 'package:flutter/material.dart';

import '../l10n/strings.dart';
import '../services/app_state.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  static const version = '1.0.0';

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final s = app.strings;
    return Scaffold(
      appBar: AppBar(title: Text(s.settings)),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          ListTile(title: Text(s.language)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SegmentedButton<String>(
              segments: [
                for (final code in Strings.supported)
                  ButtonSegment(value: code, label: Text(Strings.languageNames[code]!)),
              ],
              selected: {app.language},
              showSelectedIcon: false,
              onSelectionChanged: (selection) => app.setLanguage(selection.first),
            ),
          ),
          const SizedBox(height: 8),
          SwitchListTile(
            title: Text(s.sound),
            secondary: const Icon(Icons.volume_up_rounded),
            value: app.soundOn,
            onChanged: app.setSound,
          ),
          SwitchListTile(
            title: Text(s.vibration),
            secondary: const Icon(Icons.vibration_rounded),
            value: app.hapticsOn,
            onChanged: app.setHaptics,
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.restart_alt_rounded, color: Colors.redAccent),
            title: Text(s.resetProgress),
            onTap: () async {
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  content: Text(s.resetConfirm),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: Text(s.cancel),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: Text(s.yes),
                    ),
                  ],
                ),
              );
              if (confirmed ?? false) await app.resetProgress();
            },
          ),
          const SizedBox(height: 24),
          Center(
            child: Text(
              'Steady Doc · ${s.version} $version\nMade in Uzbekistan 🇺🇿',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}
