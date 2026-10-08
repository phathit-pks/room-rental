import 'package:flutter/material.dart';
import 'package:room_rental/core/config/supabase_config.dart';
import 'package:room_rental/core/theme/app_colors.dart';
import 'package:room_rental/features/auth/presentation/widgets/client_auth_button.dart';
import 'package:room_rental/features/listings/data/repositories/listing_report_repository.dart';

Future<void> showReportListingDialog(
  BuildContext context, {
  required String listingId,
}) async {
  if (SupabaseConfig.client?.auth.currentUser == null) {
    await showClientSignInDialog(context);
    return;
  }
  if (!context.mounted) return;
  await showDialog<void>(
    context: context,
    builder: (_) => ReportListingDialog(listingId: listingId),
  );
}

class ReportListingDialog extends StatefulWidget {
  const ReportListingDialog({required this.listingId, super.key});

  final String listingId;

  @override
  State<ReportListingDialog> createState() => _ReportListingDialogState();
}

class _ReportListingDialogState extends State<ReportListingDialog> {
  static const _reasons = [
    ('fake', 'ประกาศปลอม / หลอกลวง'),
    ('wrong_info', 'ข้อมูลไม่ถูกต้อง'),
    ('duplicate', 'ประกาศซ้ำ'),
    ('rented_out', 'ห้องถูกเช่าไปแล้ว'),
    ('other', 'อื่น ๆ'),
  ];

  final _repository = const ListingReportRepository();
  final _description = TextEditingController();
  String _reason = _reasons.first.$1;
  bool _submitting = false;
  bool _submitted = false;
  String? _error;

  @override
  void dispose() {
    _description.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await _repository.submit(
        listingId: widget.listingId,
        reason: _reason,
        description: _description.text,
      );
      if (mounted) setState(() => _submitted = true);
    } catch (error) {
      if (mounted) setState(() => _error = 'ส่งรายงานไม่สำเร็จ: $error');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    icon: Icon(Icons.flag_outlined, color: context.colors.danger, size: 30),
    title: const Text('รายงานประกาศนี้'),
    content: SizedBox(width: 400, child: _submitted ? _success() : _form()),
    actions: _submitted
        ? [
            FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('ปิด'),
            ),
          ]
        : [
            TextButton(
              onPressed: _submitting ? null : () => Navigator.pop(context),
              child: const Text('ยกเลิก'),
            ),
            FilledButton(
              onPressed: _submitting ? null : _submit,
              child: _submitting
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('ส่งรายงาน'),
            ),
          ],
  );

  Widget _success() => const Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(Icons.check_circle_outline, size: 48),
      SizedBox(height: 12),
      Text(
        'ขอบคุณที่แจ้งให้เราทราบ ทีมงานจะตรวจสอบประกาศนี้',
        textAlign: TextAlign.center,
      ),
    ],
  );

  Widget _form() => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const Text('ช่วยบอกเราว่าประกาศนี้มีปัญหาอะไร'),
      const SizedBox(height: 14),
      DropdownButtonFormField<String>(
        initialValue: _reason,
        decoration: const InputDecoration(labelText: 'เหตุผล'),
        items: _reasons
            .map((r) => DropdownMenuItem(value: r.$1, child: Text(r.$2)))
            .toList(),
        onChanged: _submitting
            ? null
            : (value) => setState(() => _reason = value!),
      ),
      const SizedBox(height: 12),
      TextField(
        controller: _description,
        maxLines: 3,
        maxLength: 1000,
        enabled: !_submitting,
        decoration: const InputDecoration(
          labelText: 'รายละเอียดเพิ่มเติม (ไม่บังคับ)',
        ),
      ),
      if (_error != null) ...[
        const SizedBox(height: 8),
        Text(
          _error!,
          style: TextStyle(color: context.colors.danger, fontSize: 12),
        ),
      ],
    ],
  );
}
