import 'package:flutter/material.dart';

import '../../../../core/themes/app_light_colors.dart';

class DividerWithText extends StatelessWidget {
  const DividerWithText({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Divider(
            color: AppLightColors.myBlack50,
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0),
          child: Text(
            "or continue with",
            style: TextStyle(
              fontSize: 14,
              color: AppLightColors.myBlack50,
            ),
          ),
        ),
        Expanded(
          child: Divider(
            color: AppLightColors.myBlack50,
          ),
        ),
      ],
    );
  }
}
