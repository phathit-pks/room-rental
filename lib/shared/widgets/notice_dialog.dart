import 'package:flutter/material.dart';
import 'package:room_rental/shared/widgets/app_dialog.dart';

Future<void> showNoticeDialog(
  BuildContext context, {
  required IconData icon,
  required String title,
  required String message,
}) => showDialog<void>(
  context: context,
  builder: (context) => AppDialog(
    icon: Icon(icon, color: Theme.of(context).colorScheme.primary),
    title: Text(title),
    scrollable: true,
    content: SizedBox(width: 352, child: Text(message)),
    actions: [
      FilledButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('ตกลง'),
      ),
    ],
  ),
);
