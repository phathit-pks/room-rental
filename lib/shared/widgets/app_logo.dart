import 'package:flutter/material.dart';

class AppLogo extends StatelessWidget {
  const AppLogo({super.key});

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'หาห้องเช่า',
    header: true,
    child: Image.asset(
      'assets/branding/source/header/logo-header.png',
      width: 164,
      height: 44,
      fit: BoxFit.contain,
      alignment: Alignment.centerLeft,
      filterQuality: FilterQuality.high,
      errorBuilder: (_, _, _) => const Text(
        'HaHong.la',
        style: TextStyle(color: Color(0xFF0E4DE8), fontWeight: FontWeight.w800),
      ),
    ),
  );
}
