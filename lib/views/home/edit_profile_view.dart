import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../controllers/edit_profile_controller.dart';
import '../../core/constants/synk_colors.dart';
import '../../l10n/l10n.dart';
import '../../models/avatar_uploader.dart';
import '../../utils/custom_widgets/synk_feedback.dart';
import 'change_password_view.dart';
import 'widgets/change_email_bottom_sheet.dart';
import 'widgets/photo_options_sheet.dart';
import '../widgets/synk_date_picker.dart';

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
  // Display-only: the real password is never loaded.
  final TextEditingController _passwordController = TextEditingController(
    text: '••••••••',
  );

  String? _usernameError;
  bool _pageReady = false;

  // Only the age is stored, so a picked date that gives the same age would
  // otherwise not count as a change.
  String _originalBirthdayText = '';

  StreamSubscription<AuthState>? _authSubscription;

  @override
  void initState() {
    super.initState();

    _loadProfile();

    try {
      _authSubscription = Supabase.instance.client.auth.onAuthStateChange
          .listen((data) {
            if (!mounted) return;
            if (data.event == AuthChangeEvent.userUpdated) {
              _loadProfile();
            } else if (data.event == AuthChangeEvent.tokenRefreshed) {
              // Only the email can change here; keep other unsaved edits.
              _controller.syncEmailFromSession();
              setState(() => _emailController.text = _controller.email);
            }
          });
    } catch (_) {}
  }

  @override
  void dispose() {
    _nameController.dispose();
    _usernameController.dispose();
    _bioController.dispose();
    _birthdayController.dispose();
    _emailController.dispose();
    _passwordController.dispose();

    _authSubscription?.cancel();
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
        ? context.l10n.ageYears(_controller.age!)
        : '';
    _emailController.text = _controller.email;
    _originalBirthdayText = _birthdayController.text;

    setState(() {
      _pageReady = true;
    });
  }

  // ---------------------------------------------------------------------------
  // Unsaved changes
  // ---------------------------------------------------------------------------

  bool get _hasUnsavedChanges {
    return _controller.hasUnsavedChanges ||
        _birthdayController.text != _originalBirthdayText;
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

    // Oldest allowed: 65 years old
    final firstDate = DateTime(today.year - 65, today.month, today.day);

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

    final selectedDate = await showSynkDatePicker(
      context: context,
      initialDate: initialDate.isBefore(firstDate)
          ? firstDate
          : (initialDate.isAfter(lastDate) ? lastDate : initialDate),
      firstDate: firstDate,
      lastDate: lastDate,
      title: context.l10n.selectBirthday,
      confirmLabel: context.l10n.setBirthday,
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

  // Pull to refresh: reloads the session so an email change confirmed in
  // the browser shows up. Other unsaved edits are kept.
  Future<void> _refreshEmail() async {
    try {
      await Supabase.instance.client.auth.refreshSession();
    } catch (_) {}
    if (!mounted) return;
    _controller.syncEmailFromSession();
    setState(() => _emailController.text = _controller.email);
  }

  Future<void> _openChangeEmailSheet() async {
    final updated = await ChangeEmailBottomSheet.show(
      context,
      currentEmail: _controller.email,
      pendingEmail: _controller.newEmail,
    );

    if (updated == true && mounted) {
      await _loadProfile();
      if (mounted) {
        setState(() {});
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Back / exit
  // ---------------------------------------------------------------------------

  Future<bool> _confirmLeave() async {
    if (!_hasUnsavedChanges) {
      return true;
    }

    return SynkFeedback.confirmDiscardChanges(context);
  }

  Future<void> _handleBack() async {
    if (_controller.isSaving) {
      return;
    }

    FocusScope.of(context).unfocus();

    final canLeave = await _confirmLeave();

    if (!mounted || !canLeave) {
      return;
    }

    await _controller.discardPhotoChanges();
    if (!mounted) return;
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
      _showMessage(appL10n.pleaseEnterYourName);
      return;
    }

    // ---------------------------------------------------------
    // Birthday / Age validation
    // ---------------------------------------------------------

    if (_controller.age != null) {
      if (_controller.age! < 16 || _controller.age! > 65) {
        _showMessage(appL10n.adultMustBeBetween16And);
        return;
      }
    }

    // ---------------------------------------------------------
    // Email validation
    // ---------------------------------------------------------

    final emailRegex = RegExp(r'^[\w\-.]+@([\w-]+\.)+[\w-]{2,4}$');

    if (email.isEmpty) {
      _showMessage(appL10n.profileEmailRequired);
      return;
    }

    if (!emailRegex.hasMatch(email)) {
      _showMessage(appL10n.profileEmailInvalid);
      return;
    }

    // ---------------------------------------------------------
    // Nothing changed
    // ---------------------------------------------------------

    // Still confirm, so tapping Save always gives feedback.
    if (!_hasUnsavedChanges) {
      if (!mounted) {
        return;
      }

      await SynkFeedback.showSaved(context);

      if (mounted) {
        Navigator.of(context).pop();
      }
      return;
    }

    // Make sure controller has latest values.
    _controller.setName(name);
    _controller.setBio(bio);
    _controller.setEmail(email);

    // Read before saving: saving resets the "original" email.
    final emailChanged = email != _controller.email;

    try {
      await _controller.saveChanges();

      if (!mounted) {
        return;
      }

      await SynkFeedback.showSaved(
        context,
        message: emailChanged
            ? context.l10n.yourChangesHaveBeenSavedCheck
            : null,
      );

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

      _showMessage(context.l10n.unableToSaveYourChangesPlease);
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

  Future<void> _adjustPhoto() async {
    final message = await _controller.adjustPhoto();

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
    } else if (action == 'adjust') {
      await _adjustPhoto();
    } else if (action == 'remove') {
      await _removePhoto();
    }
  }

  // ---------------------------------------------------------------------------
  // Password
  // ---------------------------------------------------------------------------

  Future<void> _openChangePassword() async {
    FocusScope.of(context).unfocus();

    await Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const ChangePasswordView()));
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  void _showMessage(String message) {
    if (!mounted) {
      return;
    }

    SynkFeedback.showError(context, message);
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

        title: Text(
          context.l10n.editProfile,
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
              child: RefreshIndicator(
                color: SynkColors.orangeDark,
                backgroundColor: Colors.white,
                onRefresh: _refreshEmail,
                child: ListView(
                  // Lets the pull work even when the page fits on screen.
                  physics: const AlwaysScrollableScrollPhysics(),
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

                            PositionedDirectional(
                              end: -2,
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

                    Center(
                      child: Text(
                        context.l10n.tapToChangePhoto,
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
                    _buildFieldLabel(context.l10n.name),

                    const SizedBox(height: 8),

                    _buildTextField(
                      controller: _nameController,
                      hintText: context.l10n.yourName,
                      textInputAction: TextInputAction.next,
                      onChanged: _onNameChanged,
                    ),

                    const SizedBox(height: 22),

                    // -------------------------------------------------------------
                    // Username
                    // -------------------------------------------------------------
                    _buildFieldLabel(context.l10n.username),

                    const SizedBox(height: 8),

                    _buildTextField(
                      controller: _usernameController,
                      hintText: context.l10n.username,
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
                    _buildFieldLabel(context.l10n.bio),

                    const SizedBox(height: 8),

                    _buildTextField(
                      controller: _bioController,
                      hintText: context.l10n.tellPeopleABitAboutYourself,
                      maxLines: 4,
                      maxLength: 160,
                      textInputAction: TextInputAction.newline,
                      onChanged: _onBioChanged,
                    ),

                    const SizedBox(height: 22),

                    // -------------------------------------------------------------
                    // Birthday
                    // -------------------------------------------------------------
                    _buildFieldLabel(context.l10n.birthday),

                    const SizedBox(height: 8),

                    _buildTextField(
                      controller: _birthdayController,
                      hintText: context.l10n.birthdayHint,
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
                    _buildFieldLabel(context.l10n.email),

                    const SizedBox(height: 8),

                    _buildTextField(
                      controller: _emailController,
                      hintText: context.l10n.emailAddress,
                      readOnly: true,
                      onTap: isSaving ? null : _openChangeEmailSheet,
                      prefixIcon: const Icon(
                        Icons.mail_outline_rounded,
                        size: 18,
                        color: SynkColors.textSecondary,
                      ),
                      suffixIcon: const Icon(
                        Icons.edit_outlined,
                        size: 18,
                        color: SynkColors.textSecondary,
                      ),
                    ),

                    if (_controller.hasPendingEmailChange) ...[
                      const SizedBox(height: 8),
                      GestureDetector(
                        onTap: _openChangeEmailSheet,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFBD4B4)
                                .withValues(alpha: 0.35),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.info_outline_rounded,
                                size: 15,
                                color: SynkColors.orangeDark,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  context.l10n.awaitingConfirmationOn(
                                    _controller.newEmail ?? '',
                                  ),
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF8A3B00),
                                  ),
                                ),
                              ),
                              const Icon(
                                Icons.chevron_right_rounded,
                                size: 16,
                                color: Color(0xFF8A3B00),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],

                    const SizedBox(height: 22),

                    // -------------------------------------------------------------
                    // Password
                    // -------------------------------------------------------------
                    _buildFieldLabel(context.l10n.password),

                    const SizedBox(height: 8),

                    _buildTextField(
                      controller: _passwordController,
                      hintText: context.l10n.changePassword,
                      readOnly: true,
                      onTap: isSaving ? null : _openChangePassword,
                      prefixIcon: const Icon(
                        Icons.lock_outline_rounded,
                        size: 18,
                        color: SynkColors.textSecondary,
                      ),
                      suffixIcon: const Icon(
                        Icons.chevron_right_rounded,
                        color: SynkColors.textSecondary,
                      ),
                    ),

                    const SizedBox(height: 24),
                  ],
                ),
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
                      : Text(
                          context.l10n.saveChanges,
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
    Widget? suffixIcon,
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
            prefixIcon: prefixIcon != null
                ? Padding(
                    padding: const EdgeInsetsDirectional.only(
                      start: 14,
                      end: 8,
                    ),
                    child: prefixIcon,
                  )
                : null,
            prefixIconConstraints: const BoxConstraints(
              minWidth: 0,
              minHeight: 0,
            ),
            suffixIcon: suffixIcon,
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
            padding: const EdgeInsetsDirectional.only(start: 12),
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
