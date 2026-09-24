import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'api_config.dart';
import 'app_theme.dart';
import 'realtime_service.dart';

class SystemHealthScreen extends StatefulWidget {
  const SystemHealthScreen({super.key});
  @override
  State<SystemHealthScreen> createState() => _SystemHealthScreenState();
}

class _SystemHealthScreenState extends State<SystemHealthScreen> {
  Map<String, dynamic>? data;
  bool loading = true;
  Timer? timer;

  @override
  void initState() {
    super.initState();
    load();
    timer = Timer.periodic(const Duration(seconds: 20), (_) => load(silent: true));
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  Future<void> load({bool silent = false}) async {
    if (!silent && mounted) setState(() => loading = true);
    try {
      final r = await http.get(Uri.parse('${ApiConfig.baseUrl}/api/health'));
      if (r.statusCode == 200 && mounted) {
        setState(() => data = Map<String, dynamic>.from(jsonDecode(r.body)));
      }
    } catch (_) {
      if (mounted) setState(() => data = {'status': 'DOWN', 'error': 'API unreachable'});
    } finally {
      if (mounted && !silent) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext c) {
    final d = data ?? <String, dynamic>{};
    final up = d['status'] == 'UP';

    return RefreshIndicator(
      onRefresh: load,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 40),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1050),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('System Health', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: navy)),
                const SizedBox(height: 4),
                const Text('Operational view for the Smart Campus services.', style: TextStyle(fontSize: 12, color: muted)),
                const SizedBox(height: 18),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(22),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 24,
                          backgroundColor: up ? const Color(0xFFDCFCE7) : const Color(0xFFFEE2E2),
                          child: Icon(up ? Icons.check_rounded : Icons.close_rounded, color: up ? Colors.green : Colors.redAccent),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(up ? 'API is healthy' : 'API is unavailable', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: navy)),
                              const SizedBox(height: 3),
                              Text(d['service']?.toString() ?? 'GNITS Smart Campus API', style: const TextStyle(fontSize: 11, color: muted)),
                            ],
                          ),
                        ),
                        if (loading) const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                LayoutBuilder(
                  builder: (_, box) {
                    final cols = box.maxWidth > 650 ? 3 : 1;
                    return GridView.count(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisCount: cols,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 2.4,
                      children: [
                        _metric('API STATUS', d['status']?.toString() ?? '—', up ? Colors.green : Colors.redAccent),
                        _metric('LIVE CONNECTIONS', '${d['connectedRealtimeUsers'] ?? 0}', purple),
                        _metric('REALTIME', RealtimeService.instance.isConnected ? 'CONNECTED' : 'CONNECTING', RealtimeService.instance.isConnected ? Colors.green : Colors.orange),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 14),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text('Production checklist', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: navy)),
                        SizedBox(height: 10),
                        Text('✓ REST API health endpoint', style: TextStyle(fontSize: 12, color: muted)),
                        Text('✓ WebSocket live channel', style: TextStyle(fontSize: 12, color: muted)),
                        Text('✓ Database-backed room and booking data', style: TextStyle(fontSize: 12, color: muted)),
                        Text('✓ Responsive Flutter Web client', style: TextStyle(fontSize: 12, color: muted)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _metric(String a, String b, Color color) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(a, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: muted)),
              const SizedBox(height: 5),
              Text(b, style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900, color: color)),
            ],
          ),
        ),
      );
}
