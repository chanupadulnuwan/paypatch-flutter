import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/connectivity_provider.dart';
import '../../providers/friends_provider.dart';
import '../../widgets/custom_alert.dart';

class FriendsScreen extends StatefulWidget {
  const FriendsScreen({super.key});

  @override
  State<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends State<FriendsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _syncFriends();
    });
  }

  Future<void> _syncFriends() async {
    final isOnline = Provider.of<ConnectivityProvider>(context, listen: false).isOnline;
    await Provider.of<FriendsProvider>(context, listen: false).fetchFriends(isOnline: isOnline);
  }

  void _showContactsSheet(BuildContext context) {
    Provider.of<FriendsProvider>(context, listen: false).fetchPhoneContacts();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: (sheetCtx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.75,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          expand: false,
          builder: (_, scrollController) {
            return Consumer<FriendsProvider>(
              builder: (ctx, prov, _) {
                final cs = Theme.of(ctx).colorScheme;

                Widget body;
                if (prov.isLoadingContacts) {
                  body = Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const CircularProgressIndicator(),
                      const SizedBox(height: 12),
                      Text('Loading contacts...', style: TextStyle(color: cs.onSurface.withValues(alpha: 0.6))),
                    ],
                  );
                } else if (prov.contactsPermissionDenied) {
                  body = const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        'Contacts permission denied.\nPlease allow contacts access in app settings.',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                } else if (prov.contacts.isEmpty) {
                  body = const Center(child: Text('No contacts found on this device.'));
                } else {
                  // Sort: PayPatch users first
                  final sorted = [...prov.contacts];
                  sorted.sort((a, b) {
                    final aMatch = prov.getMatchedUser(a) != null ? 0 : 1;
                    final bMatch = prov.getMatchedUser(b) != null ? 0 : 1;
                    return aMatch.compareTo(bMatch);
                  });

                  final paypatchCount = sorted.where((c) => prov.getMatchedUser(c) != null).length;

                  body = Column(
                    children: [
                      if (prov.isMatchingContacts)
                        LinearProgressIndicator(color: cs.primary, backgroundColor: cs.outlineVariant),
                      if (paypatchCount > 0)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              color: const Color(0xFF4F7D6A).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.check_circle_outline, color: Color(0xFF4F7D6A), size: 18),
                                const SizedBox(width: 8),
                                Text(
                                  '$paypatchCount contact${paypatchCount > 1 ? 's' : ''} already on PayPatch',
                                  style: const TextStyle(
                                    color: Color(0xFF4F7D6A),
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      Expanded(
                        child: ListView.builder(
                          controller: scrollController,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          itemCount: sorted.length,
                          itemBuilder: (ctx2, i) {
                            final c = sorted[i];
                            final name = c.displayName ?? 'Unknown';
                            final phoneNum = (c.phones != null && c.phones!.isNotEmpty)
                                ? (c.phones!.first.value ?? '')
                                : '';
                            final matched = prov.getMatchedUser(c);
                            final isOnPayPatch = matched != null;

                            return Card(
                              elevation: 0,
                              margin: const EdgeInsets.only(bottom: 8),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                                side: BorderSide(
                                  color: isOnPayPatch
                                      ? const Color(0xFF4F7D6A).withValues(alpha: 0.4)
                                      : cs.outlineVariant,
                                ),
                              ),
                              color: isOnPayPatch
                                  ? const Color(0xFF4F7D6A).withValues(alpha: 0.05)
                                  : cs.surface,
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: isOnPayPatch
                                      ? const Color(0xFF4F7D6A).withValues(alpha: 0.15)
                                      : cs.outlineVariant.withValues(alpha: 0.4),
                                  backgroundImage: (isOnPayPatch && matched['profile_photo_url'] != null)
                                      ? NetworkImage(matched['profile_photo_url'].toString())
                                      : null,
                                  child: (isOnPayPatch && matched['profile_photo_url'] == null) || !isOnPayPatch
                                      ? Text(
                                          name.isNotEmpty ? name[0].toUpperCase() : '?',
                                          style: TextStyle(
                                            color: isOnPayPatch ? const Color(0xFF4F7D6A) : cs.onSurface,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        )
                                      : null,
                                ),
                                title: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        isOnPayPatch ? (matched['name'] as String? ?? name) : name,
                                        style: const TextStyle(fontWeight: FontWeight.w700),
                                      ),
                                    ),
                                    if (isOnPayPatch)
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF4F7D6A),
                                          borderRadius: BorderRadius.circular(20),
                                        ),
                                        child: const Text(
                                          'PayPatch',
                                          style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700),
                                        ),
                                      ),
                                  ],
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(phoneNum, style: TextStyle(color: cs.onSurface.withValues(alpha: 0.6), fontSize: 12)),
                                    if (isOnPayPatch && matched['email'] != null)
                                      Text(
                                        matched['email'].toString(),
                                        style: const TextStyle(fontSize: 11, color: Color(0xFF4F7D6A)),
                                      ),
                                  ],
                                ),
                                trailing: isOnPayPatch
                                    ? FilledButton(
                                        style: FilledButton.styleFrom(
                                          backgroundColor: const Color(0xFF4F7D6A),
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(horizontal: 14),
                                          minimumSize: const Size(0, 36),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                        ),
                                        onPressed: () {
                                          Navigator.pop(sheetCtx);
                                          showCustomAlert(
                                            context,
                                            '${matched['name']} is already on PayPatch! Add them to a group to start splitting.',
                                            isSuccess: true,
                                          );
                                        },
                                        child: const Text('Add'),
                                      )
                                    : OutlinedButton(
                                        style: OutlinedButton.styleFrom(
                                          padding: const EdgeInsets.symmetric(horizontal: 12),
                                          minimumSize: const Size(0, 36),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                        ),
                                        onPressed: () {
                                          Navigator.pop(sheetCtx);
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(content: Text('Invite sent to $name!')),
                                          );
                                        },
                                        child: const Text('Invite'),
                                      ),
                                isThreeLine: matched != null && matched['email'] != null,
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  );
                }

                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                      child: Row(
                        children: [
                          Text(
                            'Add Friends',
                            style: Theme.of(ctx).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                          ),
                          const Spacer(),
                          if (prov.contacts.isNotEmpty && !prov.isLoadingContacts)
                            Text(
                              '${prov.contacts.length} contacts',
                              style: TextStyle(color: cs.onSurface.withValues(alpha: 0.5), fontSize: 13),
                            ),
                        ],
                      ),
                    ),
                    Expanded(child: body),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final friendsProv = Provider.of<FriendsProvider>(context);
    final conn = Provider.of<ConnectivityProvider>(context);

    final pageBg = isDark ? cs.surface : Colors.white;
    final cardBg = isDark ? cs.surfaceContainerHighest : Colors.white;

    return Scaffold(
      backgroundColor: pageBg,
      appBar: AppBar(
        title: const Text('Friends'),
        backgroundColor: isDark ? cs.surface : null,
        foregroundColor: isDark ? cs.onSurface : null,
        elevation: 0,
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: cs.primary,
        foregroundColor: Colors.white,
        onPressed: () => _showContactsSheet(context),
        child: const Icon(Icons.person_add),
      ),
      body: RefreshIndicator(
        onRefresh: _syncFriends,
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
                        'Offline Mode — Viewing Cached Friends',
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

            // Friends list
            Expanded(
              child: friendsProv.isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : friendsProv.friends.isEmpty
                      ? const Center(
                          child: Text('No friends yet. Add them to groups to start splitting!'),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: friendsProv.friends.length,
                          itemBuilder: (context, index) {
                            final f = friendsProv.friends[index];
                            final String name       = f['name'] ?? 'Friend';
                            final String? username  = f['username'] as String?;
                            final double bal        = (f['balance'] ?? 0.0).toDouble();
                            final String status     = f['status'] ?? 'settled';
                            final String currency   = f['currency'] as String? ?? 'LKR';
                            final String? photoUrl  = f['profile_photo_url'] as String?;

                            String subtitle = 'Settled up';
                            Color balColor = Colors.grey;
                            if (status == 'owes_you') {
                              subtitle = 'Owes you $currency ${bal.toStringAsFixed(2)}';
                              balColor = const Color(0xFF2E7D32);
                            } else if (status == 'you_owe') {
                              subtitle = 'You owe $currency ${bal.abs().toStringAsFixed(2)}';
                              balColor = const Color(0xFFCC7A29);
                            }

                            final String trailingText = bal.abs() < 0.01
                                ? 'Settled'
                                : (bal > 0
                                    ? '+$currency ${bal.toStringAsFixed(2)}'
                                    : '-$currency ${bal.abs().toStringAsFixed(2)}');

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
                                  backgroundColor: isDark ? cs.primary.withValues(alpha: 0.25) : cs.outlineVariant,
                                  backgroundImage: photoUrl != null ? NetworkImage(photoUrl) : null,
                                  child: photoUrl == null
                                      ? Text(
                                          name.isNotEmpty ? name[0].toUpperCase() : '?',
                                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                                        )
                                      : null,
                                ),
                                title: Row(
                                  children: [
                                    Text(name, style: const TextStyle(fontWeight: FontWeight.w700)),
                                    if (username != null && username.isNotEmpty) ...[
                                      const SizedBox(width: 6),
                                      Text(
                                        '@$username',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: cs.primary,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                subtitle: Text(subtitle),
                                trailing: Text(
                                  trailingText,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: isDark ? (bal > 0 ? cs.primary : cs.secondary) : balColor,
                                    fontSize: 12,
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
