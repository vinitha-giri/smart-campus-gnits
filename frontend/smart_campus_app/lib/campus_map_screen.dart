import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'api_config.dart';
import 'app_theme.dart';

class CampusMapScreen extends StatefulWidget {
  final String role;
  const CampusMapScreen({super.key, required this.role});
  @override State<CampusMapScreen> createState() => _CampusMapScreenState();
}

class _CampusMapScreenState extends State<CampusMapScreen> with SingleTickerProviderStateMixin {
  List<Map<String, dynamic>> rooms = [];
  bool loading = true;
  String building = 'ALL';
  String floor = 'ALL';
  Timer? timer;
  late final AnimationController pulse = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat(reverse: true);

  @override
  void initState() { super.initState(); load(); timer = Timer.periodic(const Duration(seconds: 30), (_) => load(silent: true)); }
  @override
  void dispose() { timer?.cancel(); pulse.dispose(); super.dispose(); }

  Future<void> load({bool silent = false}) async {
    if (!silent && mounted) setState(() => loading = true);
    try {
      final r = await http.get(Uri.parse('${ApiConfig.baseUrl}/api/rooms'));
      if (r.statusCode == 200) {
        final d = jsonDecode(r.body);
        if (d is List && mounted) setState(() => rooms = d.map((e) => Map<String, dynamic>.from(e as Map)).toList());
      }
    } catch (_) {} finally { if (mounted && !silent) setState(() => loading = false); }
  }

  String status(Map<String,dynamic> r) => '${r['calculated_status'] ?? r['status'] ?? 'AVAILABLE'}'.toUpperCase();
  Color statusColor(String s) => s == 'OCCUPIED' ? coral : s == 'BOOKED' ? amber : s == 'MAINTENANCE' ? muted : neonGreen;

  @override
  Widget build(BuildContext context) {
    final buildings = <String>{
      'ALL',
      ...rooms.map((r) => '${r['building'] ?? r['block'] ?? 'Main Block'}'),
    }.toList()
      ..sort();
    final filtered = rooms.where((r) {
      final b = '${r['building'] ?? r['block'] ?? 'Main Block'}';
      final f = '${r['floor'] ?? '1'}';
      return (building == 'ALL' || b == building) && (floor == 'ALL' || f == floor);
    }).toList();
    final occupied = filtered.where((r) => status(r) == 'OCCUPIED').length;
    final available = filtered.where((r) => status(r) == 'AVAILABLE').length;
    final booked = filtered.where((r) => status(r) == 'BOOKED').length;

    return RefreshIndicator(
      onRefresh: load,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        child: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 1400), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: const [
              Text('Campus Map', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: navy)),
              SizedBox(height: 5), Text('Interactive building and floor view with live classroom status.', style: TextStyle(fontSize: 12, color: muted)),
            ])),
            IconButton(tooltip: 'Refresh', onPressed: load, icon: const Icon(Icons.refresh_rounded)),
          ]),
          const SizedBox(height: 16),
          _filters(buildings),
          const SizedBox(height: 16),
          _summary(occupied, available, booked),
          const SizedBox(height: 16),
          if (loading) const Padding(padding: EdgeInsets.all(50), child: Center(child: CircularProgressIndicator()))
          else if (filtered.isEmpty) _empty()
          else _buildingGrid(filtered),
        ]))),
      ),
    );
  }

  Widget _filters(List<String> buildings) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Wrap(
          spacing: 12,
          runSpacing: 10,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
    SizedBox(width: 220, child: DropdownButtonFormField<String>(value: buildings.contains(building) ? building : 'ALL', decoration: const InputDecoration(labelText: 'Building', prefixIcon: Icon(Icons.apartment_outlined)), items: buildings.map((b) => DropdownMenuItem(value: b, child: Text(b))).toList(), onChanged: (v) => setState(() => building = v ?? 'ALL'))),
    SizedBox(width: 160, child: DropdownButtonFormField<String>(value: const ['ALL','1','2','3','4'].contains(floor) ? floor : 'ALL', decoration: const InputDecoration(labelText: 'Floor', prefixIcon: Icon(Icons.layers_outlined)), items: const [DropdownMenuItem(value:'ALL',child:Text('All floors')),DropdownMenuItem(value:'1',child:Text('Floor 1')),DropdownMenuItem(value:'2',child:Text('Floor 2')),DropdownMenuItem(value:'3',child:Text('Floor 3')),DropdownMenuItem(value:'4',child:Text('Floor 4'))], onChanged: (v) => setState(() => floor = v ?? 'ALL'))),
            _legend('Available', neonGreen),
            _legend('Occupied', coral),
            _legend('Booked', amber),
          ],
        ),
      ),
    );
  }

  Widget _summary(int occupied, int available, int booked) => Row(children: [
    Expanded(child: _metric('AVAILABLE', available, neonGreen, Icons.check_circle_outline)),
    const SizedBox(width: 10), Expanded(child: _metric('OCCUPIED', occupied, coral, Icons.meeting_room_outlined)),
    const SizedBox(width: 10), Expanded(child: _metric('BOOKED', booked, amber, Icons.bookmark_outline)),
  ]);

  Widget _metric(String label, int value, Color color, IconData icon) => Card(child: Padding(padding: const EdgeInsets.all(15), child: Row(children: [Container(width:38,height:38,decoration:BoxDecoration(color:color.withOpacity(.1),borderRadius:BorderRadius.circular(10)),child:Icon(icon,color:color,size:18)),const SizedBox(width:10),Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text('$value',style:const TextStyle(fontSize:22,fontWeight:FontWeight.w900,color:navy)),Text(label,style:TextStyle(fontSize:9,fontWeight:FontWeight.w800,color:color,letterSpacing:.6))])])));

  Widget _buildingGrid(List<Map<String,dynamic>> list) {
    final grouped = <String,List<Map<String,dynamic>>>{};
    for (final r in list) { final b='${r['building'] ?? r['block'] ?? 'Main Block'}'; (grouped[b] ??= []).add(r); }
    return Column(children: grouped.entries.map((e) => _building(e.key, e.value)).toList());
  }

  Widget _building(String name, List<Map<String,dynamic>> list) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF1E3A8A), Color(0xFF2563EB)],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.apartment_rounded, color: Colors.white),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: navy)),
                      Text('${list.length} classrooms • live status', style: const TextStyle(fontSize: 10.5, color: muted)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            LayoutBuilder(
              builder: (context, constraints) {
                final count = constraints.maxWidth > 1050
                    ? 6
                    : constraints.maxWidth > 760
                        ? 4
                        : constraints.maxWidth > 480
                            ? 3
                            : 2;
                return GridView.count(
                  crossAxisCount: count,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  childAspectRatio: 1.35,
                  children: list.map(_room).toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _room(Map<String,dynamic> r) {
    final s=status(r); final color=statusColor(s); final activity=r['current_activity'];
    return InkWell(onTap:()=>_details(r),borderRadius:BorderRadius.circular(12),child: AnimatedBuilder(animation:pulse,builder:(context,_)=>Container(padding:const EdgeInsets.all(12),decoration:BoxDecoration(color:color.withOpacity(.055 + (s=='OCCUPIED'?pulse.value*.025:0)),borderRadius:BorderRadius.circular(12),border:Border.all(color:color.withOpacity(.25))),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      Row(children:[Expanded(child:Text('${r['room_number'] ?? r['roomNo'] ?? 'Room'}',style:const TextStyle(fontSize:14,fontWeight:FontWeight.w900,color:navy))),Container(width:8,height:8,decoration:BoxDecoration(color:color,shape:BoxShape.circle))]),
      const Spacer(), Text(s,style:TextStyle(fontSize:8.5,fontWeight:FontWeight.w900,color:color,letterSpacing:.5)), const SizedBox(height:3),
      Text(activity is Map ? '${activity['section_or_by'] ?? activity['subject_or_purpose'] ?? ''}' : 'Capacity ${r['capacity'] ?? 75}',maxLines:1,overflow:TextOverflow.ellipsis,style:const TextStyle(fontSize:9.5,color:muted)),
    ]))));
  }

  void _details(Map<String,dynamic> r) { final s=status(r); final a=r['current_activity']; showDialog(context:context,builder:(_)=>AlertDialog(title:Text('${r['room_number'] ?? r['roomNo'] ?? 'Classroom'}'),content:Column(mainAxisSize:MainAxisSize.min,crossAxisAlignment:CrossAxisAlignment.start,children:[_line('Status',s,statusColor(s)),_line('Capacity','${r['capacity'] ?? 75}',navy),_line('Floor','${r['floor'] ?? '—'}',navy),if(a is Map)...[_line('Section','${a['section_or_by'] ?? '—'}',navy),_line('Activity','${a['subject_or_purpose'] ?? '—'}',navy)] ]),actions:[TextButton(onPressed:()=>Navigator.pop(context),child:const Text('Close'))])); }
  Widget _line(String l,String v,Color c)=>Padding(padding:const EdgeInsets.only(bottom:9),child:Row(children:[SizedBox(width:90,child:Text(l,style:const TextStyle(fontSize:11,color:muted))),Expanded(child:Text(v,style:TextStyle(fontSize:12,fontWeight:FontWeight.w800,color:c)))]));
  Widget _legend(String t,Color c)=>Chip(avatar:CircleAvatar(radius:4,backgroundColor:c),label:Text(t,style:const TextStyle(fontSize:10)),side:BorderSide(color:border));
  Widget _empty()=>Card(child:Padding(padding:const EdgeInsets.all(40),child:Center(child:Column(children:const[Icon(Icons.map_outlined,size:42,color:muted),SizedBox(height:10),Text('No classrooms match these filters',style:TextStyle(fontWeight:FontWeight.w800,color:navy)),SizedBox(height:4),Text('Add rooms or change the building/floor filters.',style:TextStyle(fontSize:11,color:muted))]))));
}
