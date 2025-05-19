import 'package:dio/dio.dart';
import 'package:e_learning_app/core/api/dio_consumer.dart';
import 'package:e_learning_app/core/service/auth_service.dart';
import 'package:e_learning_app/feature/auth/login/presentation/views/login_view.dart';
import 'package:e_learning_app/feature/home/presentation/views/home_view.dart';
import 'package:e_learning_app/feature/onboarding/presentation/view/onboarding_screen.dart';
import 'package:e_learning_app/feature/splash/data/splash_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SplashCubit extends Cubit<SplashState> {
  final _secureStorage = const FlutterSecureStorage();
  final _authService = AuthService(apiConsumer: DioConsumer(dio: Dio()));

  SplashCubit() : super(SplashState.initial());

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
    await Future.delayed(const Duration(milliseconds: 5000));

    try {
      final seenOnboarding =
          await _secureStorage.read(key: 'seenOnboarding') == 'true';
      final isAuthenticated = await _authService.isUserAuthenticated();

      Widget destination;

      if (isAuthenticated) {
        destination = const HomeScreen();
      } else if (seenOnboarding) {
        destination = const LoginView();
      } else {
        destination = const OnboardingView();
      }

      emit(state.copyWith(navigateTo: destination));
    } catch (e) {
      emit(state.copyWith(navigateTo: const OnboardingView()));
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
