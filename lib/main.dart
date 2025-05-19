import 'package:dio/dio.dart';
import 'package:e_learning_app/core/api/api_consumer.dart';
import 'package:e_learning_app/core/api/dio_consumer.dart';
import 'package:e_learning_app/core/service/auth_service.dart';
import 'package:e_learning_app/feature/auth/login/data/login_cubit.dart';
import 'package:e_learning_app/feature/home/presentation/views/home_view.dart';
import 'package:e_learning_app/feature/splash/presentation/views/splash_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

void main() {
  runApp(LanguageLearningApp());
}

class LanguageLearningApp extends StatelessWidget {
  const LanguageLearningApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (context) => LoginCubit(
              authService: AuthService(apiConsumer: DioConsumer(dio: Dio()))),
        ),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Communication App Onboarding',
        theme: ThemeData(
          primarySwatch: Colors.blue,
          fontFamily: 'Roboto',
        ),
        home: SplashView(),
      ),
    );
  }
}
