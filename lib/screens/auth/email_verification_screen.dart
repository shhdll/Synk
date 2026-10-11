import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/constants/auth_constants.dart';
import '../../core/constants/synk_colors.dart';
import '../../views/home/main_shell.dart';
import '../../views/login_view.dart';

class EmailVerificationScreen extends StatefulWidget {
  final String email;
  final String? password;

  const EmailVerificationScreen({
    super.key,
    required this.email,
    this.password,
  });

  @override
  State<EmailVerificationScreen> createState() =>
      _EmailVerificationScreenState();
}

class _EmailVerificationScreenState extends State<EmailVerificationScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  // Supabase allows about 30 sign-in attempts per 5 minutes per IP.
  static const Duration _pollInterval = Duration(seconds: 15);

  StreamSubscription<AuthState>? _authSubscription;
  Timer? _cooldownTimer;
  Timer? _pollTimer;
  bool _isChecking = false;
  int _cooldownSeconds = 0;
  bool _isResending = false;

  // Set once a confirmed session arrives, so the stream listener and the
  // post-frame check cannot both navigate.
  bool _isCompleting = false;

  late final AnimationController _blobAnimationController;
  late final AnimationController _pulseAnimationController;
  late final Animation<double> _pulseScale;

  @override
  void initState() {
    super.initState();

    // Background floating blobs animation
    _blobAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat(reverse: true);

    // Glowing aura pulsing animation
    _pulseAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);

    _pulseScale = Tween<double>(begin: 1.0, end: 1.08).animate(
      CurvedAnimation(
        parent: _pulseAnimationController,
        curve: Curves.easeInOut,
      ),
    );

    WidgetsBinding.instance.addObserver(this);
    _startPolling();

    // Deep-link / auth state listener:
    // The synk.cc landing page opens io.supabase.synk://login-callback,
    // AuthDeepLinkHandler verifies the token and Supabase emits signedIn
    // with a session whose emailConfirmedAt is populated.
    try {
      _authSubscription = Supabase.instance.client.auth.onAuthStateChange
          .listen((data) {
            debugPrint(
              'EmailVerificationScreen: auth event ${data.event.name}, '
              'session=${data.session != null}, '
              'confirmed=${_isUserConfirmed(data.session?.user)}',
            );
            const completingEvents = {
              AuthChangeEvent.signedIn,
              AuthChangeEvent.tokenRefreshed,
              AuthChangeEvent.userUpdated,
              AuthChangeEvent.initialSession,
            };
            if (!completingEvents.contains(data.event)) return;
            final session = data.session;
            if (session != null && _isUserConfirmed(session.user)) {
              _handleConfirmedSession(session);
            }
          });

      // Check if session is already active AND confirmed (e.g. returning after web redirect)
      WidgetsBinding.instance.addPostFrameCallback((_) {
        try {
          final session = Supabase.instance.client.auth.currentSession;
          if (session != null && _isUserConfirmed(session.user)) {
            _handleConfirmedSession(session);
          }
        } catch (_) {}
      });
    } catch (_) {
      // Supabase is not initialized in widget test environment
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Coming back from the email app or the browser.
    if (state == AppLifecycleState.resumed) {
      _checkConfirmation();
      _startPolling();
    } else if (state == AppLifecycleState.paused) {
      _pollTimer?.cancel();
    }
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(_pollInterval, (_) => _checkConfirmation());
  }

  /// Asks Supabase whether the email has been confirmed yet. With
  /// [userInitiated] the user is told when it has not.
  Future<void> _checkConfirmation({bool userInitiated = false}) async {
    if (_isChecking || _isCompleting) return;
    setState(() => _isChecking = true);

    const notConfirmed = 'Not confirmed yet. Tap the link in the email first.';
    String message = notConfirmed;
    try {
      final auth = Supabase.instance.client.auth;
      Session? session;
      if (auth.currentSession != null) {
        session = (await auth.refreshSession()).session;
      } else if (widget.password != null && widget.password!.isNotEmpty) {
        session = (await auth.signInWithPassword(
          email: widget.email.trim(),
          password: widget.password!,
        )).session;
      } else {
        message = 'Already confirmed? Go back and sign in.';
      }

      debugPrint(
        'EmailVerificationScreen: check, session=${session != null}, '
        'confirmed=${_isUserConfirmed(session?.user)}',
      );
      if (session != null && _isUserConfirmed(session.user)) {
        if (mounted) setState(() => _isChecking = false);
        await _handleConfirmedSession(session);
        return;
      }
    } on AuthException catch (e) {
      debugPrint('EmailVerificationScreen: check failed: ${e.code} $e');
      if (e.code != 'email_not_confirmed') message = e.message;
    } catch (e) {
      debugPrint('EmailVerificationScreen: check failed: $e');
      message = 'Could not check right now. Please try again.';
    }

    if (!mounted) return;
    setState(() => _isChecking = false);
    if (!userInitiated) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pollTimer?.cancel();
    _authSubscription?.cancel();
    _cooldownTimer?.cancel();
    _blobAnimationController.dispose();
    _pulseAnimationController.dispose();
    super.dispose();
  }

  bool _isUserConfirmed(User? user) {
    if (user == null) return false;
    final confirmedAt = user.emailConfirmedAt;
    return confirmedAt != null && confirmedAt.isNotEmpty;
  }

  Future<void> _handleConfirmedSession(Session session) async {
    if (_isCompleting || !_isUserConfirmed(session.user)) return;

    _cooldownTimer?.cancel();
    _pollTimer?.cancel();
    setState(() {
      _isCompleting = true;
      _isResending = false;
      _cooldownSeconds = 0;
    });

    // Safety net: ensure profile row exists in public.users before entering MainShell
    await _ensureProfileExists(session.user);

    if (!mounted) return;
    debugPrint('EmailVerificationScreen: email confirmed, opening MainShell');
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const MainShell(isNewUser: true)),
      (route) => false,
    );
  }

  Future<void> _ensureProfileExists(User user) async {
    try {
      final existing = await Supabase.instance.client
          .from('users')
          .select('id')
          .eq('id', user.id)
          .maybeSingle();

      if (existing == null) {
        final meta = user.userMetadata ?? {};
        await Supabase.instance.client.from('users').upsert({
          'id': user.id,
          'email': user.email ?? widget.email,
          'username': meta['username'] ?? '',
          'full_name': meta['full_name'] ?? '',
          'age': meta['age'],
          'gender': meta['gender'],
          'interests': meta['interests'],
          'activity_type': meta['activity_type'],
          'location_preference': meta['location_preference'],
        });
      }
    } catch (e) {
      debugPrint('Notice: Error verifying or populating profile row: $e');
    }
  }

  Future<void> _handleResendEmail() async {
    if (_cooldownSeconds > 0 || _isResending) return;

    setState(() {
      _isResending = true;
    });

    try {
      await Supabase.instance.client.auth.resend(
        type: OtpType.signup,
        email: widget.email.trim(),
        emailRedirectTo: AuthConstants.emailRedirectUrl,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(
                Icons.check_circle_outline_rounded,
                color: Colors.white,
                size: 20,
              ),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Verification email resent! Please check your inbox.',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          backgroundColor: SynkColors.teal,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          duration: const Duration(seconds: 4),
        ),
      );

      setState(() {
        _cooldownSeconds = AuthConstants.resendCooldownSeconds;
      });

      _cooldownTimer?.cancel();
      _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (!mounted) {
          timer.cancel();
          return;
        }
        setState(() {
          if (_cooldownSeconds > 1) {
            _cooldownSeconds--;
          } else {
            _cooldownSeconds = 0;
            timer.cancel();
          }
        });
      });
    } on AuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e.message.isNotEmpty
                ? e.message
                : 'Failed to resend confirmation email.',
          ),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'An unexpected error occurred. Please try again.',
          ),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isResending = false;
        });
      }
    }
  }

  Future<void> _handleBackToSignIn() async {
    try {
      await Supabase.instance.client.auth.signOut();
    } catch (_) {}

    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginView()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _handleBackToSignIn();
      },
      child: Scaffold(
        backgroundColor: SynkColors.background,
        body: Stack(
          children: [
            // 1. Ambient animated background blobs matching Synk's identity
            AnimatedBuilder(
              animation: _blobAnimationController,
              builder: (context, _) {
                final anim = _blobAnimationController.value;
                return Stack(
                  children: [
                    Positioned(
                      top: -60 + (anim * 24),
                      left: -40 + (anim * 20),
                      child: _buildBlob(SynkColors.teal, 280),
                    ),
                    Positioned(
                      bottom: -80 - (anim * 28),
                      right: -50 - (anim * 18),
                      child: _buildBlob(SynkColors.orange, 320),
                    ),
                    Positioned(
                      top: size.height * 0.42 + (anim * 16),
                      right: 30 - (anim * 20),
                      child: _buildBlob(SynkColors.pink, 140),
                    ),
                  ],
                );
              },
            ),

            // 2. Backdrop blur
            Positioned.fill(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 55, sigmaY: 55),
                child: const SizedBox.expand(),
              ),
            ),

            // 3. Foreground content
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 12),

                    // Top Header: Logo + Brand
                    _buildHeader(),

                    const Spacer(flex: 2),

                    // Glowing Email Icon with aura
                    Center(
                      child: AnimatedBuilder(
                        animation: _pulseAnimationController,
                        builder: (context, child) {
                          return Transform.scale(
                            scale: _pulseScale.value,
                            child: child,
                          );
                        },
                        child: _buildGlowingMailBadge(),
                      ),
                    ),

                    const SizedBox(height: 32),

                    // Headline
                    const Text(
                      'Check your inbox',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 34,
                        fontWeight: FontWeight.w900,
                        height: 1.15,
                        letterSpacing: -1.2,
                        color: SynkColors.textPrimary,
                      ),
                    ),

                    const SizedBox(height: 12),

                    // Subtitle / Recipient highlight
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Text(
                        'We sent a confirmation link to:',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 15,
                          color: SynkColors.textSecondary.withValues(
                            alpha: 0.9,
                          ),
                          fontWeight: FontWeight.w500,
                          height: 1.4,
                        ),
                      ),
                    ),

                    const SizedBox(height: 10),

                    // Email Address Highlight Chip
                    Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.85),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: SynkColors.orange.withValues(alpha: 0.25),
                            width: 1.2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.04),
                              blurRadius: 10,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.alternate_email_rounded,
                              size: 16,
                              color: SynkColors.orangeDark,
                            ),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                widget.email,
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: SynkColors.textPrimary,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const Spacer(flex: 3),

                    // Primary Action: Resend Verification Email (with cooldown)
                    GestureDetector(
                      onTap:
                          (_cooldownSeconds > 0 ||
                              _isResending ||
                              _isCompleting)
                          ? null
                          : _handleResendEmail,
                      child: Container(
                        height: 56,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(28),
                          gradient: _cooldownSeconds > 0
                              ? null
                              : const LinearGradient(
                                  colors: [
                                    SynkColors.orange,
                                    SynkColors.orangeDark,
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                          color: _cooldownSeconds > 0
                              ? Colors.white.withValues(alpha: 0.85)
                              : null,
                          border: _cooldownSeconds > 0
                              ? Border.all(
                                  color: SynkColors.textSecondary.withValues(
                                    alpha: 0.15,
                                  ),
                                  width: 1.2,
                                )
                              : null,
                          boxShadow: [
                            BoxShadow(
                              color: _cooldownSeconds > 0
                                  ? Colors.black.withValues(alpha: 0.03)
                                  : SynkColors.orange.withValues(alpha: 0.40),
                              blurRadius: _cooldownSeconds > 0 ? 8 : 18,
                              offset: Offset(0, _cooldownSeconds > 0 ? 3 : 6),
                            ),
                          ],
                        ),
                        child: Center(
                          child: _isResending || _isCompleting
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.2,
                                    color: Colors.white,
                                  ),
                                )
                              : Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.refresh_rounded,
                                      size: 20,
                                      color: _cooldownSeconds > 0
                                          ? SynkColors.textSecondary
                                          : Colors.white,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      _cooldownSeconds > 0
                                          ? 'Resend in ${_cooldownSeconds}s'
                                          : 'Resend verification email',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                        color: _cooldownSeconds > 0
                                            ? SynkColors.textSecondary
                                            : Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 10),

                    // Checks with Supabase when the link did not open the app.
                    TextButton(
                      onPressed: _isChecking || _isCompleting
                          ? null
                          : () => _checkConfirmation(userInitiated: true),
                      style: TextButton.styleFrom(
                        foregroundColor: SynkColors.orangeDark,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _isChecking
                              ? const SizedBox(
                                  height: 16,
                                  width: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: SynkColors.orangeDark,
                                  ),
                                )
                              : const Icon(
                                  Icons.check_circle_outline_rounded,
                                  size: 18,
                                ),
                          const SizedBox(width: 6),
                          const Text(
                            "I've confirmed my email",
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Fallback Action: Back to Sign In
                    TextButton(
                      onPressed: _handleBackToSignIn,
                      style: TextButton.styleFrom(
                        foregroundColor: SynkColors.textSecondary,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.arrow_back_rounded, size: 16),
                          SizedBox(width: 6),
                          Text(
                            'Back to Sign In',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGlowingMailBadge() {
    return Container(
      width: 110,
      height: 110,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            SynkColors.orange.withValues(alpha: 0.28),
            SynkColors.pink.withValues(alpha: 0.12),
            Colors.transparent,
          ],
          stops: const [0.45, 0.75, 1.0],
        ),
      ),
      child: Center(
        child: Container(
          width: 82,
          height: 82,
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: SynkColors.orange.withValues(alpha: 0.35),
                blurRadius: 22,
                offset: const Offset(0, 8),
              ),
            ],
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.9),
              width: 2.5,
            ),
          ),
          child: Center(
            child: ShaderMask(
              shaderCallback: (bounds) => const LinearGradient(
                colors: [SynkColors.orange, SynkColors.orangeDark],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ).createShader(bounds),
              child: const Icon(
                Icons.mail_rounded,
                size: 44,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Image.asset(
            'assets/synk_logo_transparent.png',
            fit: BoxFit.contain,
          ),
        ),
        const SizedBox(width: 12),
        const Text(
          'Synk',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w900,
            color: SynkColors.textPrimary,
            letterSpacing: -0.5,
          ),
        ),
      ],
    );
  }

  Widget _buildBlob(Color color, double diameter) {
    return Container(
      width: diameter,
      height: diameter,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.65),
        shape: BoxShape.circle,
      ),
    );
  }
}
