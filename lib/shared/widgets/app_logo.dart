import 'package:flutter/material.dart';
import 'package:room_rental/core/theme/app_colors.dart';

class AppLogo extends StatelessWidget {
  const AppLogo({super.key});

  @override
  Widget build(BuildContext context) => Semantics(
    header: true,
    child: SizedBox(
      width: 164,
      height: 44,
      child: Row(
        children: [
          Image.asset(
            'assets/branding/source/icon/logo-icon.png',
            width: 36,
            height: 36,
            excludeFromSemantics: true,
            errorBuilder: (_, _, _) => Icon(
              Icons.home_outlined,
              color: context.colors.primary,
              size: 28,
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: FittedBox(
              alignment: AlignmentDirectional.centerStart,
              fit: BoxFit.scaleDown,
              child: Text(
                'apphahong.com',
                style: TextStyle(
                  color: context.colors.primary,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
