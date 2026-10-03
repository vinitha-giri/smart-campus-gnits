import 'dart:async';
import 'package:flutter/material.dart';
import 'realtime_service.dart';
import 'app_theme.dart';
import 'api_config.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key, this.email = ''});
  final String email;
  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  Timer? _pollTimer;
  late final StreamSubscription<Map<String, dynamic>> subscription;
  List<Map<String, dynamic>> events = [];

  @override
  void initState() {
    super.initState();
    events = RealtimeService.instance.history.toList();
    if (widget.email.isNotEmpty) { _loadPersistent(); _pollTimer=Timer.periodic(const Duration(seconds:20),(_)=>_loadPersistent()); }
    subscription = RealtimeService.instance.events.listen((event) {
      if (!mounted) return;
      setState(() => events = RealtimeService.instance.history.toList());
    });
  }


  Future<void> _loadPersistent() async {
    try {
      final r=await http.get(Uri.parse('${ApiConfig.baseUrl}/api/notifications').replace(queryParameters:{'email':widget.email}));
      if(r.statusCode!=200||!mounted)return;
      final body=jsonDecode(r.body); final raw=body is Map?body['notifications']:null;
      if(raw is List){
        final persisted=raw.map<Map<String,dynamic>>((e){ final n=Map<String,dynamic>.from(e as Map); return {'type':n['type']??'NOTIFICATION','message':n['message']??n['title']??'Notification','timestamp':n['createdAt']!=null?DateTime.tryParse(n['createdAt'].toString())?.millisecondsSinceEpoch:null,'notificationId':n['id'],'read':n['read']??false};}).toList();
        if(mounted){
          final seen=<String>{};
          final merged=[...persisted,...events].where((e){
            final key=e['notificationId']?.toString() ?? '${e['type']}|${e['message']}|${e['timestamp']}';
            return seen.add(key);
          }).toList();
          setState(()=>events=merged);
        }
      }
    }catch(_){}
  }

  @override
  void dispose() { _pollTimer?.cancel(); subscription.cancel(); super.dispose(); }

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
