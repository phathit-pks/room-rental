import 'package:flutter/material.dart';
import 'package:room_rental/core/theme/app_colors.dart';
import 'package:room_rental/features/admin/data/admin_passkey_entry.dart';
import 'package:room_rental/shared/widgets/app_dialog.dart';

class AdminPasskeyDialog extends StatefulWidget {
  const AdminPasskeyDialog({
    super.key,
    required this.load,
    required this.register,
    required this.delete,
    required this.errorMessage,
  });

  final Future<List<AdminPasskeyEntry>> Function() load;
  final Future<bool> Function() register;
  final Future<void> Function(String id) delete;
  final String Function(Object error, String fallback) errorMessage;

  @override
  State<AdminPasskeyDialog> createState() => _AdminPasskeyDialogState();
}

class _AdminPasskeyDialogState extends State<AdminPasskeyDialog> {
  late Future<List<AdminPasskeyEntry>> _entries;
  bool _busy = false;
  String? _message;
  String? _error;

  @override
  void initState() {
    super.initState();
    _entries = widget.load();
  }

  Future<void> _register() => _run(
    widget.register,
    success: 'ลงทะเบียน Passkey แล้ว',
    failure: 'ลงทะเบียน Passkey ไม่สำเร็จ',
  );

  Future<void> _delete(AdminPasskeyEntry entry, {required bool isLast}) async {
    if (_busy) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AppDialog(
        title: const Text('ลบ Passkey'),
        content: Text(
          'ลบ “${entry.name}” ออกจากบัญชีนี้หรือไม่? '
          'เบราว์เซอร์จะขอยืนยันตัวตนก่อนลบ'
          '${isLast ? '\n\nหลังลบรายการสุดท้าย ให้ใช้รหัสผ่านเพื่อเข้าสู่ระบบครั้งถัดไป' : ''}',
        ),
        scrollable: true,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('ยกเลิก'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('ยืนยันตัวตนและลบ'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await _run(
      () async {
        await widget.delete(entry.id);
        return true;
      },
      success: 'ลบ Passkey แล้ว',
      failure: 'ลบ Passkey ไม่สำเร็จ',
    );
  }

  Future<void> _run(
    Future<bool> Function() action, {
    required String success,
    required String failure,
  }) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _message = null;
      _error = null;
    });
    try {
      final changed = await action();
      if (!mounted || !changed) return;
      setState(() {
        _entries = widget.load();
        _message = success;
      });
    } catch (error) {
      if (mounted) setState(() => _error = widget.errorMessage(error, failure));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_busy,
    child: AppDialog(
      icon: const Icon(Icons.fingerprint),
      title: const Text('จัดการ Passkey'),
      closeEnabled: !_busy,
      scrollable: true,
      content: SizedBox(
        width: 380,
        child: FutureBuilder<List<AdminPasskeyEntry>>(
          future: _entries,
          builder: (context, snapshot) {
            final entries = snapshot.data;
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_busy ||
                    snapshot.connectionState == ConnectionState.waiting)
                  const LinearProgressIndicator(),
                if (_message case final message?)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      message,
                      style: TextStyle(color: context.colors.success),
                    ),
                  ),
                if (_error case final error?)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      error,
                      style: TextStyle(color: context.colors.danger),
                    ),
                  ),
                if (snapshot.hasError)
                  TextButton(
                    onPressed: _busy
                        ? null
                        : () => setState(() => _entries = widget.load()),
                    child: const Text('โหลดรายการ Passkey ใหม่'),
                  )
                else if (snapshot.connectionState == ConnectionState.done &&
                    entries != null)
                  if (entries.isEmpty) ...[
                    const Text('บัญชีนี้ยังไม่มี Passkey'),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed: _busy ? null : _register,
                      icon: const Icon(Icons.add),
                      label: const Text('ลงทะเบียน Passkey'),
                    ),
                  ] else ...[
                    if (_message == null) const Text('ลงทะเบียน Passkey แล้ว'),
                    for (final entry in entries)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.key_outlined),
                        title: Text(entry.name),
                        subtitle: Text(
                          MaterialLocalizations.of(
                            context,
                          ).formatMediumDate(entry.createdAt.toLocal()),
                        ),
                        trailing: IconButton(
                          tooltip: 'ลบ Passkey',
                          onPressed: _busy
                              ? null
                              : () =>
                                    _delete(entry, isLast: entries.length == 1),
                          icon: const Icon(Icons.delete_outline),
                        ),
                      ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: _busy ? null : _register,
                      icon: const Icon(Icons.add),
                      label: const Text('เพิ่ม Passkey สำหรับอุปกรณ์นี้'),
                    ),
                  ],
              ],
            );
          },
        ),
      ),
    ),
  );
}
