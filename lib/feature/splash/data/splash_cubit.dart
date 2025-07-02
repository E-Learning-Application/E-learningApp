import 'package:dio/dio.dart';
import 'package:e_learning_app/core/api/dio_consumer.dart';
import 'package:e_learning_app/core/service/auth_service.dart';
import 'package:e_learning_app/feature/Auth/presentation/login/views/login_view.dart';
import 'package:e_learning_app/feature/app_container/app_container.dart';
import 'package:e_learning_app/feature/onboarding/presentation/view/onboarding_screen.dart';
import 'package:e_learning_app/feature/splash/data/splash_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SplashCubit extends Cubit<SplashState> {
  final FlutterSecureStorage _secureStorage;
  final AuthService _authService;

  SplashCubit()
      : _secureStorage = const FlutterSecureStorage(),
        _authService = AuthService(dioConsumer: DioConsumer(dio: Dio())),
        super(SplashState.initial());

  void initialize(TickerProvider vsync) {
    _initAnimations(vsync);
    _checkAuthAndNavigate();
  }

  void _initAnimations(TickerProvider vsync) {
    final animationController = AnimationController(
      vsync: vsync,
      duration: const Duration(milliseconds: 1500),
    );

    final fadeInAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: animationController,
        curve: const Interval(0.0, 0.7, curve: Curves.easeIn),
      ),
    );

    final scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(
        parent: animationController,
        curve: const Interval(0.2, 0.8, curve: Curves.easeOutBack),
      ),
    );

    final slidingAnimation =
        Tween<Offset>(begin: const Offset(0, 0.5), end: Offset.zero).animate(
      CurvedAnimation(
        parent: animationController,
        curve: const Interval(0.3, 1.0, curve: Curves.elasticOut),
      ),
    );

    emit(state.copyWith(
      animationController: animationController,
      fadeInAnimation: fadeInAnimation,
      scaleAnimation: scaleAnimation,
      slidingAnimation: slidingAnimation,
    ));

    animationController.forward();
  }

  Future<void> _checkAuthAndNavigate() async {
    // Wait for animations to complete
    await Future.delayed(const Duration(milliseconds: 3000));

    try {
      // Check if user has seen onboarding
      final seenOnboardingValue =
          await _secureStorage.read(key: 'seenOnboarding');
      final seenOnboarding = seenOnboardingValue == 'true';

      // If haven't seen onboarding, go to onboarding
      if (!seenOnboarding) {
        emit(state.copyWith(navigateTo: const OnboardingView()));
        return;
      }

      // Try to validate and refresh token if needed
      final isTokenValid = await _authService.validateAndRefreshTokenIfNeeded();

      if (isTokenValid) {
        // Token is valid or was successfully refreshed
        final user = await _authService.getCurrentUser();
        if (user != null) {
          print('User authenticated successfully: ${user.username}');
          emit(state.copyWith(navigateTo: const AppContainer()));
          return;
        }
      }

      // If we reach here, authentication failed
      print('Authentication failed, redirecting to login');
      emit(state.copyWith(navigateTo: const LoginView()));
    } catch (e) {
      print('Error during authentication check: $e');
      // On error, check if seen onboarding to decide where to go
      final seenOnboardingValue =
          await _secureStorage.read(key: 'seenOnboarding');
      final seenOnboarding = seenOnboardingValue == 'true';

      emit(state.copyWith(
        navigateTo: seenOnboarding ? const LoginView() : const OnboardingView(),
      ));
    }
  }

  void dispose() {
    state.animationController?.dispose();
  }

  @override
  Future<void> close() {
    state.animationController?.dispose();
    return super.close();
  }
}
