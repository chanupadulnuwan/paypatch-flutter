import 'package:flutter/material.dart';

class AnnouncementDetailScreen extends StatelessWidget {
  final Map<String, dynamic> announcement;

  const AnnouncementDetailScreen({super.key, required this.announcement});

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

    final String title = announcement['title'] ?? 'Notice';
    final String content = announcement['content'] ?? '';
    final String date = announcement['date'] ?? '';
    final String priority = announcement['priority'] ?? 'low';
    final String author = announcement['author'] ?? 'Admin';

    final pageBg = isDark ? cs.surface : Colors.white;
    final cardBg = isDark ? cs.surfaceContainerHighest : Colors.white;

    return Scaffold(
      backgroundColor: pageBg,
      appBar: AppBar(
        title: const Text('Announcement Details'),
        backgroundColor: isDark ? cs.surface : null,
        foregroundColor: isDark ? cs.onSurface : null,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Card(
          elevation: 0,
          color: cardBg,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
            side: BorderSide(color: cs.outlineVariant),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Priority Badge & Date
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: _getPriorityColor(priority),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${priority.toUpperCase()} PRIORITY',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    Text(
                      date,
                      style: TextStyle(
                        fontSize: 12,
                        color: cs.onSurface.withOpacity(0.6),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Title
                Text(
                  title,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: isDark ? cs.onSurface : Colors.black87,
                  ),
                ),
                const SizedBox(height: 12),

                // Divider
                Divider(color: cs.outlineVariant),
                const SizedBox(height: 16),

                // Content Body
                Text(
                  content,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    height: 1.6,
                    color: isDark ? cs.onSurface.withOpacity(0.9) : Colors.black87,
                  ),
                ),
                const SizedBox(height: 30),

                // Divider
                Divider(color: cs.outlineVariant),
                const SizedBox(height: 12),

                // Author Info
                Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: cs.primary.withOpacity(0.1),
                      child: Icon(Icons.campaign, color: cs.primary),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          author,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'PayPatch System Channel',
                          style: TextStyle(
                            fontSize: 11,
                            color: cs.onSurface.withOpacity(0.5),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
