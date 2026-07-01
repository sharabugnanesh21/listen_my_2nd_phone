import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import 'native.dart';
import 'settings_page.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ListenMyPhoneApp());
}

class ListenMyPhoneApp extends StatelessWidget {
  const ListenMyPhoneApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Listen My Phone',
      debugShowCheckedModeBanner: false,
      theme: buildAppleTheme(),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with WidgetsBindingObserver {
  bool _accessGranted = false;
  final List<CapturedEvent> _events = [];
  final Map<String, Uint8List?> _iconCache = {};
  StreamSubscription<dynamic>? _sub;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _init();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _sub?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshAll();
    }
  }

  Future<void> _init() async {
    await Permission.notification.request();
    await _refreshAll();
    _sub = notifChannel
        .receiveBroadcastStream()
        .listen(_onNotification, onError: (_) {});
  }

  Future<void> _refreshAll() async {
    final granted = await Native.isAccessGranted();
    final events = await Native.getEvents();
    if (!mounted) return;
    setState(() {
      _accessGranted = granted;
      _events
        ..clear()
        ..addAll(events);
    });
    await _ensureIcons(events.map((e) => e.package));
  }

  /// Fetch (and cache) the icon for every package we don't already have.
  Future<void> _ensureIcons(Iterable<String> packages) async {
    final missing =
        packages.where((p) => !_iconCache.containsKey(p)).toSet();
    if (missing.isEmpty) return;
    for (final pkg in missing) {
      _iconCache[pkg] = await Native.getAppIcon(pkg);
    }
    if (mounted) setState(() {});
  }

  Future<void> _onNotification(dynamic event) async {
    final e = CapturedEvent.fromMap(Map<String, dynamic>.from(event as Map));
    setState(() => _events.insert(0, e));
    await _ensureIcons([e.package]);
  }

  Future<void> _deleteEvent(CapturedEvent e) async {
    setState(() => _events.removeWhere((x) => x.id == e.id));
    await Native.removeEvent(e.id);
  }

  Future<void> _openSettings() async {
    await Navigator.of(context)
        .push(MaterialPageRoute<void>(builder: (_) => const SettingsPage()));
    _refreshAll();
  }

  // ---------- UI ----------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Listen My Phone'),
        actions: [
          IconButton(
            tooltip: 'Settings',
            icon: const Icon(Icons.settings_outlined),
            onPressed: _openSettings,
          ),
        ],
      ),
      body: Column(
        children: [
          if (!_accessGranted) _accessBanner(),
          Expanded(
            child: _events.isEmpty ? _emptyState() : _eventList(),
          ),
        ],
      ),
    );
  }

  Widget _accessBanner() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.tileDark,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Notification access is off',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.374)),
                SizedBox(height: 4),
                Text('Turn it on so we can capture notifications.',
                    style: TextStyle(color: Color(0xFFCCCCCC), fontSize: 14)),
              ],
            ),
          ),
          const SizedBox(width: 12),
          FilledButton(
            onPressed: Native.openAccessSettings,
            child: const Text('Grant'),
          ),
        ],
      ),
    );
  }

  Widget _emptyState() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Text(
          'No captured notifications yet.\n\n'
          'Open Settings → grant access → choose apps.\n'
          'Then a notification from one of them appears here.',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.inkMuted, fontSize: 15, height: 1.4),
        ),
      ),
    );
  }

  Widget _eventList() {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      itemCount: _events.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, index) => _eventCard(_events[index]),
    );
  }

  Widget _eventCard(CapturedEvent e) {
    return Dismissible(
      key: ValueKey(e.id.isEmpty ? '${e.package}-${e.time.microsecondsSinceEpoch}' : e.id),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => _deleteEvent(e),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 22),
        decoration: BoxDecoration(
          color: const Color(0xFFFF3B30),
          borderRadius: BorderRadius.circular(18),
        ),
        child: const Icon(Icons.delete_outline, color: Colors.white),
      ),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.canvas,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.hairline),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _appIcon(e.package),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          e.appName,
                          style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              letterSpacing: -0.2,
                              color: AppColors.ink),
                        ),
                      ),
                      Text(_timeLabel(e.time),
                          style: const TextStyle(
                              fontSize: 12, color: AppColors.inkMuted)),
                    ],
                  ),
                  if (e.title.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 3),
                      child: Text(e.title,
                          style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: AppColors.ink)),
                    ),
                  if (e.text.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(e.text,
                          style: const TextStyle(
                              fontSize: 15,
                              color: AppColors.ink,
                              height: 1.3)),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _appIcon(String package) {
    final bytes = _iconCache[package];
    if (bytes != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(11),
        child: Image.memory(bytes, width: 42, height: 42, fit: BoxFit.cover),
      );
    }
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: AppColors.actionBlue,
        borderRadius: BorderRadius.circular(11),
      ),
      child: const Icon(Icons.notifications, color: Colors.white, size: 22),
    );
  }

  String _timeLabel(DateTime t) {
    final now = DateTime.now();
    final hm =
        '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
    final sameDay = t.year == now.year && t.month == now.month && t.day == now.day;
    return sameDay ? hm : '${t.day}/${t.month} · $hm';
  }
}
