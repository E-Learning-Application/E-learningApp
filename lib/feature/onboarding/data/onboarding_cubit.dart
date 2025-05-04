import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:e_learning_app/feature/onboarding/data/onboarding_state.dart';
import 'package:e_learning_app/feature/Auth/login/presentation/views/login_view.dart';
// import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class OnboardingCubit extends Cubit<OnboardingState> {
  OnboardingCubit() : super(OnboardingState.initial());

  // For storing onboarding status
  // final _secureStorage = const FlutterSecureStorage();
  
  // PageController for managing the onboarding pages
  final PageController pageController = PageController();

  @override
  Future<void> close() {
    pageController.dispose();
    return super.close();
  }

  // Update the current page when user swipes
  void onPageChanged(int page) {
    emit(state.copyWith(currentPage: page));
  }

  // Skip to the login screen
  void skip(BuildContext context) async {
    // await _secureStorage.write(key: 'seenOnboarding', value: 'true');
    navigateToLogin(context);
  }

  // Go to next page or finish onboarding
  void next(BuildContext context) {
    if (state.currentPage < 2) {
      pageController.nextPage(
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
    } else {
      completeOnboarding(context);
    }
  }

  // Complete onboarding and save to storage
  Future<void> completeOnboarding(BuildContext context) async {
    // await _secureStorage.write(key: 'seenOnboarding', value: 'true');
    navigateToLogin(context);
  }

  // Navigate to login screen with animation
  void navigateToLogin(BuildContext context) {
    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (_, animation, __) => const LoginView(),
        transitionsBuilder: (_, animation, __, child) {
          return FadeTransition(
            opacity: Tween<double>(begin: 0.0, end: 1.0).animate(animation),
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 500),
      ),
    );
  }
}