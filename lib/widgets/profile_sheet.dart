import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';

class ProfileSheet extends StatelessWidget {
  final VoidCallback onLogout;

  const ProfileSheet({super.key, required this.onLogout});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final auth = Provider.of<AuthProvider>(context);
    final user = auth.user;

    final displayName = user?['name'] ?? 'User';
    final displayEmail = user?['email'] ?? 'No email';

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 44,
              height: 5,
              decoration: BoxDecoration(
                color: cs.outlineVariant,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            const SizedBox(height: 14),

            CircleAvatar(
              radius: 34,
              backgroundColor: cs.primary.withOpacity(0.1),
              child: Icon(Icons.person, size: 34, color: cs.primary),
            ),
            const SizedBox(height: 10),

            Text(
              displayName,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            Text(
              displayEmail,
              style: TextStyle(color: cs.onSurface.withOpacity(0.7)),
            ),
            const SizedBox(height: 16),

            SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton.icon(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Premium upgrade (UI only)')),
                  );
                },
                icon: const Icon(Icons.workspace_premium_outlined),
                label: const Text('Upgrade to Premium'),
              ),
            ),
            const SizedBox(height: 10),

            SizedBox(
              width: double.infinity,
              height: 48,
              child: OutlinedButton.icon(
                onPressed: () async {
                  await auth.logout();
                  onLogout();
                },
                icon: const Icon(Icons.logout),
                label: const Text('Log out'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
