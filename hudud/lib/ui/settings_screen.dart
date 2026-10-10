import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../app.dart';
import '../data/settings.dart';
import '../l10n/strings.dart';
import '../map/map_style.dart';
import '../run/location.dart';
import '../services/gpx.dart';
import 'paywall_screen.dart';
import 'start_run.dart';
import 'theme.dart';
import 'widgets.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  void _pro(BuildContext context) =>
      Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const PaywallScreen()));

  Future<void> _toggleHealth(BuildContext context, bool on) async {
    final app = AppScope.read(context);
    final s = app.settings.strings;
    if (!on) {
      await app.settings.setHealthSync(false);
      return;
    }
    if (await app.fitness.needsHealthConnect()) {
      if (!context.mounted) return;
      final install = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: Palette.surface,
          content: Text(s.healthConnectMissing),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: Text(s.cancel)),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(s.install)),
          ],
        ),
      );
      if (install == true) await app.fitness.installHealthConnect();
      return;
    }
    if (await app.fitness.connect()) await app.settings.setHealthSync(true);
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final settings = app.settings;
    final s = settings.strings;
    final isPro = app.pro.isPro;

    Widget section(String title) => Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
          child: Text(title.toUpperCase(), style: caption),
        );

    return Scaffold(
      appBar: AppBar(title: Text(s.settings, style: const TextStyle(fontWeight: FontWeight.w800))),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 40),
        children: [
          if (!isPro)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: GestureDetector(
                onTap: () => _pro(context),
                child: Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(gradient: Palette.proGradient, borderRadius: BorderRadius.circular(20)),
                  child: Row(
                    children: [
                      const Icon(Icons.workspace_premium_rounded, color: Palette.background, size: 34),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(s.proTitle,
                                style: const TextStyle(color: Palette.background, fontWeight: FontWeight.w900, fontSize: 18)),
                            Text(s.proSubtitle, style: const TextStyle(color: Palette.background, fontSize: 12)),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right_rounded, color: Palette.background),
                    ],
                  ),
                ),
              ),
            ),
          section(s.language),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SegmentedButton<String>(
              segments: [
                for (final code in Strings.supported)
                  ButtonSegment(value: code, label: Text(Strings.languageNames[code]!)),
              ],
              selected: {settings.language},
              onSelectionChanged: (v) => settings.setLanguage(v.first),
              showSelectedIcon: false,
            ),
          ),
          section(s.territoryColor),
          SizedBox(
            height: 56,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                for (var i = 0; i < skins.length; i++)
                  GestureDetector(
                    onTap: () => i == 0 || isPro ? settings.setSkin(i) : _pro(context),
                    child: Container(
                      width: 48,
                      height: 48,
                      margin: const EdgeInsets.only(right: 10),
                      decoration: BoxDecoration(
                        color: skins[i],
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: settings.skinIndex == i && (i == 0 || isPro) ? Colors.white : Colors.transparent,
                          width: 3,
                        ),
                        boxShadow: [BoxShadow(color: skins[i].withValues(alpha: 0.5), blurRadius: 12)],
                      ),
                      child: i > 0 && !isPro ? const Icon(Icons.lock_rounded, size: 18, color: Palette.background) : null,
                    ),
                  ),
              ],
            ),
          ),
          section(s.mapStyle),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Wrap(
              spacing: 8,
              children: [
                for (final theme in MapTheme.all)
                  ChoiceChip(
                    label: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(s.mapThemeName(theme.id)),
                        if (theme.pro && !isPro) ...[const SizedBox(width: 6), const ProTag(small: true)],
                      ],
                    ),
                    selected: app.mapTheme.id == theme.id,
                    onSelected: (_) => theme.pro && !isPro ? _pro(context) : settings.setMapTheme(theme),
                  ),
              ],
            ),
          ),
          section(s.voiceCoach),
          SwitchListTile(
            title: Text(s.voiceCoach),
            subtitle: Text(s.voiceCoachText),
            value: settings.voiceCoach,
            onChanged: settings.setVoiceCoach,
          ),
          SwitchListTile(
            title: Text(s.autoPause),
            subtitle: Text(s.autoPauseText),
            value: settings.autoPause,
            onChanged: settings.setAutoPause,
          ),
          SwitchListTile(title: Text(s.vibration), value: settings.haptics, onChanged: settings.setHaptics),
          ListTile(
            title: Text(s.weight),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.remove_rounded),
                  onPressed: () => settings.setWeight((settings.weightKg - 1).clamp(30, 200)),
                ),
                Text('${settings.weightKg.round()} kg', style: const TextStyle(fontWeight: FontWeight.w800)),
                IconButton(
                  icon: const Icon(Icons.add_rounded),
                  onPressed: () => settings.setWeight((settings.weightKg + 1).clamp(30, 200)),
                ),
              ],
            ),
          ),
          section(s.healthSync),
          SwitchListTile(
            title: Text(s.healthSync),
            subtitle: Text(defaultTargetPlatform == TargetPlatform.iOS ? s.healthSyncTextIos : s.healthSyncText),
            value: settings.healthSync,
            onChanged: (on) => _toggleHealth(context, on),
          ),
          section(s.privacyZone),
          ListTile(
            leading: const Icon(Icons.shield_moon_rounded),
            title: Text(settings.home == null ? s.setHomeHere : s.homeSet),
            subtitle: Text(s.privacyZoneText),
            trailing: settings.home == null
                ? null
                : TextButton(onPressed: () => settings.setHome(null), child: Text(s.clearHome)),
            onTap: () async {
              final fix = await DeviceLocation.current();
              if (fix != null) await settings.setHome(fix.pos);
            },
          ),
          section(s.about),
          ListTile(
            leading: const Icon(Icons.play_circle_outline_rounded),
            title: Text(s.demoRun),
            subtitle: Text(s.demoRunText),
            onTap: () async {
              final fix = await DeviceLocation.current();
              if (context.mounted) unawaited(startDemo(context, fix?.pos ?? fallbackCenter));
            },
          ),
          ListTile(
            leading: const Icon(Icons.file_download_rounded),
            title: Row(children: [Text(s.exportGpx), if (!isPro) ...[const SizedBox(width: 8), const ProTag(small: true)]]),
            subtitle: Text(s.exportGpxText),
            onTap: () => isPro ? shareGpx(app.store) : _pro(context),
          ),
          if (proPreviewBuild)
            SwitchListTile(
              title: Text(s.proPreview),
              value: settings.proPreview,
              onChanged: settings.setProPreview,
            ),
          ListTile(
            leading: const Icon(Icons.delete_forever_rounded, color: Palette.danger),
            title: Text(s.resetData, style: const TextStyle(color: Palette.danger)),
            onTap: () async {
              final ok = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  backgroundColor: Palette.surface,
                  content: Text(s.resetConfirm),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(context, false), child: Text(s.cancel)),
                    TextButton(
                      onPressed: () => Navigator.pop(context, true),
                      style: TextButton.styleFrom(foregroundColor: Palette.danger),
                      child: Text(s.yes),
                    ),
                  ],
                ),
              );
              if (ok == true) await app.store.clear();
            },
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: Text(s.mapCredits, style: const TextStyle(color: Palette.muted, fontSize: 12)),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 6, 20, 0),
            child: Text('Hudud 1.0', style: TextStyle(color: Palette.muted, fontSize: 12)),
          ),
        ],
      ),
    );
  }
}
