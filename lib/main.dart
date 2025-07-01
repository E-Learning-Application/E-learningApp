import 'package:dio/dio.dart';
import 'package:e_learning_app/core/api/dio_consumer.dart';
import 'package:e_learning_app/core/service/auth_service.dart';
import 'package:e_learning_app/core/service/language_service.dart';
import 'package:e_learning_app/feature/Auth/data/auth_cubit.dart';
import 'package:e_learning_app/feature/language/data/language_cubit.dart';
import 'package:e_learning_app/feature/profile/data/user_cubit.dart';
import 'package:e_learning_app/feature/splash/presentation/views/splash_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

void main() {
  runApp(const LanguageLearningApp());
}

class LanguageLearningApp extends StatelessWidget {
  const LanguageLearningApp({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = AuthService(dioConsumer: DioConsumer(dio: Dio()));

    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider<AuthService>.value(value: authService),
      ],
      child: MultiBlocProvider(
        providers: [
          BlocProvider(
            create: (context) => AuthCubit(
              authService: context.read<AuthService>(),
            ),
          ),
          BlocProvider<LanguageCubit>(
            create: (context) => LanguageCubit(
              languageService:
                  LanguageService(dioConsumer: DioConsumer(dio: Dio())),
              authService: context.read<AuthService>(),
            ),
          ),
          BlocProvider<UserCubit>(
            create: (context) => UserCubit(
              dioConsumer: DioConsumer(dio: Dio()),
              authCubit: context.read<AuthCubit>(),
            ),
          ),
        ],
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'E-Learning App',
          theme: ThemeData(
            primarySwatch: Colors.blue,
            fontFamily: 'Roboto',
          ),
          home: SplashView(),
        ),
      ),
    );
  }
}
