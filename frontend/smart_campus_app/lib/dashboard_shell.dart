import 'dart:async';
import 'package:flutter/material.dart';
import 'app_theme.dart';
import 'analytics_screen.dart';
import 'auth_screens.dart';
import 'common_widgets.dart';
import 'occupancy_screen.dart';
import 'rooms_screen.dart';
import 'upload_timetable_screen.dart';
import 'booking_screen.dart';
import 'overview_screen.dart';
import 'timetable_view_screen.dart';
import 'room_management_screen.dart';
import 'campus_map_screen.dart';
import 'notifications_screen.dart';
import 'my_bookings_screen.dart';
import 'manage_users_screen.dart';
import 'realtime_service.dart';

class DashboardScreen extends StatefulWidget {
  final String role;
  final String username;
  const DashboardScreen({super.key, required this.role, required this.username});
  @override State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _pageMotion = AnimationController(vsync: this, duration: const Duration(milliseconds: 420))..forward();
  int index = 0;
  String roomSearch = '';
  final ScrollController sidebarScroll = ScrollController();
  StreamSubscription<Map<String, dynamic>>? _realtimeSubscription;
  bool _realtimeConnected = false;

  List<NavItem> get navItems {
    if (widget.role == 'STUDENT') {
      return const [
        NavItem('Dashboard', Icons.dashboard_outlined, Icons.dashboard_rounded),
        NavItem('Live Occupancy', Icons.radar_outlined, Icons.radar_rounded),
        NavItem('My Timetable', Icons.calendar_month_outlined, Icons.calendar_month_rounded),
        NavItem('Classrooms', Icons.door_front_door_outlined, Icons.door_front_door_rounded),
      ];
    }
    if (widget.role == 'FACULTY') {
      return const [
        NavItem('Dashboard', Icons.dashboard_outlined, Icons.dashboard_rounded),
        NavItem('Live Occupancy', Icons.radar_outlined, Icons.radar_rounded),
        NavItem('Timetable', Icons.calendar_month_outlined, Icons.calendar_month_rounded),
        NavItem('Classrooms', Icons.door_front_door_outlined, Icons.door_front_door_rounded),
        NavItem('My Bookings', Icons.event_note_outlined, Icons.event_note_rounded),
      ];
    }
    return const [
      NavItem('Dashboard', Icons.dashboard_outlined, Icons.dashboard_rounded),
      NavItem('Live Occupancy', Icons.radar_outlined, Icons.radar_rounded),
      NavItem('Classrooms', Icons.door_front_door_outlined, Icons.door_front_door_rounded),
      NavItem('Timetable', Icons.calendar_month_outlined, Icons.calendar_month_rounded),
      NavItem('Bookings', Icons.event_note_outlined, Icons.event_note_rounded),
      NavItem('Manage Rooms', Icons.settings_outlined, Icons.settings_rounded),
      NavItem('Manage Users', Icons.people_outline_rounded, Icons.people_rounded),
      NavItem('Campus Analytics', Icons.insights_outlined, Icons.insights_rounded),
    ];
  }

  @override
  void initState() {
    super.initState();
    final realtime = RealtimeService.instance;
    realtime.start();
    _realtimeConnected = realtime.isConnected;
    _realtimeSubscription = realtime.events.listen((event) {
      if (!mounted) return;
      setState(() => _realtimeConnected = true);
      final message = event['message']?.toString();
      if (message != null && message.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), duration: const Duration(seconds: 3)));
      }
    });
  }

  @override
  void dispose() { _realtimeSubscription?.cancel(); _pageMotion.dispose(); sidebarScroll.dispose(); super.dispose(); }

  Widget current() {
    final item = navItems[index];
    switch (item.label) {
      case 'Classrooms': return RoomsScreen(
        initialQuery: roomSearch,
        onOpenCampusMap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => CampusMapScreen(role: widget.role)),
        ),
      );
      case 'Campus Map': return CampusMapScreen(role: widget.role);
      case 'Live Occupancy': return const OccupancyScreen();
      case 'Timetable': return widget.role == 'ADMIN' ? const UploadTimetableScreen() : TimetableViewScreen(role: widget.role);
      case 'My Timetable': return TimetableViewScreen(role: widget.role);
      case 'Find Classroom': return BookingScreen(role: widget.role, username: widget.username);
      case 'My Bookings':
      case 'Bookings': return MyBookingsScreen(role: widget.role, username: widget.username);
      case 'Notifications': return const NotificationsScreen();
      case 'Manage Rooms': return const RoomManagementScreen();
      case 'Campus Analytics': return const AnalyticsScreen();
      case 'Manage Users': return ManageUsersScreen(adminUsername: widget.username);
      default:
        return OverviewScreen(role: widget.role, username: widget.username, onNavigate: _navigateByLabel);
    }
  }

  void select(int i) {
    setState(() { index = i; _pageMotion.forward(from: 0); });
    if (MediaQuery.sizeOf(context).width < 980 && Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }

  void _navigateByLabel(String label, {String query = ''}) {
    // Booking, map and notifications stay accessible from dashboard/top-bar
    // actions without adding redundant sidebar entries.
    if (label == 'Find Classroom' || label == 'Find & Book') {
      Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => BookingScreen(role: widget.role, username: widget.username),
      ));
      return;
    }
    if (label == 'Campus Map') {
      Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => CampusMapScreen(role: widget.role),
      ));
      return;
    }
    if (label == 'Notifications') {
      Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => const NotificationsScreen(),
      ));
      return;
    }
    final target = navItems.indexWhere((e) => e.label == label);
    if (target < 0) return;
    setState(() { roomSearch = query; index = target; });
  }

  Future<void> _openGlobalSearch() async {
    final controller = TextEditingController(text: roomSearch);
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Search campus'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Classroom, subject, section or building',
            prefixIcon: Icon(Icons.search_rounded),
          ),
          onSubmitted: (_) => Navigator.pop(context, controller.text.trim()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton.icon(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            icon: const Icon(Icons.search_rounded, size: 17),
            label: const Text('Search'),
          ),
        ],
      ),
    );
    // Do not dispose the dialog controller here. Flutter's route transition can
    // still rebuild the TextField for a frame after showDialog completes.
    // Disposing here causes 'TextEditingController was used after disposed'.
    if (result != null) _navigateByLabel('Classrooms', query: result);
  }

  void _logout() => Navigator.of(context).pushAndRemoveUntil(
    MaterialPageRoute(builder: (_) => const SplashScreen()), (_) => false,
  );

  Widget _sidebar() {
    final items = navItems;
    return Container(
      width: 240,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(right: BorderSide(color: border)),
      ),
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
              child: const CampusBrand(),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '${widget.role} PORTAL',
                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800,
                    letterSpacing: 1.1, color: Color(0xFF94A3B8)),
                ),
              ),
            ),
            Expanded(
              child: Scrollbar(
                controller: sidebarScroll,
                thumbVisibility: true,
                child: ListView.builder(
                  controller: sidebarScroll,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  itemCount: items.length,
                  itemBuilder: (_, i) => NavTile(
                    item: items[i], selected: i == index, onTap: () => select(i),
                  ),
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: const BoxDecoration(
                color: Color(0xFFF8FAFC),
                border: Border(top: BorderSide(color: border)),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: const Color(0xFFDBEAFE),
                    child: Text(
                      widget.username.isEmpty ? 'U' : widget.username[0].toUpperCase(),
                      style: const TextStyle(color: Color(0xFF1D4ED8), fontSize: 12, fontWeight: FontWeight.w800),
                    ),
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(widget.username, overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800)),
                        Text(widget.role.toLowerCase(), style: const TextStyle(fontSize: 10, color: muted)),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Sign out',
                    onPressed: _logout,
                    icon: const Icon(Icons.logout_rounded, size: 16, color: muted),
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _mobileDrawer() => Drawer(
    child: SafeArea(
      child: Column(
        children: [
          const Padding(padding: EdgeInsets.all(18), child: CampusBrand()),
          const Divider(height: 1),
          Expanded(
            child: ListView.builder(
              itemCount: navItems.length,
              itemBuilder: (_, i) => NavTile(item: navItems[i], selected: i == index, onTap: () => select(i)),
            ),
          ),
        ],
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 980;
    return Scaffold(
      drawer: wide ? null : _mobileDrawer(),
      appBar: AppBar(
        toolbarHeight: 64,
        titleSpacing: wide ? 20 : 8,
        automaticallyImplyLeading: !wide,
        title: wide
            ? const Text('Smart Campus', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800))
            : const Text('Smart Campus', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
        actions: [
          if (MediaQuery.sizeOf(context).width >= 600)
            InkWell(
              onTap: _openGlobalSearch,
              borderRadius: BorderRadius.circular(10),
              child: Container(
                width: MediaQuery.sizeOf(context).width < 900 ? 170 : 300,
                height: 38,
                padding: const EdgeInsets.symmetric(horizontal: 11),
                decoration: BoxDecoration(
                  color: canvas,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: border),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.search_rounded, size: 16, color: muted),
                    SizedBox(width: 7),
                    Expanded(child: Text('Search classroom, subject, section...', style: TextStyle(fontSize: 11, color: muted))),
                  ],
                ),
              ),
            ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
            decoration: BoxDecoration(
              color: _realtimeConnected ? const Color(0xFFECFDF5) : const Color(0xFFFFF7ED),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: _realtimeConnected ? const Color(0xFFA7F3D0) : const Color(0xFFFED7AA)),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Container(width: 7, height: 7, decoration: BoxDecoration(color: _realtimeConnected ? const Color(0xFF10B981) : const Color(0xFFF59E0B), shape: BoxShape.circle)),
              const SizedBox(width: 6),
              if (MediaQuery.sizeOf(context).width >= 700) Text(_realtimeConnected ? 'LIVE' : 'CONNECTING', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: _realtimeConnected ? const Color(0xFF047857) : const Color(0xFFB45309))),
            ]),
          ),
          const SizedBox(width: 5),
          PopupMenuButton<String>(
            tooltip: 'Notifications',
            icon: const Icon(Icons.notifications_none_rounded, size: 20),
            onSelected: (value) {
              if (value == 'notifications') {
                Navigator.of(context).push(MaterialPageRoute(builder: (_) => const NotificationsScreen()));
              }
              if (value == 'occupancy') _navigateByLabel('Classrooms');
              if (value == 'book') _navigateByLabel('Find Classroom');
              if (value == 'timetable') _navigateByLabel(widget.role == 'ADMIN' ? 'Timetable' : widget.role == 'FACULTY' ? 'Timetable' : 'My Timetable');
            },
            itemBuilder: (_) => widget.role == 'STUDENT'
                ? const [
                    PopupMenuItem(value: 'notifications', child: ListTile(leading: Icon(Icons.notifications_active_outlined), title: Text('View notifications'), dense: true)),
                    PopupMenuItem(value: 'occupancy', child: ListTile(leading: Icon(Icons.meeting_room_outlined), title: Text('Classroom availability'), dense: true)),
                    PopupMenuItem(value: 'timetable', child: ListTile(leading: Icon(Icons.calendar_month_outlined), title: Text('View timetable'), dense: true)),
                  ]
                : const [
                    PopupMenuItem(value: 'occupancy', child: ListTile(leading: Icon(Icons.meeting_room_outlined), title: Text('Check live occupancy'), dense: true)),
                    PopupMenuItem(value: 'book', child: ListTile(leading: Icon(Icons.event_available_outlined), title: Text('Find a classroom'), dense: true)),
                    PopupMenuItem(value: 'timetable', child: ListTile(leading: Icon(Icons.calendar_month_outlined), title: Text('View timetable'), dense: true)),
                  ],
          ),
          Container(
            margin: const EdgeInsets.only(right: 14, left: 3),
            padding: const EdgeInsets.only(left: 9),
            decoration: const BoxDecoration(border: Border(left: BorderSide(color: border))),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 15,
                  backgroundColor: const Color(0xFFDBEAFE),
                  child: Text(widget.username.isEmpty ? 'U' : widget.username[0].toUpperCase(),
                    style: const TextStyle(color: Color(0xFF1D4ED8), fontSize: 11, fontWeight: FontWeight.w800)),
                ),
                if (MediaQuery.sizeOf(context).width >= 760) ...[
                  const SizedBox(width: 7),
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(widget.username, style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800)),
                      Text(widget.role, style: const TextStyle(fontSize: 9, color: muted)),
                    ],
                  ),
                  const SizedBox(width: 5),
                ],
                IconButton(
                  tooltip: 'Sign out',
                  onPressed: _logout,
                  icon: const Icon(Icons.logout_rounded, size: 16, color: muted),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
          ),
        ],
      ),
      body: Row(
        children: [
          if (wide) _sidebar(),
          Expanded(
          child: AnimatedBuilder(
            animation: _pageMotion,
            builder: (context, child) {
              final curved = Curves.easeOutCubic.transform(_pageMotion.value);
              return Opacity(
                opacity: .35 + curved * .65,
                child: Transform.translate(
                  offset: Offset(0, 10 * (1 - curved)),
                  child: child,
                ),
              );
            },
            child: KeyedSubtree(key: ValueKey(index), child: current()),
          ),
        ),
        ],
      ),
    );
  }
}

class NavItem {
  final String label;
  final IconData icon;
  final IconData selectedIcon;
  const NavItem(this.label, this.icon, this.selectedIcon);
}

class NavTile extends StatelessWidget {
  final NavItem item;
  final bool selected;
  final bool dark;
  final bool compact;
  final VoidCallback onTap;
  const NavTile({
    super.key, required this.item, required this.selected, required this.onTap,
    this.dark = false, this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: Material(
        color: selected ? const Color(0xFFEFF6FF) : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 10),
            child: Row(
              children: [
                Icon(
                  selected ? item.selectedIcon : item.icon,
                  size: 18,
                  color: selected ? const Color(0xFF1D4ED8) : const Color(0xFF94A3B8),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Text(
                    item.label,
                    style: TextStyle(
                      color: selected ? const Color(0xFF1E3A8A) : const Color(0xFF475569),
                      fontSize: 12,
                      fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
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
}
