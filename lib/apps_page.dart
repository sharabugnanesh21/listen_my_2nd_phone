import 'dart:convert';

import 'package:flutter/material.dart';

import 'native.dart';
import 'theme.dart';

/// Lists installed apps with a per-app toggle. Enabled apps are sorted to the
/// top each time the page is opened.
class AppsPage extends StatefulWidget {
  const AppsPage({super.key});

  @override
  State<AppsPage> createState() => _AppsPageState();
}

class _AppsPageState extends State<AppsPage> {
  List<Map<String, dynamic>> _apps = [];
  Set<String> _enabled = {};
  bool _loading = true;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final enabled = await Native.getEnabledPackages();
    final apps = await Native.getInstalledApps();

    // Sort: enabled first, then alphabetical.
    apps.sort((a, b) {
      final ae = enabled.contains(a['package']);
      final be = enabled.contains(b['package']);
      if (ae != be) return ae ? -1 : 1;
      return (a['name'] as String)
          .toLowerCase()
          .compareTo((b['name'] as String).toLowerCase());
    });

    if (!mounted) return;
    setState(() {
      _apps = apps;
      _enabled = enabled;
      _loading = false;
    });
  }

  Future<void> _toggle(String pkg, bool on) async {
    setState(() => on ? _enabled.add(pkg) : _enabled.remove(pkg));
    await Native.setEnabledPackages(_enabled);
  }

  @override
  Widget build(BuildContext context) {
    final query = _query.toLowerCase();
    final filtered = _apps
        .where((a) => (a['name'] as String).toLowerCase().contains(query))
        .toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Choose apps to listen')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                  child: TextField(
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.search, size: 20),
                      hintText: 'Search apps',
                      filled: true,
                      fillColor: AppColors.canvas,
                      contentPadding: EdgeInsets.zero,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(11),
                        borderSide:
                            const BorderSide(color: AppColors.hairline),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(11),
                        borderSide:
                            const BorderSide(color: AppColors.hairline),
                      ),
                    ),
                    onChanged: (v) => setState(() => _query = v),
                  ),
                ),
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                    itemCount: filtered.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final app = filtered[index];
                      final pkg = app['package'] as String;
                      final name = app['name'] as String;
                      final icon = app['icon'] as String?;
                      final on = _enabled.contains(pkg);
                      return Container(
                        decoration: BoxDecoration(
                          color: AppColors.canvas,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppColors.hairline),
                        ),
                        child: SwitchListTile(
                          contentPadding:
                              const EdgeInsets.symmetric(horizontal: 12),
                          secondary: ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: icon != null
                                ? Image.memory(base64Decode(icon),
                                    width: 40, height: 40)
                                : Container(
                                    width: 40,
                                    height: 40,
                                    color: AppColors.parchment,
                                    child: const Icon(Icons.android,
                                        color: AppColors.inkMuted),
                                  ),
                          ),
                          title: Text(name,
                              style:
                                  Theme.of(context).textTheme.titleMedium),
                          value: on,
                          onChanged: (v) => _toggle(pkg, v),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }
}
