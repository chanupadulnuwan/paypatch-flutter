import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../main.dart';
import '../../models/group.dart';
import '../../widgets/app_routes.dart';
import '../../widgets/profile_sheet.dart';
import '../../widgets/search_bar.dart';
import '../../providers/auth_provider.dart';
import '../../providers/groups_provider.dart';
import '../../providers/connectivity_provider.dart';
import '../auth/login_screen.dart';
import 'group_detail_screen.dart';

class GroupsScreen extends StatefulWidget {
  const GroupsScreen({super.key});

  @override
  State<GroupsScreen> createState() => _GroupsScreenState();
}

class _GroupsScreenState extends State<GroupsScreen> {
  final _newGroupNameCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _syncGroups();
    });
  }

  @override
  void dispose() {
    _newGroupNameCtrl.dispose();
    super.dispose();
  }

  Future<void> _syncGroups() async {
    final isOnline = Provider.of<ConnectivityProvider>(context, listen: false).isOnline;
    await Provider.of<GroupsProvider>(context, listen: false).fetchGroups(isOnline: isOnline);
  }

  void _openProfileSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) {
        return ProfileSheet(
          onLogout: () {
            Navigator.pop(context);
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (_) => const LoginScreen()),
              (route) => false,
            );
          },
        );
      },
    );
  }

  String _greetingText() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  void _showCreateGroupDialog(BuildContext context, bool isOnline) {
    if (!isOnline) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cannot create groups while offline.')),
      );
      return;
    }

    _newGroupNameCtrl.clear();
    showDialog(
      context: context,
      builder: (dialogCtx) {
        return AlertDialog(
          title: const Text('Create New Group'),
          content: TextField(
            controller: _newGroupNameCtrl,
            decoration: const InputDecoration(
              hintText: 'Group Name',
              labelText: 'Name',
            ),
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                final name = _newGroupNameCtrl.text.trim();
                if (name.isNotEmpty) {
                  Navigator.pop(dialogCtx);
                  final success = await Provider.of<GroupsProvider>(context, listen: false)
                      .createGroup(name);
                  if (success && context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Group "$name" created successfully!')),
                    );
                  } else if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Failed to create group. Please try again.')),
                    );
                  }
                }
              },
              child: const Text('Create'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final auth = Provider.of<AuthProvider>(context);
    final groupsProv = Provider.of<GroupsProvider>(context);
    final conn = Provider.of<ConnectivityProvider>(context);

    final String userName = auth.user?['name'] ?? 'User';
    final greeting = _greetingText();

    const lightPageBg = Color.fromARGB(255, 245, 251, 245);
    final headerBg = isDark ? cs.surface : cs.primary;
    final headerText = isDark ? cs.onSurface : Colors.white;
    final headerSubText = isDark ? cs.onSurface.withOpacity(0.7) : Colors.white70;
    final groupCardBg = isDark ? cs.surfaceContainerHighest : lightPageBg;

    // Calculate total net balance dynamically
    final double totalBalance = groupsProv.groups.fold(0.0, (sum, g) => sum + g.balance);
    final balanceText = totalBalance >= 0
        ? '\$${totalBalance.toStringAsFixed(2)} you are owed'
        : '\$${totalBalance.abs().toStringAsFixed(2)} you owe';
    final balanceColor = totalBalance >= 0
        ? (isDark ? cs.secondary : Colors.white)
        : (isDark ? cs.error : Colors.red.shade100);

    return LayoutBuilder(
      builder: (context, constraints) {
        final isTablet = constraints.maxWidth >= 700;

        return Scaffold(
          backgroundColor: cs.surface,
          floatingActionButton: FloatingActionButton.extended(
            backgroundColor: isDark ? cs.surface : cs.primary,
            foregroundColor: isDark ? cs.primary : Colors.white,
            shape: isDark
                ? RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(color: cs.primary, width: 1.2),
                  )
                : null,
            onPressed: () => _showCreateGroupDialog(context, conn.isOnline),
            icon: Icon(Icons.add, size: isTablet ? 26 : 24),
            label: Text(
              'Create New Group',
              style: TextStyle(fontSize: isTablet ? 16 : 14),
            ),
          ),
          body: RefreshIndicator(
            onRefresh: _syncGroups,
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                // ===== OFFLINE WARNING BANNER =====
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
                            'Offline Mode — Viewing Cached Data',
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

                // ===== HEADER =====
                Container(
                  padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
                  decoration: BoxDecoration(
                    color: headerBg,
                    borderRadius: const BorderRadius.vertical(
                      bottom: Radius.circular(28),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Hello $userName!',
                                  style: TextStyle(
                                    color: headerText,
                                    fontSize: isTablet ? 26 : 20,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  greeting,
                                  style: TextStyle(
                                    color: headerSubText,
                                    fontSize: isTablet ? 16 : 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: () => _openProfileSheet(context),
                            icon: Icon(Icons.person_outline,
                                color: headerText, size: isTablet ? 26 : 24),
                            tooltip: 'Profile',
                          ),
                          IconButton(
                            onPressed: () {
                              PayPatchApp.of(context).controller.toggleTheme();
                            },
                            icon: Icon(
                              isDark
                                  ? Icons.light_mode_outlined
                                  : Icons.dark_mode_outlined,
                              color: headerText,
                              size: isTablet ? 26 : 24,
                            ),
                            tooltip: 'Theme',
                          ),
                        ],
                      ),
                      const SizedBox(height: 17),
                      Container(
                        height: isTablet ? 46 : 40,
                        decoration: BoxDecoration(
                          color: isDark
                              ? cs.surfaceContainerHighest.withOpacity(0.9)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(22),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        child: const AppSearchBar(),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // ===== BALANCE CARD =====
                Card(
                  elevation: 0,
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  color: isDark ? cs.surface : cs.secondary,
                  surfaceTintColor: Colors.transparent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                    side: BorderSide(
                      color: isDark ? cs.secondary : Colors.transparent,
                      width: isDark ? 1.2 : 0,
                    ),
                  ),
                  child: Padding(
                    padding: EdgeInsets.all(isTablet ? 20 : 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Total Balance',
                          style: TextStyle(
                            color: isDark ? cs.secondary : Colors.white70,
                            fontWeight: FontWeight.w600,
                            fontSize: isTablet ? 16 : 14,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Padding(
                          padding: const EdgeInsets.only(left: 10),
                          child: RichText(
                            text: TextSpan(
                              children: [
                                TextSpan(
                                  text: balanceText,
                                  style: TextStyle(
                                    color: balanceColor,
                                    fontSize: isTablet ? 26 : 20,
                                    fontWeight: FontWeight.w800,
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

                const SizedBox(height: 18),

                // TITLE 
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    'Your Groups',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w400,
                      fontSize: isTablet ? 28 : null,
                      color: isDark ? cs.onSurface : null,
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Loader / Dynamic Data
                groupsProv.isLoading
                    ? const Center(
                        child: Padding(
                          padding: EdgeInsets.all(24.0),
                          child: CircularProgressIndicator(),
                        ),
                      )
                    : Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: isTablet
                            ? _TabletGrid(
                                groups: groupsProv.groups,
                                cardBg: groupCardBg,
                              )
                            : _MobileList(
                                groups: groupsProv.groups,
                                cardBg: groupCardBg,
                              ),
                      ),

                const SizedBox(height: 90),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ------ MOBILE LIST 
class _MobileList extends StatelessWidget {
  final List<Group> groups;
  final Color cardBg;

  const _MobileList({required this.groups, required this.cardBg});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (groups.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(20.0),
          child: Text('No groups yet. Tap the button below to create one!'),
        ),
      );
    }

    return Column(
      children: groups.map((group) {
        final balColor = group.balance >= 0
            ? const Color.fromARGB(255, 10, 95, 13)
            : const Color.fromARGB(255, 244, 120, 54);

        return Card(
          elevation: 0,
          margin: const EdgeInsets.only(bottom: 12),
          color: cardBg,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: BorderSide(color: cs.outlineVariant),
          ),
          child: ListTile(
            leading: Hero(
              tag: group.id,
              child: CircleAvatar(
                backgroundColor:
                    isDark ? cs.primary.withOpacity(0.25) : cs.outlineVariant,
                child: Icon(
                  Icons.groups,
                  color: isDark ? cs.primary : Colors.white,
                ),
              ),
            ),
            title: Text(
              group.name,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: isDark ? cs.onSurface : null,
              ),
            ),
            subtitle: Text(
              '${group.members} members',
              style: TextStyle(
                color: isDark ? cs.onSurface.withOpacity(0.7) : null,
              ),
            ),
            trailing: Text(
              group.balance >= 0
                  ? '+\$${group.balance.toStringAsFixed(2)}'
                  : '-\$${group.balance.abs().toStringAsFixed(2)}',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: isDark
                    ? (group.balance >= 0 ? cs.primary : cs.secondary)
                    : balColor,
              ),
            ),
            onTap: () {
              Navigator.push(
                context,
                AppRoutes.slide(GroupDetailScreen(group: group)),
              );
            },
          ),
        );
      }).toList(),
    );
  }
}

// ---- TABLET GRID 
class _TabletGrid extends StatelessWidget {
  final List<Group> groups;
  final Color cardBg;

  const _TabletGrid({required this.groups, required this.cardBg});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (groups.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(20.0),
          child: Text('No groups yet. Tap the button below to create one!'),
        ),
      );
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: groups.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 14,
        mainAxisSpacing: 14,
        childAspectRatio: 3.0,
      ),
      itemBuilder: (context, i) {
        final group = groups[i];
        final balColor = group.balance >= 0
            ? const Color.fromARGB(255, 10, 95, 13)
            : const Color.fromARGB(255, 244, 120, 54);

        return Card(
          elevation: 0,
          color: cardBg,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: BorderSide(color: cs.outlineVariant),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: () {
              Navigator.push(
                context,
                AppRoutes.slide(GroupDetailScreen(group: group)),
              );
            },
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Row(
                children: [
                  Hero(
                    tag: group.id,
                    child: CircleAvatar(
                      radius: 26,
                      backgroundColor: isDark
                          ? cs.primary.withOpacity(0.25)
                          : cs.outlineVariant,
                      child: Icon(
                        Icons.groups,
                        size: 28,
                        color: isDark ? cs.primary : Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          group.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 18,
                            color: isDark ? cs.onSurface : null,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '${group.members} members',
                          style: TextStyle(
                            fontSize: 14,
                            color: isDark ? cs.onSurface.withOpacity(0.7) : null,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    group.balance >= 0
                        ? '+\$${group.balance.toStringAsFixed(2)}'
                        : '-\$${group.balance.abs().toStringAsFixed(2)}',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                      color: isDark
                          ? (group.balance >= 0 ? cs.primary : cs.secondary)
                          : balColor,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
