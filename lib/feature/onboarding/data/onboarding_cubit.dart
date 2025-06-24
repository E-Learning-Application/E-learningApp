import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart'; // Add this import
import 'package:e_learning_app/feature/auth/login/presentation/views/login_view.dart';

class OnboardingState {
  final int currentPage;
  final bool isLoading;

  const OnboardingState({
    required this.currentPage,
    this.isLoading = false,
  });

  factory OnboardingState.initial() {
    return const OnboardingState(
      currentPage: 0,
    );
  }

  OnboardingState copyWith({
    int? currentPage,
    bool? isLoading,
  }) {
    return OnboardingState(
      currentPage: currentPage ?? this.currentPage,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class OnboardingCubit extends Cubit<OnboardingState> {
  OnboardingCubit() : super(OnboardingState.initial());

  final _secureStorage = const FlutterSecureStorage();
  final PageController pageController = PageController();

  @override
  Future<void> close() {
    pageController.dispose();
    return super.close();
  }

  void onPageChanged(int page) {
    emit(state.copyWith(currentPage: page));
  }

  void skip(BuildContext context) async {
    emit(state.copyWith(isLoading: true));
    
    try {
      await _secureStorage.write(key: 'seenOnboarding', value: 'true');
      navigateToLogin(context);
    } catch (e) {
      emit(state.copyWith(isLoading: false));
      navigateToLogin(context);
    }
  }

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

  Future<void> completeOnboarding(BuildContext context) async {
    emit(state.copyWith(isLoading: true));
    
    try {
      await _secureStorage.write(key: 'seenOnboarding', value: 'true');
      navigateToLogin(context);
    } catch (e) {
      emit(state.copyWith(isLoading: false));
      navigateToLogin(context);
    }
  }

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