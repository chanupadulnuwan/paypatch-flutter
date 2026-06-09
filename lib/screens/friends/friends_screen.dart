import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';

import '../../config.dart';
import '../../models/group_post.dart';
import '../../providers/auth_provider.dart';
import '../../providers/connectivity_provider.dart';
import '../../providers/friends_provider.dart';
import '../../providers/posts_provider.dart';
import '../../widgets/custom_alert.dart';
import '../../widgets/fade_slide_item.dart';
import '../../widgets/net_image.dart';
import '../posts/story_viewer_screen.dart';

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

  void _showInviteSheet(BuildContext context) {
    final conn = Provider.of<ConnectivityProvider>(context, listen: false);
    if (!conn.isOnline) {
      showCustomAlert(context, 'You are offline. Connect to the internet to add friends.');
      return;
    }
    Provider.of<FriendsProvider>(context, listen: false).fetchPhoneContacts();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: (sheetCtx) => _InviteSheet(parentContext: context),
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

    // Split friends into active and settled
    final activeFriends = friendsProv.friends
        .where((f) => (f['status'] ?? 'settled') != 'settled')
        .toList();
    final settledFriends = friendsProv.friends
        .where((f) => (f['status'] ?? 'settled') == 'settled')
        .toList();

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
        onPressed: () => _showInviteSheet(context),
        child: const Icon(Icons.person_add),
      ),
      body: RefreshIndicator(
        onRefresh: _syncFriends,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            // Connection banner
            if (!conn.isOnline)
              SliverToBoxAdapter(
                child: Container(
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
              ),

            // ── Section 1: Friends Feed ──────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Friends Feed',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF4F7D6A),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Posts from your groups',
                      style: TextStyle(
                        fontSize: 13,
                        color: cs.onSurface.withValues(alpha: 0.55),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Stories row
            SliverToBoxAdapter(
              child: Consumer<PostsProvider>(
                builder: (ctx, postsProv, _) {
                  if (postsProv.posts.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.fromLTRB(20, 10, 20, 4),
                      child: Text(
                        'No posts yet.',
                        style: TextStyle(
                          color: cs.onSurface.withValues(alpha: 0.4),
                          fontSize: 13,
                        ),
                      ),
                    );
                  }
                  // Group posts by user — one bubble per user (their latest post)
                  final Map<String, GroupPost> byUser = {};
                  for (final p in postsProv.posts) {
                    if (!byUser.containsKey(p.userId)) byUser[p.userId] = p;
                  }
                  final storyPosts = byUser.values.toList();
                  return SizedBox(
                    height: 96,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: storyPosts.length,
                      itemBuilder: (_, index) {
                        final post = storyPosts[index];
                        final userPosts = postsProv.posts
                            .where((p) => p.userId == post.userId)
                            .toList();
                        return GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              PageRouteBuilder(
                                pageBuilder: (context, anim, secondary) =>
                                    FadeTransition(
                                  opacity: anim,
                                  child: StoryViewerScreen(
                                      posts: userPosts, initialIndex: 0),
                                ),
                                transitionDuration:
                                    const Duration(milliseconds: 350),
                                reverseTransitionDuration:
                                    const Duration(milliseconds: 250),
                              ),
                            );
                          },
                          child: Padding(
                            padding: const EdgeInsets.only(right: 14),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // Gradient ring around avatar
                                Container(
                                  padding: const EdgeInsets.all(3),
                                  decoration: const BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: LinearGradient(
                                      colors: [
                                        Color(0xFF4F7D6A),
                                        Color(0xFFE8AC73)
                                      ],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                  ),
                                  child: Container(
                                    padding: const EdgeInsets.all(2),
                                    decoration: const BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: Colors.white),
                                    child: NetImage(
                                        url: post.userPhotoUrl,
                                        radius: 26,
                                        fallbackText: post.userName),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                SizedBox(
                                  width: 60,
                                  child: Text(
                                    post.userName.split(' ').first,
                                    textAlign: TextAlign.center,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  );
                },
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 12)),
            SliverToBoxAdapter(
              child: Divider(
                  height: 1,
                  thickness: 1,
                  color: cs.outlineVariant.withValues(alpha: 0.5),
                  indent: 20,
                  endIndent: 20),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 8)),

            // ── Section 2: Your Friends ──────────────────────────────────
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(20, 12, 20, 4),
                child: Text(
                  'Your Friends',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF4F7D6A),
                  ),
                ),
              ),
            ),

            if (friendsProv.isLoading)
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 40),
                  child: Center(child: CircularProgressIndicator()),
                ),
              )
            else if (friendsProv.friends.isEmpty)
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 40, horizontal: 20),
                  child: Center(
                    child: Text(
                      'No friends yet. Add them to groups to start splitting!',
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              )
            else ...[
              // Active sub-section
              if (activeFriends.isNotEmpty) ...[
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
                    child: Text(
                      'Active',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: cs.onSurface.withValues(alpha: 0.5),
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final f = activeFriends[index];
                        return _buildFriendCard(
                            context, f, index, cardBg, cs, isDark);
                      },
                      childCount: activeFriends.length,
                    ),
                  ),
                ),
              ],

              // Settled sub-section
              if (settledFriends.isNotEmpty) ...[
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
                    child: Text(
                      'Settled',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: cs.onSurface.withValues(alpha: 0.5),
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final f = settledFriends[index];
                        return _buildFriendCard(context, f,
                            activeFriends.length + index, cardBg, cs, isDark);
                      },
                      childCount: settledFriends.length,
                    ),
                  ),
                ),
              ],

              const SliverToBoxAdapter(child: SizedBox(height: 80)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildFriendCard(
    BuildContext context,
    dynamic f,
    int index,
    Color cardBg,
    ColorScheme cs,
    bool isDark,
  ) {
    final String name      = f['name'] ?? 'Friend';
    final String? username = f['username'] as String?;
    final double bal       = (f['balance'] ?? 0.0).toDouble();
    final String status    = f['status'] ?? 'settled';
    final String currency  = f['currency'] as String? ?? 'LKR';
    final String? photoUrl = f['profile_photo_url'] as String?;

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

    return FadeSlideItem(
      index: index,
      child: Card(
        elevation: 0,
        margin: const EdgeInsets.only(bottom: 10),
        color: cardBg,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: cs.outlineVariant),
        ),
        child: ListTile(
          leading: NetImage(
            url: photoUrl,
            radius: 20,
            fallbackText: name,
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
      ),
    );
  }
}

// ── Invite Sheet ─────────────────────────────────────────────────────────────

class _InviteSheet extends StatefulWidget {
  final BuildContext parentContext;
  const _InviteSheet({required this.parentContext});

  @override
  State<_InviteSheet> createState() => _InviteSheetState();
}

class _InviteSheetState extends State<_InviteSheet>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (_, scrollController) {
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
              child: Row(
                children: [
                  Text(
                    'Add Friends',
                    style: theme.textTheme.titleLarge
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                ],
              ),
            ),
            TabBar(
              controller: _tabController,
              labelColor: const Color(0xFF4F7D6A),
              unselectedLabelColor: cs.onSurface.withValues(alpha: 0.5),
              indicatorColor: const Color(0xFF4F7D6A),
              tabs: const [
                Tab(text: 'Contacts'),
                Tab(text: 'By Username'),
                Tab(text: 'By Email'),
              ],
            ),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _ContactsTab(
                    scrollController: scrollController,
                    parentContext: widget.parentContext,
                  ),
                  _SearchTab(
                    key: const ValueKey('username'),
                    searchType: 'username',
                    hint: 'Enter username (without @)',
                    parentContext: widget.parentContext,
                  ),
                  _SearchTab(
                    key: const ValueKey('email'),
                    searchType: 'email',
                    hint: 'Enter email address',
                    parentContext: widget.parentContext,
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

// ── Contacts Tab ─────────────────────────────────────────────────────────────

class _ContactsTab extends StatelessWidget {
  final ScrollController scrollController;
  final BuildContext parentContext;

  const _ContactsTab({
    required this.scrollController,
    required this.parentContext,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<FriendsProvider>(
      builder: (ctx, prov, _) {
        final cs = Theme.of(ctx).colorScheme;

        if (prov.isLoadingContacts) {
          return Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 12),
              Text('Loading contacts...',
                  style:
                      TextStyle(color: cs.onSurface.withValues(alpha: 0.6))),
            ],
          );
        }
        if (prov.contactsPermissionDenied) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'Contacts permission denied.\nPlease allow contacts access in app settings.',
                textAlign: TextAlign.center,
              ),
            ),
          );
        }
        if (prov.contacts.isEmpty) {
          return const Center(child: Text('No contacts found on this device.'));
        }

        final sorted = [...prov.contacts];
        sorted.sort((a, b) {
          final aMatch = prov.getMatchedUser(a) != null ? 0 : 1;
          final bMatch = prov.getMatchedUser(b) != null ? 0 : 1;
          return aMatch.compareTo(bMatch);
        });
        final paypatchCount =
            sorted.where((c) => prov.getMatchedUser(c) != null).length;

        return Column(
          children: [
            if (prov.isMatchingContacts)
              LinearProgressIndicator(
                  color: cs.primary, backgroundColor: cs.outlineVariant),
            if (paypatchCount > 0)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF4F7D6A).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle_outline,
                          color: Color(0xFF4F7D6A), size: 18),
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
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                itemCount: sorted.length,
                itemBuilder: (ctx2, i) {
                  final c = sorted[i];
                  final name = c.displayName ?? 'Unknown';
                  final phoneNum =
                      (c.phones != null && c.phones!.isNotEmpty)
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
                      leading: NetImage(
                        url: isOnPayPatch
                            ? matched['profile_photo_url']?.toString()
                            : null,
                        radius: 20,
                        fallbackText: name,
                        fallbackColor:
                            isOnPayPatch ? const Color(0xFF4F7D6A) : null,
                      ),
                      title: Row(
                        children: [
                          Expanded(
                            child: Text(
                              isOnPayPatch
                                  ? (matched['name'] as String? ?? name)
                                  : name,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w700),
                            ),
                          ),
                          if (isOnPayPatch)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0xFF4F7D6A),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Text(
                                'PayPatch',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700),
                              ),
                            ),
                        ],
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(phoneNum,
                              style: TextStyle(
                                  color: cs.onSurface.withValues(alpha: 0.6),
                                  fontSize: 12)),
                          if (isOnPayPatch && matched['email'] != null)
                            Text(
                              matched['email'].toString(),
                              style: const TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFF4F7D6A)),
                            ),
                        ],
                      ),
                      trailing: isOnPayPatch
                          ? FilledButton(
                              style: FilledButton.styleFrom(
                                backgroundColor: const Color(0xFF4F7D6A),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14),
                                minimumSize: const Size(0, 36),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12)),
                              ),
                              onPressed: () {
                                Navigator.pop(context);
                                showCustomAlert(
                                  parentContext,
                                  '${matched['name']} is already on PayPatch! Add them to a group to start splitting.',
                                  isSuccess: true,
                                );
                              },
                              child: const Text('Add'),
                            )
                          : OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12),
                                minimumSize: const Size(0, 36),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12)),
                              ),
                              onPressed: () {
                                Navigator.pop(context);
                                ScaffoldMessenger.of(parentContext)
                                    .showSnackBar(
                                  SnackBar(
                                      content:
                                          Text('Invite sent to $name!')),
                                );
                              },
                              child: const Text('Invite'),
                            ),
                      isThreeLine:
                          matched != null && matched['email'] != null,
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

// ── Search Tab (username / email) ─────────────────────────────────────────────

class _SearchTab extends StatefulWidget {
  final String searchType; // 'username' or 'email'
  final String hint;
  final BuildContext parentContext;

  const _SearchTab({
    super.key,
    required this.searchType,
    required this.hint,
    required this.parentContext,
  });

  @override
  State<_SearchTab> createState() => _SearchTabState();
}

class _SearchTabState extends State<_SearchTab> {
  final TextEditingController _ctrl = TextEditingController();
  Timer? _debounce;
  bool _isSearching = false;
  List<Map<String, dynamic>> _results = [];
  bool _searched = false;
  String? _errorMsg;
  final Set<int> _sending = {};

  @override
  void initState() {
    super.initState();
    _ctrl.addListener(_onChanged);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _ctrl.removeListener(_onChanged);
    _ctrl.dispose();
    super.dispose();
  }

  void _onChanged() {
    final q = _ctrl.text.trim();
    _debounce?.cancel();
    if (q.length < 2) {
      if (_searched || _results.isNotEmpty || _errorMsg != null) {
        setState(() { _results = []; _searched = false; _errorMsg = null; });
      }
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 500), _search);
  }

  Future<void> _search() async {
    final query = _ctrl.text.trim();
    if (query.length < 2) return;

    setState(() { _isSearching = true; _errorMsg = null; });

    try {
      final token = Provider.of<AuthProvider>(context, listen: false).token;
      if (token == null) {
        setState(() => _errorMsg = 'Not authenticated.');
        return;
      }

      final uri = Uri.parse('${AppConfig.baseUrl}/users/search')
          .replace(queryParameters: {'q': query});

      final response = await http.get(
        uri,
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 10));

      if (!mounted) return;

      if (response.statusCode == 200) {
        final decoded = json.decode(response.body) as Map<String, dynamic>;
        final users = (decoded['users'] as List?)
                ?.whereType<Map<String, dynamic>>()
                .toList() ??
            [];
        setState(() { _results = users; _searched = true; });
      } else {
        setState(() { _results = []; _searched = true; });
      }
    } catch (_) {
      if (mounted) setState(() => _errorMsg = 'Network error. Please try again.');
    } finally {
      if (mounted) setState(() => _isSearching = false);
    }
  }

  Future<void> _sendRequest(Map<String, dynamic> user) async {
    final userId = user['id'] as int?;
    if (userId == null) return;

    setState(() => _sending.add(userId));

    final token = Provider.of<AuthProvider>(context, listen: false).token;
    final friendsProv =
        Provider.of<FriendsProvider>(widget.parentContext, listen: false);
    final connectProv =
        Provider.of<ConnectivityProvider>(widget.parentContext, listen: false);
    final messenger = ScaffoldMessenger.of(widget.parentContext);
    final sheetNav = Navigator.of(context);

    if (token == null) {
      setState(() => _sending.remove(userId));
      return;
    }

    try {
      final response = await http
          .post(
            Uri.parse('${AppConfig.baseUrl}/friends/invite'),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: json.encode({'user_id': userId}),
          )
          .timeout(const Duration(seconds: 10));

      if (!mounted) return;
      sheetNav.pop();

      final body = json.decode(response.body) as Map<String, dynamic>;
      if (response.statusCode == 200 || response.statusCode == 201) {
        messenger.showSnackBar(SnackBar(
          content: Text('Friend request sent to ${user['name']}!'),
        ));
        friendsProv.fetchFriends(isOnline: connectProv.isOnline);
      } else {
        messenger.showSnackBar(SnackBar(
          content: Text(body['message'] as String? ?? 'Could not send request.'),
        ));
      }
    } catch (_) {
      if (mounted) sheetNav.pop();
      messenger.showSnackBar(
          const SnackBar(content: Text('Network error. Please try again.')));
    } finally {
      if (mounted) setState(() => _sending.remove(userId));
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          TextField(
            controller: _ctrl,
            decoration: InputDecoration(
              hintText: widget.hint,
              prefixIcon: _isSearching
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : const Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide:
                    const BorderSide(color: Color(0xFF4F7D6A), width: 2),
              ),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              suffixIcon: _ctrl.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () => _ctrl.clear(),
                    )
                  : null,
            ),
            onSubmitted: (_) => _search(),
            textInputAction: TextInputAction.search,
          ),
          const SizedBox(height: 16),

          if (_errorMsg != null)
            Center(
              child: Text(_errorMsg!,
                  style: const TextStyle(color: Colors.red, fontSize: 14)),
            ),

          if (_searched && _results.isEmpty && !_isSearching)
            Center(
              child: Text(
                'No users found.',
                style: TextStyle(
                    color: cs.onSurface.withValues(alpha: 0.6), fontSize: 15),
              ),
            ),

          Expanded(
            child: ListView.builder(
              itemCount: _results.length,
              itemBuilder: (ctx, i) {
                final user = _results[i];
                final userId = user['id'] as int?;
                final name = user['name']?.toString() ?? '';
                final email = user['email']?.toString() ?? '';
                final username = user['username']?.toString();
                final photoUrl = user['profile_photo_url']?.toString();
                final isSending = userId != null && _sending.contains(userId);

                return Card(
                  elevation: 0,
                  margin: const EdgeInsets.only(bottom: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(
                        color:
                            const Color(0xFF4F7D6A).withValues(alpha: 0.4)),
                  ),
                  color: const Color(0xFF4F7D6A).withValues(alpha: 0.05),
                  child: ListTile(
                    leading: NetImage(
                      url: photoUrl,
                      radius: 22,
                      fallbackText: name,
                      fallbackColor: const Color(0xFF4F7D6A),
                    ),
                    title: Text(name,
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                    subtitle: Text(
                      username != null && username.isNotEmpty
                          ? '@$username'
                          : email,
                      style: const TextStyle(
                          color: Color(0xFF4F7D6A), fontSize: 12),
                    ),
                    trailing: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF4F7D6A),
                        foregroundColor: Colors.white,
                        padding:
                            const EdgeInsets.symmetric(horizontal: 14),
                        minimumSize: const Size(0, 36),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed:
                          isSending ? null : () => _sendRequest(user),
                      child: isSending
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white),
                            )
                          : const Text('Add'),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
