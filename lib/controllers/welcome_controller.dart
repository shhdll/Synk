import 'package:flutter/material.dart';

import '../models/welcome_model.dart';

class WelcomeController extends ChangeNotifier {
  final PageController pageController = PageController();
  final WelcomeModel model = const WelcomeModel();

  double scrollProgress = 0.0;
  int currentIndex = 0;

  WelcomeController() {
    pageController.addListener(_onScroll);
  }

  void _onScroll() {
    if (pageController.hasClients) {
      scrollProgress = pageController.page ?? 0.0;
      final newIndex = scrollProgress.round();
      if (newIndex != currentIndex) {
        currentIndex = newIndex;
      }
      notifyListeners();
    }
  }

  void nextSlide() {
    if (pageController.hasClients) {
      pageController.animateToPage(
        1,
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeInOutCubic,
      );
    }
  }

  void previousSlide() {
    if (pageController.hasClients) {
      pageController.animateToPage(
        0,
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeInOutCubic,
      );
    }
  }

  void onSignUp(BuildContext context) {
    // Route to Sign Up screen
  }

  void onLogIn(BuildContext context) {
    // Route to Log In screen
  }

  @override
  void dispose() {
    pageController.removeListener(_onScroll);
    pageController.dispose();
    super.dispose();
  }
}
