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
import '../../widgets/fade_slide_item.dart';
import '../../widgets/net_image.dart';
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
  String _searchQuery = '';

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



    final headerBg = isDark ? cs.surface : cs.primary;
    final headerText = isDark ? cs.onSurface : Colors.white;
    final headerSubText = isDark
        ? cs.onSurface.withValues(alpha: 0.72)
        : Colors.white.withValues(alpha: 0.82);

    final filtered = groupsProvider.groups
        .where((g) => g.name.toLowerCase().contains(_searchQuery.toLowerCase()))
        .toList();

    return LayoutBuilder(
      builder: (context, constraints) {
        final isTablet = constraints.maxWidth >= 760;

        return Scaffold(
          backgroundColor: isDark ? cs.surface : Colors.white,
          floatingActionButton: FloatingActionButton.extended(
            backgroundColor: isDark ? cs.surface : cs.primary,
            foregroundColor: isDark ? cs.primary : Colors.white,
            onPressed: () => _showCreateGroupDialog(context, connectivity.isOnline),
            icon: const Icon(Icons.add),
            label: const Text('Create Group'),
          ),
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Fixed header (never scrolls) ──────────────────────────────
              if (!connectivity.isOnline)
                Container(
                  color: const Color(0xFFCC7A29),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: const Row(
                    children: [
                      Icon(Icons.wifi_off_rounded, color: Colors.white),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Offline mode: showing your cached group data.',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ),
                ),
              Container(
                padding: EdgeInsets.fromLTRB(18, MediaQuery.of(context).padding.top + 16, 18, 22),
                decoration: BoxDecoration(
                  color: headerBg,
                  borderRadius: const BorderRadius.vertical(bottom: Radius.circular(32)),
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
                                style: theme.textTheme.headlineSmall?.copyWith(
                                  color: headerText,
                                  fontSize: 20,
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                greeting,
                                style: theme.textTheme.bodyLarge?.copyWith(color: headerSubText),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: () => _openProfileSheet(context),
                          icon: Icon(Icons.person_outline_rounded, color: headerText),
                        ),
                        IconButton(
                          onPressed: () => PayPatchApp.themeControllerOf(context).toggleTheme(),
                          icon: Icon(
                            isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
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
                      child: AppSearchBar(
                        onChanged: (q) => setState(() => _searchQuery = q),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 16, 18, 0),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8AC73),
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Total Balance',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 6),
                      RichText(
                        text: TextSpan(
                          children: [
                            TextSpan(
                              text: 'Rs. ${normalizedBalance.abs().toStringAsFixed(2)} ',
                              style: const TextStyle(
                                fontSize: 26,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                                height: 1.1,
                              ),
                            ),
                            TextSpan(
                              text: normalizedBalance >= 0 ? 'you are owed' : 'you owe',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: normalizedBalance >= 0
                                    ? const Color(0xFF1B7A3E)
                                    : const Color(0xFFB84A00),
                                height: 1.1,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '1 USD = Rs. ${(groupsProvider.usdToLkrRate ?? 334.85).toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w400,
                          color: Colors.white.withValues(alpha: 0.85),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                child: Text(
                  'Your Groups',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // ── Only the group list scrolls ───────────────────────────────
              if (groupsProvider.isLoading)
                const Expanded(
                  child: Center(child: CircularProgressIndicator()),
                )
              else
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: _syncGroups,
                    child: filtered.isEmpty
                        ? ListView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            children: const [
                              Padding(
                                padding: EdgeInsets.all(24),
                                child: Center(
                                  child: Text('No groups yet. Create one to start tracking expenses.'),
                                ),
                              ),
                            ],
                          )
                        : isTablet
                            ? GridView.builder(
                                padding: const EdgeInsets.fromLTRB(18, 0, 18, 96),
                                itemCount: filtered.length,
                                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 2,
                                  crossAxisSpacing: 14,
                                  mainAxisSpacing: 14,
                                  childAspectRatio: 1.5,
                                ),
                                itemBuilder: (context, index) => _GroupCard(group: filtered[index]),
                              )
                            : ListView.builder(
                                padding: const EdgeInsets.fromLTRB(18, 0, 18, 96),
                                itemCount: filtered.length,
                                itemBuilder: (context, index) => FadeSlideItem(
                                  index: index,
                                  child: Padding(
                                    padding: const EdgeInsets.only(bottom: 12),
                                    child: _GroupCard(group: filtered[index]),
                                  ),
                                ),
                              ),
                  ),
                ),
            ],
          ),
        );
      },
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

    final usdApprox = convertUsdToLkr(
      group.balance.abs(),
      groupsProvider.usdToLkrRate,
      group.currency,
    );

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () {
          Navigator.push(
            context,
            AppRoutes.slide(GroupDetailScreen(group: group)),
          );
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: isDark ? cs.surfaceContainerHigh : Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: cs.outlineVariant),
            boxShadow: [
              if (!isDark)
                BoxShadow(
                  color: cs.shadow.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
            ],
          ),
          child: Row(
            children: [
              Hero(
                tag: 'group-avatar-${group.id}',
                child: NetImage(
                  url: group.profileImageUrl,
                  radius: 26,
                  fallbackText: group.name,
                  overlayIcon: group.profileImageUrl == null
                      ? Icon(Icons.people_alt_outlined, color: cs.primary, size: 24)
                      : null,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      group.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${group.members} members',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: cs.onSurface.withValues(alpha: 0.62),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    formatCurrencyAmount(group.currency, group.balance.abs()),
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: group.balance >= 0
                          ? const Color(0xFF146B2E)
                          : const Color(0xFFCC7A29),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    group.balance >= 0 ? 'you are owed' : 'you owe',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: group.balance >= 0
                          ? const Color(0xFF146B2E)
                          : const Color(0xFFCC7A29),
                    ),
                  ),
                  if (usdApprox != null)
                    Text(
                      'Rs. ${usdApprox.toStringAsFixed(0)}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: cs.onSurface.withValues(alpha: 0.55),
                      ),
                    ),
                ],
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
                              avatar: NetImage(
                                url: member['profile_photo_url']?.toString(),
                                radius: 18,
                                fallbackText: member['name']?.toString() ?? '?',
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
                            leading: NetImage(
                              url: user['profile_photo_url']?.toString(),
                              radius: 18,
                              fallbackText: user['name']?.toString() ?? '?',
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
