import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/connectivity_provider.dart';
import '../../providers/friends_provider.dart';

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
    final friendsProv = Provider.of<FriendsProvider>(context, listen: false);
    friendsProv.fetchPhoneContacts();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (sheetCtx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.7,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          expand: false,
          builder: (_, scrollController) {
            return Consumer<FriendsProvider>(
              builder: (context, prov, child) {
                return Column(
                  children: [
                    Container(
                      margin: const EdgeInsets.symmetric(vertical: 10),
                      width: 40,
                      height: 5,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    Text(
                      'Invite from Contacts',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: prov.isLoadingContacts
                          ? const Center(child: CircularProgressIndicator())
                          : prov.contactsPermissionDenied
                              ? const Center(
                                  child: Padding(
                                    padding: EdgeInsets.all(24.0),
                                    child: Text(
                                      'Contacts permission denied. Please allow contacts access in app settings.',
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                )
                              : prov.contacts.isEmpty
                                  ? const Center(child: Text('No contacts found on phone.'))
                                  : ListView.builder(
                                      controller: scrollController,
                                      itemCount: prov.contacts.length,
                                      itemBuilder: (context, index) {
                                        final c = prov.contacts[index];
                                        final displayName = c.displayName ?? 'Unknown';
                                        final phone = (c.phones != null && c.phones!.isNotEmpty) ? (c.phones!.first.value ?? 'No number') : 'No number';
                                        return ListTile(
                                          leading: CircleAvatar(
                                            child: Text(displayName.isNotEmpty ? displayName[0] : '?'),
                                          ),
                                          title: Text(displayName),
                                          subtitle: Text(phone),
                                          onTap: () {
                                            Navigator.pop(sheetCtx);
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              SnackBar(content: Text('Invitation sent to $displayName!')),
                                            );
                                          },
                                        );
                                      },
                                    ),
                    ),
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
                            final String name = f['name'] ?? 'Friend';
                            final double bal = (f['balance'] ?? 0.0).toDouble();
                            final String status = f['status'] ?? 'settled';

                            String subtitle = 'Settled';
                            Color balColor = Colors.grey;
                            if (status == 'owes_you') {
                              subtitle = 'Owes you \$${bal.toStringAsFixed(2)}';
                              balColor = const Color.fromARGB(255, 10, 95, 13);
                            } else if (status == 'you_owe') {
                              subtitle = 'You owe \$${bal.abs().toStringAsFixed(2)}';
                              balColor = const Color.fromARGB(255, 244, 120, 54);
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
                                  child: const Icon(Icons.person, color: Colors.white),
                                ),
                                title: Text(
                                  name,
                                  style: const TextStyle(fontWeight: FontWeight.w700),
                                ),
                                subtitle: Text(subtitle),
                                trailing: Text(
                                  bal == 0
                                      ? 'Settled'
                                      : (bal > 0 ? '+\$${bal.toStringAsFixed(2)}' : '-\$${bal.abs().toStringAsFixed(2)}'),
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: isDark ? (bal > 0 ? cs.primary : cs.secondary) : balColor,
                                  ),
                                ),
                                onTap: () {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('$name details (Q&A Demo)')),
                                  );
                                },
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
