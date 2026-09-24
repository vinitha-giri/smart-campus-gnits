import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'api_config.dart';
import 'app_theme.dart';
import 'common_widgets.dart';
import 'realtime_service.dart';

class OccupancyScreen extends StatefulWidget {
  const OccupancyScreen({super.key});
  @override State<OccupancyScreen> createState() => _OccupancyScreenState();
}

class _OccupancyScreenState extends State<OccupancyScreen> {
  String day = _todayCampusDay();
  String? time;
  TimeOfDay? selectedTime;
  List<Map<String, String>> slots = [];
  List<OccupancyRoom> rooms = [];
  bool loading = true;
  bool slotsLoading = true;
  String? error;
  Timer? timer;
  StreamSubscription<Map<String, dynamic>>? realtimeSubscription;
  bool liveNow = true;
  String classTypeFilter = 'ALL';
  String blockFilter = 'ALL';
  int minCapacity = 0;
  int _fetchRequestId = 0;
  bool _isFetching = false;
bool _fetchQueued = false;

  static String _todayCampusDay() {
    final n = DateTime.now().weekday;
    return n >= 1 && n <= 6 ? const ['MONDAY','TUESDAY','WEDNESDAY','THURSDAY','FRIDAY','SATURDAY'][n - 1] : 'MONDAY';
  }

  @override
  void initState() {
    super.initState();
    loadSlots().then((_) {
      final now = TimeOfDay.now();
      selectedTime = now;
      time = _timeString(now);
      fetch();
    });
    RealtimeService.instance.start();
    realtimeSubscription = RealtimeService.instance.events.listen((event) {
      final type = event['type']?.toString() ?? '';
      if (type == 'BOOKING_CHANGED' || type == 'ROOM_CHANGED' || type == 'TIMETABLE_CHANGED' || type == 'ROOM_STATUS_CHANGED') fetch(silent: true);
    });
    timer = Timer.periodic(const Duration(seconds: 15), (_) => fetch(silent: true));
  }
  @override void dispose() { timer?.cancel(); realtimeSubscription?.cancel(); super.dispose(); }

  static String _timeString(TimeOfDay t) => '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  static String _formatTime(TimeOfDay? t) {
    if (t == null) return 'Select time';
    final h = t.hourOfPeriod == 0 ? 12 : t.hourOfPeriod;
    final m = t.minute.toString().padLeft(2, '0');
    return '$h:$m ${t.period == DayPeriod.am ? 'AM' : 'PM'}';
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: selectedTime ?? TimeOfDay.now(),
      helpText: 'Select a particular time',
      cancelText: 'Cancel',
      confirmText: 'Check occupancy',
    );
    if (picked == null || !mounted) return;
    setState(() {
      selectedTime = picked;
      time = _timeString(picked);
      liveNow = false;
    });
    await fetch();
  }

  Future<void> loadSlots() async {
    setState(() => slotsLoading = true);
    try {
      final r = await http.get(Uri.parse('${ApiConfig.baseUrl}/api/occupancy/slots').replace(queryParameters: {'day': day, 'academicYear': '2026-2027', 'semesterNo': '1'}));
      if (r.statusCode != 200) throw Exception(r.body);
      final rawList = (jsonDecode(r.body) as List).map((e) => Map<String, String>.from(e)).toList();
      final seenStartTimes = <String>{};
      final list = <Map<String, String>>[
        for (final slot in rawList)
          if (slot['startTime'] != null && seenStartTimes.add(slot['startTime']!)) slot,
      ];
      if (mounted) setState(() {
        slots = list;
        if (selectedTime == null) {
          final now = TimeOfDay.now();
          selectedTime = now;
          time = _timeString(now);
        }
      });
    } catch (e) {
      if (mounted) setState(() => error = 'Could not load timetable time slots: $e');
    } finally { if (mounted) setState(() => slotsLoading = false); }
  }
Future<void> fetch({bool silent = false}) async {
  if (time == null) {
    if (mounted) {
      setState(() => loading = false);
    }
    return;
  }

  // Prevent multiple database/API requests from running at the same time.
  if (_isFetching) {
    _fetchQueued = true;
    return;
  }

  _isFetching = true;

  if (!silent && mounted) {
    setState(() => loading = true);
  }

  try {
    final uri = liveNow
        ? Uri.parse('${ApiConfig.baseUrl}/api/rooms/live-status')
        : Uri.parse('${ApiConfig.baseUrl}/api/occupancy').replace(
            queryParameters: {
              'day': day,
              'time': time!,
              'academicYear': '2026-2027',
              'semesterNo': '1',
            },
          );

    final r = await http.get(uri);

    if (r.statusCode != 200) {
      throw Exception(r.body);
    }

    final list = jsonDecode(r.body) as List;

    if (!mounted) return;

    setState(() {
      rooms = list
          .map((e) => OccupancyRoom.fromJson(e))
          .toList();
      error = null;
    });
  } catch (e) {
    if (mounted) {
      setState(() {
        error = e.toString();
      });
    }
  } finally {
    if (mounted && !silent) {
      setState(() => loading = false);
    }

    // The current request has finished.
    _isFetching = false;

    // If another refresh was requested while this request
    // was running, perform exactly ONE more refresh.
    if (_fetchQueued && mounted) {
      _fetchQueued = false;

      Future.microtask(() {
        if (mounted) {
          fetch(silent: true);
        }
      });
    }
  }
}
  // Future<void> fetch({bool silent = false}) async {
  // if (time == null) {
  //   if (mounted) setState(() => loading = false);
  //   return;
  // }

  // Give this request a unique number.
  // If another request starts before this one finishes,
  // this old request will no longer be allowed to update the UI.
//   final requestId = ++_fetchRequestId;

//   if (!silent && mounted) {
//     setState(() => loading = true);
//   }

//   try {
//     final uri = liveNow
//         ? Uri.parse('${ApiConfig.baseUrl}/api/rooms/live-status')
//         : Uri.parse('${ApiConfig.baseUrl}/api/occupancy').replace(
//             queryParameters: {
//               'day': day,
//               'time': time!,
//               'academicYear': '2026-2027',
//               'semesterNo': '1',
//             },
//           );

//     final r = await http.get(uri);

//     if (r.statusCode != 200) {
//       throw Exception(r.body);
//     }

//     final list = jsonDecode(r.body) as List;

//     // Ignore this response if a newer request has already started.
//     if (!mounted || requestId != _fetchRequestId) return;

//     setState(() {
//       rooms = list
//           .map((e) => OccupancyRoom.fromJson(e))
//           .toList();
//       error = null;
//     });
//   } catch (e) {
//     // Also ignore errors from old requests.
//     if (!mounted || requestId != _fetchRequestId) return;

//     setState(() {
//       error = e.toString();
//     });
//   } finally {
//     // Only the newest request is allowed to control the loading state.
//     if (mounted && !silent && requestId == _fetchRequestId) {
//       setState(() => loading = false);
//     }
//   }
// }

  Color statusColor(String s) {
    switch (s) {
      case 'OCCUPIED': return coral;
      case 'BOOKED': return purple;
      case 'MAINTENANCE': return amber;
      case 'RESERVED': return const Color(0xFFA855F7);
      default: return neonGreen;
    }
  }

  String _blockOf(String roomNo) {
    final m = RegExp(r'^\s*([A-Za-z])').firstMatch(roomNo);
    return m?.group(1)?.toUpperCase() ?? '';
  }

  bool _typeMatches(OccupancyRoom room) {
    if (classTypeFilter == 'ALL') return true;
    final t = room.roomType.toUpperCase().replaceAll(RegExp(r'[_-]+'), ' ');
    switch (classTypeFilter) {
      case 'CLASSROOM': return t.contains('CLASS') || t.contains('E CLASSROOM') || t.contains('ECLASSROOM');
      case 'LAB': return t.contains('LAB');
      case 'SEMINAR HALL': return t.contains('SEMINAR') || t.contains('HALL');
      case 'CONFERENCE': return t.contains('CONFERENCE');
      default: return true;
    }
  }

  bool _capacityMatches(OccupancyRoom room) => (room.capacity ?? 0) >= minCapacity;

  List<OccupancyRoom> _filteredRooms() => rooms.where((r) =>
      (blockFilter == 'ALL' || _blockOf(r.roomNo) == blockFilter) &&
      _typeMatches(r) && _capacityMatches(r)).toList();

  void _clearFilters() {
    setState(() { classTypeFilter = 'ALL'; blockFilter = 'ALL'; minCapacity = 0; });
  }

  String imageFor(String type) {
    final t = type.toUpperCase();
    if (t.contains('SEMINAR') || t.contains('HALL') || t.contains('AUDITOR')) return hallImage;
    return classroomImage;
  }

  void _showRoomDetails(BuildContext context, OccupancyRoom r, String selectedDay, String slotLabel) {
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: Row(children: [
          Expanded(child: Text(r.roomNo, style: const TextStyle(fontWeight: FontWeight.w900))),
          StatusPill(r.status, statusColor(r.status)),
        ]),
        content: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width - 40),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${r.roomType} • ${r.capacity ?? '—'} seats', style: const TextStyle(color: muted)),
            const Divider(height: 24),
            _detail('Day', selectedDay),
            _detail('Checked slot', slotLabel),
            _detail('Reason', r.status == 'OCCUPIED' ? 'Scheduled class' : r.status == 'BOOKED' ? 'Confirmed booking' : r.status == 'AVAILABLE' ? 'No class or booking' : 'Administrative restriction'),
            if (r.subject != null) _detail('Class / purpose', r.subject!),
            if (r.section != null) _detail(r.status == 'BOOKED' ? 'Booked by' : 'Section', r.section!),
            if (r.startTime != null) _detail('Time', '${r.startTime} – ${r.endTime ?? '—'}'),
          ]),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close'))],
      ),
    );
  }

  Widget _detail(String label, String value) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SizedBox(width: 105, child: Text(label, style: const TextStyle(color: muted, fontSize: 11))),
      Expanded(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w700, color: navy, fontSize: 11))),
    ]),
  );

  @override
  Widget build(BuildContext context) {
    final filteredRooms = _filteredRooms();
    final occupied = filteredRooms.where((r) => r.status == 'OCCUPIED' || r.status == 'BOOKED').length;
    final available = filteredRooms.where((r) => r.status == 'AVAILABLE').length;
    final maintenance = filteredRooms.where((r) => r.status == 'MAINTENANCE').length;
    final label = liveNow ? 'Live now' : _formatTime(selectedTime);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 40),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1450),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Live Occupancy', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: navy)),
                SizedBox(height: 5),
                Text('A visual room network driven by the actual timetable and booking state.', style: TextStyle(color: muted)),
              ])),
              IconButton(onPressed: fetch, tooltip: 'Refresh', icon: const Icon(Icons.refresh_rounded)),
            ]),
            const SizedBox(height: 18),
            Row(children: [
              FilledButton.icon(onPressed: () { setState(() => liveNow = true); fetch(); }, icon: const Icon(Icons.radar_rounded, size: 17), label: const Text('LIVE NOW')),
              const SizedBox(width: 10),
              Text(liveNow ? 'Showing the server-calculated current room state' : 'Showing selected timetable slot', style: const TextStyle(color: muted, fontSize: 12)),
            ]),
            const SizedBox(height: 12),
            Card(child: Padding(padding: const EdgeInsets.all(16), child: Wrap(spacing: 14, runSpacing: 14, children: [
              SizedBox(width: 220, child: DropdownButtonFormField<String>(
                value: day, decoration: const InputDecoration(labelText: 'Day'),
                items: [for (final d in const ['MONDAY','TUESDAY','WEDNESDAY','THURSDAY','FRIDAY','SATURDAY']) DropdownMenuItem(value: d, child: Text(d)),
                ], onChanged: (v) async { if (v != null) { setState(() { day = v; liveNow = false; }); await loadSlots(); await fetch(); } },
              )),
              SizedBox(width: 250, child: OutlinedButton.icon(
                onPressed: _pickTime,
                icon: const Icon(Icons.access_time_rounded),
                label: Align(alignment: Alignment.centerLeft, child: Text(_formatTime(selectedTime))),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(56),
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  side: BorderSide(color: Colors.black.withOpacity(.14)),
                ),
              )),
              if (!liveNow) Padding(
                padding: const EdgeInsets.only(left: 2),
                child: Text('Checks the timetable/booking at exactly ${_formatTime(selectedTime)}', style: const TextStyle(color: muted, fontSize: 11)),
              ),
              if (slotsLoading) const Padding(padding: EdgeInsets.all(14), child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2))),
            ]))),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    const Icon(Icons.filter_alt_rounded, size: 18, color: navy),
                    const SizedBox(width: 8),
                    const Expanded(child: Text('Find classrooms faster', style: TextStyle(fontWeight: FontWeight.w900, color: navy))),
                    if (classTypeFilter != 'ALL' || blockFilter != 'ALL' || minCapacity > 0)
                      TextButton.icon(onPressed: _clearFilters, icon: const Icon(Icons.clear_all_rounded, size: 17), label: const Text('Clear')),
                  ]),
                  const SizedBox(height: 12),
                  LayoutBuilder(builder: (context, c) {
                    final w = c.maxWidth >= 1050 ? (c.maxWidth - 28) / 3 : c.maxWidth >= 700 ? (c.maxWidth - 14) / 2 : c.maxWidth;
                    return Wrap(spacing: 14, runSpacing: 14, children: [
                      SizedBox(width: w, child: DropdownButtonFormField<String>(
                        value: classTypeFilter,
                        decoration: const InputDecoration(labelText: 'Class type', prefixIcon: Icon(Icons.meeting_room_outlined)),
                        items: const [
                          DropdownMenuItem(value: 'ALL', child: Text('All class types')),
                          DropdownMenuItem(value: 'CLASSROOM', child: Text('Classroom')),
                          DropdownMenuItem(value: 'LAB', child: Text('Lab')),
                          DropdownMenuItem(value: 'SEMINAR HALL', child: Text('Seminar hall')),
                          DropdownMenuItem(value: 'CONFERENCE', child: Text('Conference')),
                        ],
                        onChanged: (v) => setState(() => classTypeFilter = v ?? 'ALL'),
                      )),
                      SizedBox(width: w, child: DropdownButtonFormField<String>(
                        value: blockFilter,
                        decoration: const InputDecoration(labelText: 'Block', prefixIcon: Icon(Icons.apartment_rounded)),
                        items: const [
                          DropdownMenuItem(value: 'ALL', child: Text('All blocks')),
                          DropdownMenuItem(value: 'A', child: Text('A Block')),
                          DropdownMenuItem(value: 'B', child: Text('B Block')),
                          DropdownMenuItem(value: 'C', child: Text('C Block')),
                          DropdownMenuItem(value: 'D', child: Text('D Block')),
                          DropdownMenuItem(value: 'F', child: Text('F Block')),
                          DropdownMenuItem(value: 'S', child: Text('S Block')),
                        ],
                        onChanged: (v) => setState(() => blockFilter = v ?? 'ALL'),
                      )),
                      SizedBox(width: w, child: DropdownButtonFormField<int>(
                        value: minCapacity,
                        decoration: const InputDecoration(labelText: 'Capacity', prefixIcon: Icon(Icons.groups_rounded)),
                        items: const [
                          DropdownMenuItem(value: 0, child: Text('Any capacity')),
                          DropdownMenuItem(value: 30, child: Text('30+ seats')),
                          DropdownMenuItem(value: 50, child: Text('50+ seats')),
                          DropdownMenuItem(value: 75, child: Text('75+ seats')),
                          DropdownMenuItem(value: 100, child: Text('100+ seats')),
                        ],
                        onChanged: (v) => setState(() => minCapacity = v ?? 0),
                      )),
                    ]);
                  }),
                  const SizedBox(height: 10),
                  Text('${filteredRooms.length} classroom${filteredRooms.length == 1 ? '' : 's'} match your filters', style: const TextStyle(color: muted, fontSize: 11, fontWeight: FontWeight.w600)),
                ]),
              ),
            ),
            const SizedBox(height: 14),
            LayoutBuilder(builder: (context, constraints) {
              final cardWidth = constraints.maxWidth >= 760
                  ? (constraints.maxWidth - 20) / 3
                  : constraints.maxWidth >= 500
                      ? (constraints.maxWidth - 10) / 2
                      : constraints.maxWidth;
              return Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  SizedBox(width: cardWidth, child: _Mini('Available', '$available', neonGreen)),
                  SizedBox(width: cardWidth, child: _Mini('Occupied / booked', '$occupied', coral)),
                  SizedBox(width: cardWidth, child: _Mini('Maintenance', '$maintenance', amber)),
                ],
              );
            }),
            const SizedBox(height: 16),
            if (error != null) ErrorCard(message: error!),
            if (loading)
              const Padding(padding: EdgeInsets.all(50), child: Center(child: CircularProgressIndicator()))
            else if (filteredRooms.isEmpty)
              EmptyCard(title: rooms.isEmpty ? 'No room data' : 'No rooms match these filters', text: rooms.isEmpty ? 'No rooms are available for this selection.' : 'Try another class type, block, or capacity.')
            else
              LayoutBuilder(builder: (c, b) {
                final cols = b.maxWidth > 1180 ? 4 : b.maxWidth > 760 ? 3 : b.maxWidth > 480 ? 2 : 1;
                return GridView.builder(
                  shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), itemCount: filteredRooms.length,
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: cols, crossAxisSpacing: 14, mainAxisSpacing: 14, childAspectRatio: 1.18),
                  itemBuilder: (c, i) {
                    final r = filteredRooms[i];
                    final color = statusColor(r.status);
                    final occupiedNow = r.status == 'OCCUPIED' || r.status == 'BOOKED';
                    return _RoomVisualCard(
                      room: r,
                      statusColor: color,
                      imageUrl: imageFor(r.roomType),
                      occupiedNow: occupiedNow,
                      availableLabel: label,
                      onTap: () => _showRoomDetails(context, r, day, label),
                    );
                  },
                );
              }),
          ]),
        ),
      ),
    );
  }
}

class _RoomVisualCard extends StatelessWidget {
  final OccupancyRoom room;
  final Color statusColor;
  final String imageUrl;
  final bool occupiedNow;
  final String availableLabel;
  final VoidCallback onTap;
  const _RoomVisualCard({required this.room, required this.statusColor, required this.imageUrl, required this.occupiedNow, required this.availableLabel, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final title = room.roomType.toUpperCase().contains('SEMINAR') || room.roomType.toUpperCase().contains('HALL') ? 'Seminar Hall' : 'Classroom';
    final subtitle = occupiedNow
        ? '${room.subject ?? 'Occupied'}${room.section == null ? '' : ' • ${room.section}'}'
        : room.status == 'AVAILABLE'
            ? 'Available for ${availableLabel.isEmpty ? 'this slot' : availableLabel}'
            : 'Operational status restriction';

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: statusColor.withOpacity(.28)),
        boxShadow: [BoxShadow(color: statusColor.withOpacity(.06), blurRadius: 24, offset: const Offset(0, 10))],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.network(imageUrl, fit: BoxFit.cover, errorBuilder: (_, __, ___) => Container(color: surface2)),
          Container(color: const Color(0xB50B0F19)),
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.transparent, const Color(0xF20B0F19)],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(child: Text(room.roomNo, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900))),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
                  decoration: BoxDecoration(color: statusColor.withOpacity(.18), borderRadius: BorderRadius.circular(20), border: Border.all(color: statusColor.withOpacity(.45))),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Container(width: 6, height: 6, decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle)),
                    const SizedBox(width: 6),
                    Text(room.status, style: TextStyle(color: statusColor, fontSize: 8, fontWeight: FontWeight.w900)),
                  ]),
                ),
              ]),
              const SizedBox(height: 6),
              Text('$title • ${room.capacity ?? '—'} seats', style: const TextStyle(color: Colors.white70, fontSize: 10)),
              const Spacer(),
              if (occupiedNow && room.startTime != null && room.endTime != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: const LinearProgressIndicator(value: .58, minHeight: 5, backgroundColor: Colors.white12, color: coral),
                ),
              const SizedBox(height: 10),
              Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 11, height: 1.35)),
              if (occupiedNow && room.startTime != null) Text('${room.startTime} – ${room.endTime ?? '—'}', style: const TextStyle(color: Colors.white54, fontSize: 9)),
              const SizedBox(height: 8),
              Row(children: [
                const Icon(Icons.schedule_rounded, color: Colors.white54, size: 13),
                const SizedBox(width: 5),
                Expanded(child: Text(occupiedNow ? 'Live schedule data' : 'Timetable-aware availability', style: const TextStyle(color: Colors.white54, fontSize: 9))),
              ]),
            ]),
          ),
        ],
      ),
    ),
    );
  }
}

class _Mini extends StatelessWidget {
  final String a, b; final Color c;
  const _Mini(this.a, this.b, this.c);
  @override Widget build(BuildContext x) => Card(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12), child: Row(children: [Container(width: 8, height: 8, decoration: BoxDecoration(color: c, shape: BoxShape.circle)), const SizedBox(width: 8), Expanded(child: Text(a, style: const TextStyle(color: muted, fontSize: 10))), Text(b, style: const TextStyle(fontWeight: FontWeight.w800, color: navy))])));
}
