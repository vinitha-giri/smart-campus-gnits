import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'api_config.dart';

class ApprovalRequestsScreen extends StatefulWidget {
  final String email;
  const ApprovalRequestsScreen({super.key, required this.email});
  @override State<ApprovalRequestsScreen> createState()=>_ApprovalRequestsScreenState();
}

class _ApprovalRequestsScreenState extends State<ApprovalRequestsScreen> {
  bool loading=true;
  Timer? _pollTimer;
  String? info;
  List<Map<String,dynamic>> requests=[];
  String? error;

  @override void initState(){super.initState(); load(); _pollTimer=Timer.periodic(const Duration(seconds:20),(_)=>load(silent:true));}
  @override void dispose(){_pollTimer?.cancel();super.dispose();}
  Map<String,dynamic> decode(String s){try{final v=jsonDecode(s); return v is Map?Map<String,dynamic>.from(v):{};}catch(_){return {};}}

  Future<void> load({bool silent=false}) async {
    if(!silent && mounted) setState(()=>loading=true);
    if(mounted && !silent) setState(()=>error=null);

    try {
      final r=await http.get(Uri.parse('${ApiConfig.baseUrl}/api/bookings/pending-approvals').replace(queryParameters:{'email':widget.email}));
      final body=decode(r.body);
      if(r.statusCode!=200) throw Exception(body['error']??'Could not load approval requests.');
      final raw=body['bookings'];
      if(mounted) setState(() { requests = raw is List ? raw.map((e)=>Map<String,dynamic>.from(e as Map)).toList() : []; info = body['message']?.toString(); });
    }catch(e){if(mounted)setState(()=>error=e.toString().replaceFirst('Exception: ',''));}
    finally{if(mounted && !silent)setState(()=>loading=false);}
  }

  Future<void> decide(Map<String,dynamic> b,bool approve) async {
    String reason='';
    if(!approve){
      final c=TextEditingController();
      final ok=await showDialog<bool>(context:context,builder:(ctx)=>AlertDialog(title:const Text('Reject booking'),content:TextField(controller:c,maxLines:3,decoration:const InputDecoration(labelText:'Reason (optional)',hintText:'Explain why the booking is rejected')),actions:[TextButton(onPressed:()=>Navigator.pop(ctx,false),child:const Text('Cancel')),FilledButton(onPressed:()=>Navigator.pop(ctx,true),child:const Text('Reject'))]));
      reason=c.text.trim(); c.dispose(); if(ok!=true)return;
    } else {
      final ok=await showDialog<bool>(context:context,builder:(ctx)=>AlertDialog(title:const Text('Approve booking?'),content:Text('${b['roomNo']} • ${b['bookingDate']} • ${b['startTime']}–${b['endTime']}'),actions:[TextButton(onPressed:()=>Navigator.pop(ctx,false),child:const Text('Cancel')),FilledButton(onPressed:()=>Navigator.pop(ctx,true),child:const Text('Approve'))]));
      if(ok!=true)return;
    }
    try{
      final uri=Uri.parse('${ApiConfig.baseUrl}/api/bookings/${b['bookingId']}/${approve?'approve':'reject'}').replace(queryParameters:{'email':widget.email,if(!approve)'reason':reason});
      final r=await http.post(uri); final body=decode(r.body);
      if(!mounted)return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(body['message']??body['error']??'Request completed.'),backgroundColor:r.statusCode==200?Colors.green:Colors.redAccent));
      if(r.statusCode==200) await load();
    }catch(e){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('Could not update booking: $e')));}
  }

  @override Widget build(BuildContext context){
    return RefreshIndicator(onRefresh:load,child:ListView(padding:const EdgeInsets.fromLTRB(24,24,24,40),children:[
      Row(children:[const Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text('Approval Requests',style:TextStyle(fontSize:22,fontWeight:FontWeight.w900)),SizedBox(height:5),Text('Review classroom booking requests from your department.',style:TextStyle(fontSize:12,color:Colors.blueGrey))])),IconButton(onPressed:load,icon:const Icon(Icons.refresh_rounded))]),
      const SizedBox(height:18),
      if(loading) const Center(child:Padding(padding:EdgeInsets.all(40),child:CircularProgressIndicator()))
      else if(error!=null) Card(child:Padding(padding:const EdgeInsets.all(20),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[const Icon(Icons.info_outline_rounded,color:Colors.orange),const SizedBox(height:8),Text(error!,style:const TextStyle(color:Colors.orange,fontWeight:FontWeight.w700)),const SizedBox(height:6),const Text('Please contact Admin if your Head Staff department is not configured.',style:TextStyle(fontSize:12,color:Colors.blueGrey))])))
      else if(requests.isEmpty) Card(child:Padding(padding:const EdgeInsets.all(40),child:Center(child:Column(children:[Icon(Icons.check_circle_outline_rounded,size:46,color:Colors.green.shade600),const SizedBox(height:10),const Text('No pending booking requests',style:TextStyle(fontWeight:FontWeight.w800)),const SizedBox(height:5),const Text('New requests from your department will appear here.',style:TextStyle(fontSize:12,color:Colors.blueGrey))]))))
      else ...requests.map((b)=>Card(margin:const EdgeInsets.only(bottom:12),child:Padding(padding:const EdgeInsets.all(16),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        Row(children:[Expanded(child:Text('${b['roomNo']}',style:const TextStyle(fontSize:17,fontWeight:FontWeight.w900))),Container(padding:const EdgeInsets.symmetric(horizontal:9,vertical:5),decoration:BoxDecoration(color:Colors.orange.shade50,borderRadius:BorderRadius.circular(20)),child:const Text('PENDING',style:TextStyle(fontSize:10,fontWeight:FontWeight.w900,color:Colors.orange))) ]),
        const SizedBox(height:10),
        Text('Date: ${b['bookingDate']}'),Text('Time: ${b['startTime']} – ${b['endTime']}'),Text('Faculty: ${b['bookedBy']}'),Text('Purpose: ${b['purpose']}'),
        const SizedBox(height:14),Row(children:[Expanded(child:OutlinedButton.icon(onPressed:()=>decide(b,false),icon:const Icon(Icons.close_rounded),label:const Text('Reject'))),const SizedBox(width:10),Expanded(child:FilledButton.icon(onPressed:()=>decide(b,true),icon:const Icon(Icons.check_rounded),label:const Text('Approve')))])
      ]))))
    ]));
  }
}
