import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/activity_badge_provider.dart';

class ResponsiveScaffold extends StatelessWidget {
  final int index;
  final ValueChanged<int> onIndexChanged;
  final List<Widget> pages;

  const ResponsiveScaffold({
    super.key,
    required this.index,
    required this.onIndexChanged,
    required this.pages,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final unread = Provider.of<ActivityBadgeProvider>(context).unreadCount;

    Widget activityIcon(bool active) {
      final icon = Icon(active ? Icons.timeline : Icons.timeline_outlined);
      if (unread <= 0) return icon;
      return Stack(
        clipBehavior: Clip.none,
        children: [
          icon,
          Positioned(
            top: -4,
            right: -6,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              decoration: BoxDecoration(
                color: const Color(0xFFE8AC73),
                borderRadius: BorderRadius.circular(10),
              ),
              constraints: const BoxConstraints(minWidth: 16, minHeight: 14),
              child: Text(
                unread > 99 ? '99+' : '$unread',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ],
      );
    }

    return Scaffold(
      body: pages[index],
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: isDark ? cs.surface : Colors.white,
          border: Border(top: BorderSide(color: cs.outlineVariant, width: 1)),
        ),
        child: BottomNavigationBar(
          currentIndex: index,
          onTap: onIndexChanged,
          type: BottomNavigationBarType.fixed,
          showUnselectedLabels: true,
          backgroundColor: isDark ? cs.surface : Colors.white,
          elevation: 0,
          selectedItemColor: cs.primary,
          unselectedItemColor: cs.onSurface.withValues(alpha: isDark ? 0.65 : 0.6),
          selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w700),
          items: [
            const BottomNavigationBarItem(
              icon: Icon(Icons.groups_outlined),
              activeIcon: Icon(Icons.groups),
              label: 'Groups',
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.person_add_alt_1_outlined),
              activeIcon: Icon(Icons.person_add_alt_1),
              label: 'Friends',
            ),
            BottomNavigationBarItem(
              icon: activityIcon(false),
              activeIcon: activityIcon(true),
              label: 'Activity',
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.settings_outlined),
              activeIcon: Icon(Icons.settings),
              label: 'Settings',
            ),
          ],
        ),
      ),
    );
  }
}
