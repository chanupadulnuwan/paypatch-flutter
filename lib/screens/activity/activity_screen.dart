import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';

import '../../config.dart';
import '../../models/group.dart';
import '../../providers/activity_badge_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/connectivity_provider.dart';
import '../../providers/friends_provider.dart';
import '../../providers/groups_provider.dart';
import '../../screens/groups/group_detail_screen.dart';
import '../../widgets/fade_slide_item.dart';
import '../../widgets/net_image.dart';

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
    if (isOnline && mounted) {
      Provider.of<ActivityBadgeProvider>(context, listen: false).clearBadge();
    }
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

  Future<void> _respondToFriendRequest(dynamic friendshipId, bool accept) async {
    if (friendshipId == null) return;
    final token = Provider.of<AuthProvider>(context, listen: false).token;
    if (token == null) return;

    final endpoint = accept ? 'accept' : 'decline';
    try {
      await http.post(
        Uri.parse('${AppConfig.baseUrl}/friends/$friendshipId/$endpoint'),
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 10));

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(accept
            ? 'Friend request accepted!'
            : 'Friend request declined.'),
      ));
      await _refresh();
      if (accept && mounted) {
        final isOnline =
            Provider.of<ConnectivityProvider>(context, listen: false).isOnline;
        Provider.of<FriendsProvider>(context, listen: false)
            .fetchFriends(isOnline: isOnline);
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Network error. Please try again.')),
        );
      }
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
      case 'settlement':   return Icons.check_circle_outline;
      case 'reminder':     return Icons.notifications_outlined;
      case 'post_like':    return Icons.favorite_outline;
      case 'post_comment': return Icons.chat_bubble_outline;
      default:             return Icons.info_outline;
    }
  }

  Color _colorForLogType(String type, ColorScheme cs) {
    switch (type) {
      case 'settlement':   return const Color(0xFF4F7D6A);
      case 'reminder':     return const Color(0xFFE8AC73);
      case 'post_like':    return const Color(0xFFE8AC73);
      case 'post_comment': return const Color(0xFF4F7D6A);
      default:             return cs.primary;
    }
  }

  void _navigateToGroup(BuildContext context, String? groupName, List<Group> groups) {
    if (groupName == null || groupName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Group not found')),
      );
      return;
    }
    final Group? matched = groups.cast<Group?>().firstWhere(
      (g) => g?.name == groupName,
      orElse: () => null,
    );
    if (matched != null) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => GroupDetailScreen(group: matched)),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Group not found')),
      );
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

                          return FadeSlideItem(
                            index: index,
                            child: _ActivityCard(
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
                            ),
                          );
                        } else {
                          // Activity log
                          final String type    = item['type'] as String? ?? 'info';
                          final String message = item['message'] as String? ?? '';
                          final String? grp    = item['group_name'] as String?;
                          final logColor       = _colorForLogType(type, cs);

                          // Friend request card with Accept / Decline
                          if (type == 'friend_request') {
                            final friendshipId     = item['friendship_id'];
                            final friendshipStatus = item['friendship_status'] as String?;
                            final fromName         = item['from_user_name'] as String? ?? 'Someone';
                            final fromPhoto        = item['from_user_photo'] as String?;
                            return FadeSlideItem(
                              index: index,
                              child: _FriendRequestCard(
                                cardBg: cardBg,
                                cs: cs,
                                fromUserName: fromName,
                                fromUserPhoto: fromPhoto,
                                message: message,
                                date: displayDate,
                                friendshipId: friendshipId,
                                friendshipStatus: friendshipStatus,
                                onAccept: () =>
                                    _respondToFriendRequest(friendshipId, true),
                                onDecline: () =>
                                    _respondToFriendRequest(friendshipId, false),
                              ),
                            );
                          }

                          // Friend accepted notification
                          if (type == 'friend_accepted') {
                            return FadeSlideItem(
                              index: index,
                              child: _ActivityCard(
                                cardBg: cardBg,
                                cs: cs,
                                icon: Icons.check_circle_outline,
                                iconBg: const Color(0xFF4F7D6A)
                                    .withValues(alpha: 0.15),
                                iconColor: const Color(0xFF4F7D6A),
                                title: 'Friend Request Accepted',
                                subtitle: message,
                                trailing: '',
                                trailingColor: const Color(0xFF4F7D6A),
                                date: displayDate,
                              ),
                            );
                          }

                          final bool isTappable =
                              type == 'reminder' || type == 'settlement';

                          final card = FadeSlideItem(
                            index: index,
                            child: _ActivityCard(
                              cardBg: cardBg,
                              cs: cs,
                              icon: _iconForLogType(type),
                              iconBg: logColor.withValues(alpha: 0.15),
                              iconColor: logColor,
                              title: type == 'reminder'
                                  ? 'Reminder'
                                  : type == 'settlement'
                                      ? 'Settlement'
                                      : type == 'post_like'
                                          ? 'Post Liked'
                                          : type == 'post_comment'
                                              ? 'New Comment'
                                              : 'Notice',
                              subtitle: message,
                              trailing: grp ?? '',
                              trailingColor: logColor,
                              date: displayDate,
                            ),
                          );

                          if (isTappable) {
                            return GestureDetector(
                              onTap: () => _navigateToGroup(
                                  context, grp, groupsProv.groups),
                              child: card,
                            );
                          }
                          return card;
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

class _FriendRequestCard extends StatelessWidget {
  const _FriendRequestCard({
    required this.cardBg,
    required this.cs,
    required this.fromUserName,
    this.fromUserPhoto,
    required this.message,
    required this.date,
    this.friendshipId,
    this.friendshipStatus,
    required this.onAccept,
    required this.onDecline,
  });

  final Color cardBg;
  final ColorScheme cs;
  final String fromUserName;
  final String? fromUserPhoto;
  final String message;
  final String date;
  final dynamic friendshipId;
  final String? friendshipStatus;
  final VoidCallback onAccept;
  final VoidCallback onDecline;

  @override
  Widget build(BuildContext context) {
    final isPending =
        friendshipStatus == null || friendshipStatus == 'pending';

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 10),
      color: cardBg,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: cs.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 22,
              backgroundColor:
                  const Color(0xFF4F7D6A).withValues(alpha: 0.15),
              child: fromUserPhoto != null
                  ? NetImage(
                      url: fromUserPhoto,
                      radius: 22,
                      fallbackText: fromUserName,
                      fallbackColor: const Color(0xFF4F7D6A),
                    )
                  : const Icon(Icons.person_add,
                      color: Color(0xFF4F7D6A), size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Friend Request',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    message,
                    style: TextStyle(
                        fontSize: 13,
                        color: cs.onSurface.withValues(alpha: 0.7)),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (date.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        date,
                        style: TextStyle(
                            fontSize: 11,
                            color: cs.onSurface.withValues(alpha: 0.5)),
                      ),
                    ),
                  if (isPending && friendshipId != null) ...[
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF4F7D6A),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 18, vertical: 8),
                            minimumSize: const Size(0, 34),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                          ),
                          onPressed: onAccept,
                          child: const Text('Accept',
                              style: TextStyle(fontSize: 13)),
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF4F7D6A),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 18, vertical: 8),
                            minimumSize: const Size(0, 34),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                            side: const BorderSide(
                                color: Color(0xFF4F7D6A)),
                          ),
                          onPressed: onDecline,
                          child: const Text('Decline',
                              style: TextStyle(fontSize: 13)),
                        ),
                      ],
                    ),
                  ] else if (!isPending) ...[
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 3),
                      decoration: BoxDecoration(
                        color: friendshipStatus == 'accepted'
                            ? const Color(0xFF4F7D6A)
                                .withValues(alpha: 0.12)
                            : Colors.grey.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        friendshipStatus == 'accepted'
                            ? 'Accepted'
                            : 'Declined',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: friendshipStatus == 'accepted'
                              ? const Color(0xFF4F7D6A)
                              : Colors.grey,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
