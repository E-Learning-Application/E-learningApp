import 'package:e_learning_app/feature/authorization/presentation/widget/custom_text_from_felid.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class SignInEmailAndPasswordFields extends StatelessWidget {
  final TextEditingController emailController;
  final TextEditingController passwordController;
  final GlobalKey<FormState> formKey;

  const SignInEmailAndPasswordFields({
    super.key,
    required this.emailController,
    required this.passwordController,
    required this.formKey,
  });

  @override
  Widget build(BuildContext context) {
    return Form(
      key: formKey,
      child: Column(
        children: [
          CustomTextField(
            labelText: 'Email',
            hintText: "Enter Email",
            inputType: TextInputType.emailAddress,
            obscureText: false,
            controller: emailController,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Email is required';
              }
              final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
              if (!emailRegex.hasMatch(value)) {
                return 'Enter a valid email address';
              }
              return null;
            },
          ),
          CustomTextField(
            labelText: 'Password',
            hintText: "Enter password",
            inputType: TextInputType.visiblePassword,
            obscureText: obscurePassword,
            controller: passwordController,
            suffixIcon:
                Icon(obscurePassword ? Icons.visibility_off : Icons.visibility),
            onSuffixIconPressed: () {},
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Password is required';
              }
              if (value.length < 6) {
                return 'Password must be at least 6 characters';
              }
              return null;
            },
          ),
        ],
      ),
    );
  }
}
