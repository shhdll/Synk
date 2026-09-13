import 'package:flutter/material.dart';

import '../controllers/home_controller.dart';
import '../core/constants/synk_colors.dart';

class HomeView extends StatefulWidget {
  // True when arriving straight from registration, so the greeting reads
  // as a first hello rather than a returning-user welcome.
  final bool isNewUser;

  const HomeView({super.key, this.isNewUser = false});

  @override
  State<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends State<HomeView> {
  final HomeController _homeController = HomeController();
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _homeController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  // Placeholder for sections that don't have a screen yet.
  void _showComingSoon(String feature) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            '$feature is coming soon.',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
          backgroundColor: SynkColors.textPrimary,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(20),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      );
  }

  Widget _navIcon({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
    bool selected = false,
  }) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: 48,
        height: 48,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected
              ? SynkColors.orange.withValues(alpha: 0.18)
              : Colors.transparent,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: SynkColors.textSecondary, size: 26),
      ),
    );
  }

  Widget _buildBottomNav() {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      child: BottomAppBar(
        color: Colors.white,
        shape: const CircularNotchedRectangle(),
        notchMargin: 8,
        height: 64,
        padding: EdgeInsets.zero,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _navIcon(
              icon: Icons.person_outline_rounded,
              label: 'Profile',
              onPressed: () => _showComingSoon('Profile'),
            ),
            _navIcon(
              icon: Icons.location_on_outlined,
              label: 'Location',
              onPressed: () => _showComingSoon('Location'),
            ),
            const SizedBox(width: 64), // Space for the notched button.
            _navIcon(
              icon: Icons.calendar_today_outlined,
              label: 'Calendar',
              onPressed: () => _showComingSoon('Calendar'),
            ),
            _navIcon(
              icon: Icons.home_rounded,
              label: 'Home',
              selected: true,
              onPressed: () {},
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SynkColors.background,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: GestureDetector(
        onTap: () => _showComingSoon('Create Activity'),
        child: Container(
          width: 58,
          height: 58,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            // A muted, pastel tint of the brand orange rather than the
            // full-strength color, to sit quietly on the bar.
            color: Color.lerp(SynkColors.orange, Colors.white, 0.45),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.10),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: const Icon(
            Icons.add_rounded,
            color: SynkColors.orangeDark,
            size: 26,
          ),
        ),
      ),
      bottomNavigationBar: _buildBottomNav(),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 20),

              // Branding header, consistent with the other screens.
              Row(
                children: [
                  SizedBox(
                    width: 44,
                    height: 44,
                    child: Image.asset(
                      'assets/synk_logo_transparent.png',
                      fit: BoxFit.contain,
                      errorBuilder: (_, _, _) => const Icon(
                        Icons.all_inclusive_rounded,
                        color: SynkColors.orange,
                        size: 32,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'Synk',
                    style: TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.8,
                      color: SynkColors.textPrimary,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // Search bar.
              Container(
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.45),
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(
                    color: SynkColors.textSecondary.withValues(alpha: 0.10),
                  ),
                ),
                child: TextField(
                  controller: _searchController,
                  style: const TextStyle(color: SynkColors.textPrimary),
                  decoration: const InputDecoration(
                    hintText: 'Search activities, people, places...',
                    hintStyle: TextStyle(color: SynkColors.textSecondary),
                    prefixIcon: Icon(
                      Icons.search_rounded,
                      color: SynkColors.textSecondary,
                    ),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),

              const SizedBox(height: 20),

              Text(
                widget.isNewUser ? 'Welcome to Synk,' : 'Welcome back,',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: SynkColors.textSecondary,
                ),
              ),

              Text(
                _homeController.userName ?? 'there',
                style: const TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -1.0,
                  height: 1.1,
                  color: SynkColors.textPrimary,
                ),
              ),

              const SizedBox(height: 36),

              Expanded(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 96,
                        height: 96,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.06),
                              blurRadius: 16,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.all_inclusive_rounded,
                          color: SynkColors.orange,
                          size: 44,
                        ),
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        "You're all set.",
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: SynkColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 24),
                        child: Text(
                          'This is your home. Activities and connections will show up here soon.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            color: SynkColors.textSecondary,
                            height: 1.4,
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
      ),
    );
  }
}
