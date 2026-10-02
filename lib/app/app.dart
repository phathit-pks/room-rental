import 'package:flutter/material.dart';
import 'package:room_rental/core/theme/app_theme.dart';
import 'package:room_rental/core/theme/theme_store.dart';
import 'package:room_rental/features/admin/presentation/pages/admin_locations_page.dart';
import 'package:room_rental/features/contact/presentation/pages/contact_page.dart';
import 'package:room_rental/features/home/presentation/pages/home_page.dart';
import 'package:room_rental/features/privacy/presentation/widgets/privacy_consent_gate.dart';
import 'package:room_rental/features/settings/presentation/pages/settings_page.dart';

class RoomRentalApp extends StatelessWidget {
  const RoomRentalApp({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: ThemeStore.instance,
      builder: (context, _) {
        return MaterialApp(
          title: 'Room Rental',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          themeMode: ThemeStore.instance.mode,
          routes: {
            '/': (_) => const PrivacyConsentGate(child: HomePage()),
            '/admin': (_) => const AdminLocationsPage(),
            '/contact': (_) => const ContactPage(),
            '/settings': (_) => const SettingsPage(),
          },
        );
      },
    );
  }
}
