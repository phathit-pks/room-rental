import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:room_rental/core/theme/app_colors.dart';

class PrivacyConsentGate extends StatefulWidget {
  const PrivacyConsentGate({required this.child, super.key});

  final Widget child;

  @override
  State<PrivacyConsentGate> createState() => _PrivacyConsentGateState();
}

class _PrivacyConsentGateState extends State<PrivacyConsentGate> {
  static const _consentVersion = 'privacy-v3';
  static const _versionKey = 'privacy_consent_version';

  bool _loading = true;
  bool _accepted = false;
  bool _policyAccepted = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadConsent();
  }

  Future<void> _loadConsent() async {
    var accepted = false;
    try {
      final preferences = await SharedPreferences.getInstance();
      accepted = preferences.getString(_versionKey) == _consentVersion;
    } catch (error) {
      debugPrint('Could not read the saved privacy policy version: $error');
    }
    if (!mounted) return;
    setState(() {
      _accepted = accepted;
      _loading = false;
    });
  }

  Future<void> _accept() async {
    if (!_policyAccepted || _saving) return;
    setState(() => _saving = true);
    try {
      final preferences = await SharedPreferences.getInstance();
      await preferences.setString(_versionKey, _consentVersion);
    } catch (error) {
      debugPrint('Could not save the privacy policy version: $error');
    }
    if (!mounted) return;
    setState(() {
      _accepted = true;
      _saving = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_accepted) return widget.child;
    return Scaffold(
      backgroundColor: context.colors.shadow.withAlpha(0xAA),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: Card(
                elevation: 20,
                clipBehavior: Clip.antiAlias,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          // Always a dark-to-primary accent gradient, in both light and dark mode.
                          colors: [
                            const Color(0xFF172554),
                            context.colors.primary,
                          ],
                        ),
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 26,
                            backgroundColor: context.colors.onPrimary.withAlpha(
                              0x3D,
                            ),
                            child: Icon(
                              Icons.privacy_tip_outlined,
                              color: context.colors.onPrimary,
                              size: 29,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'นโยบายการใช้งานและความเป็นส่วนตัว',
                                  style: TextStyle(
                                    color: context.colors.onPrimary,
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'โปรดอ่านและยอมรับก่อนเข้าใช้งานเว็บไซต์',
                                  style: const TextStyle(
                                    // Fixed light tint: this banner stays dark in both themes.
                                    color: Color(0xFFDBEAFE),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(26, 24, 26, 26),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const _PolicySection(
                            icon: Icons.home_work_outlined,
                            title: 'วัตถุประสงค์ของเว็บไซต์',
                            text:
                                'apphahong.com ช่วยให้ผู้ใช้รู้ว่าบริเวณที่สนใจมีห้องเช่าหรือที่พักให้เช่าหรือไม่ ผู้ใช้ค้นหาตามพื้นที่หรือใช้ตำแหน่งปัจจุบันเมื่ออนุญาต แล้วติดต่อเจ้าของห้องหรือผู้ลงประกาศโดยตรง การนัดดูห้อง การจอง การทำสัญญา และการชำระเงินเป็นเรื่องที่ผู้ใช้ตกลงกับผู้ให้เช่าโดยตรง',
                          ),
                          SizedBox(height: 16),
                          const _PolicySection(
                            icon: Icons.gpp_maybe_outlined,
                            title: 'ข้อจำกัดความรับผิดชอบ',
                            text:
                                'ราคา รูปภาพ ตำแหน่ง และรายละเอียดต่าง ๆ เป็นข้อมูลจากผู้ประกาศและอาจเปลี่ยนแปลงได้ ผู้ใช้งานควรตรวจสอบสถานที่ บุคคล เอกสาร ราคา และเงื่อนไขด้วยตนเองก่อนโอนเงินหรือทำสัญญา หากบุคคลใดนำชื่อ เว็บไซต์ หรือข้อมูลไปแอบอ้าง หลอกลวง หรือใช้โดยไม่ได้รับอนุญาต ทางเว็บไซต์จะไม่รับผิดชอบต่อความเสียหายที่เกิดจากการติดต่อหรือธุรกรรมระหว่างผู้ใช้งานกับบุคคลภายนอก',
                          ),
                          SizedBox(height: 16),
                          const _PolicySection(
                            icon: Icons.storage_outlined,
                            title: 'ข้อมูลที่ผู้ใช้ส่งให้เว็บไซต์',
                            text:
                                'ประกาศที่ผ่านการอนุมัติอาจแสดงข้อมูลที่ผู้ลงประกาศส่งเพื่อเผยแพร่ เช่น รูปที่พัก ทำเล ชื่อผู้ลงประกาศ และช่องทางติดต่อ อีเมลจากบัญชีที่ใช้ส่งประกาศเก็บแยกไว้สำหรับผู้ดูแล ตำแหน่งปัจจุบันจะใช้ระหว่างการค้นหาเมื่อผู้ใช้อนุญาต และไม่แสดงให้ผู้ใช้รายอื่นเห็น เว็บไซต์อาจใช้ Google Analytics เพื่อวัดการเข้าชมหน้าสาธารณะ',
                          ),
                          const SizedBox(height: 12),
                          TextButton.icon(
                            onPressed: () => launchUrl(
                              Uri.base.resolve('/th/privacy.html'),
                              webOnlyWindowName: '_blank',
                            ),
                            icon: const Icon(Icons.open_in_new),
                            label: const Text(
                              'อ่านนโยบายความเป็นส่วนตัวฉบับเต็ม',
                            ),
                          ),
                          const SizedBox(height: 12),
                          _ConsentCheckbox(
                            value: _policyAccepted,
                            title:
                                'ฉันได้อ่านและยอมรับนโยบายการใช้งานและความเป็นส่วนตัว',
                            onChanged: (value) => setState(
                              () => _policyAccepted = value ?? false,
                            ),
                          ),
                          const SizedBox(height: 22),
                          FilledButton.icon(
                            onPressed: _policyAccepted && !_saving
                                ? _accept
                                : null,
                            icon: _saving
                                ? const SizedBox.square(
                                    dimension: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.check_circle_outline),
                            label: Text(
                              _saving
                                  ? 'กำลังบันทึก...'
                                  : 'ยอมรับและเข้าสู่เว็บไซต์',
                            ),
                            style: FilledButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 18),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'เบราว์เซอร์จะจดจำการยอมรับหากอนุญาตให้จัดเก็บข้อมูลเว็บไซต์',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: context.colors.textMuted,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PolicySection extends StatelessWidget {
  const _PolicySection({
    required this.icon,
    required this.title,
    required this.text,
  });

  final IconData icon;
  final String title;
  final String text;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Container(
        padding: const EdgeInsets.all(9),
        decoration: BoxDecoration(
          color: context.colors.primaryContainer,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: context.colors.primary),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 5),
            Text(
              text,
              style: TextStyle(
                height: 1.55,
                color: context.colors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    ],
  );
}

class _ConsentCheckbox extends StatelessWidget {
  const _ConsentCheckbox({
    required this.value,
    required this.title,
    required this.onChanged,
  });

  final bool value;
  final String title;
  final ValueChanged<bool?> onChanged;

  @override
  Widget build(BuildContext context) => Material(
    color: value ? context.colors.primaryContainer : context.colors.background,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(14),
      side: BorderSide(
        color: value
            ? context.colors.primaryContainerStrong
            : context.colors.border,
      ),
    ),
    child: CheckboxListTile(
      value: value,
      onChanged: onChanged,
      controlAffinity: ListTileControlAffinity.leading,
      title: Text(title, style: const TextStyle(fontSize: 14, height: 1.4)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
    ),
  );
}
