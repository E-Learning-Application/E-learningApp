
import 'package:flutter/material.dart';

class SignInFaceBookAndGoogleButtons extends StatelessWidget {
  const SignInFaceBookAndGoogleButtons({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        SignInSocialButton(
          textColor: AppLightColors.myGray100_1,
          icon: const CustomIcon(
            hight: 21,
            width: 21,
            flag: false,
            imageIcon: AppAssets.assetsIconsFacebookIcon,
          ),
          color: Colors.blue,
          text: 'Facebook',
        ),
        const Gap(20),
        SignInSocialButton(
          textColor: AppLightColors.myBlack100,
          icon: const CustomIcon(
            hight: 21,
            width: 21,
            flag: false,
            imageIcon: AppAssets.assetsIconsGoogleIcon,
          ),
          color: AppLightColors.myGray100_1,
          text: 'Google',
        ),
      ],
    );
  }
}
