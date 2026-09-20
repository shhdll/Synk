import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../controllers/edit_profile_controller.dart';
import '../../core/constants/synk_colors.dart';
import '../../models/avatar_uploader.dart';
import 'widgets/photo_options_sheet.dart';

class EditProfileView extends StatefulWidget {
  const EditProfileView({super.key});

  @override
  State<EditProfileView> createState() => _EditProfileViewState();
}

class _EditProfileViewState extends State<EditProfileView> {
  final EditProfileController _controller = EditProfileController();

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _bioController = TextEditingController();
  final TextEditingController _birthdayController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();

  String? _usernameError;
  bool _pageReady = false;

  @override
  void initState() {
    super.initState();

    _loadProfile();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _usernameController.dispose();
    _bioController.dispose();
    _birthdayController.dispose();
    _emailController.dispose();

    _controller.dispose();

    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Load
  // ---------------------------------------------------------------------------

  Future<void> _loadProfile() async {
    await _controller.loadProfile();

    if (!mounted) {
      return;
    }

    _nameController.text = _controller.name;
    _usernameController.text = _controller.username;
    _bioController.text = _controller.bio;
    _birthdayController.text = _controller.age != null
        ? '${_controller.age} yrs'
        : '';
    _emailController.text = _controller.email;

    setState(() {
      _pageReady = true;
    });
  }

  // ---------------------------------------------------------------------------
  // Unsaved changes
  // ---------------------------------------------------------------------------

  bool get _hasUnsavedChanges {
    return _controller.hasUnsavedChanges;
  }

  // ---------------------------------------------------------------------------
  // Update controller drafts
  // ---------------------------------------------------------------------------

  void _onNameChanged(String value) {
    _controller.setName(value);
  }

  void _onUsernameChanged(String value) {
    if (_usernameError != null) {
      setState(() {
        _usernameError = null;
      });
    }
    _controller.setUsername(value);
  }

  void _onBioChanged(String value) {
    _controller.setBio(value);
  }

  Future<void> _pickBirthday() async {
    final today = DateTime.now();

    // Oldest allowed: 90 years old
    final firstDate = DateTime(today.year - 90, today.month, today.day);

    // Youngest allowed: 16 years old
    final lastDate = DateTime(today.year - 16, today.month, today.day);

    DateTime initialDate = DateTime(
      today.year - (_controller.age ?? 21),
      today.month,
      today.day,
    );

    if (_birthdayController.text.isNotEmpty &&
        _birthdayController.text.contains('/')) {
      try {
        final parts = _birthdayController.text.split('/');
        if (parts.length == 3) {
          final day = int.parse(parts[0]);
          final month = int.parse(parts[1]);
          final year = int.parse(parts[2]);

          final existingDate = DateTime(year, month, day);
          if (!existingDate.isBefore(firstDate) &&
              !existingDate.isAfter(lastDate)) {
            initialDate = existingDate;
          }
        }
      } catch (_) {}
    }

    final selectedDate = await showDatePicker(
      context: context,
      initialDate: initialDate.isBefore(firstDate)
          ? firstDate
          : (initialDate.isAfter(lastDate) ? lastDate : initialDate),
      firstDate: firstDate,
      lastDate: lastDate,
      helpText: 'Select birthday',
    );

    if (selectedDate != null) {
      var age = today.year - selectedDate.year;
      if (today.month < selectedDate.month ||
          (today.month == selectedDate.month && today.day < selectedDate.day)) {
        age--;
      }

      final day = selectedDate.day.toString().padLeft(2, '0');
      final month = selectedDate.month.toString().padLeft(2, '0');
      final formatted = '$day/$month/${selectedDate.year}';

      setState(() {
        _birthdayController.text = formatted;
      });
      _controller.setAge(age.toString());
    }
  }

  void _onEmailChanged(String value) {
    _controller.setEmail(value);
  }

  // ---------------------------------------------------------------------------
  // Back / exit
  // ---------------------------------------------------------------------------

  Future<bool> _confirmLeave() async {
    if (!_hasUnsavedChanges) {
      return true;
    }

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: SynkColors.background,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
          title: const Text(
            'Leave without saving?',
            style: TextStyle(
              color: SynkColors.textPrimary,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          content: const Text(
            'You have unsaved changes. If you leave now, '
            'your changes will be lost.',
            style: TextStyle(
              color: SynkColors.textSecondary,
              fontSize: 14,
              height: 1.5,
            ),
          ),
          actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(false);
              },
              child: const Text(
                'Keep editing',
                style: TextStyle(
                  color: SynkColors.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(true);
              },
              child: const Text(
                'Leave',
                style: TextStyle(
                  color: SynkColors.orangeDark,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        );
      },
    );

    return result ?? false;
  }

  Future<void> _handleBack() async {
    FocusScope.of(context).unfocus();

    final canLeave = await _confirmLeave();

    if (!mounted || !canLeave) {
      return;
    }

    Navigator.of(context).pop();
  }

  // ---------------------------------------------------------------------------
  // Save
  // ---------------------------------------------------------------------------

  Future<void> _saveChanges() async {
    FocusScope.of(context).unfocus();

    // ---------------------------------------------------------
    // Username validation & uniqueness check
    // ---------------------------------------------------------

    final usernameError = await _controller.updateUsername(
      _usernameController.text.trim(),
    );

    if (usernameError != null) {
      setState(() {
        _usernameError = usernameError;
      });
      return;
    } else if (_usernameError != null) {
      setState(() {
        _usernameError = null;
      });
    }

    final name = _nameController.text.trim();
    final bio = _bioController.text.trim();
    final email = _emailController.text.trim();

    // ---------------------------------------------------------
    // Name validation
    // ---------------------------------------------------------

    if (name.isEmpty) {
      _showMessage('Please enter your name.');
      return;
    }

    // ---------------------------------------------------------
    // Birthday / Age validation
    // ---------------------------------------------------------

    if (_controller.age != null) {
      if (_controller.age! < 16 || _controller.age! > 90) {
        _showMessage('Adult must be between 16 and 90 years old.');
        return;
      }
    }

    // ---------------------------------------------------------
    // Email validation
    // ---------------------------------------------------------

    final emailRegex = RegExp(r'^[\w\-.]+@([\w-]+\.)+[\w-]{2,4}$');

    if (email.isEmpty) {
      _showMessage('Please enter your email.');
      return;
    }

    if (!emailRegex.hasMatch(email)) {
      _showMessage('Please enter a valid email address.');
      return;
    }

    // ---------------------------------------------------------
    // Nothing changed
    // ---------------------------------------------------------

    if (!_hasUnsavedChanges) {
      if (mounted) {
        Navigator.of(context).pop();
      }
      return;
    }

    // Make sure controller has latest values.
    _controller.setName(name);
    _controller.setBio(bio);
    _controller.setEmail(email);

    try {
      await _controller.saveChanges();

      if (!mounted) {
        return;
      }

      _showMessage('Profile updated successfully.');

      // Give the snackbar a moment to appear before leaving.
      await Future<void>.delayed(const Duration(milliseconds: 350));

      if (!mounted) {
        return;
      }

      Navigator.of(context).pop();
    } on AuthException catch (e) {
      if (!mounted) {
        return;
      }

      _showMessage(e.message);
    } catch (_) {
      if (!mounted) {
        return;
      }

      _showMessage('Unable to save your changes. Please try again.');
    }
  }

  // ---------------------------------------------------------------------------
  // Photo
  // ---------------------------------------------------------------------------

  Future<void> _changePhoto() async {
    final message = await _controller.changePhoto();

    if (!mounted || message == null) {
      return;
    }

    _showMessage(message);
  }

  Future<void> _removePhoto() async {
    final message = await _controller.removePhoto();

    if (!mounted || message == null) {
      return;
    }

    _showMessage(message);
  }

  Future<void> _openPhotoOptions() async {
    final action = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return PhotoOptionsSheet(hasPhoto: _controller.avatarImage != null);
      },
    );

    if (action == null || !mounted) {
      return;
    }

    if (action == 'change') {
      await _changePhoto();
    } else if (action == 'remove') {
      await _removePhoto();
    }
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  void _showMessage(String message) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        if (!_pageReady || _controller.isLoading) {
          return const Scaffold(
            backgroundColor: SynkColors.background,
            body: Center(child: CircularProgressIndicator()),
          );
        }

        return PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, result) async {
            if (didPop) {
              return;
            }

            await _handleBack();
          },
          child: _buildScaffold(),
        );
      },
    );
  }

  Widget _buildScaffold() {
    final avatarImage = _controller.avatarImage;

    final displayImage =
        avatarImage ?? AvatarUploader.defaultImageForGender(_controller.gender);

    final isUploadingPhoto = _controller.isUploadingPhoto;

    final isSaving = _controller.isSaving;

    return Scaffold(
      backgroundColor: SynkColors.background,

      // -----------------------------------------------------------------------
      // App bar
      // -----------------------------------------------------------------------
      appBar: AppBar(
        backgroundColor: SynkColors.background,
        elevation: 0,
        surfaceTintColor: Colors.transparent,

        leading: IconButton(
          onPressed: isSaving ? null : _handleBack,
          icon: const Icon(
            Icons.arrow_back_rounded,
            color: SynkColors.textPrimary,
          ),
        ),

        title: const Text(
          'Edit Profile',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.6,
            color: SynkColors.textPrimary,
          ),
        ),

        centerTitle: true,
      ),

      // -----------------------------------------------------------------------
      // Body
      // -----------------------------------------------------------------------
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
                children: [
                  // -------------------------------------------------------------
                  // Profile photo
                  // -------------------------------------------------------------

                  Center(
                    child: GestureDetector(
                      onTap: isUploadingPhoto ? null : _openPhotoOptions,
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Container(
                            width: 104,
                            height: 104,
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
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
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
                              padding: const EdgeInsets.all(8),
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
                                size: 17,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 10),

                  const Center(
                    child: Text(
                      'Tap to change photo',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: SynkColors.textSecondary,
                      ),
                    ),
                  ),

                  const SizedBox(height: 30),

                  // -------------------------------------------------------------
                  // Name
                  // -------------------------------------------------------------
                  _buildFieldLabel('Name'),

                  const SizedBox(height: 8),

                  _buildTextField(
                    controller: _nameController,
                    hintText: 'Your name',
                    textInputAction: TextInputAction.next,
                    onChanged: _onNameChanged,
                  ),

                  const SizedBox(height: 22),

                  // -------------------------------------------------------------
                  // Username
                  // -------------------------------------------------------------
                  _buildFieldLabel('Username'),

                  const SizedBox(height: 8),

                  _buildTextField(
                    controller: _usernameController,
                    hintText: 'alex_99',
                    prefixIcon: const Icon(
                      Icons.alternate_email_rounded,
                      size: 18,
                      color: SynkColors.textSecondary,
                    ),
                    errorText: _usernameError,
                    textInputAction: TextInputAction.next,
                    onChanged: _onUsernameChanged,
                  ),

                  const SizedBox(height: 22),

                  // -------------------------------------------------------------
                  // Bio
                  // -------------------------------------------------------------
                  _buildFieldLabel('Bio'),

                  const SizedBox(height: 8),

                  _buildTextField(
                    controller: _bioController,
                    hintText: 'Tell people a bit about yourself...',
                    maxLines: 4,
                    maxLength: 160,
                    textInputAction: TextInputAction.newline,
                    onChanged: _onBioChanged,
                  ),

                  const SizedBox(height: 22),

                  // -------------------------------------------------------------
                  // Birthday
                  // -------------------------------------------------------------
                  _buildFieldLabel('Birthday'),

                  const SizedBox(height: 8),

                  _buildTextField(
                    controller: _birthdayController,
                    hintText: 'DD/MM/YYYY',
                    readOnly: true,
                    onTap: _pickBirthday,
                    prefixIcon: const Icon(
                      Icons.cake_outlined,
                      color: SynkColors.textSecondary,
                    ),
                  ),

                  const SizedBox(height: 22),

                  // -------------------------------------------------------------
                  // Email
                  // -------------------------------------------------------------
                  _buildFieldLabel('Email'),

                  const SizedBox(height: 8),

                  _buildTextField(
                    controller: _emailController,
                    hintText: 'you@example.com',
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.done,
                    onChanged: _onEmailChanged,
                  ),

                  const SizedBox(height: 12),

                  const Text(
                    'If you change your email, Supabase '
                    'will send a confirmation link to '
                    'the new address.',
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.4,
                      color: SynkColors.textSecondary,
                    ),
                  ),

                  const SizedBox(height: 24),
                ],
              ),
            ),

            // -----------------------------------------------------------------
            // ONE SAVE BUTTON FOR THE WHOLE PAGE
            // -----------------------------------------------------------------
            Container(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
              decoration: BoxDecoration(
                color: SynkColors.background,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 12,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: isSaving ? null : _saveChanges,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: SynkColors.orangeDark,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: SynkColors.orangeDark.withValues(
                      alpha: 0.45,
                    ),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(17),
                    ),
                  ),
                  child: isSaving
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                        )
                      : const Text(
                          'Save changes',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Field label
  // ---------------------------------------------------------------------------

  Widget _buildFieldLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w800,
        color: SynkColors.textPrimary,
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Text field
  // ---------------------------------------------------------------------------

  Widget _buildTextField({
    required TextEditingController controller,
    required String hintText,
    ValueChanged<String>? onChanged,
    TextInputType? keyboardType,
    TextInputAction? textInputAction,
    int maxLines = 1,
    int? maxLength,
    String? errorText,
    Widget? prefixIcon,
    bool readOnly = false,
    VoidCallback? onTap,
  }) {
    final hasError = errorText != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: controller,
          onChanged: onChanged,
          readOnly: readOnly,
          onTap: onTap,
          keyboardType: keyboardType,
          textInputAction: textInputAction,
          maxLines: maxLines,
          maxLength: maxLength,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w500,
            color: SynkColors.textPrimary,
          ),
          decoration: InputDecoration(
            prefixIcon: prefixIcon,
            hintText: hintText,
            hintStyle: const TextStyle(color: SynkColors.textSecondary),
            filled: true,
            fillColor: Colors.white.withValues(alpha: 0.55),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 15,
            ),
            counterStyle: const TextStyle(
              color: SynkColors.textSecondary,
              fontSize: 11,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(
                color: hasError
                    ? const Color(0xFFE53935)
                    : SynkColors.textSecondary.withValues(alpha: 0.15),
                width: hasError ? 1.5 : 1.0,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(
                color: hasError
                    ? const Color(0xFFE53935)
                    : SynkColors.textSecondary.withValues(alpha: 0.15),
                width: hasError ? 1.5 : 1.0,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(
                color: hasError
                    ? const Color(0xFFE53935)
                    : SynkColors.orangeDark,
                width: 1.5,
              ),
            ),
          ),
        ),
        if (hasError) ...[
          const SizedBox(height: 5),
          Padding(
            padding: const EdgeInsets.only(left: 12),
            child: Text(
              errorText,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFFE53935),
              ),
            ),
          ),
        ],
      ],
    );
  }
}
