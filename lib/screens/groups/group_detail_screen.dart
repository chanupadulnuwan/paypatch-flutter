import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../models/group.dart';
import '../../providers/connectivity_provider.dart';
import '../../providers/groups_provider.dart';
import '../../utils/currency_utils.dart';
import '../../widgets/custom_alert.dart';

class GroupDetailScreen extends StatefulWidget {
  const GroupDetailScreen({super.key, required this.group});

  final Group group;

  @override
  State<GroupDetailScreen> createState() => _GroupDetailScreenState();
}

class _GroupDetailScreenState extends State<GroupDetailScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _syncDetails();
    });
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

  Future<void> _openMembersSheet(bool canEdit) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: (_) => _MembersSheet(
        groupId: widget.group.id,
        canEdit: canEdit,
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
        onOpenMembers: () => _openMembersSheet(true),
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

    return Scaffold(
      backgroundColor: pageBackground,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openAddExpenseDialog(details, currency, usdToLkrRate),
        backgroundColor: isDark ? cs.surface : cs.primary,
        foregroundColor: isDark ? cs.primary : Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Add Expense'),
      ),
      body: RefreshIndicator(
        onRefresh: _syncDetails,
        child: ListView(
          padding: EdgeInsets.zero,
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            _GroupHeader(
              groupId: widget.group.id,
              name: groupName,
              currency: currency,
              memberCount: memberCount,
              coverImageUrl: groupData?['cover_image_url']?.toString() ??
                  widget.group.coverImageUrl,
              coverPreset: groupData?['cover_image_preset']?.toString() ??
                  widget.group.coverImagePreset,
              profileImageUrl: groupData?['profile_image_url']?.toString() ??
                  widget.group.profileImageUrl,
              onBack: () => Navigator.pop(context),
              onSync: _syncDetails,
              onMembers: () => _openMembersSheet(canEdit),
              onEdit: canEdit ? () => _openEditGroupSheet(canEdit) : null,
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
                    Text(
                      summaryText,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: balanceValue >= 0
                            ? const Color(0xFF146B2E)
                            : const Color(0xFFCC7A29),
                      ),
                    ),
                    if (lkrApprox != null && usdToLkrRate != null) ...[
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
                    child: _InfoPill(
                      icon: Icons.people_alt_outlined,
                      label: '$memberCount members',
                      onTap: () => _openMembersSheet(canEdit),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _InfoPill(
                      icon: Icons.currency_exchange_rounded,
                      label: currency == 'USD' && usdToLkrRate != null
                          ? '1 USD = Rs. ${usdToLkrRate.toStringAsFixed(2)}'
                          : 'Currency: $currency',
                      onTap: () {},
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
                  fontWeight: FontWeight.w800,
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
                  child: const Center(
                    child: Text('No expenses recorded yet. Add one!'),
                  ),
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                child: Column(
                  children: expenses
                      .map(
                        (expense) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _ExpenseCard(
                            expense: expense,
                            currency: currency,
                            usdToLkrRate: usdToLkrRate,
                            onDelete: expense['can_delete'] == true
                                ? () => _confirmDeleteExpense(expense)
                                : null,
                            onOpenReceipt:
                                expense['receipt_image_url'] != null &&
                                        expense['receipt_image_url']
                                            .toString()
                                            .isNotEmpty
                                    ? () => _showImageDialog(
                                          expense['receipt_image_url']
                                              .toString(),
                                        )
                                    : null,
                          ),
                        ),
                      )
                      .toList(),
                ),
              ),
            const SizedBox(height: 100),
          ],
        ),
      ),
    );
  }
}

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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final topPadding = MediaQuery.of(context).padding.top;

    return Container(
      height: 270,
      decoration: BoxDecoration(
        gradient: coverImageUrl == null ? _headerGradient(coverPreset) : null,
        image: coverImageUrl != null
            ? DecorationImage(
                image: NetworkImage(coverImageUrl!),
                fit: BoxFit.cover,
              )
            : null,
      ),
      child: Container(
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
        padding: EdgeInsets.fromLTRB(18, topPadding + 12, 18, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _HeaderActionIcon(
                  icon: Icons.arrow_back_rounded,
                  onTap: onBack,
                ),
                const Spacer(),
                _HeaderActionIcon(
                  icon: Icons.group_outlined,
                  onTap: onMembers,
                ),
                const SizedBox(width: 8),
                if (onEdit != null) ...[
                  _HeaderActionIcon(
                    icon: Icons.edit_outlined,
                    onTap: onEdit!,
                  ),
                  const SizedBox(width: 8),
                ],
                _HeaderActionIcon(
                  icon: Icons.sync_rounded,
                  onTap: onSync,
                ),
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
                    backgroundImage: profileImageUrl != null
                        ? NetworkImage(profileImageUrl!)
                        : null,
                    child: profileImageUrl == null
                        ? Text(
                            name.isEmpty ? 'G' : name[0].toUpperCase(),
                            style: TextStyle(
                              color: cs.primary,
                              fontWeight: FontWeight.w800,
                              fontSize: 24,
                            ),
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
                        style: theme.textTheme.headlineMedium?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Currency: $currency   $memberCount members',
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: Colors.white.withValues(alpha: 0.84),
                        ),
                      ),
                    ],
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

class _HeaderActionIcon extends StatelessWidget {
  const _HeaderActionIcon({
    required this.icon,
    required this.onTap,
  });

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

class _InfoPill extends StatelessWidget {
  const _InfoPill({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Material(
      color: cs.surface,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: cs.outlineVariant),
          ),
          child: Row(
            children: [
              Icon(icon, color: cs.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w700,
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

class _ExpenseCard extends StatelessWidget {
  const _ExpenseCard({
    required this.expense,
    required this.currency,
    required this.usdToLkrRate,
    required this.onDelete,
    required this.onOpenReceipt,
  });

  final Map<String, dynamic> expense;
  final String currency;
  final double? usdToLkrRate;
  final VoidCallback? onDelete;
  final VoidCallback? onOpenReceipt;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final amount = (expense['amount'] as num?)?.toDouble() ?? 0;
    final amountText = formatCurrencyAmount(currency, amount);
    final lkrApprox = convertUsdToLkr(amount, usdToLkrRate, currency);

    return Container(
      decoration: BoxDecoration(
        color: theme.brightness == Brightness.dark
            ? cs.surfaceContainerHigh
            : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: cs.outlineVariant),
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
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
                  expense['title']?.toString() ?? 'Expense',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Paid by ${expense['paid_by_name'] ?? 'User'}',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: cs.onSurface.withValues(alpha: 0.72),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Added by ${expense['created_by_name'] ?? 'User'}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: cs.onSurface.withValues(alpha: 0.62),
                  ),
                ),
                if (lkrApprox != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      'Approx. Rs. ${lkrApprox.toStringAsFixed(2)}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: cs.onSurface.withValues(alpha: 0.62),
                      ),
                    ),
                  ),
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
                  color: cs.primary,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (onOpenReceipt != null)
                    IconButton(
                      icon: const Icon(Icons.image_outlined),
                      tooltip: 'View receipt',
                      onPressed: onOpenReceipt,
                    ),
                  if (onDelete != null)
                    IconButton(
                      icon: Icon(
                        Icons.delete_outline_rounded,
                        color: cs.error,
                      ),
                      tooltip: 'Delete expense',
                      onPressed: onDelete,
                    ),
                ],
              ),
            ],
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

  @override
  void initState() {
    super.initState();
    _selectedPayerId = (widget.members.first['id'] as num).toInt();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _pickReceiptImage() async {
    try {
      final file = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 72,
      );
      if (file != null && mounted) {
        setState(() => _receiptImage = file);
      }
    } catch (_) {}
  }

  Future<void> _fetchGps() async {
    setState(() => _isFetchingGps = true);
    final position = await widget.getCurrentLocation();
    if (!mounted) {
      return;
    }
    setState(() {
      _gpsPosition = position;
      _isFetchingGps = false;
    });
  }

  Future<void> _submit() async {
    final title = _titleController.text.trim();
    final amount = double.tryParse(_amountController.text.trim());

    if (title.isEmpty || amount == null || amount <= 0 || _selectedPayerId == null) {
      await showCustomAlert(
        context,
        'Please fill in a title, amount, and payer before saving.',
      );
      return;
    }

    setState(() => _isSubmitting = true);

    String? locationName;
    if (_gpsPosition != null) {
      locationName =
          'at ${_gpsPosition!.latitude.toStringAsFixed(4)}, ${_gpsPosition!.longitude.toStringAsFixed(4)}';
    }

    final provider = Provider.of<GroupsProvider>(context, listen: false);
    final success = await provider.addExpense(
      widget.groupId,
      title,
      amount,
      _selectedPayerId!,
      locationName: locationName,
      localImagePath: _receiptImage?.path,
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
      provider.errorMessage ?? 'Failed to add the expense.',
    );
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
                  const SizedBox(height: 18),
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
  });

  final String groupId;
  final bool canEdit;

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
                itemCount: members.length + (widget.canEdit ? 1 : 0),
                separatorBuilder: (context, index) =>
                    const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  if (widget.canEdit && index == members.length) {
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
                        if (widget.canEdit && member['is_owner'] != true)
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
                    child: Align(
                      alignment: Alignment.bottomLeft,
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 28,
                            backgroundColor:
                                Colors.white.withValues(alpha: 0.96),
                            backgroundImage: profileImage,
                            child: _newProfilePath == null &&
                                    groupData?['profile_image_url'] == null
                                ? Text(
                                    (groupData?['name']?.toString() ??
                                                _nameController.text)
                                            .isEmpty
                                        ? 'G'
                                        : (groupData?['name']?.toString() ??
                                                _nameController.text)[0]
                                            .toUpperCase(),
                                    style: TextStyle(
                                      color: cs.primary,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  )
                                : null,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Tap to change the cover image',
                              style: theme.textTheme.bodyLarge?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: () => _pickImage(false),
                            icon: const Icon(Icons.camera_alt_rounded),
                            color: Colors.white,
                            tooltip: 'Change profile picture',
                          ),
                        ],
                      ),
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
