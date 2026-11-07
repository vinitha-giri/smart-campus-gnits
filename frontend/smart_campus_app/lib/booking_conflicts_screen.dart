import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'api_config.dart';

class BookingConflictsScreen extends StatefulWidget {
  final String role, username;
  final int? initialBookingId;
  const BookingConflictsScreen({super.key, required this.role, required this.username, this.initialBookingId});
  @override State<BookingConflictsScreen> createState() => _BookingConflictsScreenState();
}

class _BookingConflictsScreenState extends State<BookingConflictsScreen> {
  bool loading = true;
  String? error;
  List<Map<String, dynamic>> items = [];
  Map<String, dynamic> decode(String s) { try { final v=jsonDecode(s); return v is Map ? Map<String,dynamic>.from(v) : {}; } catch (_) { return {}; } }
  @override void initState(){ super.initState(); load(); }
  Future<void> load() async {
    if(mounted) setState(()=>loading=true);
    try {
      final uri=Uri.parse('${ApiConfig.baseUrl}/api/booking-conflicts').replace(queryParameters:{'role':widget.role,'emailAddress':widget.username});
      final r=await http.get(uri); final b=decode(r.body);
      if(r.statusCode!=200) throw Exception(b['error']??'Unable to load conflict reviews');
      final raw=jsonDecode(r.body);
      if(mounted) setState(()=>items=raw is List?raw.map((e)=>Map<String,dynamic>.from(e)).toList():[]);
    } catch(e) { if(mounted)setState(()=>error=e.toString().replaceFirst('Exception: ','')); }
    finally { if(mounted)setState(()=>loading=false); }
  }
  Future<void> submit() async {
    final r=await http.get(Uri.parse('${ApiConfig.baseUrl}/api/booking-conflicts/candidates').replace(queryParameters:{'username':widget.username}));
    if(r.statusCode!=200){_toast(decode(r.body)['error']??'Could not load bookings.');return;}
    final candidates=(jsonDecode(r.body) as List).map((e)=>Map<String,dynamic>.from(e)).toList();
    if(candidates.isEmpty){_toast('No other pending or approved bookings are available for review.');return;}
    int? selected = candidates.any((b) => b['bookingId'] == widget.initialBookingId) ? widget.initialBookingId : null; String priority='P3'; final reason=TextEditingController();
    final ok=await showDialog<bool>(context:context,builder:(ctx)=>StatefulBuilder(builder:(ctx,setD)=>AlertDialog(
      title:const Text('Request priority conflict review'),
      content:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,children:[
        const Text('You can request review of a pending or approved booking. Submitting a review does not cancel or change the original booking.'),
        const SizedBox(height:12), DropdownButtonFormField<int>(isExpanded:true,decoration:const InputDecoration(labelText:'Booking to review'),
          value:selected,items:candidates.map((b)=>DropdownMenuItem<int>(value:b['bookingId'] as int,child:Text('${b['roomNo']} • ${b['bookingDate']} • ${b['startTime']}-${b['endTime']} • ${b['status']}',overflow:TextOverflow.ellipsis))).toList(),onChanged:(v)=>setD(()=>selected=v)),
        const SizedBox(height:12),DropdownButtonFormField<String>(value:priority,decoration:const InputDecoration(labelText:'Requested priority'),items:const [DropdownMenuItem(value:'P1',child:Text('P1 – Critical')),DropdownMenuItem(value:'P2',child:Text('P2 – High')),DropdownMenuItem(value:'P3',child:Text('P3 – Normal')),DropdownMenuItem(value:'P4',child:Text('P4 – Routine'))],onChanged:(v)=>setD(()=>priority=v??'P3')),
        const SizedBox(height:12),TextField(controller:reason,maxLines:4,maxLength:1000,onChanged:(_)=>setD((){}),decoration:const InputDecoration(labelText:'Justification',hintText:'Explain the academic need and why this time slot is important (at least 12 characters)')),
      ])),actions:[TextButton(onPressed:()=>Navigator.pop(ctx,false),child:const Text('Cancel')),FilledButton(onPressed:selected==null||reason.text.trim().length<12?null:()=>Navigator.pop(ctx,true),child:const Text('Submit review'))])));
    if(ok!=true){reason.dispose();return;}
    try{final res=await http.post(Uri.parse('${ApiConfig.baseUrl}/api/booking-conflicts'),headers:{'Content-Type':'application/json'},body:jsonEncode({'username':widget.username,'existingBookingId':selected,'priority':priority,'justification':reason.text.trim()}));final d=decode(res.body);_toast(d['message']??d['error']??'Request submitted',good:res.statusCode==200);if(res.statusCode==200)await load();}
    catch(e){_toast('Could not submit: $e');}finally{reason.dispose();}
  }
  Future<void> _post(String path,Map<String,dynamic> body) async {
    try{final uri=Uri.parse('${ApiConfig.baseUrl}$path').replace(queryParameters:{'emailAddress':widget.username});final r=await http.post(uri,headers:{'Content-Type':'application/json'},body:jsonEncode(body));final d=decode(r.body);_toast(d['message']??d['error']??'Updated',good:r.statusCode==200);if(r.statusCode==200)await load();}
    catch(e){_toast('Action failed: $e');}
  }
  Future<void> headDecision(Map<String,dynamic> c,String decision)=>_post('/api/booking-conflicts/${c['id']}/head-decision',{'decision':decision});
  Future<void> verifyPriority(Map<String,dynamic> c) async {
    String p='${c['requestedPriority']??'P3'}';
    final ok=await showDialog<bool>(context:context,builder:(ctx)=>StatefulBuilder(builder:(ctx,setD)=>AlertDialog(title:const Text('Verify priority'),content:DropdownButtonFormField<String>(value:p,items:const [DropdownMenuItem(value:'P1',child:Text('P1 – Critical')),DropdownMenuItem(value:'P2',child:Text('P2 – High')),DropdownMenuItem(value:'P3',child:Text('P3 – Normal')),DropdownMenuItem(value:'P4',child:Text('P4 – Routine'))],onChanged:(v)=>setD(()=>p=v??p)),actions:[TextButton(onPressed:()=>Navigator.pop(ctx,false),child:const Text('Cancel')),FilledButton(onPressed:()=>Navigator.pop(ctx,true),child:const Text('Verify'))])));
    if(ok==true) await _post('/api/booking-conflicts/${c['id']}/priority-verification',{'priority':p});
  }
  Future<void> resolve(Map<String,dynamic> c) async {
    String choice='KEEP_EXISTING'; final note=TextEditingController(); final roomId=TextEditingController(); final date=TextEditingController(); final start=TextEditingController(); final end=TextEditingController();
    final ok=await showDialog<bool>(context:context,builder:(ctx)=>StatefulBuilder(builder:(ctx,setD)=>AlertDialog(title:const Text('Admin resolution'),content:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,children:[
      DropdownButtonFormField<String>(value:choice,decoration:const InputDecoration(labelText:'Resolution'),items:const [DropdownMenuItem(value:'KEEP_EXISTING',child:Text('Keep existing booking')),DropdownMenuItem(value:'ALTERNATE_ROOM',child:Text('Move existing booking to another room')),DropdownMenuItem(value:'ALTERNATE_TIME',child:Text('Move existing booking to another time')),DropdownMenuItem(value:'MUTUAL_RESCHEDULE',child:Text('Mutual rescheduling (requires both consents)')),DropdownMenuItem(value:'ESCALATE',child:Text('Escalate to Admin queue'))],onChanged:(v)=>setD(()=>choice=v??choice)),
      const SizedBox(height:8),TextField(controller:roomId,keyboardType:TextInputType.number,decoration:const InputDecoration(labelText:'Target room ID (alternate room / mutual)')),
      TextField(controller:date,decoration:const InputDecoration(labelText:'Target date YYYY-MM-DD')),
      TextField(controller:start,decoration:const InputDecoration(labelText:'Target start time HH:MM')),
      TextField(controller:end,decoration:const InputDecoration(labelText:'Target end time HH:MM')),
      TextField(controller:note,maxLines:3,decoration:const InputDecoration(labelText:'Admin note (required)')),
    ])),actions:[TextButton(onPressed:()=>Navigator.pop(ctx,false),child:const Text('Cancel')),FilledButton(onPressed:()=>Navigator.pop(ctx,true),child:const Text('Apply resolution'))])));
    if(ok==true){final body=<String,dynamic>{'resolution':choice,'note':note.text.trim()};if(roomId.text.trim().isNotEmpty)body['targetRoomId']=int.tryParse(roomId.text.trim());if(date.text.trim().isNotEmpty)body['targetDate']=date.text.trim();if(start.text.trim().isNotEmpty)body['targetStartTime']=start.text.trim();if(end.text.trim().isNotEmpty)body['targetEndTime']=end.text.trim();await _post('/api/booking-conflicts/${c['id']}/admin-resolution',body);}
    note.dispose();roomId.dispose();date.dispose();start.dispose();end.dispose();
  }
  Future<void> consent(Map<String,dynamic> c,bool agree)=>_post('/api/booking-conflicts/${c['id']}/consent',{'agree':agree});
  Future<void> history(Map<String,dynamic> c) async {
    final uri=Uri.parse('${ApiConfig.baseUrl}/api/booking-conflicts/${c['id']}/history').replace(queryParameters:{'emailAddress':widget.username});
    try{final r=await http.get(uri);if(r.statusCode!=200){_toast(decode(r.body)['error']??'Unable to load history');return;}final list=jsonDecode(r.body) as List;if(!mounted)return;showDialog(context:context,builder:(ctx)=>AlertDialog(title:Text('Review #${c['id']} history'),content:SizedBox(width:420,child:ListView(shrinkWrap:true,children:list.map((e){final a=Map<String,dynamic>.from(e);return ListTile(dense:true,title:Text('${a['action']} • ${a['actor']}'),subtitle:Text('${a['details']??''}\n${a['createdAt']??''}'));}).toList())),actions:[TextButton(onPressed:()=>Navigator.pop(ctx),child:const Text('Close'))]));}catch(e){_toast('History unavailable: $e');}
  }
  void _toast(Object? msg,{bool good=false}){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('$msg'),backgroundColor:good?Colors.green:Colors.redAccent));}
  @override Widget build(BuildContext context){
    final faculty=widget.role=='FACULTY'||widget.role=='HEAD_STAFF';
    return RefreshIndicator(onRefresh:load,child:ListView(padding:const EdgeInsets.all(22),children:[
      Row(children:[const Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text('Priority Conflict Reviews',style:TextStyle(fontSize:22,fontWeight:FontWeight.w900)),SizedBox(height:5),Text('Review competing room requests with approvals, reminders and an auditable resolution.',style:TextStyle(color:Colors.blueGrey,fontSize:12))])),IconButton(onPressed:load,icon:const Icon(Icons.refresh))]),
      if(faculty)Align(alignment:Alignment.centerLeft,child:FilledButton.icon(onPressed:submit,icon:const Icon(Icons.add),label:const Text('Request conflict review'))),const SizedBox(height:14),
      if(loading)const Center(child:CircularProgressIndicator()) else if(error!=null)Text(error!,style:const TextStyle(color:Colors.red)) else if(items.isEmpty)const Card(child:Padding(padding:EdgeInsets.all(28),child:Text('No conflict review requests yet.'))) else ...items.map((c){
        final status='${c['status']??''}';final id='${c['id']}';
        return Card(margin:const EdgeInsets.only(bottom:12),child:Padding(padding:const EdgeInsets.all(16),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
          Row(children:[Expanded(child:Text('${c['roomNo']} • ${c['bookingDate']}',style:const TextStyle(fontWeight:FontWeight.w900,fontSize:16))),Chip(label:Text(status.replaceAll('_',' ')))]),
          Text('Time: ${c['startTime']} – ${c['endTime']}'),Text('Priority: ${c['verifiedPriority']??c['requestedPriority']} (requested ${c['requestedPriority']})'),Text('Requesting department: ${c['requesterDepartment']}'),Text('Existing booking department: ${c['existingDepartment']}'),const SizedBox(height:6),Text('${c['justification']}'),
          if(faculty && (status=='PENDING_HEAD_REVIEW'||status=='PENDING_ADMIN_RESOLUTION')) ...[const SizedBox(height:8),Text('Your rescheduling consent: ${widget.username.toLowerCase()==('${c['requesterEmail']??''}').toLowerCase()?(c['requesterConsent']==true?'Agreed':'Not agreed'):(c['existingOwnerConsent']==true?'Agreed':'Not agreed')}'),Wrap(spacing:8,children:[OutlinedButton(onPressed:()=>consent(c,true),child:const Text('Agree to reschedule')),OutlinedButton(onPressed:()=>consent(c,false),child:const Text('Decline reschedule'))])],
          if(widget.role=='HEAD_STAFF'&&status=='PENDING_HEAD_REVIEW') ...[const SizedBox(height:12),Wrap(spacing:8,children:[OutlinedButton(onPressed:()=>verifyPriority(c),child:const Text('Verify priority')),OutlinedButton(onPressed:()=>headDecision(c,'ESCALATE'),child:const Text('Escalate to Admin')),OutlinedButton(onPressed:()=>headDecision(c,'DECLINE'),child:const Text('Decline')),FilledButton(onPressed:()=>headDecision(c,'KEEP_EXISTING'),child:const Text('Keep existing booking'))])],
          if(widget.role=='ADMIN'&&(status=='PENDING_ADMIN_RESOLUTION'||status=='ESCALATED_TO_ADMIN'))Padding(padding:const EdgeInsets.only(top:12),child:FilledButton.icon(onPressed:()=>resolve(c),icon:const Icon(Icons.gavel),label:const Text('Resolve conflict'))),
          Align(alignment:Alignment.centerRight,child:TextButton.icon(onPressed:()=>history(c),icon:const Icon(Icons.history),label:const Text('Audit history'))),
        ])));
      })
    ]));
  }
}
