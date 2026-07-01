import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Must match the channel name used in MainActivity.kt.
const EventChannel _smsChannel = EventChannel('com.perkypet.listen_my_phone/sms');

/// Key used to persist the message history in local storage.
const String _storageKey = 'saved_messages';

final FlutterLocalNotificationsPlugin _notifications =
    FlutterLocalNotificationsPlugin();

/// The Android notification channel every SMS notification is posted to.
const AndroidNotificationChannel _androidChannel = AndroidNotificationChannel(
  'incoming_sms',
  'Incoming SMS',
  description: 'Shown when this phone receives a text message',
  importance: Importance.high,
);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  const initSettings = InitializationSettings(
    android: AndroidInitializationSettings('@mipmap/ic_launcher'),
  );
  await _notifications.initialize(settings: initSettings);
  await _notifications
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(_androidChannel);

  runApp(const ListenMyPhoneApp());
}

class ListenMyPhoneApp extends StatelessWidget {
  const ListenMyPhoneApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Listen My Phone',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
      ),
      home: const HomePage(),
    );
  }
}

class SmsMessage {
  SmsMessage({required this.sender, required this.body, required this.time});

  final String sender;
  final String body;
  final DateTime time;

  Map<String, dynamic> toJson() => {
        'sender': sender,
        'body': body,
        'time': time.toIso8601String(),
      };

  factory SmsMessage.fromJson(Map<String, dynamic> json) => SmsMessage(
        sender: json['sender'] as String? ?? 'Unknown',
        body: json['body'] as String? ?? '',
        time: DateTime.tryParse(json['time'] as String? ?? '') ?? DateTime.now(),
      );
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  bool _listening = false;
  bool _smsGranted = false;
  bool _notifGranted = false;
  StreamSubscription<dynamic>? _subscription;
  final List<SmsMessage> _messages = [];
  int _notificationId = 0;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    await _loadMessages();
    await _requestPermissions();
    // If SMS permission is granted, start listening automatically.
    if (_smsGranted) {
      _startListening();
    }
  }

  // ---------- Local storage ----------

  Future<void> _loadMessages() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_storageKey) ?? [];
    final loaded = raw
        .map((s) => SmsMessage.fromJson(jsonDecode(s) as Map<String, dynamic>))
        .toList();
    if (!mounted) return;
    setState(() {
      _messages
        ..clear()
        ..addAll(loaded);
    });
  }

  Future<void> _saveMessages() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = _messages.map((m) => jsonEncode(m.toJson())).toList();
    await prefs.setStringList(_storageKey, raw);
  }

  Future<void> _clearMessages() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_storageKey);
    if (!mounted) return;
    setState(_messages.clear);
  }

  // ---------- Permissions ----------

  Future<void> _requestPermissions() async {
    final statuses = await [Permission.sms, Permission.notification].request();
    if (!mounted) return;
    setState(() {
      _smsGranted = statuses[Permission.sms]?.isGranted ?? false;
      _notifGranted = statuses[Permission.notification]?.isGranted ?? false;
    });
  }

  // ---------- SMS listening ----------

  void _startListening() {
    _subscription ??= _smsChannel.receiveBroadcastStream().listen(
      _onSmsReceived,
      onError: (Object error) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('SMS stream error: $error')),
        );
      },
    );
    setState(() => _listening = true);
  }

  void _stopListening() {
    _subscription?.cancel();
    _subscription = null;
    setState(() => _listening = false);
  }

  Future<void> _onSmsReceived(dynamic event) async {
    final map = Map<Object?, Object?>.from(event as Map);
    final sender = (map['sender'] as String?) ?? 'Unknown';
    final body = (map['body'] as String?) ?? '';

    setState(() {
      _messages.insert(
          0, SmsMessage(sender: sender, body: body, time: DateTime.now()));
    });
    await _saveMessages();
    await _showNotification(sender, body);
  }

  // ---------- Notifications ----------

  Future<void> _showNotification(String title, String body) async {
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'incoming_sms',
        'Incoming SMS',
        importance: Importance.high,
        priority: Priority.high,
      ),
    );
    await _notifications.show(
      id: _notificationId++,
      title: title,
      body: body,
      notificationDetails: details,
    );
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  // ---------- UI ----------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Listen My Phone'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          if (_messages.isNotEmpty)
            IconButton(
              tooltip: 'Clear history',
              icon: const Icon(Icons.delete_outline),
              onPressed: _clearMessages,
            ),
        ],
      ),
      body: Column(
        children: [
          Card(
            margin: const EdgeInsets.all(12),
            child: SwitchListTile(
              title: const Text('Listen for SMS'),
              subtitle: Text(
                _listening
                    ? 'Listening — new texts pop up as a notification'
                    : 'Off — turn on to start catching texts',
              ),
              value: _listening,
              onChanged: (value) =>
                  value ? _startListening() : _stopListening(),
              secondary: Icon(
                _listening ? Icons.hearing : Icons.hearing_disabled,
                color: _listening ? Colors.teal : Colors.grey,
              ),
            ),
          ),
          _permissionRow(
            label: 'SMS permission',
            granted: _smsGranted,
          ),
          _permissionRow(
            label: 'Notification permission',
            granted: _notifGranted,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.refresh),
                    label: const Text('Re-check permissions'),
                    onPressed: _requestPermissions,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton.tonalIcon(
                    icon: const Icon(Icons.notifications_active),
                    label: const Text('Test notification'),
                    onPressed: () => _showNotification(
                      'Test notification',
                      'If you see this, notifications work! 🎉',
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 16),
          Expanded(
            child: _messages.isEmpty
                ? const Center(
                    child: Text(
                      'No messages yet.\nSend an SMS to this phone to test.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey),
                    ),
                  )
                : ListView.separated(
                    itemCount: _messages.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final m = _messages[index];
                      return ListTile(
                        leading: const CircleAvatar(child: Icon(Icons.sms)),
                        title: Text(m.sender),
                        subtitle: Text(m.body),
                        trailing: Text(
                          '${m.time.hour.toString().padLeft(2, '0')}:'
                          '${m.time.minute.toString().padLeft(2, '0')}',
                          style: const TextStyle(color: Colors.grey),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _permissionRow({required String label, required bool granted}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      child: Row(
        children: [
          Icon(
            granted ? Icons.check_circle : Icons.cancel,
            color: granted ? Colors.green : Colors.red,
            size: 20,
          ),
          const SizedBox(width: 8),
          Text(label),
          const Spacer(),
          Text(
            granted ? 'Granted' : 'Not granted',
            style: TextStyle(
              color: granted ? Colors.green : Colors.red,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
