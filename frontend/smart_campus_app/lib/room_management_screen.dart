import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'api_config.dart';
import 'app_theme.dart';
import 'common_widgets.dart';

class RoomManagementScreen extends StatefulWidget {
  const RoomManagementScreen({super.key});
  @override
  State<RoomManagementScreen> createState() => _RoomManagementScreenState();
}

class _RoomManagementScreenState extends State<RoomManagementScreen> {
  static const roomTypes = ['Classroom', 'Laboratory', 'Seminar Hall', 'Auditorium'];
  static const statuses = ['AVAILABLE', 'MAINTENANCE', 'RESERVED'];

  List<Map<String, dynamic>> rooms = [];
  bool loading = true;
  String filter = 'ALL';

  @override
  void initState() {
    super.initState();
    load();
  }

  String _safeRoomType(dynamic raw) {
    final value = '${raw ?? ''}'.trim().toUpperCase().replaceAll('-', '_');
    if (value == 'LAB' || value == 'LABORATORY') return 'Laboratory';
    if (value == 'SEMINAR' || value == 'SEMINAR_HALL' || value == 'SEMINAR HALL') return 'Seminar Hall';
    if (value == 'AUDITORIUM') return 'Auditorium';
    return 'Classroom';
  }

  String _safeStatus(dynamic raw) {
    final value = '${raw ?? ''}'.trim().toUpperCase();
    return statuses.contains(value) ? value : 'AVAILABLE';
  }

  Future<void> load() async {
    if (mounted) setState(() => loading = true);
    try {
      final r = await http.get(Uri.parse('${ApiConfig.baseUrl}/api/rooms'));
      if (r.statusCode != 200) throw Exception(r.body);
      final decoded = jsonDecode(r.body);
      final list = decoded is List ? decoded : const [];
      if (mounted) {
        setState(() {
          rooms = [for (final x in list) Map<String, dynamic>.from(x as Map)];
        });
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not load rooms: $e')));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> edit([Map<String, dynamic>? room]) async {
    final no = TextEditingController(text: '${room?['roomNo'] ?? ''}');
    final cap = TextEditingController(text: '${room?['capacity'] ?? 75}');
    final floor = TextEditingController(text: '${room?['floorNo'] ?? ''}');
    String type = _safeRoomType(room?['roomType']);
    // Always keep the dropdown value in the same canonical form as its items.
    // Database rows may contain CLASSROOM/LAB/SEMINAR_HALL while the UI uses labels.
    if (!roomTypes.contains(type)) type = 'Classroom';
    String status = _safeStatus(room?['status']);

    try {
      final ok = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
          builder: (context, dialogSetState) => AlertDialog(
            title: Text(room == null ? 'Add classroom' : 'Edit ${room['roomNo']}'),
            content: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width - 40),
              child: Wrap(
                runSpacing: 12,
                children: [
                  TextField(controller: no, decoration: const InputDecoration(labelText: 'Room number')),
                  TextField(controller: floor, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Floor')),
                  TextField(controller: cap, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Capacity')),
                  DropdownButtonFormField<String>(
                    value: roomTypes.contains(type) ? type : 'Classroom',
                    decoration: const InputDecoration(labelText: 'Room type'),
                    items: const [
                      DropdownMenuItem<String>(value: 'Classroom', child: Text('Classroom')),
                      DropdownMenuItem<String>(value: 'Laboratory', child: Text('Laboratory')),
                      DropdownMenuItem<String>(value: 'Seminar Hall', child: Text('Seminar Hall')),
                      DropdownMenuItem<String>(value: 'Auditorium', child: Text('Auditorium')),
                    ],
                    onChanged: (v) { if (v != null) dialogSetState(() => type = v); },
                  ),
                  DropdownButtonFormField<String>(
                    value: statuses.contains(status) ? status : 'AVAILABLE',
                    decoration: const InputDecoration(labelText: 'Administrative status'),
                    items: statuses.map((x) => DropdownMenuItem<String>(value: x, child: Text(x))).toList(),
                    onChanged: (v) { if (v != null) dialogSetState(() => status = v); },
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
              FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Save')),
            ],
          ),
        ),
      );
      if (ok != true) return;
      final roomNo = no.text.trim();
      if (roomNo.isEmpty) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Room number is required.')));
        return;
      }
      final capacity = int.tryParse(cap.text.trim()) ?? 75;
      if (capacity <= 0) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Capacity must be greater than 0.')));
        return;
      }
      final body = {
        'roomNo': roomNo,
        'floorNo': int.tryParse(floor.text.trim()),
        'capacity': capacity,
        'roomType': type,
        'status': status,
      };
      try {
        final uri = Uri.parse('${ApiConfig.baseUrl}/api/rooms${room == null ? '' : '/${room['roomId']}'}');
        final r = room == null
            ? await http.post(uri, headers: {'Content-Type': 'application/json'}, body: jsonEncode(body))
            : await http.put(uri, headers: {'Content-Type': 'application/json'}, body: jsonEncode(body));
        if (r.statusCode >= 200 && r.statusCode < 300) {
          await load();
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Classroom saved successfully.')));
        } else {
          final b = jsonDecode(r.body);
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(b['error'] ?? 'Save failed')));
        }
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Save error: $e')));
      }
    } finally {
      no.dispose();
      cap.dispose();
      floor.dispose();
    }
  }

  Future<void> remove(Map<String, dynamic> r) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text('Delete ${r['roomNo']}?'),
        content: const Text('This removes the classroom from the room catalogue. Rooms with confirmed bookings cannot be deleted.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
          FilledButton(style: FilledButton.styleFrom(backgroundColor: Colors.redAccent), onPressed: () => Navigator.pop(c, true), child: const Text('Delete')),
        ],
      ),
    );
    if (yes != true) return;
    try {
      final x = await http.delete(Uri.parse('${ApiConfig.baseUrl}/api/rooms/${r['roomId']}'));
      if (x.statusCode >= 200 && x.statusCode < 300) {
        await load();
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Delete failed: ${x.body}')));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Delete error: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final list = rooms.where((r) => filter == 'ALL' || _safeStatus(r['status']) == filter).toList();
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 44),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1420),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Classroom Management', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: navy)),
                  SizedBox(height: 5),
                  Text('Manage classroom capacity, type and administrative status.', style: TextStyle(color: muted)),
                ])),
                FilledButton.icon(onPressed: () => edit(), icon: const Icon(Icons.add_rounded), label: const Text('Add classroom')),
                IconButton(onPressed: load, tooltip: 'Refresh', icon: const Icon(Icons.refresh_rounded)),
              ]),
              const SizedBox(height: 18),
              Card(child: Padding(
                padding: const EdgeInsets.all(14),
                child: DropdownButtonFormField<String>(
                  initialValue: filter,
                  decoration: const InputDecoration(labelText: 'Status filter'),
                  items: const [
                    DropdownMenuItem(value: 'ALL', child: Text('All rooms')),
                    DropdownMenuItem(value: 'AVAILABLE', child: Text('Available')),
                    DropdownMenuItem(value: 'MAINTENANCE', child: Text('Maintenance')),
                    DropdownMenuItem(value: 'RESERVED', child: Text('Reserved')),
                  ],
                  onChanged: (v) { if (v != null) setState(() => filter = v); },
                ),
              )),
              const SizedBox(height: 16),
              if (loading)
                const Padding(padding: EdgeInsets.all(50), child: Center(child: CircularProgressIndicator()))
              else if (list.isEmpty)
                const EmptyCard(title: 'No classrooms found', text: 'Add a classroom or change the status filter.')
              else
                Card(child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    columns: const [
                      DataColumn(label: Text('Room')), DataColumn(label: Text('Floor')), DataColumn(label: Text('Type')),
                      DataColumn(label: Text('Capacity')), DataColumn(label: Text('Status')), DataColumn(label: Text('Actions')),
                    ],
                    rows: [for (final r in list) DataRow(cells: [
                      DataCell(Text('${r['roomNo']}', style: const TextStyle(fontWeight: FontWeight.w800))),
                      DataCell(Text('${r['floorNo'] ?? '—'}')),
                      DataCell(Text(_safeRoomType(r['roomType']))),
                      DataCell(Text('${r['capacity'] ?? 75}')),
                      DataCell(StatusPill(_safeStatus(r['status']), _safeStatus(r['status']) == 'MAINTENANCE' ? Colors.orange : (_safeStatus(r['status']) == 'RESERVED' ? Colors.purple : Colors.green))),
                      DataCell(Row(children: [
                        IconButton(onPressed: () => edit(r), tooltip: 'Edit', icon: const Icon(Icons.edit_outlined, size: 18)),
                        IconButton(onPressed: () => remove(r), tooltip: 'Delete', icon: const Icon(Icons.delete_outline, size: 18, color: Colors.redAccent)),
                      ])),
                    ])],
                  ),
                )),
            ],
          ),
        ),
      ),
    );
  }
}
