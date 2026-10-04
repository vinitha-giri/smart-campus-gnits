import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'api_config.dart';
import 'app_theme.dart';
import 'common_widgets.dart';

class TimetableViewScreen extends StatefulWidget {
  final String role;
  const TimetableViewScreen({super.key, required this.role});
  @override State<TimetableViewScreen> createState() => _TimetableViewScreenState();
}
class _TimetableViewScreenState extends State<TimetableViewScreen> {
  String day='MONDAY', section='ALL';
  List<String> sections=[]; List<Map<String,dynamic>> entries=[]; bool loading=true; String? error;
  @override void initState(){super.initState(); load();}
  Future<void> load() async { setState(()=>loading=true); try {
    final sec=await http.get(Uri.parse('${ApiConfig.baseUrl}/api/timetable/excel/sections').replace(queryParameters:{'academicYear':'2026-2027','semesterNo':'1'}));
    if(sec.statusCode!=200) throw Exception(sec.body); final sm=jsonDecode(sec.body); sections=[for(final x in (sm['sections'] as List? ?? [])) '${x['sectionName']}'];
    final q=<String,String>{'academicYear':'2026-2027','semesterNo':'1','day':day}; if(section!='ALL') q['sectionName']=section;
    final r=await http.get(Uri.parse('${ApiConfig.baseUrl}/api/timetable/excel/entries').replace(queryParameters:q));
    if(r.statusCode!=200) throw Exception(r.body); final body=jsonDecode(r.body); entries=[for(final x in (body['entries'] as List? ?? [])) Map<String,dynamic>.from(x)]; error=null;
  } catch(e){error='Could not load timetable: $e';} finally{if(mounted)setState(()=>loading=false);}}
  @override Widget build(BuildContext context)=>SingleChildScrollView(padding:const EdgeInsets.fromLTRB(24,24,24,44),child:Center(child:ConstrainedBox(constraints:const BoxConstraints(maxWidth:1420),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
    const Text('Timetable',style:TextStyle(fontSize:28,fontWeight:FontWeight.w800,color:navy)),const SizedBox(height:5),Text(widget.role == 'STUDENT' ? 'View the timetable for any section without adding section details to your login.' : widget.role == 'FACULTY' ? 'View the official timetable by day and section.' : 'View scheduled classes by day and section.',style:const TextStyle(color:muted)),const SizedBox(height:18),
    Card(child:Padding(padding:const EdgeInsets.all(14),child:Wrap(spacing:12,runSpacing:12,children:[SizedBox(width:190,child:DropdownButtonFormField<String>(value:day,decoration:const InputDecoration(labelText:'Day'),items:[for(final d in const ['MONDAY','TUESDAY','WEDNESDAY','THURSDAY','FRIDAY','SATURDAY'])DropdownMenuItem(value:d,child:Text(d))],onChanged:(v){if(v!=null){setState(()=>day=v);load();}})),SizedBox(width:230,child:DropdownButtonFormField<String>(value:sections.contains(section)?section:'ALL',decoration:const InputDecoration(labelText:'Section'),items:[const DropdownMenuItem(value:'ALL',child:Text('All sections')),for(final s in sections)DropdownMenuItem(value:s,child:Text(s))],onChanged:(v){if(v!=null){setState(()=>section=v);load();}})),IconButton(onPressed:load,tooltip:'Refresh',icon:const Icon(Icons.refresh_rounded))]))),const SizedBox(height:16),
    if(error!=null)ErrorCard(message:error!),if(loading)const Padding(padding:EdgeInsets.all(50),child:Center(child:CircularProgressIndicator())) else if(entries.isEmpty)const EmptyCard(title:'No scheduled classes',text:'No timetable entries match the selected filters.') else Card(child:SingleChildScrollView(scrollDirection:Axis.horizontal,child:DataTable(columns:const[DataColumn(label:Text('Time')),DataColumn(label:Text('Room')),DataColumn(label:Text('Subject')),DataColumn(label:Text('Section'))],rows:[for(final e in entries)DataRow(cells:[DataCell(Text('${e['startTime']} – ${e['endTime']}')),DataCell(Text('${e['roomNo']}',style:const TextStyle(fontWeight:FontWeight.w800))),DataCell(Text('${e['subject']}')),DataCell(Text('${e['section']}'))])]))),
  ]))));
}
