import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'api_config.dart';
import 'app_theme.dart';
import 'common_widgets.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});
  @override State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  Map<String, dynamic>? data;
  Map<String, dynamic>? dayData;
  bool loading = true;
  bool dayLoading = false;
  String selectedDay = _campusDay();
  String year = '2026-2027';
  int sem = 1;
  String section = 'ALL';
  late final TextEditingController yearController;
  static const days = ['MONDAY','TUESDAY','WEDNESDAY','THURSDAY','FRIDAY','SATURDAY'];

  static String _campusDay() {
    final n = DateTime.now().weekday;
    return n >= 1 && n <= 6 ? days[n - 1] : 'MONDAY';
  }

  @override void initState() { super.initState(); yearController = TextEditingController(text: year); load(); }
  @override void dispose() { yearController.dispose(); super.dispose(); }

  Map<String, String> get _query => {
    'academicYear': year,
    'semesterNo': '$sem',
    if (section != 'ALL') 'sectionName': section,
  };

  Future<void> load() async {
    setState(() => loading = true);
    try {
      final response = await http.get(Uri.parse('${ApiConfig.baseUrl}/api/reports/summary').replace(queryParameters: _query));
      if (response.statusCode != 200) throw Exception(response.body);
      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      final names = ((decoded['sectionNames'] as List?) ?? []).map((e) => '$e').toList();
      if (section != 'ALL' && !names.contains(section)) section = 'ALL';
      if (mounted) setState(() => data = decoded);
      await loadDay(selectedDay);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Reports unavailable: $e')));
    } finally { if (mounted) setState(() => loading = false); }
  }

  Future<void> loadDay(String day) async {
    setState(() { selectedDay = day; dayLoading = true; });
    try {
      final q = Map<String, String>.from(_query)..['day'] = day;
      final response = await http.get(Uri.parse('${ApiConfig.baseUrl}/api/reports/day').replace(queryParameters: q));
      if (response.statusCode != 200) throw Exception(response.body);
      if (mounted) setState(() => dayData = jsonDecode(response.body));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not load $day details: $e')));
    } finally { if (mounted) setState(() => dayLoading = false); }
  }

  Future<void> exportReport() async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/api/reports/export').replace(queryParameters: _query);
    if (!await launchUrl(uri, mode: LaunchMode.platformDefault) && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not open the Excel report.')));
    }
  }

  Widget dayCard(String day, num count) {
    final selected = day == selectedDay;
    return SizedBox(
      width: 190,
      child: InkWell(
        onTap: () => loadDay(day),
        borderRadius: BorderRadius.circular(13),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(color: selected ? purple.withOpacity(.08) : Colors.white, borderRadius: BorderRadius.circular(13), border: Border.all(color: selected ? purple : border, width: selected ? 1.3 : 1)),
          child: Row(children: [
            Container(width: 34, height: 34, decoration: BoxDecoration(color: selected ? purple : canvas, borderRadius: BorderRadius.circular(9)), child: Icon(Icons.calendar_today_outlined, size: 16, color: selected ? Colors.white : navy)),
            const SizedBox(width: 9),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(day, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: selected ? purple : navy)), const SizedBox(height: 2), Text('$count scheduled', style: const TextStyle(fontSize: 9, color: muted))])),
            if (selected && dayLoading) const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 1.8)),
          ]),
        ),
      ),
    );
  }

  Widget dayDetails() {
    final d = dayData ?? {};
    final timetable = (d['timetable'] as List?)?.cast<Map>() ?? [];
    final bookings = (d['bookings'] as List?)?.cast<Map>() ?? [];
    return Card(child: Padding(padding: const EdgeInsets.all(20), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('$selectedDay operations', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: navy)),
          const SizedBox(height: 3),
          Text('Week date: ${d['reportDate'] ?? '—'} • ${timetable.length} timetable slots • ${bookings.length} confirmed bookings', style: const TextStyle(color: muted, fontSize: 11)),
        ])),
        if (dayLoading) const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
      ]),
      const SizedBox(height: 16),
      if (timetable.isNotEmpty) ...[
        const Text('Scheduled classes', style: TextStyle(fontWeight: FontWeight.w800, color: navy)),
        const SizedBox(height: 7),
        SingleChildScrollView(scrollDirection: Axis.horizontal, child: DataTable(
          columns: const [DataColumn(label: Text('Time')), DataColumn(label: Text('Room')), DataColumn(label: Text('Subject')), DataColumn(label: Text('Section'))],
          rows: timetable.map((e) => DataRow(cells: [DataCell(Text('${e['startTime']}–${e['endTime']}')), DataCell(Text('${e['roomNo']}', style: const TextStyle(fontWeight: FontWeight.w800))), DataCell(Text('${e['subject']}')), DataCell(Text('${e['section']}'))])).toList(),
        )),
      ],
      if (bookings.isNotEmpty) ...[
        const SizedBox(height: 16),
        const Text('Confirmed bookings', style: TextStyle(fontWeight: FontWeight.w800, color: navy)),
        const SizedBox(height: 7),
        SingleChildScrollView(scrollDirection: Axis.horizontal, child: DataTable(
          columns: const [DataColumn(label: Text('Time')), DataColumn(label: Text('Room')), DataColumn(label: Text('Purpose')), DataColumn(label: Text('Booked by'))],
          rows: bookings.map((e) => DataRow(cells: [DataCell(Text('${e['startTime']}–${e['endTime']}')), DataCell(Text('${e['roomNo']}')), DataCell(Text('${e['purpose']}')), DataCell(Text('${e['bookedBy']}'))])).toList(),
        )),
      ],
      if (timetable.isEmpty && bookings.isEmpty) const EmptyCard(title: 'No activity for this day', text: 'No timetable slots or confirmed bookings match the selected filters.'),
    ])));
  }

  @override
  Widget build(BuildContext context) {
    final d = data ?? {};
    final counts = (d['dayCounts'] as Map?)?.cast<String, dynamic>() ?? {};
    final sections = ((d['sectionNames'] as List?) ?? []).map((e) => '$e').toList();
    final rooms = (d['roomUtilization'] as List?) ?? [];

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 44),
      child: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 1420), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Reports & Analytics', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: navy)), SizedBox(height: 5), Text('Live, filter-aware operational reporting from timetable and booking data.', style: TextStyle(color: muted))])),
          IconButton(onPressed: load, tooltip: 'Refresh', icon: const Icon(Icons.refresh_rounded)),
          FilledButton.icon(onPressed: exportReport, style: FilledButton.styleFrom(backgroundColor: purple), icon: const Icon(Icons.download_outlined), label: const Text('Export Excel')),
        ]),
        const SizedBox(height: 18),
        Card(child: Padding(padding: const EdgeInsets.all(14), child: Wrap(spacing: 12, runSpacing: 12, children: [
          SizedBox(width: 220, child: TextField(controller: yearController, decoration: const InputDecoration(labelText: 'Academic year'))),
          SizedBox(width: 155, child: DropdownButtonFormField<int>(value: sem, decoration: const InputDecoration(labelText: 'Semester'), items: const [DropdownMenuItem(value: 1, child: Text('Semester 1')), DropdownMenuItem(value: 2, child: Text('Semester 2'))], onChanged: (v) { if (v != null) setState(() => sem = v); })),
          SizedBox(width: 210, child: DropdownButtonFormField<String>(value: sections.contains(section) ? section : 'ALL', decoration: const InputDecoration(labelText: 'Section'), items: [const DropdownMenuItem(value: 'ALL', child: Text('All sections')), for (final s in sections) DropdownMenuItem(value: s, child: Text(s))], onChanged: (v) { if (v != null) setState(() => section = v); })),
          FilledButton.icon(onPressed: () { year = yearController.text.trim(); load(); }, style: FilledButton.styleFrom(backgroundColor: navy), icon: const Icon(Icons.filter_alt_outlined), label: const Text('Apply filters')),
        ]))),
        const SizedBox(height: 18),
        if (loading)
          const Padding(padding: EdgeInsets.all(50), child: Center(child: CircularProgressIndicator()))
        else ...[
          LayoutBuilder(builder: (c, b) {
            final cols = b.maxWidth > 1050 ? 4 : b.maxWidth > 650 ? 2 : 1;
            return GridView.count(crossAxisCount: cols, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), crossAxisSpacing: 14, mainAxisSpacing: 14, childAspectRatio: 2.55, children: [
              AppKpi('Scheduled today', '${d['scheduledToday'] ?? 0}', Icons.event_note_outlined, navy),
              AppKpi('Active now', '${d['activeNow'] ?? 0}', Icons.sensors_outlined, Colors.redAccent),
              AppKpi('Bookings today', '${d['bookingsToday'] ?? 0}', Icons.event_available_outlined, Colors.teal),
              AppKpi('Available now', '${d['availableRooms'] ?? 0}', Icons.check_circle_outline, Colors.green),
            ]);
          }),
          const SizedBox(height: 18),
          Card(child: Padding(padding: const EdgeInsets.all(20), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const SectionHeader(title: 'Weekly activity', subtitle: 'Compact weekly view. Select a day to load its actual classes and bookings.'),
            const SizedBox(height: 14),
            Wrap(spacing: 10, runSpacing: 10, children: [for (final day in days) dayCard(day, (counts[day] ?? 0) as num)]),
          ]))),
          const SizedBox(height: 16),
          dayDetails(),
          const SizedBox(height: 16),
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(child: Card(child: Padding(padding: const EdgeInsets.all(20), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const SectionHeader(title: 'Current utilization', subtitle: 'Occupied operational rooms ÷ operational rooms, right now'),
              const SizedBox(height: 14),
              Text('${d['currentUtilizationPercent'] ?? 0}%', style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w800, color: navy)),
              const SizedBox(height: 5),
              const Text('Useful for management to understand live campus demand; it does not determine whether a room is bookable.', style: TextStyle(color: muted, fontSize: 11, height: 1.4)),
              const SizedBox(height: 12),
              Builder(builder: (_) { final value = ((d['currentUtilizationPercent'] ?? 0) as num).toDouble(); return LinearProgressIndicator(value: (value / 100).clamp(0, 1), minHeight: 8, backgroundColor: canvas, color: purple); }),
            ])))),
            const SizedBox(width: 14),
            Expanded(child: Card(child: Padding(padding: const EdgeInsets.all(20), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const SectionHeader(title: 'Most scheduled rooms', subtitle: 'Filtered timetable load by room'),
              const SizedBox(height: 14),
              if (rooms.isEmpty) const Text('No room activity for the selected filters.', style: TextStyle(color: muted))
              else for (final x in rooms.take(6)) AnalyticsBar('${(x as Map)['roomNo'] ?? '—'}', ((x['scheduledSlots'] ?? 0) as num)),
            ])))),
          ]),
        ],
      ]))),
    );
  }
}
