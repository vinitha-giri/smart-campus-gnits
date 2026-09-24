import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'api_config.dart';

const bookingNavy = Color(0xFF0B1533);
const bookingPurple = Color(0xFF4F46E5);
const bookingCanvas = Color(0xFFF5F7FC);
const bookingBorder = Color(0xFFDCE4F0);
const bookingMuted = Color(0xFF64748B);

class BookingScreen extends StatefulWidget {
  final String role;
  final String username;

  const BookingScreen({
    super.key,
    required this.role,
    required this.username,
  });

  @override
  State<BookingScreen> createState() => _BookingScreenState();
}

class _BookingScreenState extends State<BookingScreen> {
  DateTime date = DateTime.now();
  TimeOfDay startTime = const TimeOfDay(hour: 10, minute: 0);
  TimeOfDay endTime = const TimeOfDay(hour: 11, minute: 0);
  int capacity = 0;
  String roomType = 'ALL';
  bool loading = false;
  List<Map<String, dynamic>> rooms = [];
  List<Map<String, dynamic>> bookings = [];
  String? error;

  static const List<int> _nextFreeMinutes = [
    7 * 60,
    7 * 60 + 30,
    8 * 60,
    8 * 60 + 30,
    9 * 60,
    9 * 60 + 30,
    10 * 60,
    10 * 60 + 30,
    11 * 60,
    11 * 60 + 30,
    12 * 60,
    12 * 60 + 30,
    13 * 60,
    13 * 60 + 30,
    14 * 60,
    14 * 60 + 30,
    15 * 60,
    15 * 60 + 30,
    16 * 60,
    16 * 60 + 30,
    17 * 60,
    17 * 60 + 30,
    18 * 60,
  ];

  String get dateText =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  String _two(int value) => value.toString().padLeft(2, '0');

  String _apiTime(TimeOfDay value) => '${_two(value.hour)}:${_two(value.minute)}';

  String _displayTime(TimeOfDay value) {
    final hour = value.hourOfPeriod == 0 ? 12 : value.hourOfPeriod;
    final minute = _two(value.minute);
    final suffix = value.period == DayPeriod.am ? 'AM' : 'PM';
    return '$hour:$minute $suffix';
  }

  int _minutes(TimeOfDay value) => value.hour * 60 + value.minute;

  int get durationMinutes => _minutes(endTime) - _minutes(startTime);

  String get durationLabel {
    final minutes = durationMinutes;
    if (minutes <= 0) return 'Invalid duration';
    final hours = minutes ~/ 60;
    final remaining = minutes % 60;
    if (hours == 0) return '$remaining min';
    if (remaining == 0) return hours == 1 ? '1 hour' : '$hours hours';
    return '$hours hr $remaining min';
  }

  @override
  void initState() {
    super.initState();
    refresh();
  }

  Future<void> refresh() async {
    await Future.wait([loadAvailable(), loadBookings()]);
  }

  Future<void> loadAvailable() async {
    if (_minutes(endTime) <= _minutes(startTime)) {
      if (mounted) {
        setState(() {
          rooms = [];
          error = 'End time must be later than start time.';
          loading = false;
        });
      }
      return;
    }

    if (mounted) {
      setState(() {
        loading = true;
        error = null;
      });
    }

    try {
      final query = <String, String>{
        'date': dateText,
        'startTime': _apiTime(startTime),
        'endTime': _apiTime(endTime),
        'capacity': '$capacity',
      };
      if (roomType != 'ALL') query['roomType'] = roomType;

      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/api/bookings/available')
            .replace(queryParameters: query),
      );

      if (response.statusCode != 200) {
        final decoded = _decodeMap(response.body);
        throw Exception(decoded['error']?.toString() ?? response.body);
      }

      final body = _decodeMap(response.body);
      final rawRooms = body['rooms'];
      if (mounted) {
        setState(() {
          rooms = rawRooms is List
              ? rawRooms
                  .map((item) => Map<String, dynamic>.from(item as Map))
                  .toList()
              : <Map<String, dynamic>>[];
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          error = e.toString();
          rooms = [];
        });
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> loadBookings() async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/api/bookings').replace(
          queryParameters: {
            'role': widget.role,
            'username': widget.username,
          },
        ),
      );
      if (response.statusCode != 200 || !mounted) return;
      final decoded = jsonDecode(response.body);
      if (decoded is List) {
        setState(() {
          bookings = decoded
              .map((item) => Map<String, dynamic>.from(item as Map))
              .toList();
        });
      }
    } catch (_) {
      // Booking search remains usable if history is temporarily unavailable.
    }
  }

  Future<void> chooseDate() async {
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 180)),
      initialDate: date.isBefore(DateTime.now()) ? DateTime.now() : date,
    );
    if (picked == null) return;
    setState(() => date = picked);
    await loadAvailable();
  }

  Future<void> chooseStartTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: startTime,
      helpText: 'SELECT START TIME',
    );
    if (picked == null) return;
    setState(() => startTime = picked);
    if (_minutes(endTime) <= _minutes(startTime)) {
      final suggestedEnd = _minutes(startTime) + 60;
      if (suggestedEnd < 24 * 60) {
        setState(() => endTime = TimeOfDay(
              hour: suggestedEnd ~/ 60,
              minute: suggestedEnd % 60,
            ));
      }
    }
    await loadAvailable();
  }

  Future<void> chooseEndTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: endTime,
      helpText: 'SELECT END TIME',
    );
    if (picked == null) return;
    if (_minutes(picked) <= _minutes(startTime)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('End time must be later than start time.')),
        );
      }
      return;
    }
    setState(() => endTime = picked);
    await loadAvailable();
  }

  Future<void> findNextFree() async {
    if (durationMinutes <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Choose a valid start and end time first.')),
      );
      return;
    }

    setState(() => loading = true);
    final requestedDuration = durationMinutes;
    final originalStart = _minutes(startTime);

    try {
      for (int dayOffset = 0; dayOffset < 8; dayOffset++) {
        final candidateDate = DateTime(
          date.year,
          date.month,
          date.day,
        ).add(Duration(days: dayOffset));

        for (final candidateStart in _nextFreeMinutes) {
          if (dayOffset == 0 && candidateStart < originalStart) continue;
          final candidateEnd = candidateStart + requestedDuration;
          if (candidateEnd > 20 * 60) continue;

          final start = TimeOfDay(
            hour: candidateStart ~/ 60,
            minute: candidateStart % 60,
          );
          final end = TimeOfDay(
            hour: candidateEnd ~/ 60,
            minute: candidateEnd % 60,
          );

          final query = <String, String>{
            'date': _formatDate(candidateDate),
            'startTime': _apiTime(start),
            'endTime': _apiTime(end),
            'capacity': '$capacity',
          };
          if (roomType != 'ALL') query['roomType'] = roomType;

          final response = await http.get(
            Uri.parse('${ApiConfig.baseUrl}/api/bookings/available')
                .replace(queryParameters: query),
          );
          if (response.statusCode != 200) continue;

          final body = _decodeMap(response.body);
          final list = body['rooms'];
          if (list is List && list.isNotEmpty && mounted) {
            setState(() {
              date = candidateDate;
              startTime = start;
              endTime = end;
              rooms = list
                  .map((item) => Map<String, dynamic>.from(item as Map))
                  .toList();
              error = null;
            });
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Found ${list.length} free room(s) for ${_displayTime(start)}–${_displayTime(end)} on ${_formatDate(candidateDate)}.',
                ),
              ),
            );
            return;
          }
        }
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No matching free room found in the next 7 days.')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not search for the next free time.')),
        );
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  String _formatDate(DateTime value) =>
      '${value.year}-${_two(value.month)}-${_two(value.day)}';

  Future<Map<String, dynamic>?> _checkRoom(Map<String, dynamic> room) async {
    final roomId = room['roomId'];
    if (roomId == null) return null;
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/api/bookings/check').replace(
          queryParameters: {
            'roomId': '$roomId',
            'date': dateText,
            'startTime': _apiTime(startTime),
            'endTime': _apiTime(endTime),
          },
        ),
      );
      if (response.statusCode == 200) return _decodeMap(response.body);
    } catch (_) {}
    return null;
  }

  Future<void> book(Map<String, dynamic> room) async {
    if (durationMinutes <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a valid time range.')),
      );
      return;
    }

    final check = await _checkRoom(room);
    if (check != null && check['available'] == false) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.redAccent,
            content: Text(check['reason']?.toString() ?? 'Room is no longer available.'),
          ),
        );
        await loadAvailable();
      }
      return;
    }

    final purposeController = TextEditingController();
    String purposeType = 'Extra class';
    const purposes = [
      'Extra class',
      'Meeting',
      'Workshop',
      'Seminar',
      'Project review',
      'Guest lecture',
      'Club activity',
      'Other',
    ];

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            return AlertDialog(
              title: Text('Book ${room['roomNo']}'),
              content: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: math.min(MediaQuery.sizeOf(context).width - 40, 460),
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: bookingBorder),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${room['roomNo']} • ${room['roomType'] ?? 'Classroom'}',
                              style: const TextStyle(fontWeight: FontWeight.w800, color: bookingNavy),
                            ),
                            const SizedBox(height: 5),
                            Text('Capacity: ${room['capacity'] ?? '—'} seats', style: const TextStyle(color: bookingMuted, fontSize: 12)),
                            const SizedBox(height: 5),
                            Text('$dateText • ${_displayTime(startTime)} – ${_displayTime(endTime)}', style: const TextStyle(color: bookingMuted, fontSize: 12)),
                            const SizedBox(height: 5),
                            Text('Duration: $durationLabel', style: const TextStyle(fontWeight: FontWeight.w700, color: bookingPurple, fontSize: 12)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        value: purposeType,
                        decoration: const InputDecoration(
                          labelText: 'Booking purpose',
                          prefixIcon: Icon(Icons.description_outlined),
                        ),
                        items: purposes
                            .map((value) => DropdownMenuItem(value: value, child: Text(value)))
                            .toList(),
                        onChanged: (value) {
                          if (value != null) setDialogState(() => purposeType = value);
                        },
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: purposeController,
                        maxLength: 120,
                        decoration: InputDecoration(
                          labelText: purposeType == 'Other' ? 'Purpose' : 'Additional details (optional)',
                          hintText: 'Add a short note if needed',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: const Text('Cancel'),
                ),
                FilledButton.icon(
                  onPressed: () => Navigator.pop(dialogContext, true),
                  icon: const Icon(Icons.check_rounded, size: 17),
                  label: const Text('Confirm booking'),
                ),
              ],
            );
          },
        );
      },
    );

    if (confirmed != true) {
      purposeController.dispose();
      return;
    }

    final typedPurpose = purposeController.text.trim();
    final purpose = typedPurpose.isNotEmpty ? '$purposeType — $typedPurpose' : purposeType;

    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/api/bookings'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'roomId': room['roomId'],
          'date': dateText,
          'startTime': _apiTime(startTime),
          'endTime': _apiTime(endTime),
          'purpose': purpose,
          'username': widget.username,
          'role': widget.role,
        }),
      );

      final body = _decodeMap(response.body);
      if (!mounted) return;

      if (response.statusCode == 200 || response.statusCode == 201) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: Colors.green,
            content: Text('Room booked successfully.'),
          ),
        );
        await refresh();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.redAccent,
            content: Text(body['error']?.toString() ?? 'Booking failed.'),
          ),
        );
        await loadAvailable();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Booking error: $e')),
        );
      }
    } finally {
      purposeController.dispose();
    }
  }

  Future<void> cancel(Map<String, dynamic> booking) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Cancel booking?'),
        content: Text(
          '${booking['roomNo']} • ${booking['bookingDate']} • ${booking['startTime']}–${booking['endTime']}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Keep'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Cancel booking'),
          ),
        ],
      ),
    );
    if (yes != true) return;

    try {
      final response = await http.delete(
        Uri.parse('${ApiConfig.baseUrl}/api/bookings/${booking['bookingId']}')
            .replace(queryParameters: {
          'role': widget.role,
          'username': widget.username,
        }),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            response.statusCode == 200 ? 'Booking cancelled.' : 'Could not cancel booking.',
          ),
        ),
      );
      await refresh();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Cancellation error: $e')),
        );
      }
    }
  }

  Map<String, dynamic> _decodeMap(String source) {
    try {
      final decoded = jsonDecode(source);
      return decoded is Map ? Map<String, dynamic>.from(decoded) : <String, dynamic>{};
    } catch (_) {
      return <String, dynamic>{};
    }
  }

  Widget _timeField({required String label, required TimeOfDay value, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: const Icon(Icons.schedule_outlined),
          suffixIcon: const Icon(Icons.access_time_rounded, size: 19),
        ),
        child: Text(
          _displayTime(value),
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: bookingNavy),
        ),
      ),
    );
  }

  Widget _filterPanel() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: bookingBorder),
        boxShadow: const [
          BoxShadow(color: Color(0x0A0B1533), blurRadius: 18, offset: Offset(0, 8)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: bookingPurple.withOpacity(.09),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: const Icon(Icons.tune_rounded, color: bookingPurple, size: 20),
              ),
              const SizedBox(width: 11),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Find your classroom', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: bookingNavy)),
                    SizedBox(height: 3),
                    Text('Choose any start and end time. Timetable occupancy and existing bookings are checked automatically.', style: TextStyle(fontSize: 11.5, color: bookingMuted)),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              OutlinedButton.icon(
                onPressed: loading ? null : findNextFree,
                icon: const Icon(Icons.auto_awesome_rounded, size: 16),
                label: const Text('Find next free'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 900;
              final width = compact ? (constraints.maxWidth - 12) / 2 : 195.0;
              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  SizedBox(
                    width: compact ? width : 185,
                    child: OutlinedButton.icon(
                      onPressed: chooseDate,
                      icon: const Icon(Icons.calendar_today_outlined, size: 18),
                      label: Text(dateText),
                    ),
                  ),
                  SizedBox(
                    width: compact ? width : 195,
                    child: _timeField(label: 'Start time', value: startTime, onTap: chooseStartTime),
                  ),
                  SizedBox(
                    width: compact ? width : 195,
                    child: _timeField(label: 'End time', value: endTime, onTap: chooseEndTime),
                  ),
                  SizedBox(
                    width: compact ? width : 180,
                    child: DropdownButtonFormField<int>(
                      value: capacity,
                      decoration: const InputDecoration(labelText: 'Minimum capacity'),
                      items: const [
                        DropdownMenuItem(value: 0, child: Text('Any capacity')),
                        DropdownMenuItem(value: 30, child: Text('30+ seats')),
                        DropdownMenuItem(value: 60, child: Text('60+ seats')),
                        DropdownMenuItem(value: 100, child: Text('100+ seats')),
                      ],
                      onChanged: (value) {
                        if (value == null) return;
                        setState(() => capacity = value);
                        loadAvailable();
                      },
                    ),
                  ),
                  SizedBox(
                    width: compact ? width : 180,
                    child: DropdownButtonFormField<String>(
                      value: roomType,
                      decoration: const InputDecoration(labelText: 'Room type'),
                      items: const [
                        DropdownMenuItem(value: 'ALL', child: Text('All room types')),
                        DropdownMenuItem(value: 'CLASSROOM', child: Text('Classroom')),
                        DropdownMenuItem(value: 'LAB', child: Text('Laboratory')),
                        DropdownMenuItem(value: 'SEMINAR_HALL', child: Text('Seminar Hall')),
                      ],
                      onChanged: (value) {
                        if (value == null) return;
                        setState(() => roomType = value);
                        loadAvailable();
                      },
                    ),
                  ),
                  if (durationMinutes > 0)
                    Container(
                      height: 56,
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF5F3FF),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE9D5FF)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.timelapse_rounded, size: 18, color: bookingPurple),
                          const SizedBox(width: 8),
                          Text('Duration: $durationLabel', style: const TextStyle(fontWeight: FontWeight.w800, color: bookingPurple, fontSize: 12)),
                        ],
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _availabilityContent() {
    if (error != null) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF7F7),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFFECACA)),
        ),
        child: Row(
          children: [
            const Icon(Icons.error_outline_rounded, color: Colors.redAccent),
            const SizedBox(width: 10),
            Expanded(child: Text(error!, style: const TextStyle(color: Colors.redAccent))),
            TextButton(onPressed: loadAvailable, child: const Text('Retry')),
          ],
        ),
      );
    }
    if (loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 70),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (rooms.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 54, horizontal: 24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: bookingBorder),
        ),
        child: Column(
          children: [
            const Icon(Icons.event_busy_outlined, size: 42, color: bookingMuted),
            const SizedBox(height: 12),
            const Text('No rooms available for this time', style: TextStyle(fontWeight: FontWeight.w800, color: bookingNavy)),
            const SizedBox(height: 5),
            Text('Try another time, capacity or room type. You can also use Find next free.', style: const TextStyle(color: bookingMuted, fontSize: 12), textAlign: TextAlign.center),
          ],
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth > 1050 ? 3 : constraints.maxWidth > 650 ? 2 : 1;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: rooms.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            crossAxisSpacing: 14,
            mainAxisSpacing: 14,
            childAspectRatio: columns == 1 ? 2.7 : 1.85,
          ),
          itemBuilder: (context, index) => _roomCard(rooms[index]),
        );
      },
    );
  }

  Widget _roomCard(Map<String, dynamic> room) {
    final roomNo = '${room['roomNo'] ?? '—'}';
    final type = '${room['roomType'] ?? 'Classroom'}'.replaceAll('_', ' ');
    final seats = '${room['capacity'] ?? '—'}';
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: bookingBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(color: const Color(0xFFECFDF5), borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.meeting_room_outlined, color: Color(0xFF16A34A)),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(roomNo, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: bookingNavy)),
                    const SizedBox(height: 3),
                    Text('$type • $seats seats', style: const TextStyle(fontSize: 11, color: bookingMuted)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(color: const Color(0xFFECFDF3), borderRadius: BorderRadius.circular(999)),
                child: const Text('AVAILABLE', style: TextStyle(color: Color(0xFF15803D), fontSize: 9, fontWeight: FontWeight.w900)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text('${_displayTime(startTime)} – ${_displayTime(endTime)}  •  $durationLabel', style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: bookingPurple)),
          const Spacer(),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _showRoomSchedule(room),
                  icon: const Icon(Icons.calendar_month_outlined, size: 16),
                  label: const Text('Schedule'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => book(room),
                  icon: const Icon(Icons.event_available_outlined, size: 16),
                  label: const Text('Book room'),
                  style: FilledButton.styleFrom(backgroundColor: bookingPurple),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _showRoomSchedule(Map<String, dynamic> room) async {
    final id = room['roomId'];
    if (id == null) return;
    try {
      final r = await http.get(Uri.parse('${ApiConfig.baseUrl}/api/rooms/$id/schedule?fromDate=$dateText&days=7'));
      if (!mounted) return;
      final data = r.statusCode == 200 ? jsonDecode(r.body) as Map<String, dynamic> : <String, dynamic>{};
      final events = (data['events'] as List? ?? []).map((e) => Map<String, dynamic>.from(e)).toList();
      await showDialog<void>(
        context: context,
        builder: (dc) => AlertDialog(
          title: Text('${room['roomNo']} schedule'),
          content: SizedBox(
            width: 520,
            child: events.isEmpty
                ? const Text('No scheduled classes or bookings in the next 7 days.')
                : ListView.separated(
                    shrinkWrap: true,
                    itemCount: events.length,
                    itemBuilder: (_, i) {
                      final event = events[i];
                      final isBooking = event['type'] == 'BOOKING';
                      return ListTile(
                        dense: true,
                        leading: Icon(
                          isBooking ? Icons.bookmark_rounded : Icons.school_rounded,
                          color: isBooking ? Colors.blueAccent : Colors.deepPurple,
                        ),
                        title: Text('${event['date']} • ${event['startTime']}–${event['endTime']}'),
                        subtitle: Text('${event['title'] ?? 'Scheduled class'}'),
                      );
                    },
                    separatorBuilder: (_, __) => const Divider(height: 1),
                  ),
          ),
          actions: [TextButton(onPressed: () => Navigator.pop(dc), child: const Text('Close'))],
        ),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not load room schedule.')),
        );
      }
    }
  }

  Widget _bookingsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text('My bookings', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: bookingNavy)),
            ),
            Text(
              widget.role == 'ADMIN' ? 'All confirmed bookings' : 'Your confirmed bookings',
              style: const TextStyle(color: bookingMuted, fontSize: 12),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (bookings.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(28),
              child: Text('No confirmed bookings yet.', style: TextStyle(color: bookingMuted)),
            ),
          )
        else
          Card(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columns: const [
                  DataColumn(label: Text('Room')),
                  DataColumn(label: Text('Date')),
                  DataColumn(label: Text('Time')),
                  DataColumn(label: Text('Purpose')),
                  DataColumn(label: Text('Booked by')),
                  DataColumn(label: Text('Action')),
                ],
                rows: bookings.map((booking) {
                  return DataRow(cells: [
                    DataCell(Text('${booking['roomNo']}', style: const TextStyle(fontWeight: FontWeight.w800))),
                    DataCell(Text('${booking['bookingDate']}')),
                    DataCell(Text('${booking['startTime']}–${booking['endTime']}')),
                    DataCell(Text('${booking['purpose']}')),
                    DataCell(Text('${booking['bookedBy']}')),
                    DataCell(TextButton(onPressed: () => cancel(booking), child: const Text('Cancel'))),
                  ]);
                }).toList(),
              ),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: bookingCanvas,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 44),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1280),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFF8FAFF), Colors.white],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: bookingBorder),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(color: bookingPurple.withOpacity(.10), borderRadius: BorderRadius.circular(14)),
                        child: const Icon(Icons.event_available_rounded, color: bookingPurple, size: 24),
                      ),
                      const SizedBox(width: 13),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Book a Classroom', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: bookingNavy)),
                            SizedBox(height: 4),
                            Text('Find a suitable room and reserve any time range without double-booking.', style: TextStyle(fontSize: 12, color: bookingMuted)),
                          ],
                        ),
                      ),
                      IconButton(onPressed: loading ? null : refresh, tooltip: 'Refresh availability', icon: const Icon(Icons.refresh_rounded)),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                _filterPanel(),
                const SizedBox(height: 22),
                Row(
                  children: [
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Available classrooms', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: bookingNavy)),
                          SizedBox(height: 3),
                          Text('Rooms free for the complete selected date and time range.', style: TextStyle(fontSize: 11.5, color: bookingMuted)),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
                      decoration: BoxDecoration(color: const Color(0xFFECFDF3), borderRadius: BorderRadius.circular(999)),
                      child: Text('${rooms.length} available', style: const TextStyle(color: Color(0xFF15803D), fontSize: 11, fontWeight: FontWeight.w800)),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _availabilityContent(),
                if (widget.role != 'STUDENT') ...[
                  const SizedBox(height: 30),
                  _bookingsSection(),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
