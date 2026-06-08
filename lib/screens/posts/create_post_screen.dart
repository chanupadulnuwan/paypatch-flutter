import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../providers/posts_provider.dart';
import '../../widgets/custom_alert.dart';

class CreatePostScreen extends StatefulWidget {
  final String groupId;
  final String groupName;

  const CreatePostScreen({
    super.key,
    required this.groupId,
    required this.groupName,
  });

  @override
  State<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends State<CreatePostScreen> {
  final _captionCtrl = TextEditingController();
  String? _imagePath;
  String _audience = 'group';
  bool _isSharing = false;

  @override
  void dispose() {
    _captionCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    final picker = ImagePicker();
    final file = await picker.pickImage(source: source, imageQuality: 85);
    if (file != null && mounted) {
      setState(() => _imagePath = file.path);
    }
  }

  void _showImagePicker() {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: const Text('Take Photo'),
              onTap: () { Navigator.pop(context); _pickImage(ImageSource.camera); },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from Gallery'),
              onTap: () { Navigator.pop(context); _pickImage(ImageSource.gallery); },
            ),
            if (_imagePath != null)
              ListTile(
                leading: Icon(Icons.delete_outline, color: Theme.of(context).colorScheme.error),
                title: Text('Remove Image', style: TextStyle(color: Theme.of(context).colorScheme.error)),
                onTap: () { Navigator.pop(context); setState(() => _imagePath = null); },
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _share() async {
    if (_captionCtrl.text.trim().isEmpty && _imagePath == null) {
      await showCustomAlert(context, 'Add a photo or caption to share a post.');
      return;
    }

    setState(() => _isSharing = true);

    final provider = Provider.of<PostsProvider>(context, listen: false);
    final post = await provider.createPost(
      groupId: widget.groupId,
      audience: _audience,
      caption: _captionCtrl.text.trim().isEmpty ? null : _captionCtrl.text.trim(),
      imagePath: _imagePath,
    );

    if (!mounted) return;
    setState(() => _isSharing = false);

    if (post != null) {
      Navigator.pop(context, true);
      await showCustomAlert(context, 'Your post has been shared!', isSuccess: true);
    } else {
      await showCustomAlert(
        context,
        provider.lastError ?? 'Failed to share post. Please try again.',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? cs.surface : Colors.white,
      appBar: AppBar(
        title: const Text('Share a Post'),
        backgroundColor: isDark ? cs.surface : null,
        foregroundColor: isDark ? cs.onSurface : null,
        elevation: 0,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF4F7D6A),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(horizontal: 20),
              ),
              onPressed: _isSharing ? null : _share,
              child: _isSharing
                  ? const SizedBox(
                      width: 16, height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Share'),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Group label
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF4F7D6A).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(Icons.groups_outlined, color: Color(0xFF4F7D6A), size: 18),
                const SizedBox(width: 8),
                Text(
                  'Posting from: ${widget.groupName}',
                  style: const TextStyle(color: Color(0xFF4F7D6A), fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Image section
          GestureDetector(
            onTap: _showImagePicker,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              height: _imagePath != null ? 240 : 140,
              decoration: BoxDecoration(
                color: isDark ? cs.surfaceContainerHighest : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: _imagePath != null ? const Color(0xFF4F7D6A) : cs.outlineVariant,
                  width: _imagePath != null ? 2 : 1,
                ),
              ),
              child: _imagePath != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(19),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          Image.file(File(_imagePath!), fit: BoxFit.cover),
                          Positioned(
                            top: 8, right: 8,
                            child: GestureDetector(
                              onTap: () => setState(() => _imagePath = null),
                              child: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.5),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.close, color: Colors.white, size: 16),
                              ),
                            ),
                          ),
                          Positioned(
                            bottom: 8, right: 8,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.5),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Text('Tap to change', style: TextStyle(color: Colors.white, fontSize: 11)),
                            ),
                          ),
                        ],
                      ),
                    )
                  : Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.add_photo_alternate_outlined, size: 40, color: cs.onSurface.withValues(alpha: 0.4)),
                        const SizedBox(height: 8),
                        Text('Add a photo (optional)', style: TextStyle(color: cs.onSurface.withValues(alpha: 0.5))),
                        const SizedBox(height: 4),
                        Text('Camera or Gallery', style: TextStyle(fontSize: 12, color: cs.onSurface.withValues(alpha: 0.35))),
                      ],
                    ),
            ),
          ),
          const SizedBox(height: 16),

          // Caption field
          TextField(
            controller: _captionCtrl,
            maxLines: 4,
            maxLength: 500,
            decoration: InputDecoration(
              hintText: "What's on your mind? (optional)",
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
              filled: true,
              fillColor: isDark ? cs.surfaceContainerHighest : Colors.grey.shade50,
            ),
          ),
          const SizedBox(height: 16),

          // Audience selector
          Text('Who can see this?', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _AudienceChip(
                  label: 'This Group Only',
                  icon: Icons.groups_outlined,
                  selected: _audience == 'group',
                  onTap: () => setState(() => _audience = 'group'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _AudienceChip(
                  label: 'All Friends',
                  icon: Icons.people_outline,
                  selected: _audience == 'friends',
                  onTap: () => setState(() => _audience = 'friends'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _audience == 'group'
                ? 'Only members of "${widget.groupName}" will see this post.'
                : 'All your friends across groups will see this post.',
            style: TextStyle(fontSize: 12, color: cs.onSurface.withValues(alpha: 0.55)),
          ),
          const SizedBox(height: 80),
        ],
      ),
    );
  }
}

class _AudienceChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _AudienceChip({required this.label, required this.icon, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF4F7D6A).withValues(alpha: 0.12) : cs.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? const Color(0xFF4F7D6A) : cs.outlineVariant,
            width: selected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(icon, color: selected ? const Color(0xFF4F7D6A) : cs.onSurface.withValues(alpha: 0.5), size: 24),
            const SizedBox(height: 6),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: selected ? const Color(0xFF4F7D6A) : cs.onSurface.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
