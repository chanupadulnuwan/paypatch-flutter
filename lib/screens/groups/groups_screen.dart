import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../main.dart';
import '../../models/group.dart';
import '../../providers/auth_provider.dart';
import '../../providers/connectivity_provider.dart';
import '../../providers/groups_provider.dart';
import '../../utils/currency_utils.dart';
import '../../widgets/app_routes.dart';
import '../../widgets/custom_alert.dart';
import '../../widgets/profile_sheet.dart';
import '../../widgets/search_bar.dart';
import '../auth/login_screen.dart';
import 'group_detail_screen.dart';

class GroupsScreen extends StatefulWidget {
  const GroupsScreen({super.key});

  @override
  State<GroupsScreen> createState() => _GroupsScreenState();
}

class _GroupsScreenState extends State<GroupsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _syncGroups();
    });
  }

  Future<void> _syncGroups() async {
    final groupsProvider =
        Provider.of<GroupsProvider>(context, listen: false);
    final isOnline =
        Provider.of<ConnectivityProvider>(context, listen: false).isOnline;

    await groupsProvider.fetchGroups(isOnline: isOnline);
    if (isOnline) {
      await groupsProvider.fetchUsdToLkrRate();
    }
  }

  void _openProfileSheet(BuildContext context) {
    showModalBottomSheet<void>(
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

  Future<void> _showCreateGroupDialog(BuildContext context, bool isOnline) async {
    if (!isOnline) {
      await showCustomAlert(
        context,
        'Group creation needs an online connection right now.',
      );
      return;
    }

    final created = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const _CreateGroupDialog(),
    );

    if (created == true && context.mounted) {
      await showCustomAlert(
        context,
        'Your new group is ready to use.',
        isSuccess: true,
      );
    }
  }

  double _toLkrAmount(Group group, double? usdToLkrRate) {
    if (group.currency.toUpperCase() == 'USD' && usdToLkrRate != null) {
      return group.balance * usdToLkrRate;
    }

    return group.balance;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final auth = Provider.of<AuthProvider>(context);
    final groupsProvider = Provider.of<GroupsProvider>(context);
    final connectivity = Provider.of<ConnectivityProvider>(context);

    final userName = auth.user?['name']?.toString() ?? 'User';
    final greeting = _greetingText();

    final normalizedBalance = groupsProvider.groups.fold<double>(
      0,
      (sum, group) => sum + _toLkrAmount(group, groupsProvider.usdToLkrRate),
    );

    final balanceText = normalizedBalance >= 0
        ? 'Rs. ${normalizedBalance.toStringAsFixed(2)} owed to you'
        : 'Rs. ${normalizedBalance.abs().toStringAsFixed(2)} you owe';

    const lightPageBg = Color(0xFFF4FAF4);
    final headerBg = isDark ? cs.surface : cs.primary;
    final headerText = isDark ? cs.onSurface : Colors.white;
    final headerSubText = isDark
        ? cs.onSurface.withValues(alpha: 0.72)
        : Colors.white.withValues(alpha: 0.82);

    return LayoutBuilder(
      builder: (context, constraints) {
        final isTablet = constraints.maxWidth >= 760;

        return Scaffold(
          backgroundColor: isDark ? cs.surface : lightPageBg,
          floatingActionButton: FloatingActionButton.extended(
            backgroundColor: isDark ? cs.surface : cs.primary,
            foregroundColor: isDark ? cs.primary : Colors.white,
            onPressed: () => _showCreateGroupDialog(context, connectivity.isOnline),
            icon: const Icon(Icons.add),
            label: const Text('Create Group'),
          ),
          body: RefreshIndicator(
            onRefresh: _syncGroups,
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                if (!connectivity.isOnline)
                  Container(
                    color: const Color(0xFFCC7A29),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: const Row(
                      children: [
                        Icon(Icons.wifi_off_rounded, color: Colors.white),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Offline mode: showing your cached group data.',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                Container(
                  padding: const EdgeInsets.fromLTRB(18, 20, 18, 22),
                  decoration: BoxDecoration(
                    color: headerBg,
                    borderRadius: const BorderRadius.vertical(
                      bottom: Radius.circular(32),
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
                                  'Hello $userName',
                                  style: theme.textTheme.headlineSmall?.copyWith(
                                    color: headerText,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  greeting,
                                  style: theme.textTheme.bodyLarge?.copyWith(
                                    color: headerSubText,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: () => _openProfileSheet(context),
                            icon: Icon(
                              Icons.person_outline_rounded,
                              color: headerText,
                            ),
                          ),
                          IconButton(
                            onPressed: () {
                            PayPatchApp.themeControllerOf(context).toggleTheme();
                            },
                            icon: Icon(
                              isDark
                                  ? Icons.light_mode_outlined
                                  : Icons.dark_mode_outlined,
                              color: headerText,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      Container(
                        height: 42,
                        decoration: BoxDecoration(
                          color: isDark
                              ? cs.surfaceContainerHighest
                              : Colors.white.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(24),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        child: const AppSearchBar(),
                      ),
                      const SizedBox(height: 18),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: isDark
                              ? cs.surfaceContainerHigh
                              : Colors.white.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: isDark
                                ? cs.outlineVariant
                                : Colors.white.withValues(alpha: 0.12),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Approx. total balance',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: headerSubText,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              balanceText,
                              style: theme.textTheme.titleLarge?.copyWith(
                                color: headerText,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            if (groupsProvider.usdToLkrRate != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Text(
                                  'USD groups converted using 1 USD = Rs. ${groupsProvider.usdToLkrRate!.toStringAsFixed(2)}',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: headerSubText,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  child: Text(
                    'Your Groups',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                if (groupsProvider.isLoading)
                  const Padding(
                    padding: EdgeInsets.all(28),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                    child: isTablet
                        ? _TabletGrid(groups: groupsProvider.groups)
                        : _MobileList(groups: groupsProvider.groups),
                  ),
                const SizedBox(height: 96),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _MobileList extends StatelessWidget {
  const _MobileList({required this.groups});

  final List<Group> groups;

  @override
  Widget build(BuildContext context) {
    if (groups.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Center(
          child: Text('No groups yet. Create one to start tracking expenses.'),
        ),
      );
    }

    return Column(
      children: groups
          .map(
            (group) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _GroupCard(group: group),
            ),
          )
          .toList(),
    );
  }
}

class _TabletGrid extends StatelessWidget {
  const _TabletGrid({required this.groups});

  final List<Group> groups;

  @override
  Widget build(BuildContext context) {
    if (groups.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Center(
          child: Text('No groups yet. Create one to start tracking expenses.'),
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
        childAspectRatio: 1.5,
      ),
      itemBuilder: (context, index) => _GroupCard(group: groups[index]),
    );
  }
}

class _GroupCard extends StatelessWidget {
  const _GroupCard({required this.group});

  final Group group;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final groupsProvider = Provider.of<GroupsProvider>(context, listen: false);

    final balanceText = group.balance >= 0
        ? 'You are owed ${formatCurrencyAmount(group.currency, group.balance)}'
        : 'You owe ${formatCurrencyAmount(group.currency, group.balance.abs())}';

    final usdApprox = convertUsdToLkr(
      group.balance.abs(),
      groupsProvider.usdToLkrRate,
      group.currency,
    );

    final coverGradient = _gradientForPreset(group.coverImagePreset);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(26),
        onTap: () {
          Navigator.push(
            context,
            AppRoutes.slide(GroupDetailScreen(group: group)),
          );
        },
        child: Container(
          decoration: BoxDecoration(
            color: isDark ? cs.surfaceContainerHigh : Colors.white,
            borderRadius: BorderRadius.circular(26),
            border: Border.all(color: cs.outlineVariant),
            boxShadow: [
              if (!isDark)
                BoxShadow(
                  color: cs.shadow.withValues(alpha: 0.06),
                  blurRadius: 18,
                  offset: const Offset(0, 12),
                ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                height: 86,
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(26),
                  ),
                  gradient: group.coverImageUrl == null ? coverGradient : null,
                  image: group.coverImageUrl != null
                      ? DecorationImage(
                          image: NetworkImage(group.coverImageUrl!),
                          fit: BoxFit.cover,
                        )
                      : null,
                ),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(26),
                    ),
                    color: Colors.black.withValues(alpha: 0.16),
                  ),
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Hero(
                        tag: 'group-avatar-${group.id}',
                        child: CircleAvatar(
                          radius: 26,
                          backgroundColor: Colors.white.withValues(alpha: 0.92),
                          backgroundImage: group.profileImageUrl != null
                              ? NetworkImage(group.profileImageUrl!)
                              : null,
                          child: group.profileImageUrl == null
                              ? Text(
                                  group.name.isEmpty
                                      ? 'G'
                                      : group.name[0].toUpperCase(),
                                  style: TextStyle(
                                    color: cs.primary,
                                    fontWeight: FontWeight.w800,
                                  ),
                                )
                              : null,
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          group.currency,
                          style: theme.textTheme.labelLarge?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      group.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(
                          Icons.people_alt_outlined,
                          size: 18,
                          color: cs.onSurface.withValues(alpha: 0.68),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '${group.members} members',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: cs.onSurface.withValues(alpha: 0.72),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Text(
                      balanceText,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: group.balance >= 0
                            ? const Color(0xFF146B2E)
                            : const Color(0xFFCC7A29),
                      ),
                    ),
                    if (usdApprox != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          'Approx. Rs. ${usdApprox.toStringAsFixed(2)}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: cs.onSurface.withValues(alpha: 0.66),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CreateGroupDialog extends StatefulWidget {
  const _CreateGroupDialog();

  @override
  State<_CreateGroupDialog> createState() => _CreateGroupDialogState();
}

class _CreateGroupDialogState extends State<_CreateGroupDialog> {
  final _nameController = TextEditingController();
  final _memberSearchController = TextEditingController();
  final List<Map<String, dynamic>> _selectedMembers = [];
  final List<Map<String, dynamic>> _searchResults = [];
  String _currency = 'LKR';
  bool _isSubmitting = false;
  bool _isSearching = false;
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _nameController.dispose();
    _memberSearchController.dispose();
    super.dispose();
  }

  void _handleSearchChanged(String value) {
    _debounce?.cancel();
    if (value.trim().length < 2) {
      setState(() {
        _searchResults.clear();
        _isSearching = false;
      });
      return;
    }

    _debounce = Timer(const Duration(milliseconds: 300), () {
      _searchMembers(value);
    });
  }

  Future<void> _searchMembers(String query) async {
    setState(() => _isSearching = true);

    final provider = Provider.of<GroupsProvider>(context, listen: false);
    final results = await provider.searchUsers(query);
    final selectedIds = _selectedMembers
        .map((member) => member['id']?.toString())
        .toSet();

    if (!mounted) {
      return;
    }

    setState(() {
      _searchResults
        ..clear()
        ..addAll(
          results.where(
            (user) => !selectedIds.contains(user['id']?.toString()),
          ),
        );
      _isSearching = false;
    });
  }

  Future<void> _submit() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      await showCustomAlert(context, 'Please enter a group name.');
      return;
    }

    setState(() => _isSubmitting = true);
    final provider = Provider.of<GroupsProvider>(context, listen: false);
    final success = await provider.createGroup(
      name: name,
      currency: _currency,
      memberIds: _selectedMembers
          .map((member) => (member['id'] as num).toInt())
          .toList(),
    );

    if (!mounted) {
      return;
    }

    setState(() => _isSubmitting = false);

    if (success) {
      Navigator.pop(context, true);
      return;
    }

    await showCustomAlert(
      context,
      provider.errorMessage ?? 'Failed to create the group.',
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: BorderRadius.circular(34),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.18),
                blurRadius: 32,
                offset: const Offset(0, 20),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(22, 24, 22, 20),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Center(
                    child: Text(
                      'Create New Group',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: cs.primary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Name',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: cs.primary,
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _nameController,
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.groups_2_outlined),
                      hintText: 'Enter group name',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(22),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'Add members',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: cs.primary,
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _memberSearchController,
                    onChanged: _handleSearchChanged,
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.person_add_alt_rounded),
                      hintText: 'Add by email or name',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(22),
                      ),
                      suffixIcon: _isSearching
                          ? const Padding(
                              padding: EdgeInsets.all(14),
                              child: SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                            )
                          : null,
                    ),
                  ),
                  if (_selectedMembers.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _selectedMembers
                          .map(
                            (member) => InputChip(
                              avatar: CircleAvatar(
                                backgroundImage:
                                    member['profile_photo_url'] != null
                                        ? NetworkImage(
                                            member['profile_photo_url'].toString(),
                                          )
                                        : null,
                                child: member['profile_photo_url'] == null
                                    ? Text(
                                        member['name']
                                                ?.toString()
                                                .substring(0, 1)
                                                .toUpperCase() ??
                                            '?',
                                      )
                                    : null,
                              ),
                              label: Text(member['name']?.toString() ?? 'User'),
                              onDeleted: () {
                                setState(() {
                                  _selectedMembers.removeWhere(
                                    (item) => item['id'] == member['id'],
                                  );
                                });
                              },
                            ),
                          )
                          .toList(),
                    ),
                  ],
                  if (_searchResults.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Container(
                      constraints: const BoxConstraints(maxHeight: 190),
                      decoration: BoxDecoration(
                        color: cs.surfaceContainerLowest,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: cs.outlineVariant),
                      ),
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: _searchResults.length,
                        separatorBuilder: (context, index) => Divider(
                          height: 1,
                          color: cs.outlineVariant,
                        ),
                        itemBuilder: (context, index) {
                          final user = _searchResults[index];
                          return ListTile(
                            leading: CircleAvatar(
                              backgroundImage: user['profile_photo_url'] != null
                                  ? NetworkImage(
                                      user['profile_photo_url'].toString(),
                                    )
                                  : null,
                              child: user['profile_photo_url'] == null
                                  ? Text(
                                      user['name']
                                              ?.toString()
                                              .substring(0, 1)
                                              .toUpperCase() ??
                                          '?',
                                    )
                                  : null,
                            ),
                            title: Text(user['name']?.toString() ?? 'User'),
                            subtitle: Text(user['email']?.toString() ?? ''),
                            onTap: () {
                              setState(() {
                                _selectedMembers.add(user);
                                _searchResults.clear();
                                _memberSearchController.clear();
                              });
                            },
                          );
                        },
                      ),
                    ),
                  ],
                  const SizedBox(height: 18),
                  Text(
                    'Select currency',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: cs.primary,
                    ),
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    initialValue: _currency,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(22),
                      ),
                    ),
                    items: supportedCurrencies
                        .map(
                          (currency) => DropdownMenuItem<String>(
                            value: currency['code'],
                            child: Text(currency['label']!),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setState(() => _currency = value);
                      }
                    },
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                          onPressed: _isSubmitting
                              ? null
                              : () => Navigator.pop(context, false),
                          child: const Text('Cancel'),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: FilledButton(
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                          onPressed: _isSubmitting ? null : _submit,
                          child: _isSubmitting
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor:
                                        AlwaysStoppedAnimation<Color>(
                                      Colors.white,
                                    ),
                                  ),
                                )
                              : const Text('Create Group'),
                        ),
                      ),
                    ],
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

Gradient _gradientForPreset(String? preset) {
  switch (preset) {
    case 'sunrise':
      return const LinearGradient(
        colors: [Color(0xFFFF512F), Color(0xFFDD2476)],
      );
    case 'ocean':
      return const LinearGradient(
        colors: [Color(0xFF2193B0), Color(0xFF6DD5ED)],
      );
    case 'deepspace':
      return const LinearGradient(
        colors: [Color(0xFF0F2027), Color(0xFF2C5364)],
      );
    case 'dusk':
      return const LinearGradient(
        colors: [Color(0xFF2C3E50), Color(0xFFFD746C)],
      );
    case 'cyberpunk':
      return const LinearGradient(
        colors: [Color(0xFFF107A3), Color(0xFF7B2CBF)],
      );
    default:
      return const LinearGradient(
        colors: [Color(0xFF0D5B3F), Color(0xFF2B7D63)],
      );
  }
}
