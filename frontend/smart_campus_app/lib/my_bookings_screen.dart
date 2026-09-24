import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'api_config.dart';
import 'app_theme.dart';
import 'realtime_service.dart';

class MyBookingsScreen extends StatefulWidget {
  final String role;
  final String username;
  const MyBookingsScreen({super.key, required this.role, required this.username});
  @override
  State<MyBookingsScreen> createState() => _MyBookingsScreenState();
}

class _MyBookingsScreenState extends State<MyBookingsScreen> {
  List<Map<String, dynamic>> bookings = [];
  bool loading = true;
  Timer? timer;
  late final StreamSubscription<Map<String, dynamic>> realtime;

  @override
  void initState() {
    super.initState();
    load();
    timer = Timer.periodic(const Duration(seconds: 30), (_) => load(silent: true));
    realtime = RealtimeService.instance.events.listen((_) => load(silent: true));
  }

  @override
  void dispose() {
    timer?.cancel();
    realtime.cancel();
    super.dispose();
  }

  Future<void> load({bool silent = false}) async {
    if (!silent && mounted) setState(() => loading = true);
    try {
      final r = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/api/bookings').replace(
          queryParameters: {'role': widget.role, 'username': widget.username},
        ),
      );
      if (r.statusCode == 200 && mounted) {
        final d = jsonDecode(r.body);
        if (d is List) {
          setState(() => bookings = d.map((e) => Map<String, dynamic>.from(e)).toList());
        }
      }
    } catch (_) {
      // Keep the last successfully loaded state when the API is temporarily unavailable.
    } finally {
      if (mounted && !silent) setState(() => loading = false);
    }
  }

  bool isFuture(Map<String, dynamic> b) {
    try {
      final d = DateTime.parse('${b['bookingDate']}T${b['startTime']}');
      return d.isAfter(DateTime.now());
    } catch (_) {
      return true;
    }
  }

  @override
  Widget build(BuildContext context) {
    final upcoming = bookings.where(isFuture).length;
    return RefreshIndicator(
      onRefresh: load,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 40),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1150),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('My Bookings', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: navy)),
                const SizedBox(height: 4),
                Text(
                  widget.role == 'ADMIN' ? 'All confirmed campus bookings' : 'Your confirmed room bookings',
                  style: const TextStyle(fontSize: 12, color: muted),
                ),
                const SizedBox(height: 18),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    _Stat(label: 'TOTAL', value: '${bookings.length}'),
                    _Stat(label: 'UPCOMING', value: '$upcoming'),
                  ],
                ),
                const SizedBox(height: 18),
                if (loading)
                  const Padding(
                    padding: EdgeInsets.all(50),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (bookings.isEmpty)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(40),
                      child: Center(
                        child: Column(
                          children: const [
                            Icon(Icons.event_busy_outlined, size: 44, color: muted),
                            SizedBox(height: 10),
                            Text('No confirmed bookings', style: TextStyle(fontWeight: FontWeight.w800, color: navy)),
                            SizedBox(height: 5),
                            Text('Bookings will appear here after they are confirmed.', style: TextStyle(fontSize: 12, color: muted)),
                          ],
                        ),
                      ),
                    ),
                  )
                else
                  ...bookings.map(_card),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _card(Map<String, dynamic> b) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: LayoutBuilder(
          builder: (c, box) {
            final compact = box.maxWidth < 650;
            final children = [
              _line(Icons.meeting_room_outlined, 'Room', '${b['roomNo']}'),
              _line(Icons.calendar_today_outlined, 'Date', '${b['bookingDate']}'),
              _line(Icons.schedule_outlined, 'Time', '${b['startTime']} – ${b['endTime']}'),
              _line(Icons.description_outlined, 'Purpose', '${b['purpose'] ?? '—'}'),
            ];
            return compact
                ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: children)
                : Wrap(spacing: 26, runSpacing: 12, children: children);
          },
        ),
      ),
    );
  }

  Widget _line(IconData i, String l, String v) => SizedBox(
        width: 210,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(i, size: 17, color: purple),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l, style: const TextStyle(fontSize: 9, color: muted, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text(v, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: navy)),
                ],
              ),
            ),
          ],
        ),
      );
}

class _Stat extends StatelessWidget {
  final String label;
  final String value;
  const _Stat({required this.label, required this.value});

  @override
  Widget build(BuildContext c) => Container(
        width: 125,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: purple)),
            Text(label, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: muted)),
          ],
        ),
      );
}
