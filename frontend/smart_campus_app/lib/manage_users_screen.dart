import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'api_config.dart';
import 'app_theme.dart';

class ManageUsersScreen extends StatefulWidget {
  final String adminUsername;
  const ManageUsersScreen({super.key, required this.adminUsername});

  @override
  State<ManageUsersScreen> createState() => _ManageUsersScreenState();
}

class _ManageUsersScreenState extends State<ManageUsersScreen> {
  bool loading = true;
  String? error;
  List<Map<String, dynamic>> users = [];

  @override
  void initState() {
    super.initState();
    loadUsers();
  }

  Future<void> loadUsers() async {
    if (mounted) setState(() { loading = true; error = null; });
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/api/auth/users').replace(
          queryParameters: {'requesterUsername': widget.adminUsername},
        ),
      );
      final decoded = _decode(response.body);
      if (response.statusCode != 200) {
        throw Exception(decoded['error']?.toString() ?? 'Could not load users.');
      }
      final raw = decoded['users'];
      if (mounted) {
        setState(() {
          users = raw is List
              ? raw.map((e) => Map<String, dynamic>.from(e as Map)).toList()
              : [];
        });
      }
    } catch (e) {
      if (mounted) setState(() => error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }


  Future<void> createUser() async {
    final name = TextEditingController();
    final email = TextEditingController();
    final password = TextEditingController();
    final dept = TextEditingController();
    String role = 'HEAD_STAFF';

    try {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => StatefulBuilder(
          builder: (ctx, setD) => AlertDialog(
            title: const Text('Create user account'),
            content: SizedBox(
              width: 430,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: name,
                      decoration: const InputDecoration(labelText: 'Full Name'),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: email,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: 'College Email',
                        hintText: 'name@gnits.ac.in',
                      ),
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      value: role,
                      decoration: const InputDecoration(labelText: 'Role'),
                      items: const [
                        DropdownMenuItem(value: 'HEAD_STAFF', child: Text('Head Staff')),
                        DropdownMenuItem(value: 'FACULTY', child: Text('Faculty')),
                        DropdownMenuItem(value: 'STUDENT', child: Text('Student')),
                        DropdownMenuItem(value: 'ADMIN', child: Text('Admin')),
                      ],
                      onChanged: (v) {
                        if (v != null) setD(() => role = v);
                      },
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: dept,
                      decoration: const InputDecoration(
                        labelText: 'Department',
                        hintText: 'CSE / ECE / EEE / IT',
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: password,
                      obscureText: true,
                      decoration: const InputDecoration(labelText: 'Temporary Password'),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Create'),
              ),
            ],
          ),
        ),
      );

      if (ok != true) return;

      final r = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/api/auth/users'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'requesterUsername': widget.adminUsername,
          'name': name.text.trim(),
          'email': email.text.trim(),
          'password': password.text,
          'role': role,
          'department': dept.text.trim(),
        }),
      );

      final d = _decode(r.body);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(d['message'] ?? d['error'] ?? 'Done'),
          backgroundColor: r.statusCode == 200 ? Colors.green : Colors.redAccent,
        ),
      );
      if (r.statusCode == 200) await loadUsers();
    } finally {
      name.dispose();
      email.dispose();
      password.dispose();
      dept.dispose();
    }
  }

  Future<void> deleteUser(Map<String, dynamic> user) async {
    final username = '${user['username'] ?? user['email'] ?? ''}';
                              final email = '${user['email'] ?? username}';
                              final department = '${user['department'] ?? '—'}';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete user account?'),
        content: Text(
          'This will permanently remove the account "$username". '
          'The user will no longer be able to sign in.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete account'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      final response = await http.delete(
        Uri.parse('${ApiConfig.baseUrl}/api/auth/users/${Uri.encodeComponent(username)}').replace(
          queryParameters: {'requesterUsername': widget.adminUsername},
        ),
      );
      final decoded = _decode(response.body);
      if (!mounted) return;
      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('User account deleted successfully.')),
        );
        await loadUsers();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(decoded['error']?.toString() ?? 'Could not delete the user.')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not connect to the Smart Campus server.')),
        );
      }
    }
  }

  Map<String, dynamic> _decode(String body) {
    try {
      final value = jsonDecode(body);
      return value is Map ? Map<String, dynamic>.from(value) : {};
    } catch (_) {
      return {};
    }
  }

  Color _roleColor(String role) {
    switch (role.toUpperCase()) {
      case 'ADMIN': return purple;
      case 'FACULTY': return academicBlue;
      case 'HEAD_STAFF': return const Color(0xFFB45309);
      default: return const Color(0xFF059669);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: canvas,
      child: RefreshIndicator(
        onRefresh: loadUsers,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 44),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1200),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: border),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 46,
                          height: 46,
                          decoration: BoxDecoration(
                            color: purple.withOpacity(.09),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Icon(Icons.people_alt_outlined, color: purple),
                        ),
                        const SizedBox(width: 13),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Manage Users', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: navy)),
                              SizedBox(height: 4),
                              Text('View registered accounts and remove an account when it is no longer required.', style: TextStyle(fontSize: 12, color: muted)),
                            ],
                          ),
                        ),
                        Wrap(spacing:8,children:[OutlinedButton.icon(onPressed: createUser,icon:const Icon(Icons.person_add_alt_1_rounded,size:17),label:const Text('Create User')),IconButton(onPressed: loading ? null : loadUsers, tooltip: 'Refresh users', icon: const Icon(Icons.refresh_rounded))])
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  if (error != null)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(18),
                        child: Row(
                          children: [
                            const Icon(Icons.error_outline_rounded, color: Colors.redAccent),
                            const SizedBox(width: 10),
                            Expanded(child: Text(error!, style: const TextStyle(color: Colors.redAccent))),
                            TextButton(onPressed: loadUsers, child: const Text('Retry')),
                          ],
                        ),
                      ),
                    )
                  else if (loading)
                    const Padding(padding: EdgeInsets.all(60), child: Center(child: CircularProgressIndicator()))
                  else if (users.isEmpty)
                    const Card(child: Padding(padding: EdgeInsets.all(30), child: Center(child: Text('No registered users found.', style: TextStyle(color: muted)))))
                  else
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(8),
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: DataTable(
                            columnSpacing: 34,
                            columns: const [
                              DataColumn(label: Text('NAME')),
                              DataColumn(label: Text('EMAIL')),
                              DataColumn(label: Text('DEPARTMENT')),
                              DataColumn(label: Text('ROLE')),
                              DataColumn(label: Text('CREATED')),
                              DataColumn(label: Text('ACTION')),
                            ],
                            rows: users.map((user) {
                              final role = '${user['role'] ?? ''}'.toUpperCase();
                              final username = '${user['username'] ?? user['email'] ?? ''}';
                              final email = '${user['email'] ?? username}';
                              final department = '${user['department'] ?? '—'}';
                              final isSelf = username.toLowerCase() == widget.adminUsername.toLowerCase();
                              return DataRow(cells: [
                                DataCell(Text('${user['name'] ?? '—'}', style: const TextStyle(fontWeight: FontWeight.w700))),
                                DataCell(Text(email)),
                                DataCell(Text(department)),
                                DataCell(Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                                  decoration: BoxDecoration(color: _roleColor(role).withOpacity(.09), borderRadius: BorderRadius.circular(999)),
                                  child: Text(role, style: TextStyle(color: _roleColor(role), fontSize: 9, fontWeight: FontWeight.w900)),
                                )),
                                DataCell(Text('${user['createdAt'] ?? '—'}')),
                                DataCell(
                                  IconButton(
                                    tooltip: isSelf ? 'You cannot delete your own account' : 'Delete user',
                                    onPressed: isSelf ? null : () => deleteUser(user),
                                    icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 20),
                                  ),
                                ),
                              ]);
                            }).toList(),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
