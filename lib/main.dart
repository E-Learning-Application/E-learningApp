import 'package:dio/dio.dart';
import 'package:e_learning_app/core/api/dio_consumer.dart';
import 'package:e_learning_app/core/service/auth_service.dart';
import 'package:e_learning_app/feature/auth/Register/data/register_cubit.dart';
import 'package:e_learning_app/feature/auth/login/data/login_cubit.dart';
import 'package:e_learning_app/feature/home/data/home_cubit.dart';
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
    final apiConsumer = DioConsumer(dio: Dio());
    final authService = AuthService(apiConsumer: apiConsumer);

    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider<AuthService>.value(value: authService),
      ],
      child: MultiBlocProvider(
        providers: [
          BlocProvider(
            create: (context) => LoginCubit(
              authService: context.read<AuthService>(),
            ),
          ),
          BlocProvider(
            create: (context) => RegisterCubit(
              authService: context.read<AuthService>(),
            ),      
          ),
          BlocProvider(
            create: (context) => AuthCubit(
              authService: context.read<AuthService>(),
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
            