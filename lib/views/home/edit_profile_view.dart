import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../controllers/edit_profile_controller.dart';
import '../../core/constants/synk_colors.dart';
import '../../models/avatar_uploader.dart';
import 'widgets/age_editor_sheet.dart';
import 'widgets/editable_row.dart';
import 'widgets/field_editor_sheet.dart';
import 'widgets/photo_options_sheet.dart';

class EditProfileView extends StatefulWidget {
  const EditProfileView({super.key});

  @override
  State<EditProfileView> createState() => _EditProfileViewState();
}

class _EditProfileViewState extends State<EditProfileView> {
  final EditProfileController _controller = EditProfileController();

  @override
  void initState() {
    super.initState();
    _controller.loadProfile();
  }

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

  Future<void> _removePhoto() async {
    final message = await _controller.removePhoto();
    if (!mounted || message == null) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _openPhotoOptions() async {
    final action = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) =>
          PhotoOptionsSheet(hasPhoto: _controller.avatarImage != null),
    );

    if (action == null || !mounted) return;

    if (action == 'change') {
      await _changePhoto();
    } else if (action == 'remove') {
      await _removePhoto();
    }
  }

  Future<void> _editName() async {
    await _editField(
      title: 'Edit name',
      initialValue: (_controller.profile['full_name'] as String?) ?? '',
      hint: 'Your name',
      validator: (value) => value.trim().isEmpty ? 'Enter your name' : null,
      onSave: _controller.updateName,
    );
  }

  Future<void> _editBio() async {
    await _editField(
      title: 'Edit bio',
      initialValue: (_controller.profile['bio'] as String?) ?? '',
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
      helperText: "We'll send a confirmation link to your new address before it takes effect.",
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

  Future<void> _editAge() async {
    final currentAge = _controller.profile['age'];
    final age = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) =>
          AgeEditorSheet(currentAge: currentAge is int ? currentAge : null),
    );

    if (age == null || !mounted) return;

    try {
      await _controller.updateAge(age);
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
      builder: (sheetContext) => FieldEditorSheet(
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
      builder: (context, _) {
        if (_controller.isLoading && _controller.profile.isEmpty) {
          return const Scaffold(
            backgroundColor: SynkColors.background,
            body: Center(child: CircularProgressIndicator()),
          );
        }
        return _buildScaffold(context);
      },
    );
  }

  Widget _buildScaffold(BuildContext context) {
    final fullName = (_controller.profile['full_name'] as String?)?.trim();
    final bio = (_controller.profile['bio'] as String?)?.trim();
    final age = _controller.profile['age'];
    final email = _controller.email;
    final avatarImage = _controller.avatarImage;
    final displayImage = avatarImage ?? AvatarUploader.defaultImage;
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
                      onTap: isUploadingPhoto ? null : _openPhotoOptions,
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Container(
                            width: 96,
                            height: 96,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              image: DecorationImage(
                                image: displayImage,
                                fit: BoxFit.cover,
                              ),
                            ),
                            alignment: Alignment.center,
                            child: isUploadingPhoto
                                ? Container(
                                    decoration: const BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: Colors.black38,
                                    ),
                                    alignment: Alignment.center,
                                    child: const SizedBox(
                                      width: 26,
                                      height: 26,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.5,
                                        valueColor: AlwaysStoppedAnimation(
                                          Colors.white,
                                        ),
                                      ),
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
                        EditableRow(
                          label: 'Name',
                          value: (fullName?.isNotEmpty ?? false)
                              ? fullName!
                              : 'Add your name',
                          onEdit: _editName,
                        ),
                        const Divider(height: 1, indent: 20, endIndent: 20),
                        EditableRow(
                          label: 'Bio',
                          value: (bio?.isNotEmpty ?? false)
                              ? bio!
                              : 'Add a short bio',
                          onEdit: _editBio,
                        ),
                        const Divider(height: 1, indent: 20, endIndent: 20),
                        EditableRow(
                          label: 'Age',
                          value: age is int ? '$age yrs' : 'Add your age',
                          onEdit: _editAge,
                        ),
                        const Divider(height: 1, indent: 20, endIndent: 20),
                        EditableRow(
                          label: 'Email',
                          value: email,
                          onEdit: _editEmail,
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
