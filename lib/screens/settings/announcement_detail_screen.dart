import 'package:flutter/material.dart';

class AnnouncementDetailScreen extends StatelessWidget {
  final Map<String, dynamic> announcement;

  const AnnouncementDetailScreen({super.key, required this.announcement});

  Color _getPriorityColor(BuildContext context, String? priority) {
    final cs = Theme.of(context).colorScheme;
    switch (priority?.toLowerCase()) {
      case 'high':
        return const Color(0xFFCC3A3A);
      case 'medium':
        return const Color(0xFFE8AC73);
      case 'low':
      default:
        return cs.onSurface.withValues(alpha: 0.5);
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
        backgroundColor: isDark ? cs.surface : cs.primary,
        foregroundColor: isDark ? cs.onSurface : Colors.white,
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
                    Builder(
                      builder: (ctx) {
                        final pColor = _getPriorityColor(ctx, priority);
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: pColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: pColor.withValues(alpha: 0.3)),
                          ),
                          child: Text(
                            '${priority.toUpperCase()} PRIORITY',
                            style: TextStyle(
                              color: pColor,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                        );
                      },
                    ),
                    Text(
                      date,
                      style: TextStyle(
                        fontSize: 12,
                        color: cs.onSurface.withValues(alpha: 0.6),
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
                    color: isDark ? cs.onSurface.withValues(alpha: 0.9) : Colors.black87,
                  ),
                ),
                const SizedBox(height: 30),

                // Divider
                Divider(color: cs.outlineVariant),
                const SizedBox(height: 12),

                // Author Info
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: const Color(0xFF4F7D6A).withValues(alpha: 0.14),
                        shape: BoxShape.circle,
                        border: Border.all(color: const Color(0xFF4F7D6A).withValues(alpha: 0.3)),
                      ),
                      child: const Icon(
                        Icons.campaign_rounded,
                        color: Color(0xFF4F7D6A),
                        size: 20,
                      ),
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
                            color: cs.onSurface.withValues(alpha: 0.5),
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
