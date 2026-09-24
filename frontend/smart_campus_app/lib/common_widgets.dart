import 'package:flutter/material.dart';
import 'app_theme.dart';

class CampusBrand extends StatelessWidget {
  final bool white;
  const CampusBrand({this.white = false});

  @override
  Widget build(BuildContext context) {
    final fg = white ? Colors.white : navy;
    final sub = white ? Colors.white70 : muted;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 48,
          height: 48,
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: white ? Colors.white24 : border),
            boxShadow: const [BoxShadow(color: Color(0x14000000), blurRadius: 14, offset: Offset(0, 5))],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Icon(Icons.school_rounded, color: purple, size: 27),
          ),
        ),
        const SizedBox(width: 11),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('GNITS', style: TextStyle(color: fg, fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: .3)),
            const SizedBox(height: 1),
            Text('Smart Campus', style: TextStyle(color: sub, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: .35)),
          ],
        ),
      ],
    );
  }
}

class FeatureChip extends StatelessWidget {
  final IconData icon;
  final String text;
  const FeatureChip({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white70, size: 16),
          const SizedBox(width: 7),
          Text(text, style: const TextStyle(color: Colors.white70, fontSize: 12)),
        ],
      ),
    );
  }
}

class SectionHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  const SectionHeader({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: navy)),
          const SizedBox(height: 4),
          Text(subtitle, style: const TextStyle(fontSize: 12, color: muted)),
        ],
      );
}

class OperationCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final Color color;
  const OperationCard({required this.icon, required this.title, required this.value, required this.color});

  @override
  Widget build(BuildContext context) => Container(
        width: 220,
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: canvas,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: border),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(color: color.withOpacity(.10), borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
                  const SizedBox(height: 3),
                  Text(value, style: const TextStyle(color: muted, fontSize: 10)),
                ],
              ),
            ),
          ],
        ),
      );
}

class WorkflowStep extends StatelessWidget {
  final String number;
  final String title;
  final String text;
  final IconData icon;
  const WorkflowStep({required this.number, required this.title, required this.text, required this.icon});

  @override
  Widget build(BuildContext context) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: purple.withOpacity(.09), borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, size: 19, color: purple),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('$number  $title', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
                const SizedBox(height: 4),
                Text(text, style: const TextStyle(color: muted, fontSize: 11, height: 1.4)),
              ],
            ),
          ),
        ],
      );
}

class AppKpi extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  const AppKpi(this.title, this.value, this.icon, this.color, {super.key});

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(color: color.withOpacity(.10), borderRadius: BorderRadius.circular(13)),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: navy)),
                    const SizedBox(height: 3),
                    Text(title, style: const TextStyle(color: muted, fontSize: 11)),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
}

class StatusRow extends StatelessWidget {
  final String title;
  final String value;
  final Color color;
  const StatusRow(this.title, this.value, this.color);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 15),
        child: Row(
          children: [
            Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
            const SizedBox(width: 10),
            Expanded(child: Text(title, style: const TextStyle(fontSize: 12))),
            Text(value, style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 11)),
          ],
        ),
      );
}

class AnalyticsBar extends StatelessWidget {
  final String label;
  final num value;
  const AnalyticsBar(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    final p = (value / 36).clamp(0.0, 1.0).toDouble();
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600))),
              Text('${value.toInt()}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: p,
              minHeight: 8,
              backgroundColor: const Color(0xFFE9EDF3),
              color: purple,
            ),
          ),
        ],
      ),
    );
  }
}

class StatusPill extends StatelessWidget {
  final String text;
  final Color color;
  const StatusPill(this.text, this.color);

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: color.withOpacity(.10),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          text,
          style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.w800),
        ),
      );
}

class ErrorCard extends StatelessWidget {
  final String message;
  const ErrorCard({required this.message});

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.error_outline, color: Colors.redAccent),
              const SizedBox(width: 10),
              Expanded(child: Text(message, style: const TextStyle(color: Colors.redAccent))),
            ],
          ),
        ),
      );
}

class EmptyCard extends StatelessWidget {
  final String title;
  final String text;
  const EmptyCard({required this.title, required this.text});

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(42),
          child: Center(
            child: Column(
              children: [
                const Icon(Icons.inbox_outlined, size: 38, color: muted),
                const SizedBox(height: 12),
                Text(title, style: const TextStyle(fontWeight: FontWeight.w800, color: navy)),
                const SizedBox(height: 5),
                Text(text, style: const TextStyle(color: muted)),
              ],
            ),
          ),
        ),
      );
}

class OccupancyRoom {
  final int roomId;
  final String roomNo;
  final String roomType;
  final int? capacity;
  final String status;
  final String? subject;
  final String? section;
  final String? startTime;
  final String? endTime;

  OccupancyRoom({
    required this.roomId,
    required this.roomNo,
    required this.roomType,
    this.capacity,
    required this.status,
    this.subject,
    this.section,
    this.startTime,
    this.endTime,
  });

  factory OccupancyRoom.fromJson(Map<String, dynamic> j) => OccupancyRoom(
        roomId: (j['roomId'] as num).toInt(),
        roomNo: '${j['roomNo'] ?? ''}',
        roomType: '${j['roomType'] ?? ''}',
        capacity: (j['capacity'] as num?)?.toInt(),
        status: '${j['status'] ?? 'AVAILABLE'}',
        subject: j['subject']?.toString() ?? j['currentClass']?.toString(),
        section: j['section']?.toString() ?? j['branch']?.toString(),
        startTime: j['startTime']?.toString(),
        endTime: j['endTime']?.toString(),
      );
}
