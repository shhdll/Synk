import 'package:flutter/material.dart';

import '../../controllers/change_password_controller.dart';
import '../../core/constants/synk_colors.dart';
import '../../l10n/l10n.dart';
import '../../utils/custom_widgets/synk_feedback.dart';

class ChangePasswordView extends StatefulWidget {
  const ChangePasswordView({super.key});

  @override
  State<ChangePasswordView> createState() => _ChangePasswordViewState();
}

class _ChangePasswordViewState extends State<ChangePasswordView> {
  final ChangePasswordController _controller = ChangePasswordController();

  final TextEditingController _currentController = TextEditingController();
  final TextEditingController _newController = TextEditingController();
  final TextEditingController _confirmController = TextEditingController();

  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;

  String? _currentError;
  String? _newError;
  String? _confirmError;

  @override
  void dispose() {
    _currentController.dispose();
    _newController.dispose();
    _confirmController.dispose();

    _controller.dispose();

    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Back / exit
  // ---------------------------------------------------------------------------

  bool get _hasUnsavedChanges =>
      _currentController.text.isNotEmpty ||
      _newController.text.isNotEmpty ||
      _confirmController.text.isNotEmpty;

  Future<void> _handleBack() async {
    if (_controller.isLoading) {
      return;
    }

    FocusScope.of(context).unfocus();

    if (_hasUnsavedChanges &&
        !await SynkFeedback.confirmDiscardChanges(context)) {
      return;
    }

    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  // ---------------------------------------------------------------------------
  // Submit
  // ---------------------------------------------------------------------------

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();

    final current = _currentController.text;
    final newPassword = _newController.text;
    final confirm = _confirmController.text;

    setState(() {
      _currentError = _controller.validateCurrentPassword(current);
      _newError = _controller.validateNewPassword(newPassword, current);
      _confirmError = _controller.validateConfirmPassword(confirm, newPassword);
    });

    if (_currentError != null || _newError != null || _confirmError != null) {
      return;
    }

    final success = await _controller.changePassword(
      currentPassword: current,
      newPassword: newPassword,
    );

    if (!mounted) {
      return;
    }

    if (success) {
      await SynkFeedback.showSaved(context);
      if (mounted) {
        Navigator.of(context).pop();
      }
      return;
    }

    final message = _controller.errorMessage;
    switch (_controller.errorField) {
      case ChangePasswordErrorField.current:
        setState(() => _currentError = message);
      case ChangePasswordErrorField.newPassword:
        setState(() => _newError = message);
      case ChangePasswordErrorField.general:
        if (message != null) {
          SynkFeedback.showError(context, message);
        }
    }
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final isLoading = _controller.isLoading;

        return PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, result) async {
            if (didPop) {
              return;
            }

            await _handleBack();
          },
          child: Scaffold(
            backgroundColor: SynkColors.background,
            appBar: AppBar(
              backgroundColor: SynkColors.background,
              elevation: 0,
              surfaceTintColor: Colors.transparent,
              leading: IconButton(
                onPressed: isLoading ? null : _handleBack,
                icon: const Icon(
                  Icons.arrow_back_rounded,
                  color: SynkColors.textPrimary,
                ),
              ),
              title: Text(
                context.l10n.changePasswordTitle,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.6,
                  color: SynkColors.textPrimary,
                ),
              ),
              centerTitle: true,
            ),
            body: SafeArea(
              child: Column(
                children: [
                  Expanded(
                    child: ListView(
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
                      children: [
                        _buildFieldLabel(context.l10n.currentPassword),
                        const SizedBox(height: 8),
                        _buildPasswordField(
                          controller: _currentController,
                          hintText: context.l10n.enterYourCurrentPassword,
                          obscure: _obscureCurrent,
                          onToggle: () => setState(
                            () => _obscureCurrent = !_obscureCurrent,
                          ),
                          errorText: _currentError,
                          onChanged: (_) {
                            if (_currentError != null) {
                              setState(() => _currentError = null);
                            }
                          },
                          textInputAction: TextInputAction.next,
                        ),

                        const SizedBox(height: 22),

                        _buildFieldLabel(context.l10n.newPassword),
                        const SizedBox(height: 8),
                        _buildPasswordField(
                          controller: _newController,
                          hintText: context.l10n.enterANewPassword,
                          obscure: _obscureNew,
                          onToggle: () =>
                              setState(() => _obscureNew = !_obscureNew),
                          errorText: _newError,
                          onChanged: (_) {
                            if (_newError != null) {
                              setState(() => _newError = null);
                            }
                          },
                          textInputAction: TextInputAction.next,
                        ),

                        const SizedBox(height: 22),

                        _buildFieldLabel(context.l10n.confirmNewPassword),
                        const SizedBox(height: 8),
                        _buildPasswordField(
                          controller: _confirmController,
                          hintText: context.l10n.reEnterTheNewPassword,
                          obscure: _obscureConfirm,
                          onToggle: () => setState(
                            () => _obscureConfirm = !_obscureConfirm,
                          ),
                          errorText: _confirmError,
                          onChanged: (_) {
                            if (_confirmError != null) {
                              setState(() => _confirmError = null);
                            }
                          },
                          textInputAction: TextInputAction.done,
                          onSubmitted: (_) => _submit(),
                        ),

                        const SizedBox(height: 12),

                        Text(
                          context.l10n.useAtLeast8CharactersWith,
                          style: TextStyle(
                            fontSize: 12,
                            height: 1.4,
                            color: SynkColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),

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
                        onPressed: isLoading ? null : _submit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: SynkColors.orangeDark,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: SynkColors.orangeDark
                              .withValues(alpha: 0.45),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(17),
                          ),
                        ),
                        child: isLoading
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
                                context.l10n.updatePassword,
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
          ),
        );
      },
    );
  }

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

  Widget _buildPasswordField({
    required TextEditingController controller,
    required String hintText,
    required bool obscure,
    required VoidCallback onToggle,
    String? errorText,
    ValueChanged<String>? onChanged,
    ValueChanged<String>? onSubmitted,
    TextInputAction? textInputAction,
  }) {
    final hasError = errorText != null;
    final borderColor = hasError
        ? const Color(0xFFE53935)
        : SynkColors.textSecondary.withValues(alpha: 0.15);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: controller,
          obscureText: obscure,
          enableSuggestions: false,
          autocorrect: false,
          onChanged: onChanged,
          onSubmitted: onSubmitted,
          textInputAction: textInputAction,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w500,
            color: SynkColors.textPrimary,
          ),
          decoration: InputDecoration(
            prefixIcon: const Padding(
              padding: EdgeInsetsDirectional.only(start: 14, end: 8),
              child: Icon(
                Icons.lock_outline_rounded,
                size: 18,
                color: SynkColors.textSecondary,
              ),
            ),
            prefixIconConstraints: const BoxConstraints(
              minWidth: 0,
              minHeight: 0,
            ),
            suffixIcon: IconButton(
              onPressed: onToggle,
              icon: Icon(
                obscure
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                size: 20,
                color: SynkColors.textSecondary,
              ),
            ),
            hintText: hintText,
            hintStyle: const TextStyle(color: SynkColors.textSecondary),
            filled: true,
            fillColor: Colors.white.withValues(alpha: 0.55),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 15,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(
                color: borderColor,
                width: hasError ? 1.5 : 1.0,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(
                color: borderColor,
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
