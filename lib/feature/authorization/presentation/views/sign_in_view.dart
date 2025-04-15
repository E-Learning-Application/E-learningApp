import 'package:e_learning_app/feature/authorization/presentation/widget/divider_with_text.dart';
import 'package:e_learning_app/feature/authorization/presentation/widget/sign_in_do_not_have_an_account_section.dart';
import 'package:e_learning_app/feature/authorization/presentation/widget/sign_in_email_and_password_fields.dart';
import 'package:e_learning_app/feature/authorization/presentation/widget/sign_in_face_book_and_google_buttons.dart';
import 'package:e_learning_app/feature/authorization/presentation/widget/sign_in_forget_password_button.dart';
import 'package:e_learning_app/feature/authorization/presentation/widget/sign_in_image_with_text.dart';
import 'package:flutter/material.dart';


class SignInView extends StatelessWidget {
  const SignInView({super.key});

  @override
  Widget build(BuildContext context) {
    return const _SignInContent();
  }
}

class _SignInContent extends StatelessWidget {
  const _SignInContent();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 25),
          child: Column(
            children: [
              const SignInImageWithText(),
              SignInEmailAndPasswordFields(
                // Pass the controllers and formKey to the SignInEmailAndPasswordFields widget
                emailController: TextEditingController(),
                passwordController: TextEditingController(),
                formKey: GlobalKey<FormState>(),
              ),
              SignInForgetPasswordButton(
                onPressed: () {},
              ),
              const SizedBox(height: 20),
              const DividerWithText(),
              const SizedBox(height: 20),
              const SignInFaceBookAndGoogleButtons(),
              const SizedBox(height: 20),
              const SignInDoNotHaveAnAccountSection(),
            ],
          ),
        ),
      ),
    );
  }
}
