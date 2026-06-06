import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';

import '../../models/group.dart';
import '../../providers/groups_provider.dart';
import '../../providers/connectivity_provider.dart';

class GroupDetailScreen extends StatefulWidget {
  final Group group;

  const GroupDetailScreen({super.key, required this.group});

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
    final isOnline = Provider.of<ConnectivityProvider>(context, listen: false).isOnline;
    await Provider.of<GroupsProvider>(context, listen: false)
        .fetchGroupDetails(widget.group.id, isOnline: isOnline);
  }

  Future<Position?> _getCurrentLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return null;

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return null;
    }
    
    if (permission == LocationPermission.deniedForever) return null;

    try {
      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.low,
        timeLimit: const Duration(seconds: 5),
      );
    } catch (_) {
      return null;
    }
  }

  void _showAddExpenseDialog(BuildContext context, bool isOnline, Map<String, dynamic>? details) {
    if (!isOnline) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cannot add expenses while offline.')),
      );
      return;
    }

    if (details == null || details['members'] == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Group members list is still loading.')),
      );
      return;
    }

    final members = details['members'] as List;
    if (members.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This group has no members.')),
      );
      return;
    }

    final titleCtrl = TextEditingController();
    final amountCtrl = TextEditingController();
    int? selectedPayerId = members.first['id'];
    XFile? capturedImage;
    Position? gpsPosition;
    bool isFetchingGps = false;

    showDialog(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            
            Future<void> captureReceipt() async {
              final picker = ImagePicker();
              try {
                final photo = await picker.pickImage(
                  source: ImageSource.camera,
                  imageQuality: 70,
                );
                if (photo != null) {
                  setDialogState(() {
                    capturedImage = photo;
                  });
                }
              } catch (_) {}
            }

            Future<void> fetchGps() async {
              setDialogState(() {
                isFetchingGps = true;
              });
              final pos = await _getCurrentLocation();
              setDialogState(() {
                gpsPosition = pos;
                isFetchingGps = false;
              });
            }

            return AlertDialog(
              title: const Text('Add Expense'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: titleCtrl,
                      decoration: const InputDecoration(labelText: 'Description', hintText: 'e.g., Dinner'),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: amountCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(labelText: 'Amount (\$)', hintText: '0.00'),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<int>(
                      initialValue: selectedPayerId,
                      decoration: const InputDecoration(labelText: 'Paid By'),
                      items: members.map((m) {
                        return DropdownMenuItem<int>(
                          value: m['id'],
                          child: Text(m['name']),
                        );
                      }).toList(),
                      onChanged: (val) {
                        setDialogState(() {
                          selectedPayerId = val;
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                    
                    // GPS SECTION
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            gpsPosition == null
                                ? 'No location attached'
                                : 'Location: ${gpsPosition!.latitude.toStringAsFixed(4)}, ${gpsPosition!.longitude.toStringAsFixed(4)}',
                            style: TextStyle(
                              fontSize: 12,
                              color: gpsPosition == null ? Colors.grey : Colors.green,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: isFetchingGps
                              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 1.5))
                              : Icon(Icons.my_location, color: Theme.of(context).colorScheme.primary),
                          onPressed: isFetchingGps ? null : fetchGps,
                          tooltip: 'Get current GPS coordinates',
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // CAMERA SECTION
                    Row(
                      children: [
                        Expanded(
                          child: capturedImage == null
                              ? const Text('No receipt attached', style: TextStyle(fontSize: 12, color: Colors.grey))
                              : Container(
                                  height: 80,
                                  decoration: BoxDecoration(
                                    border: Border.all(color: Colors.grey.shade400),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: Image.file(
                                      File(capturedImage!.path),
                                      fit: BoxFit.cover,
                                      width: double.infinity,
                                    ),
                                  ),
                                ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: Icon(Icons.camera_alt, color: Theme.of(context).colorScheme.primary),
                          onPressed: captureReceipt,
                          tooltip: 'Capture receipt picture',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogCtx),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () async {
                    final title = titleCtrl.text.trim();
                    final amtStr = amountCtrl.text.trim();
                    if (title.isEmpty || amtStr.isEmpty || selectedPayerId == null) {
                      return;
                    }
                    final amount = double.tryParse(amtStr);
                    if (amount == null || amount <= 0) return;

                    Navigator.pop(dialogCtx);

                    String? locationString;
                    if (gpsPosition != null) {
                      locationString = 'at ${gpsPosition!.latitude.toStringAsFixed(4)}, ${gpsPosition!.longitude.toStringAsFixed(4)}';
                    }

                    final success = await Provider.of<GroupsProvider>(context, listen: false).addExpense(
                      widget.group.id,
                      title,
                      amount,
                      selectedPayerId!,
                      locationName: locationString,
                      localImagePath: capturedImage?.path,
                    );

                    if (success && context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Expense added successfully!')),
                      );
                    } else if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Failed to add expense.')),
                      );
                    }
                  },
                  child: const Text('Add'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showImageDialog(BuildContext context, String path) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppBar(
              title: const Text('Receipt Details'),
              leading: IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ),
            Image.file(
              File(path),
              fit: BoxFit.contain,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final groupsProv = Provider.of<GroupsProvider>(context);
    final conn = Provider.of<ConnectivityProvider>(context);

    const lightPageBg = Color.fromARGB(255, 245, 251, 245);
    final pageBg = isDark ? cs.surface : lightPageBg;
    final headerBg = isDark ? cs.surface : cs.primary;
    final headerTitleColor = isDark ? cs.onSurface : Colors.white;
    final headerSubColor = isDark ? cs.onSurface.withOpacity(0.7) : Colors.white70;

    final details = groupsProv.selectedGroupDetails;
    final groupData = details?['group'];

    final double balance = groupData != null
        ? (groupData['your_balance'] ?? 0.0).toDouble()
        : widget.group.balance;

    final summaryText = balance >= 0
        ? 'You are owed \$${balance.toStringAsFixed(2)} overall'
        : 'You owe \$${balance.abs().toStringAsFixed(2)} overall';

    final summaryColor = balance >= 0
        ? const Color.fromARGB(255, 10, 95, 13)
        : const Color.fromARGB(255, 244, 120, 54);

    final List expenses = (groupData != null && groupData['expenses'] != null)
        ? groupData['expenses'] as List
        : [];

    return Scaffold(
      backgroundColor: pageBg,
      appBar: AppBar(
        backgroundColor: headerBg,
        foregroundColor: headerTitleColor,
        elevation: 0,
        title: const Text('Group Details'),
        actions: [
          IconButton(
            tooltip: 'Sync Details',
            onPressed: _syncDetails,
            icon: Icon(Icons.sync, color: headerTitleColor),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: isDark ? cs.surface : cs.primary,
        foregroundColor: isDark ? cs.primary : Colors.white,
        shape: isDark
            ? RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: cs.primary, width: 1.2),
              )
            : null,
        onPressed: () => _showAddExpenseDialog(context, conn.isOnline, details),
        icon: const Icon(Icons.add),
        label: const Text('Add Expense'),
      ),
      body: RefreshIndicator(
        onRefresh: _syncDetails,
        child: ListView(
          padding: EdgeInsets.zero,
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            // HEADER
            Container(
              color: headerBg,
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.group.name,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      color: headerTitleColor,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Text(
                        'Currency: ${groupData?['currency'] ?? 'LKR'}',
                        style: TextStyle(color: headerSubColor),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        '${groupData?['member_count'] ?? widget.group.members} members',
                        style: TextStyle(color: headerSubColor),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 14),

            // SUMMARY CARD
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Card(
                elevation: 0,
                surfaceTintColor: Colors.transparent,
                color: isDark ? cs.surface : lightPageBg,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                  side: BorderSide(
                    color: isDark ? cs.secondary : cs.outlineVariant,
                    width: isDark ? 1.2 : 1,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Center(
                    child: Text(
                      summaryText,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: isDark ? cs.secondary : summaryColor,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 12),

            // ACTION BUTTONS
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Expanded(
                    child: _ActionPill(
                      label: 'Settle up',
                      isDark: isDark,
                      cs: cs,
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Settle up (UI only)')),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _ActionPill(
                      label: 'Balances',
                      isDark: isDark,
                      cs: cs,
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Balances (UI only)')),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 18),

            // EXPENSE LIST TITLE
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'Expenses',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: isDark ? cs.onSurface : null,
                ),
              ),
            ),
            const SizedBox(height: 10),

            // EXPENSE LIST
            groupsProv.isLoadingDetails
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24.0),
                      child: CircularProgressIndicator(),
                    ),
                  )
                : expenses.isEmpty
                    ? const Center(
                        child: Padding(
                          padding: EdgeInsets.all(20.0),
                          child: Text('No expenses recorded yet. Add one!'),
                        ),
                      )
                    : Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Column(
                          children: expenses.map((e) {
                            final String receiptPath = e['receipt_image'] ?? '';
                            return Card(
                              elevation: 0,
                              margin: const EdgeInsets.only(bottom: 10),
                              color: isDark ? cs.surfaceContainerHighest : lightPageBg,
                              surfaceTintColor: Colors.transparent,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(18),
                                side: BorderSide(color: cs.outlineVariant),
                              ),
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: isDark ? cs.primary.withOpacity(0.25) : cs.outlineVariant,
                                  child: const Icon(Icons.receipt_long, color: Colors.white),
                                ),
                                title: Text(
                                  e['title'] ?? 'Expense',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: isDark ? cs.onSurface : null,
                                  ),
                                ),
                                subtitle: Text(
                                  'Paid by ${e['paid_by_name'] ?? 'User'}',
                                  style: TextStyle(
                                    color: isDark ? cs.onSurface.withOpacity(0.7) : null,
                                  ),
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      '\$${(e['amount'] ?? 0.0).toStringAsFixed(2)}',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w700,
                                        color: isDark ? cs.secondary : cs.primary,
                                      ),
                                    ),
                                    if (receiptPath.isNotEmpty) ...[
                                      const SizedBox(width: 8),
                                      IconButton(
                                        icon: const Icon(Icons.image_outlined, size: 20),
                                        onPressed: () => _showImageDialog(context, receiptPath),
                                        tooltip: 'View receipt photo',
                                      )
                                    ]
                                  ],
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),

            const SizedBox(height: 90),
          ],
        ),
      ),
    );
  }
}

class _ActionPill extends StatelessWidget {
  final String label;
  final bool isDark;
  final ColorScheme cs;
  final VoidCallback onTap;

  const _ActionPill({
    required this.label,
    required this.isDark,
    required this.cs,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (!isDark) {
      return FilledButton(
        style: FilledButton.styleFrom(
          backgroundColor: cs.secondary,
          foregroundColor: Colors.white,
        ),
        onPressed: onTap,
        child: Text(label),
      );
    }

    return OutlinedButton(
      style: OutlinedButton.styleFrom(
        foregroundColor: cs.secondary,
        side: BorderSide(color: cs.secondary, width: 1.2),
        backgroundColor: cs.surface,
      ),
      onPressed: onTap,
      child: Text(label),
    );
  }
}
