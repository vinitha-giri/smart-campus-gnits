import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'api_config.dart';
import 'app_theme.dart';
import 'common_widgets.dart';
import 'realtime_service.dart';

class RoomsScreen extends StatefulWidget {
  final String initialQuery;
  final VoidCallback? onOpenCampusMap;
  const RoomsScreen({super.key, this.initialQuery = '', this.onOpenCampusMap});
  @override
  State<RoomsScreen> createState() => _RoomsScreenState();
}

class _RoomsScreenState extends State<RoomsScreen> {
  List<Map<String, dynamic>> rooms = [];
  bool loading = true;
  String query = '';
  String status = 'ALL';
  String block = 'ALL';
  String roomType = 'ALL';
  Timer? timer;
  StreamSubscription<Map<String, dynamic>>? realtimeSubscription;
  late final TextEditingController searchController;

  @override
  void initState() {
    super.initState();
    query = widget.initialQuery;
    searchController = TextEditingController(text: query);
    load();
    RealtimeService.instance.start();
    realtimeSubscription = RealtimeService.instance.events.listen((event) {
      final type = event['type']?.toString() ?? '';
      if (type == 'BOOKING_CHANGED' || type == 'ROOM_CHANGED' || type == 'TIMETABLE_CHANGED' || type == 'ROOM_STATUS_CHANGED') {
        load(silent: true);
      }
    });
    timer = Timer.periodic(const Duration(seconds: 20), (_) => load(silent: true));
  }

  @override
  void dispose() {
    timer?.cancel();
    realtimeSubscription?.cancel();
    searchController.dispose();
    super.dispose();
  }

  Future<void> load({bool silent = false}) async {
    if (!silent && mounted) setState(() => loading = true);
    try {
      final r = await http.get(Uri.parse('${ApiConfig.baseUrl}/api/rooms/availability'));
      if (r.statusCode != 200) throw Exception(r.body);
      final list = jsonDecode(r.body) as List;
      if (mounted) setState(() => rooms = list.map((e) => Map<String, dynamic>.from(e)).toList());
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not load live room status: $e')),
        );
      }
    } finally {
      if (mounted && !silent) setState(() => loading = false);
    }
  }

  Color statusColor(String s) {
    switch (s.toUpperCase()) {
      case 'MAINTENANCE': return Colors.orange;
      case 'RESERVED': return Colors.purple;
      case 'OCCUPIED': return Colors.redAccent;
      case 'BOOKED': return Colors.blueAccent;
      default: return Colors.green;
    }
  }

  Future<void> _showRoomDetails(Map<String, dynamic> room) async {
    final roomId = room['roomId'];
    if (roomId == null) return;
    bool loadingSchedule = true;
    String? error;
    List<Map<String, dynamic>> events = [];
    String fromDate = DateTime.now().toIso8601String().substring(0, 10);
    int days = 7;

    try {
      final r = await http.get(Uri.parse(
        '${ApiConfig.baseUrl}/api/rooms/$roomId/schedule?fromDate=$fromDate&days=$days',
      ));
      if (r.statusCode != 200) {
        throw Exception(r.body);
      }
      final data = jsonDecode(r.body) as Map<String, dynamic>;
      events = (data['events'] as List? ?? [])
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    } catch (e) {
      error = e.toString();
    } finally {
      loadingSchedule = false;
    }

    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => _RoomDetailsDialog(
        room: room,
        events: events,
        loading: loadingSchedule,
        error: error,
        statusColor: statusColor,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = rooms.where((r) {
      final q = query.trim().toLowerCase();
      final text = '${r['roomNo']} ${r['roomType']} ${r['status']} ${r['currentClass'] ?? ''}'.toLowerCase();
      final roomNo = '${r['roomNo'] ?? ''}';
      final roomBlock = _blockForRoom(roomNo);
      final type = _normaliseType('${r['roomType'] ?? ''}');
      return (q.isEmpty || text.contains(q)) &&
          (status == 'ALL' || '${r['status']}'.toUpperCase() == status) &&
          (block == 'ALL' || roomBlock == block) &&
          (roomType == 'ALL' || type == roomType);
    }).toList();
    final avail = rooms.where((r) => '${r['status']}'.toUpperCase() == 'AVAILABLE').length;
    final occ = rooms.where((r) {
      final s = '${r['status']}'.toUpperCase();
      return s == 'OCCUPIED' || s == 'BOOKED';
    }).length;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 40),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1420),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Rooms', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: navy)),
                        SizedBox(height: 5),
                        Text('Live availability, current activity and future room schedule.', style: TextStyle(color: muted)),
                      ],
                    ),
                  ),
                  if (widget.onOpenCampusMap != null)
                    OutlinedButton.icon(
                      onPressed: widget.onOpenCampusMap,
                      icon: const Icon(Icons.map_outlined, size: 17),
                      label: const Text('Campus map'),
                    ),
                  const SizedBox(width: 6),
                  IconButton(onPressed: load, tooltip: 'Refresh live status', icon: const Icon(Icons.refresh_rounded)),
                ],
              ),
              const SizedBox(height: 8),
              const _InfoBanner(
                icon: Icons.touch_app_rounded,
                text: 'Tap or click any room to see today\'s activity and upcoming timetable / bookings.',
              ),
              const SizedBox(height: 14),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      SizedBox(
                        width: MediaQuery.sizeOf(context).width < 600 ? double.infinity : 340,
                        child: TextField(
                          controller: searchController,
                          onChanged: (v) => setState(() => query = v),
                          decoration: const InputDecoration(
                            labelText: 'Search room, class or type',
                            prefixIcon: Icon(Icons.search_rounded),
                          ),
                        ),
                      ),
                      SizedBox(
                        width: 180,
                        child: DropdownButtonFormField<String>(
                          value: status,
                          decoration: const InputDecoration(labelText: 'Status'),
                          items: const [
                            DropdownMenuItem(value: 'ALL', child: Text('All rooms')),
                            DropdownMenuItem(value: 'AVAILABLE', child: Text('Available')),
                            DropdownMenuItem(value: 'OCCUPIED', child: Text('Occupied')),
                            DropdownMenuItem(value: 'BOOKED', child: Text('Booked')),
                            DropdownMenuItem(value: 'MAINTENANCE', child: Text('Maintenance')),
                            DropdownMenuItem(value: 'RESERVED', child: Text('Reserved')),
                          ],
                          onChanged: (v) { if (v != null) setState(() => status = v); },
                        ),
                      ),
                      SizedBox(
                        width: 165,
                        child: DropdownButtonFormField<String>(
                          value: block,
                          decoration: const InputDecoration(labelText: 'Block'),
                          items: const [
                            DropdownMenuItem(value: 'ALL', child: Text('All blocks')),
                            DropdownMenuItem(value: 'A', child: Text('Block A')),
                            DropdownMenuItem(value: 'B', child: Text('Block B')),
                            DropdownMenuItem(value: 'C', child: Text('Block C')),
                            DropdownMenuItem(value: 'D', child: Text('Block D')),
                            DropdownMenuItem(value: 'F', child: Text('Block F')),
                          ],
                          onChanged: (v) { if (v != null) setState(() => block = v); },
                        ),
                      ),
                      SizedBox(
                        width: 190,
                        child: DropdownButtonFormField<String>(
                          value: roomType,
                          decoration: const InputDecoration(labelText: 'Room type'),
                          items: const [
                            DropdownMenuItem(value: 'ALL', child: Text('All room types')),
                            DropdownMenuItem(value: 'CLASSROOM', child: Text('Classroom')),
                            DropdownMenuItem(value: 'LAB', child: Text('Lab')),
                            DropdownMenuItem(value: 'E-CLASSROOM', child: Text('E-Classroom')),
                            DropdownMenuItem(value: 'SEMINAR HALL', child: Text('Seminar Hall')),
                          ],
                          onChanged: (v) { if (v != null) setState(() => roomType = v); },
                        ),
                      ),
                      TextButton.icon(
                        onPressed: () => setState(() { query = ''; searchController.clear(); status = 'ALL'; block = 'ALL'; roomType = 'ALL'; }),
                        icon: const Icon(Icons.clear_all_rounded),
                        label: const Text('Clear'),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Row(children: [
                _Metric('Available now', '$avail', Colors.green),
                const SizedBox(width: 10),
                _Metric('Occupied / booked', '$occ', Colors.redAccent),
              ]),
              const SizedBox(height: 14),
              if (loading)
                const Padding(padding: EdgeInsets.all(50), child: Center(child: CircularProgressIndicator()))
              else if (filtered.isEmpty)
                const EmptyCard(title: 'No matching rooms', text: 'Try another room number, class name or status.')
              else
                Card(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      headingRowColor: const WidgetStatePropertyAll(Color(0xFFF8F9FC)),
                      columns: const [
                        DataColumn(label: Text('Room', style: TextStyle(fontWeight: FontWeight.w800))),
                        DataColumn(label: Text('Type')),
                        DataColumn(label: Text('Capacity')),
                        DataColumn(label: Text('Live status')),
                        DataColumn(label: Text('Current activity')),
                        DataColumn(label: Text('Availability / next change')),
                      ],
                      rows: [
                        for (final r in filtered)
                          DataRow(
                            onSelectChanged: (_) => _showRoomDetails(r),
                            cells: [
                              DataCell(Row(mainAxisSize: MainAxisSize.min, children: [
                                Text('${r['roomNo'] ?? '—'}', style: const TextStyle(fontWeight: FontWeight.w800)),
                                const SizedBox(width: 6),
                                const Icon(Icons.open_in_new_rounded, size: 14, color: Colors.indigo),
                              ])),
                              DataCell(Text('${r['roomType'] ?? '—'}')),
                              DataCell(Text('${r['capacity'] ?? '—'}')),
                              DataCell(StatusPill('${r['status'] ?? '—'}', statusColor('${r['status'] ?? ''}'))),
                              DataCell(Text('${r['currentClass'] ?? r['statusReason'] ?? '—'}')),
                              DataCell(Text(_availabilityText(r))),
                            ],
                          ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  String _normaliseType(String value) {
    final v = value.trim().toUpperCase().replaceAll('_', '-');
    if (v.contains('SEMINAR')) return 'SEMINAR HALL';
    if (v.contains('E-CLASS') || v.contains('E CLASS') || v.contains('ECLASS')) return 'E-CLASSROOM';
    if (v.contains('LAB')) return 'LAB';
    if (v.contains('CLASSROOM') || v == 'CLASS') return 'CLASSROOM';
    return v;
  }

  String _blockForRoom(String roomNo) {
    final v = roomNo.trim().toUpperCase();
    final match = RegExp(r'^(?:BLOCK\s*)?([ABCDF])(?:[-\s]?\d|$)').firstMatch(v);
    if (match != null) return match.group(1)!;
    final named = RegExp(r'BLOCK\s*([ABCDF])').firstMatch(v);
    return named?.group(1) ?? '';
  }

  String _availabilityText(Map<String, dynamic> r) {
    final s = '${r['status'] ?? ''}'.toUpperCase();
    if (s == 'AVAILABLE') {
      final until = r['availableUntil'];
      return until == null ? 'Available — no later activity scheduled' : 'Available until $until';
    }
    if (s == 'OCCUPIED' || s == 'BOOKED') {
      return 'Available from ${r['availableFrom'] ?? r['endTime'] ?? '—'}';
    }
    return '${r['statusReason'] ?? 'Restricted'}';
  }
}

class _RoomDetailsDialog extends StatelessWidget {
  final Map<String, dynamic> room;
  final List<Map<String, dynamic>> events;
  final bool loading;
  final String? error;
  final Color Function(String) statusColor;

  const _RoomDetailsDialog({
    required this.room,
    required this.events,
    required this.loading,
    required this.error,
    required this.statusColor,
  });

  DateTime _date(String value) => DateTime.parse(value);

  String _dayLabel(String value) {
    final d = _date(value);
    final today = DateTime.now();
    final dateOnly = DateTime(d.year, d.month, d.day);
    final todayOnly = DateTime(today.year, today.month, today.day);
    if (dateOnly == todayOnly) return 'TODAY • ${_dateText(d)}';
    if (dateOnly == todayOnly.add(const Duration(days: 1))) return 'TOMORROW • ${_dateText(d)}';
    return '${_weekday(d.weekday)} • ${_dateText(d)}';
  }

  String _dateText(DateTime d) => '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  String _weekday(int n) => const ['Monday','Tuesday','Wednesday','Thursday','Friday','Saturday','Sunday'][n - 1];

  String _time(String value) {
    final parts = value.split(':');
    final h = int.tryParse(parts[0]) ?? 0;
    final m = int.tryParse(parts[1]) ?? 0;
    final suffix = h >= 12 ? 'PM' : 'AM';
    final display = h % 12 == 0 ? 12 : h % 12;
    return '$display:${m.toString().padLeft(2, '0')} $suffix';
  }

  Map<String, List<Map<String, dynamic>>> _grouped() {
    final map = <String, List<Map<String, dynamic>>>{};
    for (final e in events) {
      final date = '${e['date']}';
      map.putIfAbsent(date, () => []).add(e);
    }
    return map;
  }

  String _nextFreeSummary() {
    final now = DateTime.now();
    final sorted = [...events]..sort((a, b) {
      final ad = '${a['date']} ${a['startTime']}';
      final bd = '${b['date']} ${b['startTime']}';
      return ad.compareTo(bd);
    });
    for (final e in sorted) {
      final start = DateTime.parse('${e['date']}T${e['startTime']}');
      final end = DateTime.parse('${e['date']}T${e['endTime']}');
      if (start.isAfter(now)) return 'Free now — next activity starts ${_time('${e['startTime']}')}';
      if (now.isAfter(start) && now.isBefore(end)) return 'Occupied now — free at ${_time('${e['endTime']}')}';
    }
    return events.isEmpty ? 'No scheduled activity in the next 7 days.' : 'No later activity is scheduled in the next 7 days.';
  }

  @override
  Widget build(BuildContext context) {
    final grouped = _grouped();
    final width = MediaQuery.sizeOf(context).width;
    return AlertDialog(
      insetPadding: EdgeInsets.symmetric(horizontal: width < 600 ? 12 : 40, vertical: 20),
      titlePadding: const EdgeInsets.fromLTRB(22, 20, 12, 8),
      contentPadding: const EdgeInsets.fromLTRB(22, 0, 22, 18),
      title: Row(children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('${room['roomNo'] ?? 'Room'}', style: const TextStyle(fontWeight: FontWeight.w800, color: navy, fontSize: 22)),
          const SizedBox(height: 3),
          Text('${room['roomType'] ?? 'Classroom'} • Capacity ${room['capacity'] ?? '—'}', style: const TextStyle(color: muted, fontSize: 12)),
        ])),
        IconButton(onPressed: () => Navigator.of(context).pop(), icon: const Icon(Icons.close_rounded)),
      ]),
      content: SizedBox(
        width: width < 600 ? width - 50 : 760,
        child: SingleChildScrollView(
          child: loading
              ? const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator()))
              : error != null
                  ? _ErrorBox(message: 'Could not load future schedule: $error')
                  : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF4F7FF),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFDDE5FF)),
                        ),
                        child: Row(children: [
                          Container(width: 38, height: 38, decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle), child: const Icon(Icons.schedule_rounded, color: Colors.indigo)),
                          const SizedBox(width: 12),
                          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            const Text('Availability outlook', style: TextStyle(fontWeight: FontWeight.w800, color: navy)),
                            const SizedBox(height: 3),
                            Text(_nextFreeSummary(), style: const TextStyle(color: muted, fontSize: 12)),
                          ])),
                        ]),
                      ),
                      const SizedBox(height: 18),
                      const Text('Upcoming schedule', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: navy)),
                      const SizedBox(height: 4),
                      const Text('Timetable classes and confirmed room bookings for the next 7 days.', style: TextStyle(color: muted, fontSize: 12)),
                      const SizedBox(height: 12),
                      if (grouped.isEmpty)
                        const _EmptySchedule()
                      else
                        ...grouped.entries.map((entry) => Padding(
                          padding: const EdgeInsets.only(bottom: 14),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(_dayLabel(entry.key), style: const TextStyle(fontWeight: FontWeight.w800, color: navy, fontSize: 12)),
                            const SizedBox(height: 8),
                            ...entry.value.map((e) => _EventCard(event: e)),
                          ]),
                        )),
                    ]),
        ),
      ),
      actionsPadding: const EdgeInsets.fromLTRB(22, 0, 22, 14),
      actions: [TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Close'))],
    );
  }
}

class _EventCard extends StatelessWidget {
  final Map<String, dynamic> event;
  const _EventCard({required this.event});

  @override
  Widget build(BuildContext context) {
    final booking = '${event['type']}'.toUpperCase() == 'BOOKING';
    final color = booking ? Colors.blueAccent : Colors.redAccent;
    return Container(
      margin: const EdgeInsets.only(bottom: 7),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE3E8F2)),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(width: 5, height: 48, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(10))),
        const SizedBox(width: 11),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('${event['title'] ?? 'Scheduled activity'}', style: const TextStyle(fontWeight: FontWeight.w700, color: navy)),
          const SizedBox(height: 4),
          Text('${event['section'] ?? (booking ? 'Confirmed room booking' : 'Scheduled class')}', style: const TextStyle(color: muted, fontSize: 11)),
        ])),
        const SizedBox(width: 10),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text('${_fmt(event['startTime'])} – ${_fmt(event['endTime'])}', style: TextStyle(fontWeight: FontWeight.w700, color: color, fontSize: 11)),
          const SizedBox(height: 4),
          Text(booking ? 'BOOKED' : 'CLASS', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: color)),
        ]),
      ]),
    );
  }

  static String _fmt(dynamic value) {
    final parts = '$value'.split(':');
    final h = int.tryParse(parts[0]) ?? 0;
    final m = int.tryParse(parts[1]) ?? 0;
    final suffix = h >= 12 ? 'PM' : 'AM';
    final display = h % 12 == 0 ? 12 : h % 12;
    return '$display:${m.toString().padLeft(2, '0')} $suffix';
  }
}

class _EmptySchedule extends StatelessWidget {
  const _EmptySchedule();
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(color: const Color(0xFFF8FAFD), borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFFE4EAF3))),
    child: const Row(children: [
      Icon(Icons.event_available_rounded, color: Colors.green),
      SizedBox(width: 10),
      Expanded(child: Text('No timetable class or confirmed booking is scheduled for this room in the next 7 days.', style: TextStyle(color: muted, fontSize: 12))),
    ]),
  );
}

class _ErrorBox extends StatelessWidget {
  final String message;
  const _ErrorBox({required this.message});
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(color: const Color(0xFFFFF7F7), borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFFF4CCCC))),
    child: Text(message, style: const TextStyle(color: Colors.redAccent, fontSize: 12)),
  );
}

class _InfoBanner extends StatelessWidget {
  final IconData icon;
  final String text;
  const _InfoBanner({required this.icon, required this.text});
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
    decoration: BoxDecoration(color: const Color(0xFFF4F7FF), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFDDE5FF))),
    child: Row(children: [Icon(icon, size: 18, color: Colors.indigo), const SizedBox(width: 9), Expanded(child: Text(text, style: const TextStyle(color: muted, fontSize: 12)))]),
  );
}

class _Metric extends StatelessWidget {
  final String a, b;
  final Color c;
  const _Metric(this.a, this.b, this.c);
  @override
  Widget build(BuildContext x) => Expanded(
    child: Card(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12), child: Row(children: [
      Container(width: 8, height: 8, decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
      const SizedBox(width: 8),
      Expanded(child: Text(a, style: const TextStyle(color: muted, fontSize: 11))),
      Text(b, style: const TextStyle(fontWeight: FontWeight.w800, color: navy)),
    ]))),
  );
}
