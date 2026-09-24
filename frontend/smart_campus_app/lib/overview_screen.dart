import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'api_config.dart';
import 'app_theme.dart';
import 'common_widgets.dart';

class OverviewScreen extends StatefulWidget {
  final String role;
  final String username;
  final void Function(String label, {String query})? onNavigate;
  const OverviewScreen({super.key, required this.role, required this.username, this.onNavigate});
  @override State<OverviewScreen> createState() => _OverviewScreenState();
}

class _OverviewScreenState extends State<OverviewScreen> with SingleTickerProviderStateMixin {
  Map<String, dynamic>? data;
  bool loading = true;
  Timer? timer;
  late final AnimationController pulse = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat(reverse: true);

  @override
  void initState() {
    super.initState();
    load();
    timer = Timer.periodic(const Duration(seconds: 30), (_) => load(silent: true));
  }

  @override
  void dispose() { timer?.cancel(); pulse.dispose(); super.dispose(); }

  Future<void> load({bool silent = false}) async {
    if (!silent && mounted) setState(() => loading = true);
    try {
      final r = await http.get(Uri.parse('${ApiConfig.baseUrl}/api/reports/summary'));
      if (r.statusCode == 200 && mounted) setState(() => data = jsonDecode(r.body));
    } catch (_) {}
    finally {
      if (mounted && !silent) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = data ?? {};
    final total = d['totalRooms'] ?? 0;
    final available = d['availableRooms'] ?? 0;
    final occupied = d['occupiedRooms'] ?? 0;
    final maintenance = d['maintenanceRooms'] ?? 0;
    final booked = d['bookedRooms'] ?? 0;
    final scheduled = d['scheduledToday'] ?? 0;
    final bookings = d['bookingsToday'] ?? 0;
    final active = d['activeNow'] ?? occupied;

    return RefreshIndicator(
      onRefresh: load,
      color: purple,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1400),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _pageHeader(context, total),
                const SizedBox(height: 16),
                if (loading)
                  const Padding(padding: EdgeInsets.all(50), child: Center(child: CircularProgressIndicator()))
                else ...[
                  LayoutBuilder(builder: (_, c) {
                    final cols = c.maxWidth > 1100 ? (widget.role == 'STUDENT' ? 4 : 5) : c.maxWidth > 700 ? 3 : c.maxWidth > 480 ? 2 : 1;
                    final ratio = c.maxWidth <= 480 ? 3.05 : 1.65;
                    final cards = <Widget>[
                      _Kpi('TOTAL CLASSROOMS', '$total', 'Campus rooms', navy, Icons.apartment_outlined),
                      _Kpi('AVAILABLE', '$available', 'Empty / free now', neonGreen, Icons.check_circle_outline),
                      _Kpi('OCCUPIED', '$occupied', 'Class in progress', coral, Icons.meeting_room_outlined),
                      if (widget.role != 'STUDENT') _Kpi('BOOKED', '$booked', 'Special reservations', amber, Icons.bookmark_outline),
                      _Kpi('MAINTENANCE', '$maintenance', 'Under service', muted, Icons.build_outlined),
                    ];
                    return GridView.count(
                      crossAxisCount: cols,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: ratio,
                      children: cards,
                    );
                  }),
                  const SizedBox(height: 16),
                  _liveBanner(active, occupied, available),
                  const SizedBox(height: 16),
                  _activityCard(context, d),
                  const SizedBox(height: 16),
                  _quickActions(context),
                  const SizedBox(height: 16),
                  _summaryCard(scheduled, bookings, active),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _pageHeader(BuildContext context, dynamic total) => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: surface,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: border),
    ),
    child: LayoutBuilder(builder: (_, c) {
      final compact = c.maxWidth < 700;
      return Flex(
        direction: compact ? Axis.vertical : Axis.horizontal,
        crossAxisAlignment: compact ? CrossAxisAlignment.start : CrossAxisAlignment.center,
        children: [
          Expanded(
            flex: compact ? 0 : 1,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Welcome, ${widget.username} 👋',
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: navy),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Here is your Smart Campus overview for today.',
                  style: TextStyle(fontSize: 11.5, color: muted),
                ),
              ],
            ),
          ),
          if (compact) const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: () => widget.onNavigate?.call('Classrooms'),
                icon: const Icon(Icons.door_front_door_outlined, size: 16),
                label: const Text('View Classrooms'),
              ),
              FilledButton.icon(
                onPressed: () => widget.onNavigate?.call(widget.role == 'ADMIN' ? 'Find & Book' : 'Find Classroom'),
                icon: const Icon(Icons.search_rounded, size: 16),
                label: Text(widget.role == 'FACULTY' ? 'Book a Classroom' : 'Find & Book'),
              ),
            ],
          ),
        ],
      );
    }),
  );

  Widget _liveBanner(dynamic active, dynamic occupied, dynamic available) => AnimatedBuilder(
    animation: pulse,
    builder: (_, __) => Card(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [const Color(0xFFF8FAFF), Colors.white.withOpacity(.96)]),
        ),
        child: LayoutBuilder(builder: (_, c) {
          final compact = c.maxWidth < 520;
          return Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            runSpacing: 12,
            children: [
              Row(mainAxisSize: MainAxisSize.min, children: [
                AnimatedScale(
                  scale: 1 + pulse.value * .035,
                  duration: const Duration(milliseconds: 120),
                  child: Container(width: 42, height: 42, decoration: BoxDecoration(color: coral.withOpacity(.08 + pulse.value*.04), shape: BoxShape.circle), child: const Icon(Icons.bolt_rounded, color: coral)),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: compact ? c.maxWidth - 70 : 430,
                  child: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Campus Pulse', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: navy)),
                    SizedBox(height: 3), Text('Live classroom status updates automatically every 30 seconds.', style: TextStyle(fontSize: 10.5, color: muted)),
                  ]),
                ),
              ]),
              Row(mainAxisSize: MainAxisSize.min, children: [
                _pulseStat('ACTIVE', '$active', coral),
                const SizedBox(width: 18),
                _pulseStat('FREE', '$available', neonGreen),
              ]),
            ],
          );
        }),
      ),
    ),
  );

  Widget _pulseStat(String label, String value, Color color) => Column(crossAxisAlignment: CrossAxisAlignment.end, children: [Text(value, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: color)), Text(label, style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.w800, color: color, letterSpacing: .6))]);

  Widget _activityCard(BuildContext context, Map<String, dynamic> d) {
    final rooms = (d['rooms'] as List?) ?? const [];
    final rows = rooms.take(8).toList();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Today's Classroom Activity", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: navy)),
            const SizedBox(height: 3),
            const Text('Current room status based on timetable and booking data.',
              style: TextStyle(fontSize: 11, color: muted)),
            const SizedBox(height: 14),
            if (rows.isEmpty)
              const EmptyCard(title: 'No classroom activity', text: 'Upload the timetable or add room data to begin.')
            else
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  headingRowColor: const WidgetStatePropertyAll(Color(0xFFF8FAFC)),
                  columnSpacing: 30,
                  columns: const [
                    DataColumn(label: Text('ROOM')),
                    DataColumn(label: Text('STATUS')),
                    DataColumn(label: Text('SUBJECT / PURPOSE')),
                    DataColumn(label: Text('SECTION / BY')),
                  ],
                  rows: rows.map<DataRow>((r) {
                    final status = '${r['calculated_status'] ?? r['status'] ?? 'AVAILABLE'}';
                    final activity = r['current_activity'];
                    return DataRow(cells: [
                      DataCell(Text('${r['room_number'] ?? '—'}', style: const TextStyle(fontWeight: FontWeight.w800))),
                      DataCell(StatusPill(status, _statusColor(status))),
                      DataCell(Text('${activity?['subject_or_purpose'] ?? '—'}')),
                      DataCell(Text('${activity?['section_or_by'] ?? '—'}')),
                    ]);
                  }).toList(),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _quickActions(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Quick Actions', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: navy)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _Action(
                widget.role == 'FACULTY' ? 'Book a classroom' : 'Find a classroom',
                Icons.search_rounded,
                () => widget.onNavigate?.call(widget.role == 'ADMIN' ? 'Find & Book' : 'Find Classroom'),
              ),
              if (widget.role == 'ADMIN')
                _Action('Upload timetable', Icons.upload_file_outlined,
                  () => widget.onNavigate?.call('Timetable')),
              _Action('View classrooms', Icons.door_front_door_outlined,
                () => widget.onNavigate?.call('Classrooms')),
              if (widget.role != 'FACULTY')
                _Action('Campus map', Icons.map_outlined,
                  () => widget.onNavigate?.call('Campus Map')),
            ],
          ),
        ],
      ),
    ),
  );

  Widget _summaryCard(dynamic scheduled, dynamic bookings, dynamic active) => Card(
    child: Padding(
      padding: const EdgeInsets.all(18),
      child: Wrap(
        spacing: 28,
        runSpacing: 15,
        children: [
          _Mini('Scheduled today', '$scheduled', Icons.calendar_today_outlined),
          if (widget.role != 'STUDENT') _Mini('Bookings today', '$bookings', Icons.event_available_outlined),
          _Mini('Active now', '$active', Icons.bolt_outlined),
        ],
      ),
    ),
  );

  Color _statusColor(String status) {
    switch (status.toUpperCase()) {
      case 'OCCUPIED': return coral;
      case 'BOOKED': return amber;
      case 'MAINTENANCE': return muted;
      default: return neonGreen;
    }
  }
}

class _Kpi extends StatelessWidget {
  final String title, value, subtitle;
  final Color color;
  final IconData icon;
  const _Kpi(this.title, this.value, this.subtitle, this.color, this.icon);

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(15),
      child: LayoutBuilder(builder: (_, c) {
        final compact = c.maxWidth < 230;
        return Row(
        children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(color: color.withOpacity(.09), borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: color, size: 19),
          ),
          SizedBox(width: compact ? 10 : 11),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(color: color, fontSize: 9.5, fontWeight: FontWeight.w800, letterSpacing: .7)),
                const SizedBox(height: 4),
                Text(value, style: TextStyle(fontSize: compact ? 22 : 24, fontWeight: FontWeight.w900, color: navy)),
                Text(subtitle, style: const TextStyle(fontSize: 9.5, color: muted, overflow: TextOverflow.ellipsis)),
              ],
            ),
          ),
        ],
      );
      }),
    ),
  );
}

class _Action extends StatelessWidget {
  final String text; final IconData icon; final VoidCallback onTap;
  const _Action(this.text, this.icon, this.onTap);
  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
    onPressed: onTap, icon: Icon(icon, size: 16), label: Text(text),
  );
}

class _Mini extends StatelessWidget {
  final String title, value; final IconData icon;
  const _Mini(this.title, this.value, this.icon);
  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(width: 34, height: 34,
        decoration: BoxDecoration(color: const Color(0xFFEFF6FF), borderRadius: BorderRadius.circular(9)),
        child: Icon(icon, size: 16, color: purple)),
      const SizedBox(width: 8),
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(value, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: navy)),
        Text(title, style: const TextStyle(fontSize: 9.5, color: muted)),
      ]),
    ],
  );
}
