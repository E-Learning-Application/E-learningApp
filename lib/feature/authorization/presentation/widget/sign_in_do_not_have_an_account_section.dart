import 'package:e_learning_app/core/themes/app_light_colors.dart';
import 'package:flutter/material.dart';

class SignInDoNotHaveAnAccountSection extends StatelessWidget {
  const SignInDoNotHaveAnAccountSection({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
       const SizedBox(height: 5),
        Text(
          "Don't have an account?",
          style:  TextStyle(
              fontSize: 14,
              color: AppLightColors.myBlack50,
            ),
        ),
      ],
    );
  }
}
