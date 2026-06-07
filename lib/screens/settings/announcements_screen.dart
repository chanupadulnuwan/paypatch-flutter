import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/connectivity_provider.dart';
import '../../providers/announcements_provider.dart';
import 'announcement_detail_screen.dart';

class AnnouncementsScreen extends StatefulWidget {
  const AnnouncementsScreen({super.key});

  @override
  State<AnnouncementsScreen> createState() => _AnnouncementsScreenState();
}

class _AnnouncementsScreenState extends State<AnnouncementsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _syncAnnouncements();
    });
  }

  Future<void> _syncAnnouncements() async {
    final isOnline = Provider.of<ConnectivityProvider>(context, listen: false).isOnline;
    await Provider.of<AnnouncementsProvider>(context, listen: false)
        .fetchAnnouncements(isOnline: isOnline);
  }

  Color _getPriorityColor(String? priority) {
    switch (priority?.toLowerCase()) {
      case 'high':
        return Colors.red.shade700;
      case 'medium':
        return Colors.orange.shade700;
      case 'low':
      default:
        return Colors.blueGrey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final prov = Provider.of<AnnouncementsProvider>(context);

    final pageBg = isDark ? cs.surface : Colors.white;
    final cardBg = isDark ? cs.surfaceContainerHighest : Colors.white;

    return Scaffold(
      backgroundColor: pageBg,
      appBar: AppBar(
        title: const Text('System Announcements'),
        backgroundColor: isDark ? cs.surface : null,
        foregroundColor: isDark ? cs.onSurface : null,
        elevation: 0,
      ),
      body: RefreshIndicator(
        onRefresh: _syncAnnouncements,
        child: Column(
          children: [
            // Status Indicator (Show if loaded from external url or local asset fallback)
            Container(
              color: prov.isLoadedFromExternal ? Colors.green.shade800 : Colors.blueGrey.shade800,
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
              child: Row(
                children: [
                  Icon(
                    prov.isLoadedFromExternal ? Icons.cloud_done : Icons.storage,
                    color: Colors.white,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      prov.isLoadedFromExternal
                          ? 'Synchronized with External Server'
                          : 'Offline Fallback — Viewing Local Resource',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            Expanded(
              child: prov.isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : prov.announcements.isEmpty
                      ? ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          children: const [
                            Padding(
                              padding: EdgeInsets.all(40.0),
                              child: Center(child: Text('No announcements found.')),
                            ),
                          ],
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: prov.announcements.length,
                          itemBuilder: (context, index) {
                            final ann = prov.announcements[index];
                            final String title = ann['title'] ?? 'Notice';
                            final String summary = ann['content'] ?? '';
                            final String date = ann['date'] ?? '';
                            final String priority = ann['priority'] ?? 'low';
                            final String author = ann['author'] ?? 'Admin';

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
                                contentPadding: const EdgeInsets.all(16),
                                title: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        title,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w800,
                                          fontSize: 16,
                                        ),
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: _getPriorityColor(priority),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        priority.toUpperCase(),
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const SizedBox(height: 8),
                                    Text(
                                      summary,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: isDark ? cs.onSurface.withOpacity(0.8) : Colors.black87,
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      'Published: $date • By $author',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: cs.onSurface.withOpacity(0.6),
                                      ),
                                    ),
                                  ],
                                ),
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => AnnouncementDetailScreen(announcement: ann),
                                    ),
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
