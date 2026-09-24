import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'app_theme.dart';
import 'api_config.dart';
import 'package:url_launcher/url_launcher.dart';

class UploadTimetableScreen extends StatefulWidget {
  const UploadTimetableScreen({super.key});

  @override
  State<UploadTimetableScreen> createState() => _UploadTimetableScreenState();
}

class _UploadTimetableScreenState extends State<UploadTimetableScreen> {
  // ALL asks the backend for the complete multi-section template.
  // A specific section name can still be entered when a single-sheet template is needed.
  final section = TextEditingController(text: 'ALL');
  final year = TextEditingController(text: '2026-2027');
  final sem = TextEditingController(text: '1');

  Uint8List? bytes;
  String? name;
  bool uploading = false;
  bool opening = false;
  bool loadingSections = true;
  List<TimetableSection> uploadedSections = [];

  @override
  void initState() {
    super.initState();
    loadSections();
  }

  @override
  void dispose() {
    section.dispose();
    year.dispose();
    sem.dispose();
    super.dispose();
  }

  Future<void> loadSections() async {
    setState(() => loadingSections = true);
    try {
      final uri = Uri.parse('${ApiConfig.baseUrl}/api/timetable/excel/sections').replace(
        queryParameters: {
          'academicYear': year.text.trim(),
          'semesterNo': sem.text.trim(),
        },
      );
      final r = await http.get(uri);
      if (r.statusCode != 200) throw Exception(r.body);
      final body = jsonDecode(r.body) as Map<String, dynamic>;
      final raw = (body['sections'] as List?) ?? [];
      if (mounted) {
        setState(() {
          uploadedSections = raw
              .map((e) => TimetableSection.fromJson(Map<String, dynamic>.from(e)))
              .toList();
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not load uploaded timetables: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => loadingSections = false);
    }
  }

  Future<void> downloadTemplate() async {
    setState(() => opening = true);
    try {
      final uri = Uri.parse('${ApiConfig.baseUrl}/api/timetable/excel/template').replace(
        queryParameters: {
          'sectionName': section.text.trim().isEmpty ? 'ALL' : section.text.trim(),
          'academicYear': year.text.trim(),
          'semesterNo': sem.text.trim(),
        },
      );
      if (!await launchUrl(uri, mode: LaunchMode.platformDefault) && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open the Excel template.')),
        );
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Template error: $e')));
    } finally {
      if (mounted) setState(() => opening = false);
    }
  }

  Future<void> pick() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx'],
      withData: true,
    );
    if (result == null || result.files.single.bytes == null) return;
    setState(() {
      bytes = result.files.single.bytes!;
      name = result.files.single.name;
    });
  }

  Future<void> upload() async {
    if (bytes == null) return;

    final y = year.text.trim();
    final sm = sem.text.trim();

    if (y.isEmpty || sm.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Academic year and semester are required.')),
      );
      return;
    }

    setState(() => uploading = true);

    try {
      final uri = Uri.parse('${ApiConfig.baseUrl}/api/timetable/excel/upload').replace(
        queryParameters: {
          'sectionName': section.text.trim().isEmpty ? 'MULTI' : section.text.trim(),
          'academicYear': y,
          'semesterNo': sm,
        },
      );

      final request = http.MultipartRequest('POST', uri);
      request.files.add(
        http.MultipartFile.fromBytes(
          'file',
          bytes!,
          filename: name ?? 'GNITS_Timetable.xlsx',
        ),
      );

      final response = await request.send();
      final body = await response.stream.bytesToString();
      Map<String, dynamic>? parsed;
      try {
        parsed = jsonDecode(body) as Map<String, dynamic>;
      } catch (_) {}

      if (!mounted) return;

      if (response.statusCode == 200) {
        final sections = parsed?['sections'];
        setState(() {
          bytes = null;
          name = null;
        });
        await loadSections();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.green.shade700,
            content: Text(
              'Workbook published • ${parsed?['entriesCreated'] ?? 0} slots • '
              '${sections is List ? sections.join(', ') : 'timetable'}',
            ),
          ),
        );
      } else {
        final errors = parsed?['errors'];
        String message;
        if (errors is List && errors.isNotEmpty) {
          message = errors.take(3).join('\n');
        } else {
          message = parsed?['error']?.toString() ??
              parsed?['errors']?.toString() ??
              'Upload failed (${response.statusCode})';
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            duration: const Duration(seconds: 10),
            backgroundColor: Colors.red.shade700,
            content: Text(message),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Upload error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => uploading = false);
    }
  }

  Future<void> deleteSection(TimetableSection item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete ${item.sectionName} timetable?'),
        content: Text(
          'This will remove ${item.entries} scheduled slots for ${item.sectionName} '
          'from ${year.text.trim()} / Semester ${sem.text.trim()}. '
          'Other sections and semesters will not be changed.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete timetable'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final uri = Uri.parse('${ApiConfig.baseUrl}/api/timetable/excel/section').replace(
        queryParameters: {
          'sectionName': item.sectionName,
          'academicYear': year.text.trim(),
          'semesterNo': sem.text.trim(),
        },
      );
      final response = await http.delete(uri);
      final body = response.body;
      Map<String, dynamic>? parsed;
      try {
        parsed = jsonDecode(body) as Map<String, dynamic>;
      } catch (_) {}

      if (!mounted) return;

      if (response.statusCode == 200) {
        await loadSections();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.green.shade700,
            content: Text(
              '${item.sectionName} deleted • ${parsed?['deletedEntries'] ?? 0} slots removed',
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.red.shade700,
            content: Text(parsed?['error']?.toString() ?? 'Delete failed (${response.statusCode})'),
          ),
        );
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Delete error: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final totalSlots = uploadedSections.fold<int>(0, (sum, item) => sum + item.entries);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(28, 28, 28, 44),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1420),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Timetable Management', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: navy)),
                        SizedBox(height: 5),
                        Text(
                          'Publish, replace and manage section timetables from one controlled workspace.',
                          style: TextStyle(color: muted),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: loadSections,
                    tooltip: 'Refresh uploaded timetables',
                    icon: const Icon(Icons.refresh_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 22),

              // Enterprise summary
              LayoutBuilder(
                builder: (context, box) {
                  final cols = box.maxWidth > 1000 ? 4 : box.maxWidth > 600 ? 2 : 1;
                  return GridView.count(
                    crossAxisCount: cols,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisSpacing: 14,
                    mainAxisSpacing: 14,
                    childAspectRatio: 2.8,
                    children: [
                      _MiniKpi('Active sections', '${uploadedSections.length}', Icons.groups_outlined, purple),
                      _MiniKpi('Scheduled slots', '$totalSlots', Icons.event_note_outlined, navy),
                      _MiniKpi('Academic year', year.text.trim(), Icons.calendar_month_outlined, Colors.orange),
                      _MiniKpi('Semester', sem.text.trim(), Icons.school_outlined, Colors.teal),
                    ],
                  );
                },
              ),
              const SizedBox(height: 18),

              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 2,
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(22),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const _Header(
                              title: 'Upload a new timetable',
                              subtitle: 'Use one .xlsx workbook. Every timetable sheet becomes a unique Year + Department + Section class.',
                            ),
                            const SizedBox(height: 18),
                            LayoutBuilder(
                              builder: (context, constraints) {
                                final fields = [
                                  TextField(
                                    controller: year,
                                    onChanged: (_) => setState(() {}),
                                    decoration: const InputDecoration(
                                      labelText: 'Academic year',
                                      prefixIcon: Icon(Icons.calendar_today_outlined),
                                    ),
                                  ),
                                  TextField(
                                    controller: sem,
                                    onChanged: (_) => setState(() {}),
                                    decoration: const InputDecoration(
                                      labelText: 'Semester',
                                      prefixIcon: Icon(Icons.school_outlined),
                                    ),
                                  ),
                                  TextField(
                                    controller: section,
                                    decoration: const InputDecoration(
                                      labelText: 'Fallback class key',
                                      prefixIcon: Icon(Icons.groups_outlined),
                                    ),
                                  ),
                                ];
                                if (constraints.maxWidth > 760) {
                                  return Row(
                                    children: [
                                      Expanded(child: fields[0]),
                                      const SizedBox(width: 12),
                                      SizedBox(width: 150, child: fields[1]),
                                      const SizedBox(width: 12),
                                      Expanded(child: fields[2]),
                                    ],
                                  );
                                }
                                return Column(
                                  children: [
                                    fields[0],
                                    const SizedBox(height: 12),
                                    fields[1],
                                    const SizedBox(height: 12),
                                    fields[2],
                                  ],
                                );
                              },
                            ),
                            const SizedBox(height: 14),
                            Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF6F7FF),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: const Color(0xFFE2E2FF)),
                              ),
                              child: const Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(Icons.auto_awesome_outlined, color: purple, size: 20),
                                  SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      'Download Excel template gives you starter class sheets. IMPORTANT: CSE-A repeats in every year, so sheets use YEAR-DEPARTMENT-SECTION such as 1st-CSE-A, 2nd-CSE-A, 3rd-CSE-A and 4th-CSE-A. Delete any sheet you do not need, keep only the classes that actually exist, and upload the workbook. '
                                      'You can add/rename a sheet using the same format. Every timetable sheet must identify Year + Department + Section, for example 1st-CSE-A. Re-uploading replaces only that exact class for the selected semester. Time periods are read from the Excel headers, so different years can have different timings.',
                                      style: TextStyle(fontSize: 12, color: navy, height: 1.45),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 18),
                            Wrap(
                              spacing: 10,
                              runSpacing: 10,
                              children: [
                                OutlinedButton.icon(
                                  onPressed: opening ? null : downloadTemplate,
                                  icon: opening
                                      ? const SizedBox(width: 17, height: 17, child: CircularProgressIndicator(strokeWidth: 2))
                                      : const Icon(Icons.download_outlined),
                                  label: Text(opening ? 'Opening…' : 'Download Excel starter template'),
                                ),
                                OutlinedButton.icon(
                                  onPressed: uploading ? null : pick,
                                  icon: const Icon(Icons.folder_open_outlined),
                                  label: const Text('Choose workbook'),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              decoration: BoxDecoration(
                                color: canvas,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: border),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.description_outlined, color: navy),
                                  const SizedBox(width: 9),
                                  Expanded(
                                    child: Text(
                                      name ?? 'No workbook selected',
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
                                    ),
                                  ),
                                  if (name != null)
                                    IconButton(
                                      tooltip: 'Remove selected file',
                                      onPressed: uploading ? null : () => setState(() {
                                        name = null;
                                        bytes = null;
                                      }),
                                      icon: const Icon(Icons.close_rounded, size: 18),
                                    ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 14),
                            SizedBox(
                              width: double.infinity,
                              child: FilledButton.icon(
                                onPressed: bytes == null || uploading ? null : upload,
                                style: FilledButton.styleFrom(
                                  backgroundColor: purple,
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                ),
                                icon: uploading
                                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                    : const Icon(Icons.cloud_upload_outlined),
                                label: Text(uploading ? 'Validating & publishing…' : 'Validate & Publish Workbook'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(22),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const _Header(
                              title: 'Excel governance',
                              subtitle: 'The upload pipeline is intentionally strict.',
                            ),
                            const SizedBox(height: 18),
                            const _Rule(icon: Icons.layers_outlined, title: 'Multi-sheet ready', text: 'One workbook can contain multiple section sheets.'),
                            const _Rule(icon: Icons.room_outlined, title: 'Room-aware', text: 'Every occupied subject cell must resolve to a real LH-No.'),
                            const _Rule(icon: Icons.rule_outlined, title: 'Conflict-safe', text: 'Room/time conflicts are rejected before database changes.'),
                            const _Rule(icon: Icons.swap_horiz_rounded, title: 'Replace safely', text: 'Re-uploading a section replaces only that section for the selected semester.'),
                            const _Rule(icon: Icons.delete_outline_rounded, title: 'Controlled deletion', text: 'Admins can remove one section without touching other sections.'),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(22),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Expanded(
                            child: _Header(
                              title: 'Published timetables',
                              subtitle: 'Only sections actually stored for the selected academic year and semester are shown.',
                            ),
                          ),
                          if (!loadingSections)
                            _CountPill('${uploadedSections.length} sections'),
                        ],
                      ),
                      const SizedBox(height: 18),
                      if (loadingSections)
                        const Padding(
                          padding: EdgeInsets.all(30),
                          child: Center(child: CircularProgressIndicator()),
                        )
                      else if (uploadedSections.isEmpty)
                        const Padding(
                          padding: EdgeInsets.all(25),
                          child: Center(
                            child: Column(
                              children: [
                                Icon(Icons.table_rows_outlined, size: 42, color: muted),
                                SizedBox(height: 10),
                                Text('No timetable uploaded for this semester.', style: TextStyle(fontWeight: FontWeight.w800, color: navy)),
                                SizedBox(height: 5),
                                Text('Upload a workbook above to publish the first section.', style: TextStyle(color: muted, fontSize: 12)),
                              ],
                            ),
                          ),
                        )
                      else
                        LayoutBuilder(
                          builder: (context, box) {
                            final cols = box.maxWidth > 1050 ? 3 : box.maxWidth > 650 ? 2 : 1;
                            return GridView.builder(
                              itemCount: uploadedSections.length,
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: cols,
                                crossAxisSpacing: 14,
                                mainAxisSpacing: 14,
                                childAspectRatio: 2.05,
                              ),
                              itemBuilder: (context, index) {
                                final item = uploadedSections[index];
                                return _SectionCard(
                                  item: item,
                                  onDelete: () => deleteSection(item),
                                );
                              },
                            );
                          },
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Card(
                color: const Color(0xFFF5F8FF),
                child: Padding(
                  padding: const EdgeInsets.all(17),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.info_outline, color: Colors.orange),
                      const SizedBox(width: 11),
                      const Expanded(
                        child: Text(
                          'Excel format is flexible: Day | actual time ranges | LH-No/Room. The downloadable template automatically uses 09:20 for 1st Year and 09:00 for 2nd, 3rd and 4th Year. '
                          "You can edit the time headers to match the actual timetable for that class. "
                          'For a 3-hour lab such as 09:20-12:20, merge the subject cell across the three relevant time columns. The importer stores it as ONE 3-hour event. '
                          'If a day uses multiple rooms, create another row for that day with the other LH-No. Validation is all-or-nothing.',
                          style: TextStyle(fontSize: 12, color: Color(0xFF334155), height: 1.45),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class TimetableSection {
  final String sectionName;
  final int entries;
  final int subjects;
  final int rooms;
  final List<String> roomNames;

  const TimetableSection({
    required this.sectionName,
    required this.entries,
    required this.subjects,
    required this.rooms,
    required this.roomNames,
  });

  factory TimetableSection.fromJson(Map<String, dynamic> json) {
    return TimetableSection(
      sectionName: '${json['sectionName'] ?? ''}',
      entries: (json['entries'] as num?)?.toInt() ?? 0,
      subjects: (json['subjects'] as num?)?.toInt() ?? 0,
      rooms: (json['rooms'] as num?)?.toInt() ?? 0,
      roomNames: ((json['roomNames'] as List?) ?? []).map((e) => '$e').toList(),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final TimetableSection item;
  final VoidCallback onDelete;
  const _SectionCard({required this.item, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(color: purple.withOpacity(.09), borderRadius: BorderRadius.circular(11)),
                child: const Icon(Icons.table_view_rounded, color: purple),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Text(item.sectionName, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: navy)),
              ),
              IconButton(
                tooltip: 'Delete timetable',
                onPressed: onDelete,
                icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 20),
              ),
            ],
          ),
          const Spacer(),
          Row(
            children: [
              _Stat(label: '${item.entries}', value: 'slots'),
              _Stat(label: '${item.subjects}', value: 'subjects'),
              _Stat(label: '${item.rooms}', value: 'rooms'),
            ],
          ),
          const SizedBox(height: 9),
          Text(
            item.roomNames.isEmpty ? 'No room mappings' : item.roomNames.take(3).join(' • '),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 10, color: muted),
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final String value;
  const _Stat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) => Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontWeight: FontWeight.w800, color: navy)),
            const SizedBox(height: 2),
            Text(value, style: const TextStyle(color: muted, fontSize: 10)),
          ],
        ),
      );
}

class _MiniKpi extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  const _MiniKpi(this.title, this.value, this.icon, this.color);

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(17),
          child: Row(
            children: [
              Container(
                width: 43,
                height: 43,
                decoration: BoxDecoration(color: color.withOpacity(.09), borderRadius: BorderRadius.circular(11)),
                child: Icon(icon, color: color, size: 21),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: navy)),
                    const SizedBox(height: 3),
                    Text(title, style: const TextStyle(fontSize: 10, color: muted)),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
}

class _Header extends StatelessWidget {
  final String title;
  final String subtitle;
  const _Header({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: navy)),
          const SizedBox(height: 4),
          Text(subtitle, style: const TextStyle(fontSize: 11, color: muted, height: 1.4)),
        ],
      );
}

class _Rule extends StatelessWidget {
  final IconData icon;
  final String title;
  final String text;
  const _Rule({required this.icon, required this.title, required this.text});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 15),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(color: canvas, borderRadius: BorderRadius.circular(9)),
              child: Icon(icon, color: navy, size: 18),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
                  const SizedBox(height: 3),
                  Text(text, style: const TextStyle(color: muted, fontSize: 10, height: 1.35)),
                ],
              ),
            ),
          ],
        ),
      );
}

class _CountPill extends StatelessWidget {
  final String text;
  const _CountPill(this.text);

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: purple.withOpacity(.08),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Text(text, style: const TextStyle(color: purple, fontSize: 10, fontWeight: FontWeight.w800)),
      );
}
