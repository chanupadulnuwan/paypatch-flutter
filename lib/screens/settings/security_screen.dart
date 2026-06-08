import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../widgets/custom_alert.dart';

class SecurityScreen extends StatefulWidget {
  const SecurityScreen({super.key});

  @override
  State<SecurityScreen> createState() => _SecurityScreenState();
}

class _SecurityScreenState extends State<SecurityScreen> {
  final _currentPwCtrl = TextEditingController();
  final _newPwCtrl     = TextEditingController();
  final _confirmPwCtrl = TextEditingController();

  bool _obscureCurrent = true;
  bool _obscureNew     = true;
  bool _obscureConfirm = true;
  bool _isSaving       = false;

  @override
  void dispose() {
    _currentPwCtrl.dispose();
    _newPwCtrl.dispose();
    _confirmPwCtrl.dispose();
    super.dispose();
  }

  Future<void> _changePassword() async {
    final current = _currentPwCtrl.text.trim();
    final newPw   = _newPwCtrl.text;
    final confirm = _confirmPwCtrl.text;

    if (current.isEmpty || newPw.isEmpty || confirm.isEmpty) {
      await showCustomAlert(context, 'Please fill in all password fields.');
      return;
    }

    if (newPw.length < 8) {
      await showCustomAlert(context, 'New password must be at least 8 characters.');
      return;
    }

    final hasUpper   = RegExp(r'[A-Z]').hasMatch(newPw);
    final hasLower   = RegExp(r'[a-z]').hasMatch(newPw);
    final hasNumber  = RegExp(r'[0-9]').hasMatch(newPw);
    final hasSpecial = RegExp(r'[!@#\$&*~_.\-]').hasMatch(newPw);

    if (!hasUpper || !hasLower || !hasNumber || !hasSpecial) {
      await showCustomAlert(
        context,
        'Password must contain uppercase, lowercase, a number, and a special character.',
      );
      return;
    }

    if (newPw != confirm) {
      await showCustomAlert(context, 'New passwords do not match.');
      return;
    }

    setState(() => _isSaving = true);
    final auth = Provider.of<AuthProvider>(context, listen: false);
    try {
      await auth.changePassword(currentPassword: current, newPassword: newPw);
      if (!mounted) return;
      _currentPwCtrl.clear();
      _newPwCtrl.clear();
      _confirmPwCtrl.clear();
      await showCustomAlert(context, 'Password changed successfully.', isSuccess: true);
    } catch (e) {
      if (!mounted) return;
      await showCustomAlert(context, e.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final pageBg = isDark ? cs.surface : Colors.white;
    final cardBg = isDark ? cs.surfaceContainerHighest : Colors.white;

    return Scaffold(
      backgroundColor: pageBg,
      appBar: AppBar(
        title: const Text('Security'),
        backgroundColor: isDark ? cs.surface : null,
        foregroundColor: isDark ? cs.onSurface : null,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // --- Security Info Cards ---
          _SectionHeader(label: 'Account Security', cs: cs),
          const SizedBox(height: 10),

          Card(
            elevation: 0,
            color: cardBg,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
              side: BorderSide(color: cs.outlineVariant),
            ),
            child: Column(
              children: [
                ListTile(
                  leading: Icon(Icons.verified_user_outlined, color: cs.primary),
                  title: const Text('Account Status', style: TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: const Text('Your account is active and secure'),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF4F7D6A).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text('Active', style: TextStyle(color: Color(0xFF4F7D6A), fontWeight: FontWeight.w700, fontSize: 12)),
                  ),
                ),
                Divider(height: 1, color: cs.outlineVariant),
                ListTile(
                  leading: Icon(Icons.lock_outlined, color: cs.primary),
                  title: const Text('Password', style: TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: const Text('Use a strong, unique password'),
                  trailing: Icon(Icons.check_circle, color: const Color(0xFF4F7D6A), size: 20),
                ),
                Divider(height: 1, color: cs.outlineVariant),
                ListTile(
                  leading: Icon(Icons.devices_outlined, color: cs.primary),
                  title: const Text('Active Sessions', style: TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: const Text('Logged in on this device'),
                  trailing: Icon(Icons.chevron_right, color: cs.onSurface.withValues(alpha: 0.4)),
                  onTap: () => showCustomAlert(context, 'Session management coming soon.'),
                ),
                Divider(height: 1, color: cs.outlineVariant),
                ListTile(
                  leading: Icon(Icons.notifications_active_outlined, color: cs.primary),
                  title: const Text('Login Alerts', style: TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: const Text('Get notified of new sign-ins'),
                  trailing: Switch(
                    value: true,
                    onChanged: (_) => showCustomAlert(context, 'Login alert settings coming soon.'),
                    activeThumbColor: const Color(0xFF4F7D6A),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),
          _SectionHeader(label: 'Change Password', cs: cs),
          const SizedBox(height: 10),

          Card(
            elevation: 0,
            color: cardBg,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
              side: BorderSide(color: cs.outlineVariant),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Update your password regularly to keep your account safe.',
                    style: TextStyle(fontSize: 13, color: cs.onSurface.withValues(alpha: 0.65)),
                  ),
                  const SizedBox(height: 16),
                  _PwField(
                    controller: _currentPwCtrl,
                    label: 'Current password',
                    obscure: _obscureCurrent,
                    onToggle: () => setState(() => _obscureCurrent = !_obscureCurrent),
                    cs: cs,
                  ),
                  const SizedBox(height: 12),
                  _PwField(
                    controller: _newPwCtrl,
                    label: 'New password',
                    obscure: _obscureNew,
                    onToggle: () => setState(() => _obscureNew = !_obscureNew),
                    cs: cs,
                  ),
                  const SizedBox(height: 12),
                  _PwField(
                    controller: _confirmPwCtrl,
                    label: 'Confirm new password',
                    obscure: _obscureConfirm,
                    onToggle: () => setState(() => _obscureConfirm = !_obscureConfirm),
                    cs: cs,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '8+ chars • uppercase • lowercase • number • special character',
                    style: TextStyle(fontSize: 11, color: cs.onSurface.withValues(alpha: 0.5)),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF4F7D6A),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      onPressed: _isSaving ? null : _changePassword,
                      icon: _isSaving
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.lock_reset_outlined),
                      label: Text(_isSaving ? 'Saving...' : 'Update Password'),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Data & Privacy
          _SectionHeader(label: 'Data & Privacy', cs: cs),
          const SizedBox(height: 10),
          Card(
            elevation: 0,
            color: cardBg,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
              side: BorderSide(color: cs.outlineVariant),
            ),
            child: Column(
              children: [
                ListTile(
                  leading: Icon(Icons.privacy_tip_outlined, color: cs.primary),
                  title: const Text('Privacy Policy', style: TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: const Text('How we handle your data'),
                  trailing: Icon(Icons.chevron_right, color: cs.onSurface.withValues(alpha: 0.4)),
                  onTap: () => showCustomAlert(context, 'Privacy policy coming soon.'),
                ),
                Divider(height: 1, color: cs.outlineVariant),
                ListTile(
                  leading: Icon(Icons.delete_outline, color: cs.error),
                  title: Text('Delete Account', style: TextStyle(fontWeight: FontWeight.bold, color: cs.error)),
                  subtitle: const Text('Permanently remove your account and data'),
                  onTap: () => showCustomAlert(context, 'Please contact support to delete your account.'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.label, required this.cs});
  final String label;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return Text(
      label.toUpperCase(),
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w800,
        color: cs.onSurface.withValues(alpha: 0.5),
        letterSpacing: 1.1,
      ),
    );
  }
}

class _PwField extends StatelessWidget {
  const _PwField({
    required this.controller,
    required this.label,
    required this.obscure,
    required this.onToggle,
    required this.cs,
  });

  final TextEditingController controller;
  final String label;
  final bool obscure;
  final VoidCallback onToggle;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: const Icon(Icons.lock_outline),
        suffixIcon: IconButton(
          icon: Icon(obscure ? Icons.visibility_off : Icons.visibility, color: cs.onSurface.withValues(alpha: 0.6)),
          onPressed: onToggle,
        ),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
        isDense: true,
      ),
    );
  }
}
