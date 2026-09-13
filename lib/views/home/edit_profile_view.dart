import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../controllers/edit_profile_controller.dart';
import '../../core/constants/synk_colors.dart';
import 'change_password_view.dart';

class EditProfileView extends StatefulWidget {
  const EditProfileView({super.key});

  @override
  State<EditProfileView> createState() => _EditProfileViewState();
}

class _EditProfileViewState extends State<EditProfileView> {
  final EditProfileController _controller = EditProfileController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _changePhoto() async {
    final message = await _controller.changePhoto();
    if (!mounted || message == null) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _editName() async {
    await _editField(
      title: 'Edit name',
      initialValue: (_controller.metadata['full_name'] as String?) ?? '',
      hint: 'Your name',
      validator: (value) =>
          value.trim().isEmpty ? 'Enter your name' : null,
      onSave: _controller.updateName,
    );
  }

  Future<void> _editBio() async {
    await _editField(
      title: 'Edit bio',
      initialValue: (_controller.metadata['bio'] as String?) ?? '',
      hint: 'Tell people a bit about yourself...',
      maxLines: 4,
      maxLength: 160,
      onSave: _controller.updateBio,
    );
  }

  Future<void> _editEmail() async {
    final currentEmail = _controller.email;
    await _editField(
      title: 'Edit email',
      initialValue: currentEmail,
      hint: 'you@example.com',
      keyboardType: TextInputType.emailAddress,
      helperText:
          "We'll send a confirmation link to your new address before it takes effect.",
      validator: (value) {
        final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
        if (value.trim().isEmpty) return 'Enter your email';
        if (!emailRegex.hasMatch(value.trim())) {
          return 'Enter a valid email address';
        }
        return null;
      },
      onSave: _controller.updateEmail,
      successMessage: 'Check your new email to confirm the change.',
    );
  }

  Future<void> _openChangePassword() async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (context) => const ChangePasswordView()));
  }

  // Shared bottom-sheet editor for a single text field (name, bio, email).
  Future<void> _editField({
    required String title,
    required String initialValue,
    required String hint,
    required Future<void> Function(String value) onSave,
    String? Function(String value)? validator,
    String? helperText,
    String? successMessage,
    TextInputType? keyboardType,
    int maxLines = 1,
    int? maxLength,
  }) async {
    final controller = TextEditingController(text: initialValue);
    final formKey = GlobalKey<FormState>();

    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => _FieldEditorSheet(
        title: title,
        controller: controller,
        hint: hint,
        formKey: formKey,
        validator: validator,
        helperText: helperText,
        keyboardType: keyboardType,
        maxLines: maxLines,
        maxLength: maxLength,
      ),
    );

    if (saved != true || !mounted) return;

    try {
      await onSave(controller.text.trim());
      if (mounted && successMessage != null) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(successMessage)));
      }
    } on AuthException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(e.message)));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            const SnackBar(content: Text('Unable to save. Please try again.')),
          );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) => _buildScaffold(context),
    );
  }

  Widget _buildScaffold(BuildContext context) {
    final fullName = (_controller.metadata['full_name'] as String?)?.trim();
    final bio = (_controller.metadata['bio'] as String?)?.trim();
    final email = _controller.email;
    final avatarImage = _controller.avatarImage;
    final isUploadingPhoto = _controller.isUploadingPhoto;

    return Scaffold(
      backgroundColor: SynkColors.background,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 8, 20, 8),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(
                      Icons.arrow_back_rounded,
                      color: SynkColors.textPrimary,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Text(
                    'Edit Profile',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.6,
                      color: SynkColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                children: [
                  Center(
                    child: GestureDetector(
                      onTap: isUploadingPhoto ? null : _changePhoto,
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Container(
                            width: 96,
                            height: 96,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: avatarImage == null
                                  ? const LinearGradient(
                                      colors: [
                                        SynkColors.orange,
                                        SynkColors.orangeDark,
                                      ],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    )
                                  : null,
                              image: avatarImage != null
                                  ? DecorationImage(
                                      image: avatarImage,
                                      fit: BoxFit.cover,
                                    )
                                  : null,
                            ),
                            alignment: Alignment.center,
                            child: isUploadingPhoto
                                ? const SizedBox(
                                    width: 26,
                                    height: 26,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.5,
                                      valueColor: AlwaysStoppedAnimation(
                                        Colors.white,
                                      ),
                                    ),
                                  )
                                : avatarImage == null
                                ? Text(
                                    (fullName?.isNotEmpty ?? false)
                                        ? fullName![0].toUpperCase()
                                        : '?',
                                    style: const TextStyle(
                                      fontSize: 34,
                                      fontWeight: FontWeight.w900,
                                      color: Colors.white,
                                    ),
                                  )
                                : null,
                          ),
                          Positioned(
                            right: -2,
                            bottom: -2,
                            child: Container(
                              padding: const EdgeInsets.all(7),
                              decoration: BoxDecoration(
                                color: SynkColors.orangeDark,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: SynkColors.background,
                                  width: 3,
                                ),
                              ),
                              child: const Icon(
                                Icons.camera_alt_rounded,
                                size: 16,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Center(
                    child: Text(
                      'Tap to change photo',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: SynkColors.textSecondary.withValues(alpha: 0.8),
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 14,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        _EditableRow(
                          label: 'Name',
                          value: (fullName?.isNotEmpty ?? false)
                              ? fullName!
                              : 'Add your name',
                          onEdit: _editName,
                        ),
                        const Divider(height: 1, indent: 20, endIndent: 20),
                        _EditableRow(
                          label: 'Bio',
                          value: (bio?.isNotEmpty ?? false)
                              ? bio!
                              : 'Add a short bio',
                          onEdit: _editBio,
                        ),
                        const Divider(height: 1, indent: 20, endIndent: 20),
                        _EditableRow(
                          label: 'Email',
                          value: email,
                          onEdit: _editEmail,
                        ),
                        const Divider(height: 1, indent: 20, endIndent: 20),
                        _EditableRow(
                          label: 'Password',
                          value: '••••••••',
                          onEdit: _openChangePassword,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EditableRow extends StatelessWidget {
  const _EditableRow({
    required this.label,
    required this.value,
    required this.onEdit,
  });

  final String label;
  final String value;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 12, 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: SynkColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: SynkColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onEdit,
            icon: const Icon(
              Icons.edit_rounded,
              size: 18,
              color: SynkColors.orangeDark,
            ),
          ),
        ],
      ),
    );
  }
}

class _FieldEditorSheet extends StatelessWidget {
  const _FieldEditorSheet({
    required this.title,
    required this.controller,
    required this.hint,
    required this.formKey,
    this.validator,
    this.helperText,
    this.keyboardType,
    this.maxLines = 1,
    this.maxLength,
  });

  final String title;
  final TextEditingController controller;
  final String hint;
  final GlobalKey<FormState> formKey;
  final String? Function(String value)? validator;
  final String? helperText;
  final TextInputType? keyboardType;
  final int maxLines;
  final int? maxLength;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
        decoration: const BoxDecoration(
          color: SynkColors.background,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 18),
                  decoration: BoxDecoration(
                    color: SynkColors.textSecondary.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: SynkColors.textPrimary,
                ),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: controller,
                autofocus: true,
                maxLines: maxLines,
                maxLength: maxLength,
                keyboardType: keyboardType,
                validator: validator == null
                    ? null
                    : (value) => validator!(value ?? ''),
                style: const TextStyle(
                  fontSize: 14,
                  color: SynkColors.textPrimary,
                ),
                decoration: InputDecoration(
                  hintText: hint,
                  hintStyle: const TextStyle(color: SynkColors.textSecondary),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                ),
              ),
              if (helperText != null) ...[
                const SizedBox(height: 6),
                Text(
                  helperText!,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: SynkColors.textSecondary.withValues(alpha: 0.85),
                    height: 1.3,
                  ),
                ),
              ],
              const SizedBox(height: 12),
              SizedBox(
                height: 52,
                child: ElevatedButton(
                  onPressed: () {
                    if (formKey.currentState?.validate() ?? true) {
                      Navigator.of(context).pop(true);
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: SynkColors.orangeDark,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Text(
                    'Save',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
