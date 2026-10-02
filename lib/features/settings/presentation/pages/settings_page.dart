import 'package:flutter/material.dart';
import 'package:room_rental/core/theme/app_colors.dart';
import 'package:room_rental/core/theme/theme_store.dart';
import 'package:room_rental/shared/widgets/day_night_toggle.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Scaffold(
      appBar: AppBar(title: const Text('ตั้งค่า')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          AnimatedBuilder(
            animation: ThemeStore.instance,
            builder: (context, _) {
              final isDark = ThemeStore.instance.isDark;
              return Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: colors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: colors.border),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'โหมดมืด',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: colors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            isDark
                                ? 'กำลังใช้งานโหมดกลางคืน'
                                : 'กำลังใช้งานโหมดกลางวัน',
                            style: TextStyle(
                              fontSize: 13,
                              color: colors.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    DayNightToggle(
                      isDark: isDark,
                      onChanged: (value) => ThemeStore.instance.setDark(value),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
