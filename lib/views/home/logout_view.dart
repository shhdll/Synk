import 'package:flutter/material.dart';

import '../../controllers/logout_controller.dart';
import '../../core/constants/synk_colors.dart';
import '../../core/constants/synk_icons.dart';
import '../../l10n/l10n.dart';
import '../welcome_view.dart';

class LogoutView extends StatefulWidget {
  const LogoutView({super.key});

  @override
  State<LogoutView> createState() => _LogoutViewState();
}

class _LogoutViewState extends State<LogoutView> {
  final LogoutController _controller = LogoutController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _confirmLogout() async {
    final success = await _controller.logout();
    if (!mounted) return;

    if (success) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const WelcomeView()),
        (route) => false,
      );
      return;
    }

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            _controller.errorMessage ?? context.l10n.unableToLogOut,
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SynkColors.background,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(4, 8, 20, 8),
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
                  Text(
                    context.l10n.logOut,
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
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.all(24),
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
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Container(
                                width: 52,
                                height: 52,
                                decoration: BoxDecoration(
                                  color: SynkColors.orangeDark.withValues(
                                    alpha: 0.12,
                                  ),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  SynkIcons.logout,
                                  color: SynkColors.orangeDark,
                                ),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                context.l10n.logOutOfSynk,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  color: SynkColors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                context.l10n.youllNeedToSignInAgain,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 14,
                                  height: 1.4,
                                  color: SynkColors.textSecondary.withValues(
                                    alpha: 0.9,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    AnimatedBuilder(
                      animation: _controller,
                      builder: (context, _) {
                        final isLoggingOut = _controller.isLoggingOut;
                        return SizedBox(
                          height: 52,
                          child: ElevatedButton.icon(
                            onPressed: isLoggingOut ? null : _confirmLogout,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: SynkColors.orangeDark,
                              disabledBackgroundColor: SynkColors.orangeDark
                                  .withValues(alpha: 0.6),
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            icon: isLoggingOut
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.5,
                                      valueColor: AlwaysStoppedAnimation(
                                        Colors.white,
                                      ),
                                    ),
                                  )
                                : const Icon(
                                    SynkIcons.logout,
                                    color: Colors.white,
                                  ),
                            label: Text(
                              context.l10n.logOut,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 52,
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: SynkColors.textSecondary,
                          side: BorderSide(
                            color: SynkColors.textSecondary.withValues(
                              alpha: 0.3,
                            ),
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: Text(
                          context.l10n.cancel,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
