import 'dart:async';
import 'package:flutter/material.dart';
import 'realtime_service.dart';
import 'app_theme.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});
  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  late final StreamSubscription<Map<String, dynamic>> subscription;
  List<Map<String, dynamic>> events = [];

  @override
  void initState() {
    super.initState();
    events = RealtimeService.instance.history.toList();
    subscription = RealtimeService.instance.events.listen((event) {
      if (!mounted) return;
      setState(() => events = RealtimeService.instance.history.toList());
    });
  }

  @override
  void dispose() { subscription.cancel(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 40),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1100),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Notifications', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: navy)),
                SizedBox(height: 4),
                Text('Live campus updates from bookings, rooms and timetable changes.', style: TextStyle(fontSize: 12, color: muted)),
              ])),
              OutlinedButton.icon(onPressed: () => setState(() => events = []), icon: const Icon(Icons.clear_all_rounded, size: 17), label: const Text('Clear')),
            ]),
            const SizedBox(height: 18),
            if (events.isEmpty)
              Card(child: Padding(padding: const EdgeInsets.all(40), child: Center(child: Column(children: const [
                Icon(Icons.notifications_none_rounded, size: 44, color: muted),
                SizedBox(height: 10), Text('No new notifications', style: TextStyle(fontWeight: FontWeight.w800, color: navy)),
                SizedBox(height: 5), Text('Live updates will appear here when the campus changes.', style: TextStyle(color: muted, fontSize: 12)),
              ]))))
            else
              ...events.map(_eventCard),
          ]),
        ),
      ),
    );
  }

  Widget _eventCard(Map<String, dynamic> e) {
    final type = e['type']?.toString() ?? 'UPDATE';
    final icon = type.contains('BOOKING') ? Icons.event_available_rounded : type.contains('ROOM') ? Icons.meeting_room_rounded : Icons.sync_rounded;
    final timestamp = e['timestamp'];
    final when = timestamp is num ? DateTime.fromMillisecondsSinceEpoch(timestamp.toInt()).toLocal() : null;
    final text = when == null ? '' : '${when.day.toString().padLeft(2, '0')}/${when.month.toString().padLeft(2, '0')} ${when.hour.toString().padLeft(2, '0')}:${when.minute.toString().padLeft(2, '0')}';
    return Card(margin: const EdgeInsets.only(bottom: 10), child: ListTile(
      leading: CircleAvatar(backgroundColor: purple.withOpacity(.10), child: Icon(icon, color: purple, size: 19)),
      title: Text(e['message']?.toString() ?? 'Campus update', style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: navy)),
      subtitle: Text(type.replaceAll('_', ' '), style: const TextStyle(fontSize: 10.5, color: muted)),
      trailing: Text(text, style: const TextStyle(fontSize: 10, color: muted)),
    ));
  }
}
