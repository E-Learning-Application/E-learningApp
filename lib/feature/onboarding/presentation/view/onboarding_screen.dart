import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import 'package:e_learning_app/feature/onboarding/data/onboarding_cubit.dart';
import 'package:e_learning_app/feature/onboarding/data/onboarding_state.dart';
import 'package:e_learning_app/feature/onboarding/presentation/widgets/onboarding_page.dart';

class OnboardingView extends StatelessWidget {
  const OnboardingView({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => OnboardingCubit(),
      child: const OnboardingViewBody(),
    );
  }
}

class OnboardingViewBody extends StatelessWidget {
  const OnboardingViewBody({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<OnboardingCubit, OnboardingState>(
      builder: (context, state) {
        final cubit = context.read<OnboardingCubit>();
        return Scaffold(
          backgroundColor: Colors.white,
          body: SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: PageView(
                    controller: cubit.pageController,
                    onPageChanged: cubit.onPageChanged,
                    children: const [
                      OnboardingPage(
                        title: "Stay Connected\nAnytime, Anywhere",
                        description: "Seamless video calls, clear voice chats, and instant messaging—all in one app. Stay close to friends, family, and colleagues effortlessly!",
                        imagePath: "assets/images/onboarding1.png",
                      ),
                      OnboardingPage(
                        title: "Talk & See with Ease",
                        description: "High-quality video and voice calls for smooth, reliable communication. Connect face-to-face or with just your voice—whenever you need!",
                        imagePath: "assets/images/onboarding2.png",
                      ),
                      OnboardingPage(
                        title: "Chat Smarter & Faster",
                        description: "Instant messaging with multimedia sharing and smart notifications. Simple, secure, and built to keep you engaged!",
                        imagePath: "assets/images/onboarding3.png",
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      TextButton(
                        onPressed: () => cubit.skip(context),
                        child: Text(
                          state.currentPage == 2 ? "" : "Skip",
                          style: TextStyle(
                            color: Colors.grey[700],
                            fontSize: 16,
                          ),
                        ),
                      ),
                      SmoothPageIndicator(
                        controller: cubit.pageController,
                        count: 3,
                        effect: ExpandingDotsEffect(
                          activeDotColor: Theme.of(context).primaryColor,
                          dotColor: Colors.grey.shade300,
                          dotHeight: 8,
                          dotWidth: 8,
                          spacing: 4,
                          expansionFactor: 3,
                        ),
                      ),
                      TextButton(
                        onPressed: () => cubit.next(context),
                        child: Text(
                          state.currentPage == 2 ? "Let's Start!" : "Next",
                          style: TextStyle(
                            color: Theme.of(context).primaryColor,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}