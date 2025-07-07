import 'package:dio/dio.dart';
import 'package:e_learning_app/core/api/dio_consumer.dart';
import 'package:e_learning_app/core/service/auth_service.dart';
import 'package:e_learning_app/core/service/interest_service.dart';
import 'package:e_learning_app/core/service/language_service.dart';
import 'package:e_learning_app/core/service/message_service.dart';
import 'package:e_learning_app/core/service/signalr_service.dart';
import 'package:e_learning_app/feature/Auth/data/auth_cubit.dart';
import 'package:e_learning_app/feature/language/data/language_cubit.dart';
import 'package:e_learning_app/feature/messages/data/message_cubit.dart';
import 'package:e_learning_app/feature/profile/data/user_cubit.dart';
import 'package:e_learning_app/feature/settings/data/language_mangment_cubit.dart';
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
    final dio = Dio();
    final dioConsumer = DioConsumer(dio: dio);
    final authService = AuthService(dioConsumer: dioConsumer);
    final languageService = LanguageService(dioConsumer: dioConsumer);
    final interestService = InterestService(dioConsumer: dioConsumer);
    final messageService = MessageService(dioConsumer: dioConsumer);
    final signalRService = SignalRService();

    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider<AuthService>.value(value: authService),
        RepositoryProvider<LanguageService>.value(value: languageService),
        RepositoryProvider<InterestService>.value(value: interestService),
        RepositoryProvider<MessageService>.value(value: messageService),
        RepositoryProvider<SignalRService>.value(value: signalRService),
        RepositoryProvider<DioConsumer>.value(value: dioConsumer),
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
              languageService: context.read<LanguageService>(),
              authService: context.read<AuthService>(),
              interestService: context.read<InterestService>(),
            ),
          ),
          BlocProvider<UserCubit>(
            create: (context) => UserCubit(
              dioConsumer: context.read<DioConsumer>(),
              authCubit: context.read<AuthCubit>(),
            ),
          ),
          BlocProvider<LanguageManagementCubit>(
            create: (context) => LanguageManagementCubit(
              languageService: context.read<LanguageService>(),
              authService: context.read<AuthService>(),
            ),
          ),
          BlocProvider<MessageCubit>(
            create: (context) => MessageCubit(
              messageService: context.read<MessageService>(),
              signalRService: context.read<SignalRService>(),
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
