import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'api_config.dart';
import 'app_theme.dart';
import 'common_widgets.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});
  @override State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  Map<String,dynamic>? data;
  Map<String,dynamic>? health;
  bool loading=true;
  String? error;

  @override void initState(){super.initState(); load();}
  Future<void> load() async {
    setState(()=>loading=true);
    try {
      final results=await Future.wait([
        http.get(Uri.parse('${ApiConfig.baseUrl}/api/analytics/summary')),
        http.get(Uri.parse('${ApiConfig.baseUrl}/api/analytics/timetable-health')),
      ]);
      if(results[0].statusCode!=200 || results[1].statusCode!=200) throw Exception('Analytics service returned an error.');
      if(mounted) setState(() { data=jsonDecode(results[0].body) as Map<String,dynamic>; health=jsonDecode(results[1].body) as Map<String,dynamic>; error=null; });
    } catch(e){if(mounted)setState(()=>error=e.toString());}
    finally{if(mounted)setState(()=>loading=false);}
  }

  int n(String key)=>int.tryParse('${data?[key]??0}')??0;
  Widget metric(String title,String value,IconData icon,Color color)=>Expanded(child:Container(
    padding:const EdgeInsets.all(18),
    decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(18),border:Border.all(color:border)),
    child:Row(children:[CircleAvatar(radius:22,backgroundColor:color.withOpacity(.10),child:Icon(icon,color:color,size:20)),const SizedBox(width:12),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(title,style:const TextStyle(fontSize:9,fontWeight:FontWeight.w800,color:muted,letterSpacing:.7)),const SizedBox(height:5),Text(value,style:const TextStyle(fontSize:22,fontWeight:FontWeight.w900,color:navy))]))]),
  ));

  @override Widget build(BuildContext context){
    final wide=MediaQuery.sizeOf(context).width>=800;
    final h = health ?? <String, dynamic>{};
    final healthy = h['healthy'] == true;
    return RefreshIndicator(onRefresh:load,child:SingleChildScrollView(physics:const AlwaysScrollableScrollPhysics(),padding:const EdgeInsets.fromLTRB(24,24,24,44),child:Center(child:ConstrainedBox(constraints:const BoxConstraints(maxWidth:1250),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      Row(children:[const Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text('Campus Analytics',style:TextStyle(fontSize:28,fontWeight:FontWeight.w900,color:navy)),SizedBox(height:5),Text('Live operational metrics, usage signals and timetable quality.',style:TextStyle(color:muted))])),IconButton(onPressed:load,tooltip:'Refresh',icon:const Icon(Icons.refresh_rounded))]),
      const SizedBox(height:18),
      if(error!=null) ErrorCard(message:error!),
      if(loading) const Padding(padding:EdgeInsets.all(60),child:Center(child:CircularProgressIndicator())) else ...[
        wide?Row(children:[metric('TOTAL ROOMS','${n('totalRooms')}',Icons.meeting_room_outlined,purple),const SizedBox(width:12),metric('AVAILABLE NOW','${n('availableNow')}',Icons.check_circle_outline,Colors.green),const SizedBox(width:12),metric('OCCUPIED NOW','${n('occupiedNow')}',Icons.timelapse_rounded,Colors.orange)]):Column(children:[metric('TOTAL ROOMS','${n('totalRooms')}',Icons.meeting_room_outlined,purple),const SizedBox(height:10),metric('AVAILABLE NOW','${n('availableNow')}',Icons.check_circle_outline,Colors.green),const SizedBox(height:10),metric('OCCUPIED NOW','${n('occupiedNow')}',Icons.timelapse_rounded,Colors.orange)]),
        const SizedBox(height:12),
        wide?Row(children:[metric('MAINTENANCE','${n('maintenance')}',Icons.build_outlined,Colors.redAccent),const SizedBox(width:12),metric('RESERVED','${n('reserved')}',Icons.lock_outline,Colors.deepPurple),const SizedBox(width:12),metric('UPCOMING BOOKINGS','${n('upcomingBookings')}',Icons.event_available_outlined,Colors.blue)]):Column(children:[metric('MAINTENANCE','${n('maintenance')}',Icons.build_outlined,Colors.redAccent),const SizedBox(height:10),metric('RESERVED','${n('reserved')}',Icons.lock_outline,Colors.deepPurple),const SizedBox(height:10),metric('UPCOMING BOOKINGS','${n('upcomingBookings')}',Icons.event_available_outlined,Colors.blue)]),
        const SizedBox(height:18),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Timetable integrity',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: navy),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Icon(
                      healthy ? Icons.verified_rounded : Icons.warning_amber_rounded,
                      color: healthy ? Colors.green : Colors.orange,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        healthy
                            ? 'Healthy — no structural issues detected'
                            : 'Review recommended — some timetable fields need attention.',
                        style: const TextStyle(fontWeight: FontWeight.w700, color: navy),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 18,
                  runSpacing: 8,
                  children: [
                    Text('Entries: ${h['entries'] ?? 0}'),
                    Text('Missing rooms: ${h['missingRoom'] ?? 0}'),
                    Text('Missing days: ${h['missingDay'] ?? 0}'),
                    Text('Missing times: ${h['missingTime'] ?? 0}'),
                    Text('Invalid ranges: ${h['invalidTimeRange'] ?? 0}'),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height:14),
        Card(child:Padding(padding:const EdgeInsets.all(20),child:Wrap(spacing:30,runSpacing:14,children:[Text('Realtime connections: ${n('realtimeConnections')}',style:const TextStyle(fontWeight:FontWeight.w700)),Text('Timetable entries: ${n('timetableEntries')}',style:const TextStyle(fontWeight:FontWeight.w700)),Text('Upcoming confirmed bookings: ${n('upcomingBookings')}',style:const TextStyle(fontWeight:FontWeight.w700))]))),
      ]
    ])))));
  }
}
