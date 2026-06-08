import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';

import '../../config.dart';
import '../../models/group.dart';
import '../../providers/auth_provider.dart';
import '../../providers/connectivity_provider.dart';
import '../../providers/groups_provider.dart';

class ActivityScreen extends StatefulWidget {
  const ActivityScreen({super.key});

  @override
  State<ActivityScreen> createState() => _ActivityScreenState();
}

class _ActivityScreenState extends State<ActivityScreen> {
  List<Map<String, dynamic>> _activityLogs = [];
  bool _isLoadingLogs = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _refresh());
  }

  Future<void> _refresh() async {
    final isOnline = Provider.of<ConnectivityProvider>(context, listen: false).isOnline;
    await Provider.of<GroupsProvider>(context, listen: false).fetchGroups(isOnline: isOnline);
    if (isOnline) await _fetchActivityLogs();
  }

  Future<void> _fetchActivityLogs() async {
    final token = Provider.of<AuthProvider>(context, listen: false).token;
    if (token == null) return;
    setState(() => _isLoadingLogs = true);
    try {
      final response = await http.get(
        Uri.parse('${AppConfig.baseUrl}/activity'),
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final decoded = json.decode(response.body);
        final logs = (decoded['activity'] as List? ?? [])
            .whereType<Map<String, dynamic>>()
            .toList();
        if (mounted) setState(() => _activityLogs = logs);
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _isLoadingLogs = false);
    }
  }

  IconData _iconForExpenseTitle(String title) {
    final lower = title.toLowerCase();
    if (lower.contains('lunch') || lower.contains('dinner') || lower.contains('food') || lower.contains('cafe') || lower.contains('restaurant')) return Icons.restaurant;
    if (lower.contains('fuel') || lower.contains('taxi') || lower.contains('transport') || lower.contains('flight') || lower.contains('trip')) return Icons.directions_car;
    if (lower.contains('groceries') || lower.contains('shopping') || lower.contains('market')) return Icons.shopping_cart;
    if (lower.contains('bill') || lower.contains('electricity') || lower.contains('rent') || lower.contains('water')) return Icons.electrical_services;
    return Icons.receipt_long;
  }

  IconData _iconForLogType(String type) {
    switch (type) {
      case 'settlement': return Icons.check_circle_outline;
      case 'reminder':   return Icons.notifications_outlined;
      default:           return Icons.info_outline;
    }
  }

  Color _colorForLogType(String type, ColorScheme cs) {
    switch (type) {
      case 'settlement': return const Color(0xFF4F7D6A);
      case 'reminder':   return const Color(0xFFE8AC73);
      default:           return cs.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final groupsProv = Provider.of<GroupsProvider>(context);
    final conn = Provider.of<ConnectivityProvider>(context);

    final pageBg = isDark ? cs.surface : Colors.white;
    final cardBg = isDark ? cs.surfaceContainerHighest : Colors.white;

    // Build expense activity from groups
    final List<Map<String, dynamic>> expenseItems = [];
    for (final Group group in groupsProv.groups) {
      for (final expense in group.expenses) {
        expenseItems.add({
          '_kind':        'expense',
          'id':           expense['id'],
          'title':        expense['title'] ?? 'Expense',
          'amount':       (expense['amount'] ?? 0.0).toDouble(),
          'paid_by_name': expense['paid_by_name'] ?? 'User',
          'group_name':   group.name,
          'currency':     group.currency,
          'created_at':   expense['created_at'] ?? '',
        });
      }
    }

    // Combine expense items + API logs, sort by date
    final List<Map<String, dynamic>> allItems = [
      ...expenseItems,
      ..._activityLogs.map((l) => {...l, '_kind': 'log'}),
    ];
    allItems.sort((a, b) {
      final aDate = (a['created_at'] as String?) ?? '';
      final bDate = (b['created_at'] as String?) ?? '';
      return bDate.compareTo(aDate);
    });

    return Scaffold(
      backgroundColor: pageBg,
      appBar: AppBar(
        title: const Text('Activity'),
        backgroundColor: isDark ? cs.surface : null,
        foregroundColor: isDark ? cs.onSurface : null,
        elevation: 0,
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: Column(
          children: [
            if (!conn.isOnline)
              Container(
                color: Colors.orange.shade800,
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                child: const Row(
                  children: [
                    Icon(Icons.wifi_off, color: Colors.white, size: 20),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Offline Mode — Viewing Cached Activity',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),

            if (_isLoadingLogs)
              LinearProgressIndicator(color: cs.primary, backgroundColor: cs.outlineVariant),

            Expanded(
              child: allItems.isEmpty
                  ? ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: const [
                        Padding(
                          padding: EdgeInsets.symmetric(vertical: 60, horizontal: 20),
                          child: Center(
                            child: Text(
                              'No activity yet. Add expenses or settle up to see your history here.',
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                      ],
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: allItems.length,
                      itemBuilder: (context, index) {
                        final item = allItems[index];
                        final kind = item['_kind'] as String;
                        final String rawDate = (item['created_at'] as String?) ?? '';
                        final String displayDate = rawDate.length >= 10 ? rawDate.substring(0, 10) : rawDate;

                        if (kind == 'expense') {
                          final String title    = item['title'] as String;
                          final String group    = item['group_name'] as String;
                          final String paidBy   = item['paid_by_name'] as String;
                          final double amount   = item['amount'] as double;
                          final String currency = item['currency'] as String? ?? 'LKR';

                          return _ActivityCard(
                            cardBg: cardBg,
                            cs: cs,
                            icon: _iconForExpenseTitle(title),
                            iconBg: isDark ? cs.primary.withValues(alpha: 0.25) : cs.outlineVariant,
                            iconColor: isDark ? cs.primary : Colors.white,
                            title: title,
                            subtitle: '$group • Paid by $paidBy',
                            trailing: '$currency ${amount.toStringAsFixed(2)}',
                            trailingColor: isDark ? cs.primary : cs.secondary,
                            date: displayDate,
                          );
                        } else {
                          // Activity log (reminder / settlement)
                          final String type    = item['type'] as String? ?? 'info';
                          final String message = item['message'] as String? ?? '';
                          final String? grp    = item['group_name'] as String?;
                          final logColor       = _colorForLogType(type, cs);

                          return _ActivityCard(
                            cardBg: cardBg,
                            cs: cs,
                            icon: _iconForLogType(type),
                            iconBg: logColor.withValues(alpha: 0.15),
                            iconColor: logColor,
                            title: type == 'reminder' ? 'Reminder' : type == 'settlement' ? 'Settlement' : 'Notice',
                            subtitle: message,
                            trailing: grp ?? '',
                            trailingColor: logColor,
                            date: displayDate,
                          );
                        }
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActivityCard extends StatelessWidget {
  const _ActivityCard({
    required this.cardBg,
    required this.cs,
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.trailing,
    required this.trailingColor,
    required this.date,
  });

  final Color cardBg;
  final ColorScheme cs;
  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final String title;
  final String subtitle;
  final String trailing;
  final Color trailingColor;
  final String date;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 10),
      color: cardBg,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: cs.outlineVariant),
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: iconBg,
          child: Icon(icon, color: iconColor, size: 20),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis),
            if (date.isNotEmpty)
              Text(date, style: TextStyle(fontSize: 11, color: cs.onSurface.withValues(alpha: 0.5))),
          ],
        ),
        trailing: trailing.isNotEmpty
            ? Text(
                trailing,
                style: TextStyle(fontWeight: FontWeight.bold, color: trailingColor, fontSize: 12),
              )
            : null,
        isThreeLine: date.isNotEmpty,
      ),
    );
  }
}
