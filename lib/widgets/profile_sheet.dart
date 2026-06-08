import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../widgets/custom_alert.dart';
import 'net_image.dart';

class ProfileSheet extends StatefulWidget {
  final VoidCallback onLogout;

  const ProfileSheet({super.key, required this.onLogout});

  @override
  State<ProfileSheet> createState() => _ProfileSheetState();
}

class _ProfileSheetState extends State<ProfileSheet> {
  bool _isEditing = false;
  bool _isSaving = false;
  String? _newImagePath;

  late TextEditingController _nameCtrl;
  late TextEditingController _usernameCtrl;
  late TextEditingController _phoneCtrl;

  @override
  void initState() {
    super.initState();
    final user = Provider.of<AuthProvider>(context, listen: false).user;
    _nameCtrl     = TextEditingController(text: user?['name'] ?? '');
    _usernameCtrl = TextEditingController(text: user?['username'] ?? '');
    _phoneCtrl    = TextEditingController(text: user?['phone'] ?? '');
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _usernameCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickProfilePhoto() async {
    final picker = ImagePicker();
    final choice = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: const Text('Camera'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Gallery'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (choice == null) return;
    final file = await picker.pickImage(source: choice, imageQuality: 80);
    if (file != null && mounted) {
      setState(() => _newImagePath = file.path);
    }
  }

  Future<void> _saveProfile() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    setState(() => _isSaving = true);

    final success = await auth.updateProfile(
      name: _nameCtrl.text.trim(),
      username: _usernameCtrl.text.trim(),
      phone: _phoneCtrl.text.trim(),
      profileImagePath: _newImagePath,
    );

    if (!mounted) return;
    setState(() {
      _isSaving = false;
      if (success) {
        _isEditing = false;
        _newImagePath = null;
      }
    });

    await showCustomAlert(
      context,
      success ? 'Profile updated successfully.' : 'Failed to update profile.',
      isSuccess: success,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final auth = Provider.of<AuthProvider>(context);
    final user = auth.user;

    final displayName    = user?['name']     as String? ?? 'User';
    final displayEmail   = user?['email']    as String? ?? '';
    final displayUsername = user?['username'] as String? ?? '';
    final displayPhone   = user?['phone']    as String? ?? '';
    final displayCountry = user?['country']  as String? ?? '';
    final photoUrl       = user?['profile_photo_url'] as String?;

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollCtrl) {
        return Container(
          decoration: BoxDecoration(
            color: isDark ? cs.surface : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: ListView(
            controller: scrollCtrl,
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
            children: [
              // Drag handle
              Center(
                child: Container(
                  width: 44,
                  height: 5,
                  decoration: BoxDecoration(
                    color: cs.outlineVariant,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Header row
              Row(
                children: [
                  Text(
                    'My Profile',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: cs.primary,
                    ),
                  ),
                  const Spacer(),
                  if (!_isEditing)
                    IconButton(
                      icon: Icon(Icons.edit_outlined, color: cs.primary),
                      tooltip: 'Edit profile',
                      onPressed: () => setState(() => _isEditing = true),
                    )
                  else
                    TextButton(
                      onPressed: () => setState(() {
                        _isEditing = false;
                        _newImagePath = null;
                        final u = auth.user;
                        _nameCtrl.text     = u?['name']     ?? '';
                        _usernameCtrl.text = u?['username'] ?? '';
                        _phoneCtrl.text    = u?['phone']    ?? '';
                      }),
                      child: const Text('Cancel'),
                    ),
                ],
              ),
              const SizedBox(height: 20),

              // Avatar
              Center(
                child: Stack(
                  children: [
                    _newImagePath != null
                        ? CircleAvatar(
                            radius: 52,
                            backgroundColor: cs.primary.withValues(alpha: 0.12),
                            backgroundImage: FileImage(File(_newImagePath!)),
                          )
                        : NetImage(
                            url: photoUrl,
                            radius: 52,
                            fallbackText: displayName,
                            overlayIcon: photoUrl == null ? Icon(Icons.person, size: 50, color: cs.primary) : null,
                          ),
                    if (_isEditing)
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: GestureDetector(
                          onTap: _pickProfilePhoto,
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE8AC73),
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                            child: const Icon(Icons.camera_alt, size: 18, color: Colors.white),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 6),

              // Name below avatar (read mode)
              if (!_isEditing) ...[
                Center(
                  child: Text(
                    displayName,
                    style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                  ),
                ),
                if (displayUsername.isNotEmpty)
                  Center(
                    child: Text(
                      '@$displayUsername',
                      style: TextStyle(color: cs.primary, fontWeight: FontWeight.w600),
                    ),
                  ),
                const SizedBox(height: 20),
              ] else
                const SizedBox(height: 16),

              // Details card
              Container(
                decoration: BoxDecoration(
                  color: isDark ? cs.surfaceContainerHighest : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: cs.outlineVariant),
                ),
                child: Column(
                  children: [
                    if (_isEditing) ...[
                      _EditField(
                        controller: _nameCtrl,
                        label: 'Full Name',
                        icon: Icons.person_outline,
                        cs: cs,
                      ),
                      Divider(height: 1, color: cs.outlineVariant),
                      _EditField(
                        controller: _usernameCtrl,
                        label: 'Username',
                        icon: Icons.alternate_email,
                        cs: cs,
                        hint: 'e.g. john_doe',
                      ),
                      Divider(height: 1, color: cs.outlineVariant),
                      _EditField(
                        controller: _phoneCtrl,
                        label: 'Phone Number',
                        icon: Icons.phone_outlined,
                        cs: cs,
                        keyboardType: TextInputType.phone,
                        hint: 'e.g. +94771234567',
                      ),
                    ] else ...[
                      _InfoRow(icon: Icons.person_outline,       label: 'Name',     value: displayName,    cs: cs),
                      Divider(height: 1, color: cs.outlineVariant),
                      _InfoRow(icon: Icons.alternate_email,      label: 'Username', value: displayUsername.isNotEmpty ? '@$displayUsername' : '—', cs: cs),
                      Divider(height: 1, color: cs.outlineVariant),
                      _InfoRow(icon: Icons.email_outlined,       label: 'Email',    value: displayEmail,   cs: cs),
                      Divider(height: 1, color: cs.outlineVariant),
                      _InfoRow(icon: Icons.phone_outlined,       label: 'Phone',    value: displayPhone.isNotEmpty ? displayPhone : '—', cs: cs),
                      Divider(height: 1, color: cs.outlineVariant),
                      _InfoRow(icon: Icons.public_outlined,      label: 'Country',  value: displayCountry.isNotEmpty ? displayCountry : '—', cs: cs),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Save button (edit mode)
              if (_isEditing) ...[
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF4F7D6A),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    onPressed: _isSaving ? null : _saveProfile,
                    icon: _isSaving
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.check),
                    label: Text(_isSaving ? 'Saving...' : 'Save Changes'),
                  ),
                ),
                const SizedBox(height: 20),
              ],

              // Upgrade button
              SizedBox(
                width: double.infinity,
                height: 48,
                child: FilledButton.icon(
                  onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Premium upgrade (UI only)')),
                  ),
                  icon: const Icon(Icons.workspace_premium_outlined),
                  label: const Text('Upgrade to Premium'),
                ),
              ),
              const SizedBox(height: 10),

              // Logout button
              SizedBox(
                width: double.infinity,
                height: 48,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: cs.error,
                    side: BorderSide(color: cs.error.withValues(alpha: 0.4)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  onPressed: () async {
                    await auth.logout();
                    widget.onLogout();
                  },
                  icon: const Icon(Icons.logout),
                  label: const Text('Log out'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.cs,
  });

  final IconData icon;
  final String label;
  final String value;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Icon(icon, size: 20, color: cs.primary),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(fontSize: 11, color: cs.onSurface.withValues(alpha: 0.55))),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _EditField extends StatelessWidget {
  const _EditField({
    required this.controller,
    required this.label,
    required this.icon,
    required this.cs,
    this.hint,
    this.keyboardType,
  });

  final TextEditingController controller;
  final String label;
  final IconData icon;
  final ColorScheme cs;
  final String? hint;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          prefixIcon: Icon(icon, size: 20, color: cs.primary),
          labelText: label,
          hintText: hint,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
          isDense: true,
        ),
      ),
    );
  }
}
