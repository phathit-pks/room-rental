import 'package:flutter/material.dart';
import 'package:room_rental/core/theme/app_theme.dart';
import 'package:room_rental/core/theme/theme_store.dart';
import 'package:room_rental/features/admin/presentation/pages/admin_locations_page.dart';
import 'package:room_rental/features/contact/presentation/pages/contact_page.dart';
import 'package:room_rental/features/home/presentation/pages/home_page.dart';
import 'package:room_rental/shared/widgets/meteor_shower_overlay.dart';

/// How long the day/night crossfade (colors + meteor shower) takes.
const _themeTransitionDuration = Duration(seconds: 5);

class RoomRentalApp extends StatefulWidget {
  const RoomRentalApp({super.key});

  @override
  State<RoomRentalApp> createState() => _RoomRentalAppState();
}

class _RoomRentalAppState extends State<RoomRentalApp> {
  bool _wasDark = ThemeStore.instance.isDark;
  bool _showMeteorShower = false;
  int _meteorShowerKey = 0;

  @override
  void initState() {
    super.initState();
    ThemeStore.instance.addListener(_onThemeChanged);
  }

  void _onThemeChanged() {
    final isDark = ThemeStore.instance.isDark;
    final turningNightOn = isDark && !_wasDark;
    _wasDark = isDark;
    setState(() {
      if (turningNightOn) {
        _meteorShowerKey++;
        _showMeteorShower = true;
      }
    });
  }

  @override
  void dispose() {
    ThemeStore.instance.removeListener(_onThemeChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = ThemeStore.instance.isDark;
    return MaterialApp(
      title: 'Room Rental',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      routes: {
        '/': (_) => const HomePage(),
        '/admin': (_) => const AdminLocationsPage(),
        '/contact': (_) => const ContactPage(),
      },
      builder: (context, child) {
        return Stack(
          children: [
            AnimatedTheme(
              duration: _themeTransitionDuration,
              curve: Curves.easeInOut,
              data: isDark ? AppTheme.dark : AppTheme.light,
              child: child ?? const SizedBox.shrink(),
            ),
            if (_showMeteorShower)
              IgnorePointer(
                child: MeteorShowerOverlay(
                  key: ValueKey(_meteorShowerKey),
                  duration: _themeTransitionDuration,
                  onCompleted: () {
                    if (mounted) setState(() => _showMeteorShower = false);
                  },
                ),
              ),
          ],
        );
      },
    );
  }
}
