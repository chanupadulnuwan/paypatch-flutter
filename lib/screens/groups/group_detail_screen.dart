import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/group.dart';
import '../../providers/connectivity_provider.dart';
import '../../providers/groups_provider.dart';
import '../../utils/currency_utils.dart';
import '../../widgets/custom_alert.dart';
import '../posts/create_post_screen.dart';

class GroupDetailScreen extends StatefulWidget {
  const GroupDetailScreen({super.key, required this.group});

  final Group group;

  @override
  State<GroupDetailScreen> createState() => _GroupDetailScreenState();
}

class _GroupDetailScreenState extends State<GroupDetailScreen> {
  int _currentUserId = 0;
  final ScrollController _scrollController = ScrollController();
  double _scrollOffset = 0;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(() {
      if (mounted) setState(() => _scrollOffset = _scrollController.offset);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _syncDetails();
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _syncDetails() async {
    final isOnline =
        Provider.of<ConnectivityProvider>(context, listen: false).isOnline;
    final groupsProvider = Provider.of<GroupsProvider>(context, listen: false);

    await groupsProvider.fetchGroupDetails(widget.group.id, isOnline: isOnline);
    if (isOnline) {
      await groupsProvider.fetchUsdToLkrRate();
    }
  }

  Future<Position?> _getCurrentLocation() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return null;
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return null;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return null;
    }

    try {
      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.low,
        timeLimit: const Duration(seconds: 5),
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> _openAddExpenseDialog(
    Map<String, dynamic>? details,
    String currency,
    double? usdToLkrRate,
  ) async {
    final isOnline =
        Provider.of<ConnectivityProvider>(context, listen: false).isOnline;
    if (!isOnline) {
      await showCustomAlert(
        context,
        'You need to be online to add a new expense.',
      );
      return;
    }

    final members = _membersFromDetails(details);
    if (members.isEmpty) {
      await showCustomAlert(
        context,
        'This group needs at least one member before adding expenses.',
      );
      return;
    }

    final created = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _AddExpenseDialog(
        groupId: widget.group.id,
        members: members,
        currency: currency,
        usdToLkrRate: usdToLkrRate,
        getCurrentLocation: _getCurrentLocation,
      ),
    );

    if (created == true && mounted) {
      await showCustomAlert(
        context,
        'Expense added successfully.',
        isSuccess: true,
      );
    }
  }

  Future<void> _openMembersSheet(bool canEdit, int currentUserId) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: (_) => _MembersSheet(
        groupId: widget.group.id,
        canEdit: canEdit,
        currentUserId: currentUserId,
      ),
    );
  }

  Future<void> _openEditGroupSheet(bool canEdit) async {
    if (!canEdit) {
      return;
    }

    final deleted = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: (_) => _EditGroupSheet(
        groupId: widget.group.id,
        onOpenMembers: () => _openMembersSheet(true, _currentUserId),
      ),
    );

    if (deleted == true && mounted) {
      Navigator.pop(context);
      await showCustomAlert(
        context,
        'Group deleted successfully.',
        isSuccess: true,
      );
    }
  }

  Future<void> _leaveGroup(String groupName) async {
    final confirmed = await showConfirmationDialog(
      context,
      title: 'Leave Group?',
      message: 'Are you sure you want to leave $groupName?',
      confirmLabel: 'Leave',
      isDestructive: true,
    );
    if (!confirmed || !mounted) return;

    final provider = Provider.of<GroupsProvider>(context, listen: false);
    final success = await provider.leaveGroup(widget.group.id);
    if (!mounted) return;

    if (success) {
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(provider.errorMessage ?? 'Failed to leave the group.')),
      );
    }
  }

  void _openSettleUpSheet({
    required List<Map<String, dynamic>> members,
    required List<Map<String, dynamic>> expenses,
    required List<Map<String, dynamic>> settlements,
    required int currentUserId,
    required String currency,
  }) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: (_) => _SettleUpSheet(
        groupId: widget.group.id,
        members: members,
        expenses: expenses,
        settlements: settlements,
        currentUserId: currentUserId,
        currency: currency,
      ),
    );
  }

  void _openBalancesSheet({
    required List<Map<String, dynamic>> members,
    required List<Map<String, dynamic>> expenses,
    required List<Map<String, dynamic>> settlements,
    required int currentUserId,
    required String currency,
  }) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: (_) => _BalancesSheet(
        members: members,
        expenses: expenses,
        settlements: settlements,
        currentUserId: currentUserId,
        currency: currency,
      ),
    );
  }

  Future<void> _confirmDeleteExpense(Map<String, dynamic> expense) async {
    final shouldDelete = await showConfirmationDialog(
      context,
      title: 'Delete expense?',
      message:
          'This will permanently remove "${expense['title'] ?? 'this expense'}" from the group.',
      confirmLabel: 'Delete',
      isDestructive: true,
    );

    if (!shouldDelete || !mounted) {
      return;
    }

    final provider = Provider.of<GroupsProvider>(context, listen: false);
    final success = await provider.deleteExpense(
      widget.group.id,
      (expense['id'] as num).toInt(),
    );

    if (!mounted) {
      return;
    }

    await showCustomAlert(
      context,
      success
          ? 'Expense deleted successfully.'
          : (provider.errorMessage ?? 'Failed to delete the expense.'),
      isSuccess: success,
    );
  }

  void _showImageDialog(String imageUrl) {
    showDialog<void>(
      context: context,
      builder: (_) => Dialog(
        insetPadding: const EdgeInsets.all(18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppBar(
              title: const Text('Receipt'),
              automaticallyImplyLeading: false,
              leading: IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ),
            Flexible(
              child: InteractiveViewer(
                child: Image.network(
                  imageUrl,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) => const Padding(
                    padding: EdgeInsets.all(24),
                    child: Text('Unable to load the receipt image.'),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Map<String, dynamic>> _membersFromDetails(Map<String, dynamic>? details) {
    final members = details?['members'];
    if (members is! List) {
      return const [];
    }

    return members
        .whereType<Map<String, dynamic>>()
        .map((member) => Map<String, dynamic>.from(member))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final groupsProvider = Provider.of<GroupsProvider>(context);
    final details = groupsProvider.selectedGroupDetails;
    final groupData = details?['group'] as Map<String, dynamic>?;
    final expenses = (groupData?['expenses'] as List? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map((expense) => Map<String, dynamic>.from(expense))
        .toList();

    final settlements = (groupData?['settlements'] as List? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map((s) => Map<String, dynamic>.from(s))
        .toList();

    final members = (details?['members'] as List? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map((m) => Map<String, dynamic>.from(m))
        .toList();
    final currentUserId = members
        .where((m) => m['is_current_user'] == true)
        .map((m) => (m['id'] as num).toInt())
        .firstOrNull ?? 0;
    if (currentUserId != 0 && currentUserId != _currentUserId) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _currentUserId = currentUserId);
      });
    }

    final groupName =
        groupData?['name']?.toString() ?? widget.group.name;
    final currency =
        groupData?['currency']?.toString() ?? widget.group.currency;
    final memberCount =
        (groupData?['member_count'] as num?)?.toInt() ?? widget.group.members;
    final canEdit = groupData?['can_edit'] == true || widget.group.canEdit;
    final balanceValue =
        (groupData?['your_balance'] as num?)?.toDouble() ?? widget.group.balance;
    final usdToLkrRate =
        (details?['meta']?['usd_lkr_rate'] as num?)?.toDouble() ??
            groupsProvider.usdToLkrRate;

    final summaryText = balanceValue >= 0
        ? 'You are owed ${formatCurrencyAmount(currency, balanceValue)} overall'
        : 'You owe ${formatCurrencyAmount(currency, balanceValue.abs())} overall';

    final lkrApprox =
        convertUsdToLkr(balanceValue.abs(), usdToLkrRate, currency);

    final pageBackground =
        isDark ? cs.surface : Colors.white;

    final coverImageUrl = groupData?['cover_image_url']?.toString() ?? widget.group.coverImageUrl;
    final coverPreset = groupData?['cover_image_preset']?.toString() ?? widget.group.coverImagePreset;
    final profileImageUrl = groupData?['profile_image_url']?.toString() ?? widget.group.profileImageUrl;

    // Header collapses after 270px (height of _GroupHeader)
    const double headerHeight = 270.0;
    const double balanceCardHeight = 130.0;
    final double scrolled = _scrollOffset.clamp(0.0, headerHeight);
    final double t = (scrolled / headerHeight).clamp(0.0, 1.0); // 0=expanded, 1=collapsed
    final topPadding = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: pageBackground,
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (canEdit)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: FloatingActionButton.extended(
                heroTag: 'sharePostFAB',
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => CreatePostScreen(
                      groupId: widget.group.id,
                      groupName: groupName,
                    ),
                    ),
                  );
                },
                backgroundColor: isDark ? cs.surface : const Color(0xFFE8AC73),
                foregroundColor: isDark ? const Color(0xFFE8AC73) : Colors.white,
                icon: const Icon(Icons.photo_camera_outlined),
                label: const Text('Share Post'),
              ),
            ),
          FloatingActionButton.extended(
            heroTag: 'addExpenseFAB',
            onPressed: () => _openAddExpenseDialog(details, currency, usdToLkrRate),
            backgroundColor: isDark ? cs.surface : cs.primary,
            foregroundColor: isDark ? cs.primary : Colors.white,
            icon: const Icon(Icons.add),
            label: const Text('Add Expense'),
          ),
        ],
      ),
      body: Stack(
        children: [
          // ── Main scrollable content ──────────────────────────────────────
          RefreshIndicator(
            onRefresh: _syncDetails,
            child: ListView(
              controller: _scrollController,
              padding: EdgeInsets.zero,
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
            _GroupHeader(
              groupId: widget.group.id,
              name: groupName,
              currency: currency,
              memberCount: memberCount,
              coverImageUrl: coverImageUrl,
              coverPreset: coverPreset,
              profileImageUrl: profileImageUrl,
              onBack: () => Navigator.pop(context),
              onSync: _syncDetails,
              onMembers: () => _openMembersSheet(canEdit, currentUserId),
              onEdit: canEdit ? () => _openEditGroupSheet(canEdit) : null,
              onLeave: !canEdit ? () => _leaveGroup(groupName) : null,
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: isDark ? cs.surfaceContainerHigh : Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: cs.outlineVariant),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (balanceValue.abs() < 0.01 && expenses.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF4F7D6A).withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: const Color(0xFF4F7D6A).withValues(alpha: 0.3)),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.check_circle_rounded, color: Color(0xFF4F7D6A), size: 18),
                            SizedBox(width: 6),
                            Text(
                              'All Settled ✓',
                              style: TextStyle(color: Color(0xFF4F7D6A), fontWeight: FontWeight.w800, fontSize: 14),
                            ),
                          ],
                        ),
                      )
                    else
                      Text(
                        summaryText,
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontSize: 19,
                          fontWeight: FontWeight.w700,
                          color: balanceValue.abs() < 0.01
                              ? cs.onSurface.withValues(alpha: 0.4)
                              : balanceValue >= 0
                                  ? const Color(0xFF146B2E)
                                  : const Color(0xFFCC7A29),
                        ),
                      ),
                    if (lkrApprox != null && usdToLkrRate != null && balanceValue.abs() >= 0.01) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Approx. Rs. ${lkrApprox.toStringAsFixed(2)} at 1 USD = Rs. ${usdToLkrRate.toStringAsFixed(2)}',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: cs.onSurface.withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: Row(
                children: [
                  Expanded(
                    child: _ActionButton(
                      label: 'Settle Up',
                      icon: Icons.handshake_outlined,
                      onTap: () => _openSettleUpSheet(
                        members: members,
                        expenses: expenses,
                        settlements: settlements,
                        currentUserId: currentUserId,
                        currency: currency,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _ActionButton(
                      label: 'Balances',
                      icon: Icons.bar_chart_rounded,
                      onTap: () => _openBalancesSheet(
                        members: members,
                        expenses: expenses,
                        settlements: settlements,
                        currentUserId: currentUserId,
                        currency: currency,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: Text(
                'Expenses',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const SizedBox(height: 12),
            if (groupsProvider.isLoadingDetails)
              const Padding(
                padding: EdgeInsets.all(30),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (expenses.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                child: Container(
                  padding: const EdgeInsets.all(26),
                  decoration: BoxDecoration(
                    color: isDark ? cs.surfaceContainerHigh : Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: cs.outlineVariant),
                  ),
                  child: const Center(child: Text('No expenses recorded yet. Add one!')),
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                child: Column(
                  children: expenses.map((expense) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _ExpenseCard(
                      expense: expense,
                      currency: currency,
                      usdToLkrRate: usdToLkrRate,
                      isSettled: balanceValue.abs() < 0.01,
                      onDelete: expense['can_delete'] == true ? () => _confirmDeleteExpense(expense) : null,
                      onOpenReceipt: expense['receipt_image_url'] != null && expense['receipt_image_url'].toString().isNotEmpty
                          ? () => _showImageDialog(expense['receipt_image_url'].toString())
                          : null,
                      onTap: () {
                        showModalBottomSheet<void>(
                          context: context,
                          isScrollControlled: true,
                          showDragHandle: true,
                          backgroundColor: Theme.of(context).colorScheme.surface,
                          builder: (_) => _ExpenseDetailSheet(
                            expense: expense,
                            currency: currency,
                            members: members,
                            onDelete: expense['can_delete'] == true ? () => _confirmDeleteExpense(expense) : null,
                            onOpenReceipt: expense['receipt_image_url'] != null && expense['receipt_image_url'].toString().isNotEmpty
                                ? () => _showImageDialog(expense['receipt_image_url'].toString())
                                : null,
                          ),
                        );
                      },
                    ),
                  )).toList(),
                ),
              ),
            const SizedBox(height: 100),
          ],
        ),
      ),

          // ── Sticky collapsed header (appears when scrolled past cover) ──
          if (t > 0)
            Positioned(
              top: 0, left: 0, right: 0,
              child: Opacity(
                opacity: t,
                child: Container(
                  color: cs.surface,
                  padding: EdgeInsets.fromLTRB(8, topPadding + 8, 8, 8),
                  child: Row(
                    children: [
                      _HeaderActionIcon(icon: Icons.arrow_back_rounded, onTap: () => Navigator.pop(context)),
                      const SizedBox(width: 10),
                      CircleAvatar(
                        radius: 16,
                        backgroundColor: cs.primaryContainer,
                        backgroundImage: profileImageUrl != null ? NetworkImage(profileImageUrl) : null,
                        child: profileImageUrl == null
                            ? Text(
                                groupName.isEmpty ? 'G' : groupName[0].toUpperCase(),
                                style: TextStyle(color: cs.onPrimaryContainer, fontWeight: FontWeight.w800, fontSize: 13),
                              )
                            : null,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          groupName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: cs.onSurface, fontWeight: FontWeight.w800, fontSize: 16),
                        ),
                      ),
                      _HeaderActionIcon(icon: Icons.sync_rounded, onTap: _syncDetails),
                    ],
                  ),
                ),
              ),
            ),

          // ── Sticky balance card (appears after cover + balance card scrolled past) ──
          if (_scrollOffset > headerHeight + balanceCardHeight)
            Positioned(
              top: topPadding + 52,
              left: 0, right: 0,
              child: AnimatedOpacity(
                opacity: ((_scrollOffset - headerHeight - balanceCardHeight) / 40).clamp(0.0, 1.0),
                duration: const Duration(milliseconds: 80),
                child: Container(
                  color: cs.surface,
                  padding: const EdgeInsets.fromLTRB(18, 8, 18, 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: balanceValue.abs() < 0.01 && expenses.isNotEmpty
                            ? Row(
                                children: [
                                  const Icon(Icons.check_circle_rounded, color: Color(0xFF4F7D6A), size: 16),
                                  const SizedBox(width: 6),
                                  const Text('All Settled ✓', style: TextStyle(color: Color(0xFF4F7D6A), fontWeight: FontWeight.w800)),
                                ],
                              )
                            : Text(
                                summaryText,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 13,
                                  color: balanceValue.abs() < 0.01
                                      ? cs.onSurface.withValues(alpha: 0.4)
                                      : balanceValue >= 0
                                          ? const Color(0xFF146B2E)
                                          : const Color(0xFFCC7A29),
                                ),
                              ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        height: 32,
                        child: FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFFE8AC73),
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          onPressed: () => _openSettleUpSheet(
                            members: members, expenses: expenses,
                            settlements: settlements, currentUserId: currentUserId, currency: currency,
                          ),
                          child: const Text('Settle Up', style: TextStyle(color: Colors.white, fontSize: 12)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ─── Group Header ─────────────────────────────────────────────────────────────
class _GroupHeader extends StatelessWidget {
  const _GroupHeader({
    required this.groupId,
    required this.name,
    required this.currency,
    required this.memberCount,
    required this.coverImageUrl,
    required this.coverPreset,
    required this.profileImageUrl,
    required this.onBack,
    required this.onSync,
    required this.onMembers,
    required this.onEdit,
    this.onLeave,
  });

  final String groupId;
  final String name;
  final String currency;
  final int memberCount;
  final String? coverImageUrl;
  final String? coverPreset;
  final String? profileImageUrl;
  final VoidCallback onBack;
  final VoidCallback onSync;
  final VoidCallback onMembers;
  final VoidCallback? onEdit;
  final VoidCallback? onLeave;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final topPadding = MediaQuery.of(context).padding.top;

    return SizedBox(
      height: 270,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Container(
            decoration: BoxDecoration(gradient: _headerGradient(coverPreset)),
          ),
          if (coverImageUrl != null)
            Image.network(
              coverImageUrl!,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stack) => const SizedBox.shrink(),
            ),
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.30),
                  Colors.black.withValues(alpha: 0.16),
                ],
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(18, topPadding + 12, 18, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _HeaderActionIcon(icon: Icons.arrow_back_rounded, onTap: onBack),
                    const Spacer(),
                    _HeaderActionIcon(icon: Icons.group_outlined, onTap: onMembers),
                    const SizedBox(width: 8),
                    if (onEdit != null) ...[
                      _HeaderActionIcon(icon: Icons.edit_outlined, onTap: onEdit!),
                      const SizedBox(width: 8),
                    ],
                    if (onLeave != null) ...[
                      _HeaderActionIcon(icon: Icons.exit_to_app_rounded, onTap: onLeave!),
                      const SizedBox(width: 8),
                    ],
                    _HeaderActionIcon(icon: Icons.sync_rounded, onTap: onSync),
                  ],
                ),
                const Spacer(),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Hero(
                      tag: 'group-avatar-$groupId',
                      child: CircleAvatar(
                        radius: 34,
                        backgroundColor: Colors.white.withValues(alpha: 0.96),
                        backgroundImage: profileImageUrl != null ? NetworkImage(profileImageUrl!) : null,
                        child: profileImageUrl == null
                            ? Text(
                                name.isEmpty ? 'G' : name[0].toUpperCase(),
                                style: TextStyle(color: cs.primary, fontWeight: FontWeight.w800, fontSize: 24),
                              )
                            : null,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            style: theme.textTheme.titleLarge?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 20,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              _CoverPill(icon: Icons.people_alt_outlined, label: '$memberCount members'),
                              const SizedBox(width: 8),
                              _CoverPill(icon: Icons.monetization_on_outlined, label: currency),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderActionIcon extends StatelessWidget {
  const _HeaderActionIcon({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.18),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Icon(icon, color: Colors.white),
        ),
      ),
    );
  }
}

// ─── Action Button ────────────────────────────────────────────────────────────
class _ActionButton extends StatelessWidget {
  const _ActionButton({required this.label, required this.icon, required this.onTap});

  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFE8AC73),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15)),
            ],
          ),
        ),
      ),
    );
  }
}

class _ExpenseCard extends StatelessWidget {
  const _ExpenseCard({
    required this.expense,
    required this.currency,
    required this.usdToLkrRate,
    required this.onDelete,
    required this.onOpenReceipt,
    required this.onTap,
    this.isSettled = false,
  });

  final Map<String, dynamic> expense;
  final String currency;
  final double? usdToLkrRate;
  final VoidCallback? onDelete;
  final VoidCallback? onOpenReceipt;
  final VoidCallback onTap;
  final bool isSettled;

  // Strip embedded "(at lat, lon)" suffix from old expense titles
  String get _cleanTitle {
    final raw = expense['title']?.toString() ?? 'Expense';
    return raw.replaceAll(RegExp(r'\s*\(at\s+[-\d.]+,\s*[-\d.]+\)$'), '').trim();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final amount = (expense['amount'] as num?)?.toDouble() ?? 0;
    final amountText = formatCurrencyAmount(currency, amount);
    final hasLocation = (expense['location'] as String?)?.isNotEmpty == true ||
        RegExp(r'\(at\s+[-\d.]+,\s*[-\d.]+\)').hasMatch(expense['title']?.toString() ?? '');
    final hasReceipt = (expense['receipt_image_url'] as String?)?.isNotEmpty == true;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: theme.brightness == Brightness.dark
              ? cs.surfaceContainerHigh
              : Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: cs.outlineVariant),
        ),
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: cs.primary.withValues(alpha: 0.14),
              child: Icon(Icons.receipt_long_rounded, color: cs.primary),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _cleanTitle,
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'Paid by ${expense['paid_by_name'] ?? 'User'}',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: cs.onSurface.withValues(alpha: 0.72),
                    ),
                  ),
                  if (hasLocation || hasReceipt) ...[
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        if (hasLocation) ...[
                          Icon(Icons.location_on_outlined, size: 13, color: cs.primary),
                          const SizedBox(width: 3),
                          Text('Location', style: TextStyle(fontSize: 11, color: cs.primary)),
                          const SizedBox(width: 10),
                        ],
                        if (hasReceipt) ...[
                          Icon(Icons.receipt_outlined, size: 13, color: cs.secondary),
                          const SizedBox(width: 3),
                          Text('Receipt', style: TextStyle(fontSize: 11, color: cs.secondary)),
                        ],
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  amountText,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: isSettled
                        ? cs.onSurface.withValues(alpha: 0.35)
                        : cs.primary,
                  ),
                ),
                if (onDelete != null) ...[
                  const SizedBox(height: 4),
                  GestureDetector(
                    onTap: onDelete,
                    child: Icon(Icons.delete_outline_rounded, color: cs.error, size: 20),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ExpenseDetailSheet extends StatelessWidget {
  const _ExpenseDetailSheet({
    required this.expense,
    required this.currency,
    required this.members,
    required this.onDelete,
    required this.onOpenReceipt,
  });

  final Map<String, dynamic> expense;
  final String currency;
  final List<Map<String, dynamic>> members;
  final VoidCallback? onDelete;
  final VoidCallback? onOpenReceipt;

  String get _cleanTitle {
    final raw = expense['title']?.toString() ?? 'Expense';
    return raw.replaceAll(RegExp(r'\s*\(at\s+[-\d.]+,\s*[-\d.]+\)$'), '').trim();
  }

  // Extract lat,lon either from dedicated field or from embedded title
  String? get _locationCoords {
    final loc = expense['location'] as String?;
    if (loc != null && loc.isNotEmpty) return loc;
    final match = RegExp(r'\(at\s+([-\d.]+),\s*([-\d.]+)\)').firstMatch(expense['title']?.toString() ?? '');
    if (match != null) return '${match.group(1)},${match.group(2)}';
    return null;
  }

  Future<void> _openInMaps(BuildContext context, String coords) async {
    final parts = coords.split(',');
    if (parts.length < 2) return;
    final lat = parts[0].trim();
    final lon = parts[1].trim();
    final uri = Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$lon');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open Maps. Please install Google Maps.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final amount = (expense['amount'] as num?)?.toDouble() ?? 0;
    final date = (expense['created_at'] as String?)?.substring(0, 10) ?? '';
    final splitType = expense['split_type'] as String? ?? 'equal';
    final splitMembers = (expense['split_members'] as List?)
            ?.whereType<Map<String, dynamic>>()
            .toList() ??
        [];
    final locationCoords = _locationCoords;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title + amount
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _cleanTitle,
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: cs.primary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          formatCurrencyAmount(currency, amount),
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF146B2E),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (onDelete != null)
                    IconButton(
                      icon: Icon(Icons.delete_outline_rounded, color: cs.error),
                      tooltip: 'Delete',
                      onPressed: () {
                        Navigator.pop(context);
                        onDelete!();
                      },
                    ),
                ],
              ),
              const SizedBox(height: 16),

              // Details rows
              _DetailRow(icon: Icons.person_outlined, label: 'Paid by', value: expense['paid_by_name'] ?? 'User', cs: cs),
              _DetailRow(icon: Icons.edit_outlined, label: 'Added by', value: expense['created_by_name'] ?? 'User', cs: cs),
              if (date.isNotEmpty)
                _DetailRow(icon: Icons.calendar_today_outlined, label: 'Date', value: date, cs: cs),

              const SizedBox(height: 16),
              Divider(color: cs.outlineVariant),
              const SizedBox(height: 12),

              // Split section
              Row(
                children: [
                  Icon(Icons.people_alt_outlined, size: 18, color: cs.primary),
                  const SizedBox(width: 8),
                  Text(
                    splitType == 'custom' ? 'Custom Split' : 'Split Equally',
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (splitMembers.isNotEmpty) ...[
                ...splitMembers.map((m) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    children: [
                      const SizedBox(width: 26),
                      Expanded(
                        child: Text(
                          m['name']?.toString() ?? 'User',
                          style: TextStyle(color: cs.onSurface.withValues(alpha: 0.8)),
                        ),
                      ),
                      Text(
                        formatCurrencyAmount(currency, (m['share'] as num?)?.toDouble() ?? 0),
                        style: TextStyle(fontWeight: FontWeight.w600, color: cs.primary),
                      ),
                    ],
                  ),
                )),
              ] else ...[
                Padding(
                  padding: const EdgeInsets.only(left: 26),
                  child: Text(
                    splitType == 'equal' ? 'Equally among all members' : 'Custom split',
                    style: TextStyle(color: cs.onSurface.withValues(alpha: 0.6)),
                  ),
                ),
              ],

              // Location
              if (locationCoords != null) ...[
                const SizedBox(height: 16),
                Divider(color: cs.outlineVariant),
                const SizedBox(height: 12),
                GestureDetector(
                  onTap: () => _openInMaps(context, locationCoords),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: cs.primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: cs.primary.withValues(alpha: 0.2)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.location_on_rounded, color: cs.primary, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Location', style: TextStyle(fontWeight: FontWeight.w700)),
                              Text(
                                locationCoords,
                                style: TextStyle(fontSize: 12, color: cs.onSurface.withValues(alpha: 0.6)),
                              ),
                            ],
                          ),
                        ),
                        Icon(Icons.open_in_new_rounded, size: 16, color: cs.primary),
                      ],
                    ),
                  ),
                ),
              ],

              // Receipt
              if (onOpenReceipt != null) ...[
                const SizedBox(height: 12),
                GestureDetector(
                  onTap: () {
                    Navigator.pop(context);
                    onOpenReceipt!();
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: cs.secondary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: cs.secondary.withValues(alpha: 0.2)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.receipt_long_outlined, color: cs.secondary, size: 20),
                        const SizedBox(width: 10),
                        const Expanded(child: Text('View Receipt', style: TextStyle(fontWeight: FontWeight.w700))),
                        Icon(Icons.chevron_right, color: cs.secondary, size: 18),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.icon, required this.label, required this.value, required this.cs});
  final IconData icon;
  final String label;
  final String value;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 16, color: cs.onSurface.withValues(alpha: 0.5)),
          const SizedBox(width: 8),
          SizedBox(
            width: 70,
            child: Text(
              label,
              style: TextStyle(fontSize: 13, color: cs.onSurface.withValues(alpha: 0.55)),
            ),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}

class _AddExpenseDialog extends StatefulWidget {
  const _AddExpenseDialog({
    required this.groupId,
    required this.members,
    required this.currency,
    required this.usdToLkrRate,
    required this.getCurrentLocation,
  });

  final String groupId;
  final List<Map<String, dynamic>> members;
  final String currency;
  final double? usdToLkrRate;
  final Future<Position?> Function() getCurrentLocation;

  @override
  State<_AddExpenseDialog> createState() => _AddExpenseDialogState();
}

class _AddExpenseDialogState extends State<_AddExpenseDialog> {
  final _titleController = TextEditingController();
  final _amountController = TextEditingController();
  final _picker = ImagePicker();

  int? _selectedPayerId;
  XFile? _receiptImage;
  Position? _gpsPosition;
  bool _isFetchingGps = false;
  bool _isSubmitting = false;
  String _splitType = 'equal';
  late Set<int> _selectedSplitMemberIds;

  @override
  void initState() {
    super.initState();
    _selectedPayerId = (widget.members.first['id'] as num).toInt();
    _selectedSplitMemberIds = widget.members.map((m) => (m['id'] as num).toInt()).toSet();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _pickReceiptImage() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt_rounded),
              title: const Text('Take a photo'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_rounded),
              title: const Text('Choose from gallery'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;
    try {
      final file = await _picker.pickImage(source: source, imageQuality: 72);
      if (file != null && mounted) {
        setState(() => _receiptImage = file);
      }
    } catch (_) {}
  }

  Future<void> _fetchGps() async {
    setState(() => _isFetchingGps = true);
    final position = await widget.getCurrentLocation();
    if (!mounted) return;
    setState(() {
      _gpsPosition = position;
      _isFetchingGps = false;
    });
    if (position == null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not get location. Check permissions.')),
      );
    }
  }

  Future<void> _submit() async {
    final isOnline = Provider.of<ConnectivityProvider>(context, listen: false).isOnline;
    if (!isOnline) {
      await showCustomAlert(context, 'You are offline. Connect to the internet to add expenses / settle up.');
      return;
    }

    final title = _titleController.text.trim();
    final amount = double.tryParse(_amountController.text.trim());

    if (title.isEmpty || amount == null || amount <= 0 || _selectedPayerId == null) {
      await showCustomAlert(context, 'Please fill in a title, amount, and payer before saving.');
      return;
    }

    if (_splitType == 'custom' && _selectedSplitMemberIds.isEmpty) {
      await showCustomAlert(context, 'Select at least one member for the custom split.');
      return;
    }

    setState(() => _isSubmitting = true);

    String? locationStr;
    if (_gpsPosition != null) {
      locationStr = '${_gpsPosition!.latitude.toStringAsFixed(6)},${_gpsPosition!.longitude.toStringAsFixed(6)}';
    }

    final provider = Provider.of<GroupsProvider>(context, listen: false);
    final success = await provider.addExpense(
      widget.groupId,
      title,
      amount,
      _selectedPayerId!,
      location: locationStr,
      splitMemberIds: _splitType == 'custom' ? _selectedSplitMemberIds.toList() : null,
      localImagePath: _receiptImage?.path,
    );

    if (!mounted) return;
    setState(() => _isSubmitting = false);

    if (success) {
      Navigator.pop(context, true);
      return;
    }
    await showCustomAlert(context, provider.errorMessage ?? 'Failed to add the expense.');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final amount = double.tryParse(_amountController.text.trim());
    final approxLkr = amount == null
        ? null
        : convertUsdToLkr(amount, widget.usdToLkrRate, widget.currency);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: BorderRadius.circular(30),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.18),
                blurRadius: 28,
                offset: const Offset(0, 18),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 22, 20, 18),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Text(
                      'Add Expense',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: cs.primary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 22),
                  TextField(
                    controller: _titleController,
                    decoration: InputDecoration(
                      labelText: 'Description',
                      hintText: 'e.g. Dinner',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _amountController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      labelText: 'Amount (${widget.currency})',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                  ),
                  if (approxLkr != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        'Approx. Rs. ${approxLkr.toStringAsFixed(2)}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: cs.onSurface.withValues(alpha: 0.64),
                        ),
                      ),
                    ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<int>(
                    initialValue: _selectedPayerId,
                    decoration: InputDecoration(
                      labelText: 'Paid by',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                    items: widget.members
                        .map(
                          (member) => DropdownMenuItem<int>(
                            value: (member['id'] as num).toInt(),
                            child: Text(member['name']?.toString() ?? 'User'),
                          ),
                        )
                        .toList(),
                    onChanged: (value) => setState(() => _selectedPayerId = value),
                  ),
                  const SizedBox(height: 12),
                  // Split section
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: cs.surfaceContainerLowest,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: cs.outlineVariant),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Expanded(
                              child: Text('Split', style: TextStyle(fontWeight: FontWeight.w700)),
                            ),
                            ChoiceChip(
                              label: const Text('Equally'),
                              selected: _splitType == 'equal',
                              onSelected: (_) => setState(() {
                                _splitType = 'equal';
                                _selectedSplitMemberIds = widget.members.map((m) => (m['id'] as num).toInt()).toSet();
                              }),
                              selectedColor: const Color(0xFF4F7D6A).withValues(alpha: 0.2),
                            ),
                            const SizedBox(width: 8),
                            ChoiceChip(
                              label: const Text('Custom'),
                              selected: _splitType == 'custom',
                              onSelected: (_) => setState(() => _splitType = 'custom'),
                              selectedColor: const Color(0xFFE8AC73).withValues(alpha: 0.3),
                            ),
                          ],
                        ),
                        if (_splitType == 'custom') ...[
                          const SizedBox(height: 10),
                          ...widget.members.map((m) {
                            final id = (m['id'] as num).toInt();
                            return CheckboxListTile(
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                              title: Text(m['name']?.toString() ?? 'User'),
                              value: _selectedSplitMemberIds.contains(id),
                              activeColor: const Color(0xFFE8AC73),
                              onChanged: (v) => setState(() {
                                if (v == true) {
                                  _selectedSplitMemberIds.add(id);
                                } else {
                                  _selectedSplitMemberIds.remove(id);
                                }
                              }),
                            );
                          }),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: cs.surfaceContainerLowest,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: cs.outlineVariant),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            _gpsPosition == null
                                ? 'No location attached yet'
                                : 'Location: ${_gpsPosition!.latitude.toStringAsFixed(4)}, ${_gpsPosition!.longitude.toStringAsFixed(4)}',
                            style: theme.textTheme.bodyMedium,
                          ),
                        ),
                        IconButton(
                          icon: _isFetchingGps
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : Icon(Icons.my_location_rounded, color: cs.primary),
                          onPressed: _isFetchingGps ? null : _fetchGps,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: cs.surfaceContainerLowest,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: cs.outlineVariant),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: _receiptImage == null
                              ? const Text('No receipt image attached')
                              : ClipRRect(
                                  borderRadius: BorderRadius.circular(16),
                                  child: Image.file(
                                    File(_receiptImage!.path),
                                    height: 84,
                                    width: double.infinity,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                        ),
                        const SizedBox(width: 10),
                        IconButton(
                          icon: Icon(Icons.camera_alt_rounded, color: cs.primary),
                          onPressed: _pickReceiptImage,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 15),
                          ),
                          onPressed: _isSubmitting
                              ? null
                              : () => Navigator.pop(context, false),
                          child: const Text('Cancel'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton(
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 15),
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
                              : const Text('Save Expense'),
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

class _MembersSheet extends StatefulWidget {
  const _MembersSheet({
    required this.groupId,
    required this.canEdit,
    required this.currentUserId,
  });

  final String groupId;
  final bool canEdit;
  final int currentUserId;

  @override
  State<_MembersSheet> createState() => _MembersSheetState();
}

class _MembersSheetState extends State<_MembersSheet> {
  final _searchController = TextEditingController();
  final List<Map<String, dynamic>> _searchResults = [];
  Timer? _debounce;
  bool _isSearching = false;
  int? _busyMemberId;

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
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
      _searchUsers(value);
    });
  }

  Future<void> _searchUsers(String query) async {
    setState(() => _isSearching = true);

    final provider = Provider.of<GroupsProvider>(context, listen: false);
    final results = await provider.searchUsers(query, groupId: widget.groupId);

    if (!mounted) {
      return;
    }

    setState(() {
      _searchResults
        ..clear()
        ..addAll(results);
      _isSearching = false;
    });
  }

  Future<void> _addMember(Map<String, dynamic> user) async {
    setState(() => _busyMemberId = (user['id'] as num).toInt());
    final provider = Provider.of<GroupsProvider>(context, listen: false);
    final success = await provider.addMember(
      widget.groupId,
      (user['id'] as num).toInt(),
    );

    if (!mounted) {
      return;
    }

    setState(() {
      _busyMemberId = null;
      if (success) {
        _searchController.clear();
        _searchResults.clear();
      }
    });

    await showCustomAlert(
      context,
      success
          ? '${user['name']} added to the group.'
          : (provider.errorMessage ?? 'Failed to add the member.'),
      isSuccess: success,
    );
  }

  Future<void> _removeMember(Map<String, dynamic> member) async {
    final shouldRemove = await showConfirmationDialog(
      context,
      title: 'Remove member?',
      message: 'Remove ${member['name']} from this group?',
      confirmLabel: 'Remove',
      isDestructive: true,
    );

    if (!shouldRemove || !mounted) {
      return;
    }

    setState(() => _busyMemberId = (member['id'] as num).toInt());
    final provider = Provider.of<GroupsProvider>(context, listen: false);
    final success = await provider.removeMember(
      widget.groupId,
      (member['id'] as num).toInt(),
    );

    if (!mounted) {
      return;
    }

    setState(() => _busyMemberId = null);

    await showCustomAlert(
      context,
      success
          ? '${member['name']} removed from the group.'
          : (provider.errorMessage ?? 'Failed to remove the member.'),
      isSuccess: success,
    );
  }

  Future<void> _leaveGroup() async {
    final confirmed = await showConfirmationDialog(
      context,
      title: 'Leave Group?',
      message: 'You will no longer be part of this group and its expenses.',
      confirmLabel: 'Leave',
      isDestructive: true,
    );
    if (!confirmed || !mounted) return;
    setState(() => _busyMemberId = -1);
    final provider = Provider.of<GroupsProvider>(context, listen: false);
    final success = await provider.leaveGroup(widget.groupId);
    if (!mounted) return;
    setState(() => _busyMemberId = null);
    if (success) {
      Navigator.pop(context);
      Navigator.pop(context);
    } else {
      await showCustomAlert(
        context,
        provider.errorMessage ?? 'Failed to leave the group.',
        isSuccess: false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final provider = Provider.of<GroupsProvider>(context);
    final members = ((provider.selectedGroupDetails?['members'] as List?) ?? const [])
        .whereType<Map<String, dynamic>>()
        .map((member) => Map<String, dynamic>.from(member))
        .toList();

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 18,
          right: 18,
          top: 8,
          bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Group Members',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
                color: cs.primary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'View everyone in the group and add someone new when needed.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: cs.onSurface.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 16),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: members.length + 1,
                separatorBuilder: (context, index) =>
                    const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  if (index == members.length) {
                    return Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: cs.surfaceContainerLowest,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: cs.outlineVariant),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          TextField(
                            controller: _searchController,
                            onChanged: _handleSearchChanged,
                            decoration: InputDecoration(
                              prefixIcon:
                                  const Icon(Icons.person_add_alt_rounded),
                              hintText: 'Add by email or name',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(18),
                              ),
                              suffixIcon: _isSearching
                                  ? const Padding(
                                      padding: EdgeInsets.all(14),
                                      child: SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      ),
                                    )
                                  : null,
                            ),
                          ),
                          if (_searchResults.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            ..._searchResults.map((user) {
                              final userId = (user['id'] as num).toInt();
                              final isBusy = _busyMemberId == userId;
                              return ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: CircleAvatar(
                                  backgroundImage:
                                      user['profile_photo_url'] != null
                                          ? NetworkImage(
                                              user['profile_photo_url']
                                                  .toString(),
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
                                subtitle:
                                    Text(user['email']?.toString() ?? ''),
                                trailing: isBusy
                                    ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : FilledButton.tonal(
                                        onPressed: () => _addMember(user),
                                        child: const Text('Add'),
                                      ),
                              );
                            }),
                          ],
                        ],
                      ),
                    );
                  }

                  final member = members[index];
                  final memberId = (member['id'] as num).toInt();
                  final isBusy = _busyMemberId == memberId;

                  return Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: cs.surfaceContainerLowest,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: cs.outlineVariant),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          backgroundImage: member['profile_photo_url'] != null
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
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      member['name']?.toString() ?? 'User',
                                      style: theme.textTheme.titleMedium
                                          ?.copyWith(
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                  if (member['is_owner'] == true) ...[
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 3,
                                      ),
                                      decoration: BoxDecoration(
                                        color: cs.primary.withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(999),
                                      ),
                                      child: Text(
                                        'Owner',
                                        style: theme.textTheme.labelSmall
                                            ?.copyWith(
                                          color: cs.primary,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                member['email']?.toString() ?? '',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: cs.onSurface.withValues(alpha: 0.68),
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (memberId == widget.currentUserId && member['is_owner'] != true)
                          _busyMemberId == -1
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : TextButton(
                                  onPressed: _leaveGroup,
                                  child: Text('Leave', style: TextStyle(color: cs.error)),
                                )
                        else if (widget.canEdit && member['is_owner'] != true && memberId != widget.currentUserId)
                          isBusy
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : IconButton(
                                  icon: Icon(
                                    Icons.person_remove_alt_1_rounded,
                                    color: cs.error,
                                  ),
                                  onPressed: () => _removeMember(member),
                                ),
                      ],
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

class _EditGroupSheet extends StatefulWidget {
  const _EditGroupSheet({
    required this.groupId,
    required this.onOpenMembers,
  });

  final String groupId;
  final VoidCallback onOpenMembers;

  @override
  State<_EditGroupSheet> createState() => _EditGroupSheetState();
}

class _EditGroupSheetState extends State<_EditGroupSheet> {
  final _nameController = TextEditingController();
  final _picker = ImagePicker();
  String _currency = 'LKR';
  String? _newCoverPath;
  String? _newProfilePath;
  bool _isInitialized = false;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_isInitialized) {
      return;
    }

    final groupData = Provider.of<GroupsProvider>(context, listen: false)
        .selectedGroupDetails?['group'] as Map<String, dynamic>?;

    _nameController.text = groupData?['name']?.toString() ?? '';
    _currency = groupData?['currency']?.toString() ?? 'LKR';
    _isInitialized = true;
  }

  Future<void> _pickImage(bool isCover) async {
    try {
      final file = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 78,
      );
      if (file == null || !mounted) {
        return;
      }

      setState(() {
        if (isCover) {
          _newCoverPath = file.path;
        } else {
          _newProfilePath = file.path;
        }
      });
    } catch (_) {}
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      await showCustomAlert(context, 'Please enter a group name.');
      return;
    }

    setState(() => _isSubmitting = true);

    final provider = Provider.of<GroupsProvider>(context, listen: false);
    final success = await provider.updateGroup(
      groupId: widget.groupId,
      name: name,
      currency: _currency,
      coverImagePath: _newCoverPath,
      profileImagePath: _newProfilePath,
    );

    if (!mounted) {
      return;
    }

    setState(() => _isSubmitting = false);

    if (success) {
      Navigator.pop(context, false);
      await showCustomAlert(
        context,
        'Group updated successfully.',
        isSuccess: true,
      );
      return;
    }

    await showCustomAlert(
      context,
      provider.errorMessage ?? 'Failed to update the group.',
    );
  }

  Future<void> _deleteGroup() async {
    final shouldDelete = await showConfirmationDialog(
      context,
      title: 'Delete group?',
      message:
          'This will permanently remove the group and all of its expenses.',
      confirmLabel: 'Delete',
      isDestructive: true,
    );

    if (!shouldDelete || !mounted) {
      return;
    }

    setState(() => _isSubmitting = true);
    final provider = Provider.of<GroupsProvider>(context, listen: false);
    final success = await provider.deleteGroup(widget.groupId);

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
      provider.errorMessage ?? 'Failed to delete the group.',
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final provider = Provider.of<GroupsProvider>(context);
    final groupData =
        provider.selectedGroupDetails?['group'] as Map<String, dynamic>?;
    final members = ((provider.selectedGroupDetails?['members'] as List?) ?? const [])
        .whereType<Map<String, dynamic>>()
        .map((member) => Map<String, dynamic>.from(member))
        .toList();
    final usdToLkrRate = provider.usdToLkrRate;
    final ImageProvider<Object>? profileImage = _newProfilePath != null
        ? FileImage(File(_newProfilePath!))
        : groupData?['profile_image_url'] != null
            ? NetworkImage(groupData!['profile_image_url'].toString())
            : null;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 18,
          right: 18,
          top: 8,
          bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Edit Group',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: cs.primary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Change the name, currency, images, or member setup for this group.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: cs.onSurface.withValues(alpha: 0.7),
                ),
              ),
              const SizedBox(height: 18),
              GestureDetector(
                onTap: () => _pickImage(true),
                child: Container(
                  height: 150,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(26),
                    gradient: _newCoverPath == null &&
                            groupData?['cover_image_url'] == null
                        ? _headerGradient(
                            groupData?['cover_image_preset']?.toString(),
                          )
                        : null,
                    image: _newCoverPath != null
                        ? DecorationImage(
                            image: FileImage(File(_newCoverPath!)),
                            fit: BoxFit.cover,
                          )
                        : groupData?['cover_image_url'] != null
                            ? DecorationImage(
                                image: NetworkImage(
                                  groupData!['cover_image_url'].toString(),
                                ),
                                fit: BoxFit.cover,
                              )
                            : null,
                  ),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(26),
                      color: Colors.black.withValues(alpha: 0.18),
                    ),
                    padding: const EdgeInsets.all(16),
                    child: Stack(
                      children: [
                        Align(
                          alignment: Alignment.bottomLeft,
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              children: [
                                GestureDetector(
                                  onTap: () => _pickImage(false),
                                  child: Stack(
                                    children: [
                                      CircleAvatar(
                                        radius: 28,
                                        backgroundColor: Colors.white.withValues(alpha: 0.96),
                                        backgroundImage: profileImage,
                                        child: _newProfilePath == null && groupData?['profile_image_url'] == null
                                            ? Text(
                                                (groupData?['name']?.toString() ?? _nameController.text).isEmpty
                                                    ? 'G'
                                                    : (groupData?['name']?.toString() ?? _nameController.text)[0].toUpperCase(),
                                                style: TextStyle(color: cs.primary, fontWeight: FontWeight.w800),
                                              )
                                            : null,
                                      ),
                                      Positioned(
                                        bottom: 0,
                                        right: 0,
                                        child: Container(
                                          padding: const EdgeInsets.all(3),
                                          decoration: const BoxDecoration(
                                            color: Color(0xFFE8AC73),
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Icon(Icons.camera_alt_rounded, size: 12, color: Colors.white),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.camera_alt_rounded, color: Colors.white, size: 32),
                              SizedBox(height: 6),
                              Text(
                                'Change Cover',
                                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              TextField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: 'Group name',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _currency,
                decoration: InputDecoration(
                  labelText: 'Currency',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
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
              if (_currency == 'USD' && usdToLkrRate != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    '1 USD = Rs. ${usdToLkrRate.toStringAsFixed(2)}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: cs.onSurface.withValues(alpha: 0.68),
                    ),
                  ),
                ),
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: cs.surfaceContainerLowest,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: cs.outlineVariant),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Members',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        FilledButton.tonal(
                          onPressed: widget.onOpenMembers,
                          child: const Text('Manage'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: members
                          .map(
                            (member) => Chip(
                              avatar: CircleAvatar(
                                backgroundImage:
                                    member['profile_photo_url'] != null
                                        ? NetworkImage(
                                            member['profile_photo_url']
                                                .toString(),
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
                              label: Text(
                                member['is_owner'] == true
                                    ? '${member['name']} (Owner)'
                                    : member['name']?.toString() ?? 'User',
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 15),
                      ),
                      onPressed:
                          _isSubmitting ? null : () => Navigator.pop(context, false),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 15),
                      ),
                      onPressed: _isSubmitting ? null : _save,
                      child: _isSubmitting
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white,
                                ),
                              ),
                            )
                          : const Text('Save Changes'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: TextButton.icon(
                  style: TextButton.styleFrom(
                    foregroundColor: cs.error,
                  ),
                  onPressed: _isSubmitting ? null : _deleteGroup,
                  icon: const Icon(Icons.delete_outline_rounded),
                  label: const Text('Delete Group'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Cover Pill ───────────────────────────────────────────────────────────────
class _CoverPill extends StatelessWidget {
  const _CoverPill({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.28),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 13),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Settle Up Sheet ──────────────────────────────────────────────────────────
class _SettleUpSheet extends StatefulWidget {
  const _SettleUpSheet({
    required this.groupId,
    required this.members,
    required this.expenses,
    required this.settlements,
    required this.currentUserId,
    required this.currency,
  });

  final String groupId;
  final List<Map<String, dynamic>> members;
  final List<Map<String, dynamic>> expenses;
  final List<Map<String, dynamic>> settlements;
  final int currentUserId;
  final String currency;

  @override
  State<_SettleUpSheet> createState() => _SettleUpSheetState();
}

class _SettleUpSheetState extends State<_SettleUpSheet> {
  final Set<int> _selectedIds = {};
  bool _isBusy = false;

  Map<int, double> get _balances {
    if (widget.members.length <= 1) return {};
    final Map<int, double> bal = {};
    for (final m in widget.members) {
      final id = (m['id'] as num).toInt();
      if (id != widget.currentUserId) bal[id] = 0.0;
    }

    // Step 1: compute raw balance using actual per-member shares from the API
    for (final exp in widget.expenses) {
      final paidBy = (exp['paid_by'] as num?)?.toInt() ?? 0;
      final splitMembers = (exp['split_members'] as List? ?? []);

      if (splitMembers.isNotEmpty) {
        if (paidBy == widget.currentUserId) {
          // currentUser paid — others who have a share owe currentUser
          for (final sm in splitMembers) {
            final uid = (sm['user_id'] as num?)?.toInt() ?? 0;
            final share = (sm['share'] as num?)?.toDouble() ?? 0.0;
            if (uid != widget.currentUserId && bal.containsKey(uid)) {
              bal[uid] = (bal[uid] ?? 0) + share;
            }
          }
        } else if (bal.containsKey(paidBy)) {
          // someone else paid — find currentUser's share, add to paidBy's credit
          for (final sm in splitMembers) {
            final uid = (sm['user_id'] as num?)?.toInt() ?? 0;
            final share = (sm['share'] as num?)?.toDouble() ?? 0.0;
            if (uid == widget.currentUserId) {
              bal[paidBy] = (bal[paidBy] ?? 0) - share;
            }
          }
        }
      } else {
        // Fallback: equal split (no share data available)
        final memberCount = widget.members.length;
        final amount = (exp['amount'] as num?)?.toDouble() ?? 0.0;
        final share = amount / memberCount;
        if (paidBy == widget.currentUserId) {
          for (final id in bal.keys) {
            bal[id] = (bal[id] ?? 0) + share;
          }
        } else if (bal.containsKey(paidBy)) {
          bal[paidBy] = (bal[paidBy] ?? 0) - share;
        }
      }
    }

    // Step 2: apply settlements
    for (final s in widget.settlements) {
      final from = (s['from_user_id'] as num?)?.toInt();
      final to   = (s['to_user_id']   as num?)?.toInt();
      final amt  = (s['amount'] as num?)?.toDouble() ?? 0.0;
      if (to == widget.currentUserId && from != null && bal.containsKey(from)) {
        bal[from] = (bal[from] ?? 0) - amt;
      } else if (from == widget.currentUserId && to != null && bal.containsKey(to)) {
        bal[to] = (bal[to] ?? 0) + amt;
      }
    }
    return bal;
  }

  String _nameOf(int userId) {
    return widget.members
            .where((m) => (m['id'] as num).toInt() == userId)
            .map((m) => m['name']?.toString() ?? 'User')
            .firstOrNull ??
        'User';
  }

  Future<void> _settleSelected() async {
    final isOnline = Provider.of<ConnectivityProvider>(context, listen: false).isOnline;
    if (!isOnline) {
      await showCustomAlert(context, 'You are offline. Connect to the internet to add expenses / settle up.');
      return;
    }

    final balances = _balances;
    final allSettled = balances.isEmpty || balances.values.every((v) => v.abs() < 0.01);
    if (allSettled) {
      await showCustomAlert(context, 'You\'re all settled up! No outstanding balances.', isSuccess: true);
      return;
    }
    if (_selectedIds.isEmpty) {
      await showCustomAlert(context, 'Select at least one person to settle with.');
      return;
    }
    setState(() => _isBusy = true);
    final provider = Provider.of<GroupsProvider>(context, listen: false);
    bool anyFail = false;
    for (final id in _selectedIds) {
      final bal = balances[id] ?? 0;
      if (bal.abs() < 0.01) continue;
      final success = await provider.settleUp(
        groupId: widget.groupId,
        fromUserId: bal > 0 ? id : widget.currentUserId,
        toUserId: bal > 0 ? widget.currentUserId : id,
        amount: bal.abs(),
      );
      if (!success) anyFail = true;
    }
    if (!mounted) return;
    setState(() => _isBusy = false);
    // Show alert first while context is still valid, then close sheet
    await showCustomAlert(
      context,
      anyFail ? (provider.errorMessage ?? 'Some settlements failed.') : 'Settled up successfully!',
      isSuccess: !anyFail,
    );
    if (mounted) Navigator.pop(context);
  }

  Future<void> _remindSelected() async {
    if (_selectedIds.isEmpty) {
      await showCustomAlert(context, 'Select at least one person to remind.');
      return;
    }
    final balances = _balances;
    final toRemind = _selectedIds.where((id) => (balances[id] ?? 0) > 0.01).toList();
    if (toRemind.isEmpty) {
      await showCustomAlert(context, 'No one in your selection owes you money.');
      return;
    }
    setState(() => _isBusy = true);
    final provider = Provider.of<GroupsProvider>(context, listen: false);
    final success = await provider.sendReminders(widget.groupId, toRemind);
    if (!mounted) return;
    setState(() => _isBusy = false);
    // Show alert first while context is still valid, then close sheet
    await showCustomAlert(
      context,
      success ? 'Reminder sent to ${toRemind.length} member(s).' : 'Failed to send reminders.',
      isSuccess: success,
    );
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final balances = _balances;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Settle Up',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
                color: const Color(0xFFE8AC73),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Select who you want to settle with or remind.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: cs.onSurface.withValues(alpha: 0.65),
              ),
            ),
            const SizedBox(height: 16),
            if (balances.isEmpty || balances.values.every((v) => v.abs() < 0.01))
              Padding(
                padding: const EdgeInsets.all(20),
                child: Center(
                  child: Column(
                    children: [
                      const Icon(Icons.check_circle_outline, color: Color(0xFF4F7D6A), size: 48),
                      const SizedBox(height: 12),
                      Text(
                        'You\'re all settled up!',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 18,
                          color: const Color(0xFF4F7D6A),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'No outstanding balances in this group.',
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                ),
              )
            else
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 320),
                child: ListView(
                  shrinkWrap: true,
                  children: balances.entries.map((entry) {
                    final memberId = entry.key;
                    final bal = entry.value;
                    final isSelected = _selectedIds.contains(memberId);
                    final isOwedByThem = bal > 0.01;
                    final isOwedByMe = bal < -0.01;
                    final isSettled = !isOwedByThem && !isOwedByMe;
                    return Opacity(
                      opacity: isSettled ? 0.45 : 1.0,
                      child: CheckboxListTile(
                        value: isSelected,
                        onChanged: isSettled ? null : (v) {
                          setState(() {
                            if (v == true) {
                              _selectedIds.add(memberId);
                            } else {
                              _selectedIds.remove(memberId);
                            }
                          });
                        },
                        title: Text(
                          _nameOf(memberId),
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: isSettled ? cs.onSurface.withValues(alpha: 0.5) : null,
                          ),
                        ),
                        subtitle: Text(
                          isOwedByThem
                              ? 'Owes you ${formatCurrencyAmount(widget.currency, bal)}'
                              : isOwedByMe
                                  ? 'You owe ${formatCurrencyAmount(widget.currency, bal.abs())}'
                                  : 'All settled',
                          style: TextStyle(
                            color: isOwedByThem
                                ? const Color(0xFF146B2E)
                                : isOwedByMe
                                    ? const Color(0xFFCC7A29)
                                    : cs.onSurface.withValues(alpha: 0.45),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        activeColor: const Color(0xFFE8AC73),
                        checkColor: Colors.white,
                      ),
                    );
                  }).toList(),
                ),
              ),
            const SizedBox(height: 16),
            if (!(balances.isEmpty || balances.values.every((v) => v.abs() < 0.01)))
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: const BorderSide(color: Color(0xFFE8AC73)),
                      foregroundColor: const Color(0xFFE8AC73),
                    ),
                    onPressed: _isBusy ? null : _remindSelected,
                    icon: const Icon(Icons.notifications_outlined),
                    label: const Text('Remind'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      backgroundColor: const Color(0xFFE8AC73),
                    ),
                    onPressed: _isBusy ? null : _settleSelected,
                    icon: _isBusy
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.handshake_outlined),
                    label: const Text('Settle Up'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Balances Sheet ───────────────────────────────────────────────────────────
class _BalancesSheet extends StatelessWidget {
  const _BalancesSheet({
    required this.members,
    required this.expenses,
    required this.settlements,
    required this.currentUserId,
    required this.currency,
  });

  final List<Map<String, dynamic>> members;
  final List<Map<String, dynamic>> expenses;
  final List<Map<String, dynamic>> settlements;
  final int currentUserId;
  final String currency;

  Map<int, double> get _balances {
    final memberCount = members.length;
    if (memberCount <= 1) return {};
    final Map<int, double> bal = {};
    for (final m in members) {
      final id = (m['id'] as num).toInt();
      if (id != currentUserId) bal[id] = 0.0;
    }
    for (final exp in expenses) {
      final paidBy = (exp['paid_by'] as num?)?.toInt() ?? 0;
      final amount = (exp['amount'] as num?)?.toDouble() ?? 0.0;
      final share = amount / memberCount;
      if (paidBy == currentUserId) {
        for (final id in bal.keys) {
          bal[id] = (bal[id] ?? 0) + share;
        }
      } else if (bal.containsKey(paidBy)) {
        bal[paidBy] = (bal[paidBy] ?? 0) - share;
      }
    }
    for (final s in settlements) {
      final from = (s['from_user_id'] as num?)?.toInt();
      final to   = (s['to_user_id']   as num?)?.toInt();
      final amt  = (s['amount'] as num?)?.toDouble() ?? 0.0;
      if (to == currentUserId && from != null && bal.containsKey(from)) {
        bal[from] = (bal[from] ?? 0) - amt;
      } else if (from == currentUserId && to != null && bal.containsKey(to)) {
        bal[to] = (bal[to] ?? 0) + amt;
      }
    }
    return bal;
  }

  String _nameOf(int userId) {
    return members
            .where((m) => (m['id'] as num).toInt() == userId)
            .map((m) => m['name']?.toString() ?? 'User')
            .firstOrNull ??
        'User';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final balances = _balances;
    final maxAbs = balances.values.fold(0.0, (m, v) => v.abs() > m ? v.abs() : m);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Balances',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
                color: cs.primary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Your net balance with each member based on expenses.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: cs.onSurface.withValues(alpha: 0.65),
              ),
            ),
            const SizedBox(height: 16),
            if (balances.isEmpty)
              const Padding(
                padding: EdgeInsets.all(20),
                child: Center(child: Text('No expenses to calculate balances from.')),
              )
            else
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 360),
                child: ListView(
                  shrinkWrap: true,
                  children: balances.entries.map((entry) {
                    final memberId = entry.key;
                    final bal = entry.value;
                    final isOwed = bal > 0.01;
                    final fraction = maxAbs > 0 ? bal.abs() / maxAbs : 0.0;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  _nameOf(memberId),
                                  style: const TextStyle(fontWeight: FontWeight.w700),
                                ),
                              ),
                              Text(
                                bal.abs() < 0.01
                                    ? 'Settled'
                                    : isOwed
                                        ? '+${formatCurrencyAmount(currency, bal)}'
                                        : '-${formatCurrencyAmount(currency, bal.abs())}',
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  color: bal.abs() < 0.01
                                      ? cs.onSurface.withValues(alpha: 0.45)
                                      : isOwed
                                          ? const Color(0xFF146B2E)
                                          : const Color(0xFFCC7A29),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(999),
                            child: LinearProgressIndicator(
                              value: fraction,
                              minHeight: 8,
                              backgroundColor: cs.outlineVariant.withValues(alpha: 0.4),
                              valueColor: AlwaysStoppedAnimation<Color>(
                                bal.abs() < 0.01
                                    ? cs.outlineVariant
                                    : isOwed
                                        ? const Color(0xFF146B2E)
                                        : const Color(0xFFCC7A29),
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            isOwed
                                ? '${_nameOf(memberId)} owes you'
                                : bal.abs() < 0.01
                                    ? 'All settled up'
                                    : 'You owe ${_nameOf(memberId)}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: cs.onSurface.withValues(alpha: 0.6),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

Gradient _headerGradient(String? preset) {
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
        colors: [Color(0xFF0C5C41), Color(0xFF2C7E64)],
      );
  }
}
