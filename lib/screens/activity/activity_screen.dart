import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/groups_provider.dart';
import '../../providers/connectivity_provider.dart';

class ActivityScreen extends StatefulWidget {
  const ActivityScreen({super.key});

  @override
  State<ActivityScreen> createState() => _ActivityScreenState();
}

class _ActivityScreenState extends State<ActivityScreen> {
  Future<void> _refreshActivity() async {
    final isOnline = Provider.of<ConnectivityProvider>(context, listen: false).isOnline;
    await Provider.of<GroupsProvider>(context, listen: false).fetchGroups(isOnline: isOnline);
  }

  IconData _getCategoryIcon(String title) {
    final lower = title.toLowerCase();
    if (lower.contains('lunch') || lower.contains('dinner') || lower.contains('food') || lower.contains('cafe') || lower.contains('restaurant')) {
      return Icons.restaurant;
    }
    if (lower.contains('fuel') || lower.contains('taxi') || lower.contains('transport') || lower.contains('flight') || lower.contains('trip')) {
      return Icons.directions_car;
    }
    if (lower.contains('groceries') || lower.contains('shopping') || lower.contains('market')) {
      return Icons.shopping_cart;
    }
    if (lower.contains('bill') || lower.contains('electricity') || lower.contains('rent') || lower.contains('water')) {
      return Icons.electrical_services;
    }
    return Icons.receipt_long;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final groupsProv = Provider.of<GroupsProvider>(context);
    final conn = Provider.of<ConnectivityProvider>(context);

    const lightPageBg = Color.fromARGB(255, 245, 251, 245);
    final pageBg = isDark ? cs.surface : lightPageBg;
    final cardBg = isDark ? cs.surfaceContainerHighest : lightPageBg;

    // Collect all expenses from all groups
    final List<Map<String, dynamic>> allActivities = [];

    for (var group in groupsProv.groups) {
      for (var expense in group.expenses) {
        allActivities.add({
          'id': expense['id'],
          'title': expense['title'] ?? 'Expense',
          'amount': (expense['amount'] ?? 0.0).toDouble(),
          'paid_by_name': expense['paid_by_name'] ?? 'User',
          'group_name': group.name,
          'created_at': expense['created_at'] ?? '',
        });
      }
    }

    // Sort by created_at descending (newest first)
    allActivities.sort((a, b) {
      final aDate = a['created_at'] as String;
      final bDate = b['created_at'] as String;
      return bDate.compareTo(aDate);
    });

    return Scaffold(
      backgroundColor: pageBg,
      appBar: AppBar(
        title: const Text('Activity Log'),
        backgroundColor: isDark ? cs.surface : null,
        foregroundColor: isDark ? cs.onSurface : null,
        elevation: 0,
      ),
      body: RefreshIndicator(
        onRefresh: _refreshActivity,
        child: Column(
          children: [
            // Connection banner
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
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            // Activities list
            Expanded(
              child: allActivities.isEmpty
                  ? ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: const [
                        Padding(
                          padding: EdgeInsets.symmetric(vertical: 60.0, horizontal: 20.0),
                          child: Center(
                            child: Text(
                              'No recent activities. Add expenses in your groups to see them here!',
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                      ],
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: allActivities.length,
                      itemBuilder: (context, index) {
                        final act = allActivities[index];
                        final String title = act['title'];
                        final String groupName = act['group_name'];
                        final String paidBy = act['paid_by_name'];
                        final double amount = act['amount'];
                        final String rawDate = act['created_at'];

                        String displayDate = '';
                        if (rawDate.length >= 10) {
                          displayDate = rawDate.substring(0, 10); // YYYY-MM-DD
                        }

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
                              backgroundColor: isDark ? cs.primary.withOpacity(0.25) : cs.outlineVariant,
                              child: Icon(
                                _getCategoryIcon(title),
                                color: isDark ? cs.primary : Colors.white,
                              ),
                            ),
                            title: Text(
                              title,
                              style: const TextStyle(fontWeight: FontWeight.w700),
                            ),
                            subtitle: Text('$groupName • Paid by $paidBy • $displayDate'),
                            trailing: Text(
                              '\$${amount.toStringAsFixed(2)}',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: isDark ? cs.primary : cs.secondary,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
