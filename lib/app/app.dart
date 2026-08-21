import 'package:flutter/material.dart';
import 'package:room_rental/core/theme/app_theme.dart';
import 'package:room_rental/features/admin/presentation/pages/admin_locations_page.dart';
import 'package:room_rental/features/contact/presentation/pages/contact_page.dart';
import 'package:room_rental/features/home/presentation/pages/home_page.dart';
import 'package:room_rental/features/privacy/presentation/widgets/privacy_consent_gate.dart';

class RoomRentalApp extends StatelessWidget {
  const RoomRentalApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Room Rental',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      routes: {
        '/': (_) => const PrivacyConsentGate(child: HomePage()),
        '/admin': (_) => const AdminLocationsPage(),
        '/contact': (_) => const ContactPage(),
      },
    );
  }
}
