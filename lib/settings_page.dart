import 'package:flutter/material.dart';

import 'apps_page.dart';
import 'auth.dart';
import 'native.dart';
import 'relay.dart';
import 'theme.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _accessGranted = false;
  bool _captureAll = false;
  bool _forward = false;
  bool _receive = false;
  int _enabledCount = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final granted = await Native.isAccessGranted();
    final captureAll = await Native.getCaptureAll();
    final enabled = await Native.getEnabledPackages();
    final forward = await Native.getForward();
    final receive = await Native.getReceive();
    if (!mounted) return;
    setState(() {
      _accessGranted = granted;
      _captureAll = captureAll;
      _forward = forward;
      _receive = receive;
      _enabledCount = enabled.length;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 12),
        children: [
          _section('ACCOUNT', [
            _row(
              icon: Icons.account_circle_outlined,
              title: AuthService.currentUser?.email ?? 'Signed in',
              subtitle: 'Tap to sign out',
              trailing: const Icon(Icons.logout, color: AppColors.inkMuted),
              onTap: () async {
                final navigator = Navigator.of(context);
                await Native.stopRelayService();
                await AuthService.signOut();
                navigator.popUntil((r) => r.isFirst);
              },
            ),
          ]),
          _section('SYNC BETWEEN PHONES', [
            SwitchListTile(
              secondary:
                  const Icon(Icons.upload_outlined, color: AppColors.actionBlue),
              title: Text('Forward my notifications',
                  style: Theme.of(context).textTheme.bodyLarge),
              subtitle: const Text(
                'Send this phone’s notifications to your other phones '
                '(turn ON on the SIM phone)',
                style: TextStyle(color: AppColors.inkMuted, fontSize: 13),
              ),
              value: _forward,
              onChanged: (v) async {
                setState(() => _forward = v);
                await Native.setForward(v);
              },
            ),
            _divider(),
            SwitchListTile(
              secondary: const Icon(Icons.download_outlined,
                  color: AppColors.actionBlue),
              title: Text('Show other phones’ notifications',
                  style: Theme.of(context).textTheme.bodyLarge),
              subtitle: const Text(
                'Display notifications forwarded from your other phones '
                '(turn ON on the phone you use)',
                style: TextStyle(color: AppColors.inkMuted, fontSize: 13),
              ),
              value: _receive,
              onChanged: (v) async {
                setState(() => _receive = v);
                await Native.setReceive(v);
                if (v) {
                  await Native.startRelayService();
                } else {
                  await Native.stopRelayService();
                }
              },
            ),
          ]),
          _section('LISTENING', [
            _row(
              icon: Icons.notifications_active_outlined,
              title: 'Notification access',
              subtitle: _accessGranted ? 'On' : 'Off — tap to grant',
              trailing: Icon(
                _accessGranted ? Icons.check_circle : Icons.chevron_right,
                color: _accessGranted ? Colors.green : AppColors.inkMuted,
              ),
              onTap: () async {
                await Native.openAccessSettings();
              },
            ),
            _divider(),
            _row(
              icon: Icons.apps,
              title: 'Choose apps to listen',
              subtitle: '$_enabledCount app(s) selected',
              trailing: const Icon(Icons.chevron_right,
                  color: AppColors.inkMuted),
              onTap: () async {
                await Navigator.of(context).push(
                  MaterialPageRoute<void>(builder: (_) => const AppsPage()),
                );
                _load();
              },
            ),
            _divider(),
            SwitchListTile(
              secondary: const Icon(Icons.travel_explore,
                  color: AppColors.actionBlue),
              title: Text('Discovery mode',
                  style: Theme.of(context).textTheme.bodyLarge),
              subtitle: const Text(
                'Capture EVERY app — use it to find which app a call/SMS '
                'comes from, then long-press it to lock on',
                style: TextStyle(color: AppColors.inkMuted, fontSize: 13),
              ),
              value: _captureAll,
              onChanged: (v) async {
                setState(() => _captureAll = v);
                await Native.setCaptureAll(v);
              },
            ),
          ]),
          _section('NOTIFICATIONS', [
            _row(
              icon: Icons.music_note_outlined,
              title: 'Notification sound',
              subtitle: "Change this app's alert sound",
              trailing: const Icon(Icons.chevron_right,
                  color: AppColors.inkMuted),
              onTap: Native.openSoundSettings,
            ),
          ]),
          _section('HISTORY', [
            _row(
              icon: Icons.delete_outline,
              title: 'Clear all captured notifications',
              danger: true,
              onTap: () async {
                final messenger = ScaffoldMessenger.of(context);
                await Native.clearEvents();
                await Relay.clearRemote(); // also clear the cloud
                messenger.showSnackBar(
                  const SnackBar(content: Text('History cleared (this phone + cloud)')),
                );
              },
            ),
          ]),
        ],
      ),
    );
  }

  // ---------- iOS-style grouped list helpers ----------

  Widget _section(String header, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(28, 20, 16, 8),
          child: Text(
            header,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.4,
              color: AppColors.inkMuted,
            ),
          ),
        ),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: AppColors.canvas,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.hairline),
          ),
          child: Column(children: children),
        ),
      ],
    );
  }

  Widget _divider() => const Padding(
        padding: EdgeInsets.only(left: 56),
        child: Divider(height: 1),
      );

  Widget _row({
    required IconData icon,
    required String title,
    String? subtitle,
    Widget? trailing,
    VoidCallback? onTap,
    bool danger = false,
  }) {
    final color = danger ? Colors.red : AppColors.ink;
    return ListTile(
      leading: Icon(icon, color: danger ? Colors.red : AppColors.actionBlue),
      title: Text(title,
          style: Theme.of(context)
              .textTheme
              .bodyLarge
              ?.copyWith(color: color)),
      subtitle: subtitle == null
          ? null
          : Text(subtitle,
              style: const TextStyle(color: AppColors.inkMuted, fontSize: 13)),
      trailing: trailing,
      onTap: onTap,
    );
  }
}
