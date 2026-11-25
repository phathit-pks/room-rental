import 'package:flutter/material.dart';
import 'package:room_rental/core/theme/app_colors.dart';

class AppDialog extends StatelessWidget {
  const AppDialog({
    super.key,
    required this.title,
    required this.content,
    this.icon,
    this.actions,
    this.contentPadding,
    this.scrollable = false,
    this.closeEnabled = true,
  });

  final Widget title;
  final Widget content;
  final Widget? icon;
  final List<Widget>? actions;
  final EdgeInsetsGeometry? contentPadding;
  final bool scrollable;
  final bool closeEnabled;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Theme(
      data: theme.copyWith(
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            minimumSize: const Size(0, 44),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ),
      ),
      child: AlertDialog(
        scrollable: scrollable,
        titlePadding: const EdgeInsets.fromLTRB(24, 12, 16, 0),
        contentPadding:
            contentPadding ?? const EdgeInsets.fromLTRB(24, 16, 24, 20),
        title: Row(
          children: [
            if (icon case final leading?) ...[
              leading,
              const SizedBox(width: 10),
            ],
            Expanded(child: title),
            const SizedBox(width: 8),
            AppDialogCloseButton(enabled: closeEnabled),
          ],
        ),
        content: content,
        actions: actions,
      ),
    );
  }
}

class AppDialogCloseButton extends StatelessWidget {
  const AppDialogCloseButton({super.key, this.enabled = true});

  final bool enabled;

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: 'ปิด',
    onPressed: enabled ? () => Navigator.of(context).pop() : null,
    icon: const Icon(Icons.close_rounded),
    style: IconButton.styleFrom(
      backgroundColor: context.colors.surfaceMuted,
      foregroundColor: context.colors.textSecondary,
    ),
  );
}
