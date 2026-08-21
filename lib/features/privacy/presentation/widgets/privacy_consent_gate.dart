import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PrivacyConsentGate extends StatefulWidget {
  const PrivacyConsentGate({required this.child, super.key});

  final Widget child;

  @override
  State<PrivacyConsentGate> createState() => _PrivacyConsentGateState();
}

class _PrivacyConsentGateState extends State<PrivacyConsentGate> {
  static const _consentVersion = 'privacy-v2';
  static const _versionKey = 'privacy_consent_version';
  static const _policyKey = 'privacy_policy_accepted';
  static const _dataKey = 'voluntary_data_consent';

  bool _loading = true;
  bool _accepted = false;
  bool _policyAccepted = false;
  bool _dataAccepted = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadConsent();
  }

  Future<void> _loadConsent() async {
    final preferences = await SharedPreferences.getInstance();
    final accepted =
        preferences.getString(_versionKey) == _consentVersion &&
        (preferences.getBool(_policyKey) ?? false) &&
        (preferences.getBool(_dataKey) ?? false);
    if (mounted) {
      setState(() {
        _accepted = accepted;
        _loading = false;
      });
    }
  }

  Future<void> _accept() async {
    if (!_policyAccepted || !_dataAccepted || _saving) return;
    setState(() => _saving = true);
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_versionKey, _consentVersion);
    await preferences.setBool(_policyKey, true);
    await preferences.setBool(_dataKey, true);
    if (mounted) {
      setState(() {
        _accepted = true;
        _saving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_accepted) return widget.child;
    return Scaffold(
      backgroundColor: const Color(0xAA0F172A),
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
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Color(0xFF172554), Color(0xFF2563EB)],
                        ),
                      ),
                      child: const Row(
                        children: [
                          CircleAvatar(
                            radius: 26,
                            backgroundColor: Colors.white24,
                            child: Icon(
                              Icons.privacy_tip_outlined,
                              color: Colors.white,
                              size: 29,
                            ),
                          ),
                          SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'นโยบายการใช้งานและความเป็นส่วนตัว',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  'โปรดอ่านและยอมรับก่อนเข้าใช้งานเว็บไซต์',
                                  style: TextStyle(color: Color(0xFFDBEAFE)),
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
                                'เว็บไซต์นี้จัดทำขึ้นเพื่อช่วยให้ผู้ใช้งานค้นหาและเปรียบเทียบข้อมูลห้องแถว อพาร์ตเมนต์ บ้านเช่า และคอนโดได้สะดวกขึ้น เว็บไซต์เป็นเพียงช่องทางแสดงข้อมูลและเชื่อมต่อผู้สนใจกับผู้ประกาศเท่านั้น ไม่ใช่นายหน้า คู่สัญญา หรือระบบรับจองและชำระเงิน',
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
                                'เว็บไซต์อาจจัดเก็บเฉพาะข้อมูลที่ผู้ใช้กรอกหรืออัปโหลดโดยสมัครใจ เช่น ชื่อ เบอร์โทร อีเมล รายละเอียดประกาศ รูปภาพ และพิกัด เพื่อใช้ติดต่อกลับ แสดงประกาศ ดูแลความปลอดภัย และปรับปรุงบริการ Browser อาจขอใช้ตำแหน่งปัจจุบันเพื่อจัดอันดับห้องแนะนำใกล้ผู้ใช้ โดยใช้ชั่วคราวระหว่างการค้นหาและไม่บันทึกพิกัดผู้ใช้ลงฐานข้อมูล ขณะนี้เราไม่มีระบบติดตามพฤติกรรมหรือเก็บข้อมูลเพื่อโฆษณาโดยอัตโนมัติ',
                          ),
                          const SizedBox(height: 22),
                          _ConsentCheckbox(
                            value: _policyAccepted,
                            title:
                                'ฉันได้อ่านและยอมรับนโยบายการใช้งาน รวมถึงข้อจำกัดความรับผิดชอบ',
                            onChanged: (value) => setState(
                              () => _policyAccepted = value ?? false,
                            ),
                          ),
                          const SizedBox(height: 10),
                          _ConsentCheckbox(
                            value: _dataAccepted,
                            title:
                                'ฉันยินยอมให้เว็บไซต์จัดเก็บและใช้ข้อมูลที่ฉันส่งโดยสมัครใจตามวัตถุประสงค์ข้างต้น',
                            onChanged: (value) =>
                                setState(() => _dataAccepted = value ?? false),
                          ),
                          const SizedBox(height: 22),
                          FilledButton.icon(
                            onPressed:
                                _policyAccepted && _dataAccepted && !_saving
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
                          const Text(
                            'การยอมรับจะถูกจำไว้เฉพาะใน Browser เครื่องนี้ และสามารถล้างได้ด้วยการล้างข้อมูลเว็บไซต์',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Color(0xFF64748B),
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
          color: const Color(0xFFEEF2FF),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: const Color(0xFF2563EB)),
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
              style: const TextStyle(height: 1.55, color: Color(0xFF475569)),
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
    color: value ? const Color(0xFFEEF2FF) : const Color(0xFFF8FAFC),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(14),
      side: BorderSide(
        color: value ? const Color(0xFFA5B4FC) : const Color(0xFFE2E8F0),
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
