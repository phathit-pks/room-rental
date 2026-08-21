import 'dart:convert';

import 'package:excel/excel.dart' hide Border;
import 'package:file_picker/file_picker.dart' as picker;
import 'package:flutter/material.dart';
import 'package:room_rental/core/utils/thumbnail_compressor.dart';
import 'package:room_rental/core/utils/google_maps_location.dart';
import 'package:room_rental/features/listings/data/repositories/scraped_listing_repository.dart';
import 'package:room_rental/features/listings/data/services/rental_post_parser.dart';
import 'package:room_rental/features/admin/presentation/widgets/admin_advertisements_panel.dart';
import 'package:room_rental/features/admin/presentation/widgets/pending_listings_panel.dart';
import 'package:room_rental/features/locations/data/location_store.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AdminLocationsPage extends StatefulWidget {
  const AdminLocationsPage({super.key});

  @override
  State<AdminLocationsPage> createState() => _AdminLocationsPageState();
}

class _AdminLocationsPageState extends State<AdminLocationsPage> {
  final store = LocationStore.instance;
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  String? province;
  String? district;
  bool signingIn = false;
  bool importingListings = false;
  bool checkingAdminAccess = true;
  bool hasAdminAccess = false;
  String? loginError;

  @override
  void initState() {
    super.initState();
    _verifyAdminAccess();
  }

  Future<void> _verifyAdminAccess() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      if (mounted) {
        setState(() {
          checkingAdminAccess = false;
          hasAdminAccess = false;
        });
      }
      return;
    }
    try {
      final rows = List<Map<String, dynamic>>.from(
        await Supabase.instance.client
            .from('profiles')
            .select('role')
            .eq('id', user.id)
            .limit(1),
      );
      if (!mounted) return;
      setState(() {
        hasAdminAccess = rows.isNotEmpty && rows.first['role'] == 'admin';
        checkingAdminAccess = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        hasAdminAccess = false;
        checkingAdminAccess = false;
      });
    }
  }

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    setState(() {
      signingIn = true;
      loginError = null;
    });
    try {
      final auth = Supabase.instance.client.auth;
      final response = await auth.signInWithPassword(
        email: emailController.text.trim(),
        password: passwordController.text,
      );
      final profile = await Supabase.instance.client
          .from('profiles')
          .select('role')
          .eq('id', response.user!.id)
          .single();
      if (profile['role'] != 'admin') {
        await auth.signOut();
        throw const AuthException('บัญชีนี้ไม่มีสิทธิ์ Admin');
      }
      await store.refreshFromRemote();
      if (mounted) {
        setState(() {
          hasAdminAccess = true;
          checkingAdminAccess = false;
        });
      }
    } catch (error) {
      if (mounted) setState(() => loginError = error.toString());
    } finally {
      if (mounted) setState(() => signingIn = false);
    }
  }

  Future<void> _openAiParser() async {
    await showDialog<void>(
      context: context,
      builder: (_) => const _AiParserDialog(),
    );
  }

  Future<void> _openAddApartment() async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => const _AddApartmentDialog(),
    );
    if (saved == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('เพิ่ม Apartment และเผยแพร่แล้ว')),
      );
    }
  }

  String _cellText(Data? cell) {
    final value = cell?.value;
    return switch (value) {
      null => '',
      TextCellValue() => (value.value.text ?? '').trim(),
      IntCellValue() => value.value.toString(),
      DoubleCellValue() => value.value.toString(),
      BoolCellValue() => value.value.toString(),
      _ => value.toString().trim(),
    };
  }

  Future<void> _importListingExcels() async {
    final result = await picker.FilePicker.pickFiles(
      type: picker.FileType.custom,
      allowedExtensions: ['xlsx'],
      withData: true,
      allowMultiple: true,
    );
    if (result == null) return;
    setState(() => importingListings = true);
    var skipped = 0;
    final items = <Map<String, dynamic>>[];
    try {
      for (final file in result.files) {
        if (file.bytes == null) {
          skipped++;
          continue;
        }
        final workbook = Excel.decodeBytes(file.bytes!);
        for (final sheet in workbook.tables.values) {
          if (sheet.rows.length < 2) continue;
          final headers = sheet.rows.first
              .map((cell) => _cellText(cell).trim().toLowerCase())
              .toList();
          int column(List<String> aliases) =>
              headers.indexWhere(aliases.contains);
          final columns = <String, int>{
            'title': column(['ชื่อที่พัก', 'ชื่อ', 'title']),
            'type': column(['หมวดหมู่', 'ประเภท', 'property_type', 'type']),
            'min': column(['ราคาต่ำสุด', 'price_min', 'monthly_price_min']),
            'max': column(['ราคาสูงสุด', 'price_max', 'monthly_price_max']),
            'currency': column(['สกุลเงิน', 'currency']),
            'province': column(['แขวง', 'province']),
            'district': column(['เมือง', 'district']),
            'village': column(['บ้าน', 'village']),
            'address': column(['ที่อยู่', 'address']),
            'phone': column(['เบอร์โทร', 'phone', 'contact_phone']),
            'source': column(['ลิงก์ต้นทาง', 'source_url']),
            'map': column(['google maps', 'พิกัด', 'map', 'map_url']),
            'thumbnail': column(['thumbnail', 'thumbnail_url', 'รูป']),
          };
          if (columns['title']! < 0 ||
              columns['min']! < 0 ||
              columns['max']! < 0 ||
              columns['province']! < 0) {
            skipped += sheet.rows.length - 1;
            continue;
          }
          for (final row in sheet.rows.skip(1)) {
            String value(String key) {
              final index = columns[key]!;
              return index >= 0 && index < row.length
                  ? _cellText(row[index]).trim()
                  : '';
            }

            final title = value('title');
            final priceMin = num.tryParse(value('min').replaceAll(',', ''));
            final priceMax = num.tryParse(value('max').replaceAll(',', ''));
            final provinceName = value('province');
            final mapInput = value('map');
            final mapLocation = GoogleMapsLocation.tryParse(mapInput);
            if (title.isEmpty ||
                priceMin == null ||
                priceMax == null ||
                priceMax < priceMin ||
                provinceName.isEmpty ||
                (mapInput.isNotEmpty && mapLocation == null)) {
              skipped++;
              continue;
            }
            final type = switch (value('type').toLowerCase()) {
              'room' || 'ห้องแถว' => 'room',
              'house' || 'บ้านเช่า' => 'house',
              'condo' || 'คอนโด' => 'condo',
              _ => 'apartment',
            };
            final currencyValue = value('currency').toUpperCase();
            final currency = const ['LAK', 'THB', 'USD'].contains(currencyValue)
                ? currencyValue
                : 'LAK';
            final sourceUrl = value('source');
            final parsed = <String, dynamic>{
              'title': title,
              'property_type': type,
              'monthly_price': priceMin,
              'monthly_price_min': priceMin,
              'monthly_price_max': priceMax,
              'currency': currency,
              'province': provinceName,
              'district': value('district').isEmpty ? null : value('district'),
              'village': value('village').isEmpty ? null : value('village'),
              'address': value('address').isEmpty ? null : value('address'),
              'contact_phone': value('phone').isEmpty ? null : value('phone'),
              'source_url': sourceUrl.isEmpty ? null : sourceUrl,
              'thumbnail_url': value('thumbnail').isEmpty
                  ? null
                  : value('thumbnail'),
              'map_url': mapLocation?.url,
              'latitude': mapLocation?.latitude,
              'longitude': mapLocation?.longitude,
              'posted_at': DateTime.now().toUtc().toIso8601String(),
              'manual_entry': true,
              'excel_import': true,
            };
            items.add({
              'raw_text': '$title — ${value('address')}',
              'source_url': sourceUrl.isEmpty ? null : sourceUrl,
              'parsed_data': parsed,
            });
          }
        }
      }
      final imported = await const ScrapedListingRepository().saveManyDrafts(
        items,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'นำเข้าที่พักสำเร็จ $imported รายการจาก ${result.files.length} ไฟล์'
            '${skipped > 0 ? ' • ข้าม $skipped แถว' : ''}',
          ),
        ),
      );
    } catch (exception) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.red.shade700,
            content: Text('นำเข้าที่พักไม่สำเร็จ: $exception'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => importingListings = false);
    }
  }

  Future<void> _importExcel() async {
    final result = await picker.FilePicker.pickFiles(
      type: picker.FileType.custom,
      allowedExtensions: ['xlsx'],
      withData: true,
    );
    if (result == null || result.files.single.bytes == null) return;

    try {
      final workbook = Excel.decodeBytes(result.files.single.bytes!);
      if (workbook.tables.isEmpty) throw const FormatException('ไม่พบ Sheet');
      final sheet = workbook.tables.values.first;
      if (sheet.rows.isEmpty) throw const FormatException('ไม่มีข้อมูล');

      final headers = sheet.rows.first
          .map((cell) => _cellText(cell).toLowerCase())
          .toList();
      int column(List<String> names) =>
          headers.indexWhere((header) => names.contains(header));
      final provinceColumn = column(['แขวง', 'province']);
      final districtColumn = column(['เมือง', 'district']);
      final villageColumn = column(['บ้าน', 'village']);
      if ([provinceColumn, districtColumn, villageColumn].contains(-1)) {
        throw const FormatException('หัวตารางต้องมี แขวง, เมือง และ บ้าน');
      }

      final rows = <(String, String, String)>[];
      var skipped = 0;
      var previousProvince = '';
      var previousDistrict = '';
      for (final row in sheet.rows.skip(1)) {
        String valueAt(int index) =>
            index < row.length ? _cellText(row[index]) : '';
        final rawProvince = valueAt(provinceColumn);
        final rawDistrict = valueAt(districtColumn);
        final village = valueAt(villageColumn);
        if (rawProvince.isEmpty && rawDistrict.isEmpty && village.isEmpty) {
          continue;
        }
        if (rawProvince.isNotEmpty) {
          if (rawProvince != previousProvince) {
            previousDistrict = '';
          }
          previousProvince = rawProvince;
        }
        if (rawDistrict.isNotEmpty) {
          previousDistrict = rawDistrict;
        }
        final item = (previousProvince, previousDistrict, village);
        if (item.$1.isEmpty || item.$2.isEmpty || item.$3.isEmpty) {
          skipped++;
        } else {
          rows.add(item);
        }
      }
      final imported = await store.importRows(rows);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'นำเข้าสำเร็จ $imported บ้าน${skipped > 0 ? ' • ข้าม $skipped แถวที่ข้อมูลไม่ครบ' : ''}',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('นำเข้าไม่สำเร็จ: $error')));
    }
  }

  Future<void> _importDistrictExcel(String provinceName) async {
    final result = await picker.FilePicker.pickFiles(
      type: picker.FileType.custom,
      allowedExtensions: ['xlsx'],
      withData: true,
    );
    if (result == null || result.files.single.bytes == null) return;
    try {
      final workbook = Excel.decodeBytes(result.files.single.bytes!);
      if (workbook.tables.isEmpty) throw const FormatException('ไม่พบ Sheet');
      final sheet = workbook.tables.values.first;
      if (sheet.rows.isEmpty) throw const FormatException('ไม่มีข้อมูล');
      final headers = sheet.rows.first
          .map((cell) => _cellText(cell).toLowerCase())
          .toList();
      final districtColumn = headers.indexWhere(
        (header) => header == 'เมือง' || header == 'district',
      );
      if (districtColumn < 0) {
        throw const FormatException('หัวตารางต้องมีคอลัมน์ เมือง');
      }
      final names = sheet.rows
          .skip(1)
          .map((row) {
            if (districtColumn >= row.length) return '';
            return _cellText(row[districtColumn]);
          })
          .where((name) => name.isNotEmpty)
          .toList();
      final imported = await store.importDistricts(provinceName, names);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'นำเข้าเมืองสำเร็จ $imported รายการ${names.length > imported ? ' • ข้ามรายการซ้ำ ${names.length - imported}' : ''}',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.red.shade700,
          content: Text('นำเข้าเมืองไม่สำเร็จ: $error'),
        ),
      );
    }
  }

  Future<void> _importVillageExcel(
    String provinceName,
    String districtName,
  ) async {
    final result = await picker.FilePicker.pickFiles(
      type: picker.FileType.custom,
      allowedExtensions: ['xlsx'],
      withData: true,
    );
    if (result == null || result.files.single.bytes == null) return;
    try {
      final workbook = Excel.decodeBytes(result.files.single.bytes!);
      if (workbook.tables.isEmpty) throw const FormatException('ไม่พบ Sheet');
      final sheet = workbook.tables.values.first;
      if (sheet.rows.isEmpty) throw const FormatException('ไม่มีข้อมูล');
      final headers = sheet.rows.first
          .map((cell) => _cellText(cell).toLowerCase())
          .toList();
      final villageColumn = headers.indexWhere(
        (header) => header == 'บ้าน' || header == 'village',
      );
      if (villageColumn < 0) {
        throw const FormatException('หัวตารางต้องมีคอลัมน์ บ้าน');
      }
      final names = sheet.rows
          .skip(1)
          .map((row) {
            if (villageColumn >= row.length) return '';
            return _cellText(row[villageColumn]);
          })
          .where((name) => name.isNotEmpty)
          .toList();
      final uniqueNames = names.map((name) => name.trim()).toSet().toList();
      if (uniqueNames.isEmpty) {
        throw const FormatException('ไม่พบรายชื่อบ้านในไฟล์');
      }
      if (!mounted) return;
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('ยืนยันแทนที่รายชื่อบ้านทั้งหมด'),
          content: Text(
            'เมือง “$districtName” มีรายชื่อเดิม '
            '${store.data[provinceName]?[districtName]?.length ?? 0} บ้าน\n\n'
            'ระบบจะแทนที่ด้วยข้อมูลใหม่ ${uniqueNames.length} บ้านจาก Excel '
            'รายการเดิมที่ไม่มีในไฟล์จะถูกลบออก ต้องการดำเนินการหรือไม่?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('ยกเลิก'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('แทนที่ข้อมูลทั้งหมด'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
      final finalCount = await store.replaceVillages(
        provinceName,
        districtName,
        uniqueNames,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'แทนที่รายชื่อบ้านใน $districtName สำเร็จ • ทั้งหมด $finalCount บ้าน',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.red.shade700,
          content: Text('นำเข้าบ้านไม่สำเร็จ: $error'),
        ),
      );
    }
  }

  Future<String?> _askName(
    String title, {
    String initial = '',
    Future<void> Function()? onImportExcel,
    String importLabel = 'อัปโหลด Excel',
  }) async {
    final controller = TextEditingController(text: initial);
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'ชื่อ'),
          onSubmitted: (value) => Navigator.pop(context, value.trim()),
        ),
        actions: [
          if (onImportExcel != null)
            OutlinedButton.icon(
              onPressed: () {
                Navigator.pop(context);
                onImportExcel();
              },
              icon: const Icon(Icons.upload_file_outlined),
              label: Text(importLabel),
            ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('ยกเลิก'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('บันทึก'),
          ),
        ],
      ),
    );
  }

  Future<bool> _confirmDelete(String name) async =>
      await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('ยืนยันการลบ'),
          content: Text('ต้องการลบ “$name” และข้อมูลภายในทั้งหมดหรือไม่?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('ยกเลิก'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('ลบ'),
            ),
          ],
        ),
      ) ??
      false;

  Future<bool> _runMutation(
    Future<void> Function() action,
    String successMessage,
  ) async {
    try {
      await action();
      if (!mounted) return true;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(successMessage)));
      return true;
    } catch (error) {
      if (!mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.red.shade700,
          content: Text('บันทึกไม่สำเร็จ: $error'),
        ),
      );
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (Supabase.instance.client.auth.currentUser == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Admin • เข้าสู่ระบบ')),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Icon(
                      Icons.admin_panel_settings_outlined,
                      size: 52,
                      color: Color(0xFF2563EB),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'เข้าสู่ระบบผู้ดูแล',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 24),
                    TextField(
                      controller: emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: 'อีเมล',
                        prefixIcon: Icon(Icons.email_outlined),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: passwordController,
                      obscureText: true,
                      onSubmitted: (_) => _signIn(),
                      decoration: const InputDecoration(
                        labelText: 'รหัสผ่าน',
                        prefixIcon: Icon(Icons.lock_outline),
                      ),
                    ),
                    if (loginError != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        loginError!,
                        style: const TextStyle(color: Colors.red),
                      ),
                    ],
                    const SizedBox(height: 20),
                    FilledButton.icon(
                      onPressed: signingIn ? null : _signIn,
                      icon: signingIn
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.login),
                      label: const Text('เข้าสู่ระบบ Admin'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }
    if (checkingAdminAccess) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (!hasAdminAccess) {
      final user = Supabase.instance.client.auth.currentUser;
      return Scaffold(
        appBar: AppBar(
          title: const Text('Admin • ไม่มีสิทธิ์เข้าถึง'),
          actions: [
            TextButton.icon(
              onPressed: () async {
                await Supabase.instance.client.auth.signOut();
                if (!mounted) return;
                setState(() {
                  hasAdminAccess = false;
                  checkingAdminAccess = false;
                  loginError = null;
                });
              },
              icon: const Icon(Icons.admin_panel_settings_outlined),
              label: const Text('เข้าสู่ระบบ Admin'),
            ),
            const SizedBox(width: 16),
          ],
        ),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircleAvatar(
                      radius: 34,
                      backgroundColor: Color(0xFFFEE2E2),
                      child: Icon(
                        Icons.lock_outline,
                        size: 36,
                        color: Color(0xFFDC2626),
                      ),
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      'หน้านี้สำหรับผู้ดูแลเท่านั้น',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${user?.email ?? 'บัญชีนี้'} ไม่มีสิทธิ์จัดการข้อมูลหรืออนุมัติประกาศ',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Color(0xFF64748B)),
                    ),
                    const SizedBox(height: 22),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: () => Navigator.pushNamedAndRemoveUntil(
                          context,
                          '/',
                          (route) => false,
                        ),
                        icon: const Icon(Icons.home_outlined),
                        label: const Text('กลับหน้าหลัก'),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: () async {
                        await Supabase.instance.client.auth.signOut();
                        if (!context.mounted) return;
                        setState(() {
                          hasAdminAccess = false;
                          checkingAdminAccess = false;
                        });
                      },
                      child: const Text('ออกจากระบบ'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Admin • จัดการพื้นที่'),
        actions: [
          TextButton.icon(
            onPressed: () async {
              await Supabase.instance.client.auth.signOut();
              if (mounted) {
                setState(() {
                  hasAdminAccess = false;
                  checkingAdminAccess = false;
                });
              }
            },
            icon: const Icon(Icons.logout),
            label: const Text('ออกจากระบบ'),
          ),
          TextButton.icon(
            onPressed: () => Navigator.pushNamedAndRemoveUntil(
              context,
              '/',
              (route) => false,
            ),
            icon: const Icon(Icons.visibility_outlined),
            label: const Text('ดูหน้าเว็บไซต์'),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: AnimatedBuilder(
        animation: store,
        builder: (context, _) {
          final provinces = store.data.keys.toList();
          if (province != null && !store.data.containsKey(province)) {
            province = null;
            district = null;
          }
          final districts = province == null
              ? <String>[]
              : store.data[province]!.keys.toList();
          if (district != null && !districts.contains(district)) {
            district = null;
          }
          final villages = province == null || district == null
              ? <String>[]
              : store.data[province]![district]!;

          return ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'ภาพรวมข้อมูล',
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: _importExcel,
                    icon: const Icon(Icons.upload_file_outlined),
                    label: const Text('นำเข้าพื้นที่ Excel'),
                  ),
                  const SizedBox(width: 12),
                  OutlinedButton.icon(
                    onPressed: importingListings ? null : _importListingExcels,
                    icon: importingListings
                        ? const SizedBox.square(
                            dimension: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.file_upload_outlined),
                    label: Text(
                      importingListings
                          ? 'กำลังนำเข้า...'
                          : 'นำเข้าที่พัก Excel',
                    ),
                  ),
                  const SizedBox(width: 12),
                  FilledButton.icon(
                    onPressed: _openAiParser,
                    icon: const Icon(Icons.auto_awesome_outlined),
                    label: const Text('AI แยกประกาศ'),
                  ),
                  const SizedBox(width: 12),
                  FilledButton.icon(
                    onPressed: _openAddApartment,
                    icon: const Icon(Icons.add_home_work_outlined),
                    label: const Text('เพิ่มที่พัก'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 16,
                runSpacing: 16,
                children: [
                  _StatCard(
                    icon: Icons.map_outlined,
                    label: 'แขวง',
                    value: store.data.length,
                  ),
                  _StatCard(
                    icon: Icons.location_city_outlined,
                    label: 'เมือง',
                    value: store.districtCount,
                  ),
                  _StatCard(
                    icon: Icons.home_outlined,
                    label: 'บ้าน',
                    value: store.villageCount,
                  ),
                ],
              ),
              const SizedBox(height: 28),
              const AdminAdvertisementsPanel(),
              const SizedBox(height: 28),
              const PendingListingsPanel(),
              const SizedBox(height: 28),
              LayoutBuilder(
                builder: (context, constraints) {
                  final columns = [
                    _LocationPanel(
                      title: 'แขวง',
                      items: provinces,
                      selected: province,
                      onSelect: (value) => setState(() {
                        province = value;
                        district = null;
                      }),
                      onAdd: () async {
                        final value = await _askName('เพิ่มแขวง');
                        if (value?.isNotEmpty ?? false) {
                          await _runMutation(
                            () => store.addProvince(value!),
                            'เพิ่มแขวง $value สำเร็จ',
                          );
                        }
                      },
                      onEdit: (value) async {
                        final next = await _askName(
                          'แก้ไขแขวง',
                          initial: value,
                        );
                        if (next?.isNotEmpty ?? false) {
                          final success = await _runMutation(
                            () => store.renameProvince(value, next!),
                            'แก้ไขแขวงสำเร็จ',
                          );
                          if (success) {
                            setState(() => province = next);
                          }
                        }
                      },
                      onDelete: (value) async {
                        if (await _confirmDelete(value)) {
                          await _runMutation(
                            () => store.deleteProvince(value),
                            'ลบแขวง $value สำเร็จ',
                          );
                        }
                      },
                    ),
                    _LocationPanel(
                      title: 'เมือง',
                      items: districts,
                      selected: district,
                      enabled: province != null,
                      onSelect: (value) => setState(() => district = value),
                      onAdd: () async {
                        final value = await _askName(
                          'เพิ่มเมืองใน $province',
                          onImportExcel: () => _importDistrictExcel(province!),
                        );
                        if (value?.isNotEmpty ?? false) {
                          await _runMutation(
                            () => store.addDistrict(province!, value!),
                            'เพิ่มเมือง $value สำเร็จ',
                          );
                        }
                      },
                      onEdit: (value) async {
                        final next = await _askName(
                          'แก้ไขเมือง',
                          initial: value,
                        );
                        if (next?.isNotEmpty ?? false) {
                          final success = await _runMutation(
                            () => store.renameDistrict(province!, value, next!),
                            'แก้ไขเมืองสำเร็จ',
                          );
                          if (success) {
                            setState(() => district = next);
                          }
                        }
                      },
                      onDelete: (value) async {
                        if (await _confirmDelete(value)) {
                          await _runMutation(
                            () => store.deleteDistrict(province!, value),
                            'ลบเมือง $value สำเร็จ',
                          );
                        }
                      },
                    ),
                    _LocationPanel(
                      title: 'บ้าน',
                      items: villages,
                      enabled: district != null,
                      onSelect: (_) {},
                      onAdd: () async {
                        final value = await _askName(
                          'เพิ่มบ้านใน $district',
                          onImportExcel: () =>
                              _importVillageExcel(province!, district!),
                          importLabel: 'แทนที่บ้านทั้งหมดด้วย Excel',
                        );
                        if (value?.isNotEmpty ?? false) {
                          await _runMutation(
                            () =>
                                store.addVillage(province!, district!, value!),
                            'เพิ่มบ้าน $value สำเร็จ',
                          );
                        }
                      },
                      onEdit: (value) async {
                        final next = await _askName(
                          'แก้ไขบ้าน',
                          initial: value,
                        );
                        if (next?.isNotEmpty ?? false) {
                          await _runMutation(
                            () => store.renameVillage(
                              province!,
                              district!,
                              value,
                              next!,
                            ),
                            'แก้ไขบ้านสำเร็จ',
                          );
                        }
                      },
                      onDelete: (value) async {
                        if (await _confirmDelete(value)) {
                          await _runMutation(
                            () => store.deleteVillage(
                              province!,
                              district!,
                              value,
                            ),
                            'ลบบ้าน $value สำเร็จ',
                          );
                        }
                      },
                    ),
                  ];
                  if (constraints.maxWidth < 850) {
                    return Column(
                      children: columns
                          .expand((item) => [item, const SizedBox(height: 16)])
                          .toList(),
                    );
                  }
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children:
                        columns
                            .expand(
                              (item) => [
                                Expanded(child: item),
                                const SizedBox(width: 16),
                              ],
                            )
                            .toList()
                          ..removeLast(),
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }
}

class _AddApartmentDialog extends StatefulWidget {
  const _AddApartmentDialog();

  @override
  State<_AddApartmentDialog> createState() => _AddApartmentDialogState();
}

class _AddApartmentDialogState extends State<_AddApartmentDialog> {
  final formKey = GlobalKey<FormState>();
  final titleController = TextEditingController();
  final priceMinController = TextEditingController();
  final priceMaxController = TextEditingController();
  final addressController = TextEditingController();
  final phoneController = TextEditingController();
  final sourceController = TextEditingController();
  final mapController = TextEditingController();
  final repository = const ScrapedListingRepository();
  final store = LocationStore.instance;
  String currency = 'LAK';
  String propertyType = 'apartment';
  String? province;
  String? district;
  String? village;
  picker.PlatformFile? thumbnail;
  final List<picker.PlatformFile> galleryImages = [];
  bool thumbnailWasCompressed = false;
  bool processingThumbnail = false;
  bool processingGallery = false;
  bool saving = false;
  String? error;

  Future<void> _pickThumbnail() async {
    final result = await picker.FilePicker.pickFiles(
      type: picker.FileType.image,
      withData: true,
      allowMultiple: false,
    );
    if (result == null || result.files.single.bytes == null || !mounted) return;
    setState(() {
      processingThumbnail = true;
      error = null;
    });
    try {
      final selected = result.files.single;
      final compressed = ThumbnailCompressor.compress(
        selected.bytes!,
        selected.name,
      );
      if (!mounted) return;
      setState(() {
        thumbnail = picker.PlatformFile(
          name: compressed.fileName,
          size: compressed.bytes.lengthInBytes,
          bytes: compressed.bytes,
        );
        thumbnailWasCompressed = compressed.wasCompressed;
      });
    } catch (exception) {
      if (mounted) setState(() => error = exception.toString());
    } finally {
      if (mounted) setState(() => processingThumbnail = false);
    }
  }

  Future<void> _pickGalleryImages() async {
    final remaining = 4 - galleryImages.length;
    if (remaining <= 0) {
      setState(() => error = 'อัปโหลดรูปภายในได้ไม่เกิน 4 รูป');
      return;
    }
    final result = await picker.FilePicker.pickFiles(
      type: picker.FileType.image,
      withData: true,
      allowMultiple: true,
    );
    if (result == null || !mounted) return;
    final selected = result.files.where((file) => file.bytes != null).toList();
    if (selected.length > remaining) {
      setState(() => error = 'เลือกเพิ่มได้อีกเพียง $remaining รูป');
      return;
    }
    setState(() {
      processingGallery = true;
      error = null;
    });
    try {
      final compressedFiles = <picker.PlatformFile>[];
      for (final file in selected) {
        final compressed = ThumbnailCompressor.compress(file.bytes!, file.name);
        compressedFiles.add(
          picker.PlatformFile(
            name: compressed.fileName,
            size: compressed.bytes.lengthInBytes,
            bytes: compressed.bytes,
          ),
        );
      }
      if (mounted) setState(() => galleryImages.addAll(compressedFiles));
    } catch (exception) {
      if (mounted) setState(() => error = exception.toString());
    } finally {
      if (mounted) setState(() => processingGallery = false);
    }
  }

  @override
  void dispose() {
    titleController.dispose();
    priceMinController.dispose();
    priceMaxController.dispose();
    addressController.dispose();
    phoneController.dispose();
    sourceController.dispose();
    mapController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!(formKey.currentState?.validate() ?? false)) return;
    setState(() {
      saving = true;
      error = null;
    });
    try {
      final priceMin = num.parse(
        priceMinController.text.replaceAll(',', '').trim(),
      );
      final priceMax = num.parse(
        priceMaxController.text.replaceAll(',', '').trim(),
      );
      final mapLocation = GoogleMapsLocation.tryParse(mapController.text);
      String? thumbnailUrl;
      if (thumbnail?.bytes != null) {
        thumbnailUrl = await repository.uploadThumbnail(
          bytes: thumbnail!.bytes!,
          fileName: thumbnail!.name,
        );
      }
      final galleryUrls = await repository.uploadGalleryImages(
        galleryImages
            .where((file) => file.bytes != null)
            .map((file) => (bytes: file.bytes!, fileName: file.name))
            .toList(),
      );
      final parsed = <String, dynamic>{
        'title': titleController.text.trim(),
        'description': addressController.text.trim().isEmpty
            ? null
            : addressController.text.trim(),
        'property_type': propertyType,
        'monthly_price': priceMin,
        'monthly_price_min': priceMin,
        'monthly_price_max': priceMax,
        'currency': currency,
        'province': province,
        'district': district,
        'village': village,
        'address': addressController.text.trim().isEmpty
            ? null
            : addressController.text.trim(),
        'bedrooms': null,
        'bathrooms': null,
        'amenities': <String>[],
        'contact_name': null,
        'contact_phone': phoneController.text.trim().isEmpty
            ? null
            : phoneController.text.trim(),
        'source_url': sourceController.text.trim().isEmpty
            ? null
            : sourceController.text.trim(),
        'posted_at': DateTime.now().toUtc().toIso8601String(),
        'confidence': 1,
        'missing_fields': <String>[],
        'manual_entry': true,
        'thumbnail_url': thumbnailUrl,
        'gallery_urls': galleryUrls,
        'map_url': mapLocation?.url,
        'latitude': mapLocation?.latitude,
        'longitude': mapLocation?.longitude,
      };
      await repository.saveDraft(
        rawText: [
          titleController.text.trim(),
          addressController.text.trim(),
        ].where((value) => value.isNotEmpty).join(' — '),
        sourceUrl: sourceController.text,
        parsedData: parsed,
      );
      if (mounted) Navigator.pop(context, true);
    } catch (exception) {
      if (mounted) setState(() => error = exception.toString());
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final districts = province == null
        ? const <String>[]
        : store.data[province]?.keys.toList() ?? const <String>[];
    final villages = province == null || district == null
        ? const <String>[]
        : store.data[province]?[district] ?? const <String>[];
    return AlertDialog(
      title: const Text('เพิ่มที่พัก'),
      content: SizedBox(
        width: 680,
        child: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                InkWell(
                  onTap: saving || processingThumbnail ? null : _pickThumbnail,
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    width: double.infinity,
                    height: 150,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFCBD5E1)),
                    ),
                    child: processingThumbnail
                        ? const Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              CircularProgressIndicator(),
                              SizedBox(height: 10),
                              Text('กำลังบีบอัดรูป...'),
                            ],
                          )
                        : thumbnail?.bytes == null
                        ? const Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.add_photo_alternate_outlined,
                                size: 42,
                              ),
                              SizedBox(height: 8),
                              Text('เพิ่มรูป Thumbnail (ไม่บังคับ)'),
                              Text(
                                'รองรับ JPG, PNG และ WebP',
                                style: TextStyle(color: Color(0xFF64748B)),
                              ),
                            ],
                          )
                        : ClipRRect(
                            borderRadius: BorderRadius.circular(15),
                            child: Image.memory(
                              thumbnail!.bytes!,
                              fit: BoxFit.cover,
                            ),
                          ),
                  ),
                ),
                if (thumbnail != null)
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: saving
                          ? null
                          : () => setState(() => thumbnail = null),
                      icon: const Icon(Icons.delete_outline),
                      label: Text(
                        '${thumbnailWasCompressed ? 'บีบอัดแล้ว • ' : ''}'
                        '${(thumbnail!.size / 1024).ceil()} KB • ลบรูป',
                      ),
                    ),
                  ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: saving || processingGallery
                      ? null
                      : _pickGalleryImages,
                  icon: processingGallery
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.collections_outlined),
                  label: Text(
                    processingGallery
                        ? 'กำลังบีบอัดรูป...'
                        : 'เพิ่มรูปภายในห้อง (${galleryImages.length}/4)',
                  ),
                ),
                if (galleryImages.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: List.generate(galleryImages.length, (index) {
                      final file = galleryImages[index];
                      return Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.memory(
                              file.bytes!,
                              width: 118,
                              height: 86,
                              fit: BoxFit.cover,
                            ),
                          ),
                          Positioned(
                            top: 3,
                            right: 3,
                            child: IconButton.filled(
                              visualDensity: VisualDensity.compact,
                              tooltip: 'ลบรูป',
                              onPressed: saving
                                  ? null
                                  : () => setState(
                                      () => galleryImages.removeAt(index),
                                    ),
                              icon: const Icon(Icons.close, size: 16),
                            ),
                          ),
                          Positioned(
                            left: 5,
                            bottom: 4,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color: Colors.black54,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 5,
                                  vertical: 2,
                                ),
                                child: Text(
                                  '${(file.size / 1024).ceil()} KB',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      );
                    }),
                  ),
                ],
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: propertyType,
                  decoration: const InputDecoration(labelText: 'หมวดหมู่ *'),
                  items:
                      const {
                            'room': 'ห้องแถว',
                            'apartment': 'อพาร์ตเมนต์',
                            'house': 'บ้านเช่า',
                            'condo': 'คอนโด',
                          }.entries
                          .map(
                            (entry) => DropdownMenuItem(
                              value: entry.key,
                              child: Text(entry.value),
                            ),
                          )
                          .toList(),
                  onChanged: (value) => setState(() => propertyType = value!),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: titleController,
                  autofocus: true,
                  decoration: const InputDecoration(labelText: 'ชื่อที่พัก *'),
                  validator: (value) => value?.trim().isEmpty ?? true
                      ? 'กรุณากรอกชื่อที่พัก'
                      : null,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: priceMinController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'ราคาต่ำสุด/เดือน *',
                        ),
                        validator: (value) =>
                            num.tryParse(
                                  value?.replaceAll(',', '').trim() ?? '',
                                ) ==
                                null
                            ? 'กรุณากรอกราคาเป็นตัวเลข'
                            : null,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: priceMaxController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'ราคาสูงสุด/เดือน *',
                        ),
                        validator: (value) {
                          final maximum = num.tryParse(
                            value?.replaceAll(',', '').trim() ?? '',
                          );
                          final minimum = num.tryParse(
                            priceMinController.text.replaceAll(',', '').trim(),
                          );
                          if (maximum == null) {
                            return 'กรุณากรอกราคาเป็นตัวเลข';
                          }
                          if (minimum != null && maximum < minimum) {
                            return 'ต้องไม่น้อยกว่าราคาต่ำสุด';
                          }
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: currency,
                        decoration: const InputDecoration(
                          labelText: 'สกุลเงิน',
                        ),
                        items: const ['LAK', 'THB', 'USD']
                            .map(
                              (value) => DropdownMenuItem(
                                value: value,
                                child: Text(value),
                              ),
                            )
                            .toList(),
                        onChanged: (value) => setState(() => currency = value!),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: province,
                  decoration: const InputDecoration(labelText: 'แขวง *'),
                  items: store.data.keys
                      .map(
                        (value) =>
                            DropdownMenuItem(value: value, child: Text(value)),
                      )
                      .toList(),
                  validator: (value) => value == null ? 'กรุณาเลือกแขวง' : null,
                  onChanged: (value) => setState(() {
                    province = value;
                    district = null;
                    village = null;
                  }),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: district,
                        decoration: const InputDecoration(labelText: 'เมือง'),
                        items: districts
                            .map(
                              (value) => DropdownMenuItem(
                                value: value,
                                child: Text(value),
                              ),
                            )
                            .toList(),
                        onChanged: province == null
                            ? null
                            : (value) => setState(() {
                                district = value;
                                village = null;
                              }),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: village,
                        decoration: const InputDecoration(labelText: 'บ้าน'),
                        items: villages
                            .map(
                              (value) => DropdownMenuItem(
                                value: value,
                                child: Text(value),
                              ),
                            )
                            .toList(),
                        onChanged: district == null
                            ? null
                            : (value) => setState(() => village = value),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: addressController,
                  decoration: const InputDecoration(
                    labelText: 'ที่อยู่เพิ่มเติม',
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(labelText: 'เบอร์โทร'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: sourceController,
                  keyboardType: TextInputType.url,
                  decoration: const InputDecoration(
                    labelText: 'ลิงก์ต้นทาง (ถ้ามี)',
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: mapController,
                  keyboardType: TextInputType.url,
                  decoration: const InputDecoration(
                    labelText: 'Google Maps link หรือพิกัด',
                    hintText: '17.908634442903843, 102.63205905992898',
                    prefixIcon: Icon(Icons.map_outlined),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) return null;
                    final location = GoogleMapsLocation.tryParse(value);
                    return location?.latitude == null ||
                            location?.longitude == null
                        ? 'ลิงก์นี้ไม่มีพิกัด กรุณาใส่ latitude, longitude หรือ URL แบบเต็ม'
                        : null;
                  },
                ),
                if (error != null) ...[
                  const SizedBox(height: 12),
                  Text(error!, style: const TextStyle(color: Colors.red)),
                ],
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: saving ? null : () => Navigator.pop(context, false),
          child: const Text('ยกเลิก'),
        ),
        FilledButton.icon(
          onPressed: saving ? null : _save,
          icon: saving
              ? const SizedBox.square(
                  dimension: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.publish_outlined),
          label: Text(saving ? 'กำลังบันทึก...' : 'บันทึกและเผยแพร่'),
        ),
      ],
    );
  }
}

class _AiParserDialog extends StatefulWidget {
  const _AiParserDialog();

  @override
  State<_AiParserDialog> createState() => _AiParserDialogState();
}

class _AiParserDialogState extends State<_AiParserDialog> {
  final postController = TextEditingController();
  final sourceController = TextEditingController();
  final parser = const RentalPostParser();
  final repository = const ScrapedListingRepository();
  Map<String, dynamic>? result;
  String? error;
  bool loading = false;
  bool saving = false;
  bool saved = false;

  @override
  void dispose() {
    postController.dispose();
    sourceController.dispose();
    super.dispose();
  }

  Future<void> _saveDraft() async {
    final parsed = result;
    if (parsed == null) return;
    setState(() {
      saving = true;
      error = null;
    });
    try {
      await repository.saveDraft(
        rawText: postController.text,
        sourceUrl: sourceController.text,
        parsedData: parsed,
      );
      if (mounted) setState(() => saved = true);
    } catch (exception) {
      if (mounted) setState(() => error = exception.toString());
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Future<void> _parse() async {
    if (postController.text.trim().isEmpty) {
      setState(() => error = 'กรุณาวางข้อความประกาศ');
      return;
    }
    setState(() {
      loading = true;
      error = null;
      result = null;
      saved = false;
    });
    try {
      final parsed = await parser.parse(
        text: postController.text,
        sourceUrl: sourceController.text,
      );
      if (mounted) setState(() => result = parsed);
    } catch (exception) {
      if (mounted) setState(() => error = exception.toString());
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Row(
      children: [
        Icon(Icons.auto_awesome_outlined),
        SizedBox(width: 10),
        Text('AI แยกข้อมูลประกาศ'),
      ],
    ),
    content: SizedBox(
      width: 680,
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: postController,
              minLines: 6,
              maxLines: 12,
              decoration: const InputDecoration(
                labelText: 'ข้อความประกาศ',
                hintText: 'วางข้อความประกาศภาษาไทย ภาษาลาว หรืออังกฤษที่นี่',
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: sourceController,
              decoration: const InputDecoration(
                labelText: 'ลิงก์โพสต์ต้นทาง (ถ้ามี)',
                prefixIcon: Icon(Icons.link),
              ),
            ),
            if (error != null) ...[
              const SizedBox(height: 12),
              Text(error!, style: const TextStyle(color: Colors.red)),
            ],
            if (result != null) ...[
              const SizedBox(height: 18),
              const Text(
                'ผลลัพธ์ (ตรวจสอบก่อนบันทึก)',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              SelectableText(
                const JsonEncoder.withIndent('  ').convert(result),
                style: const TextStyle(fontFamily: 'monospace'),
              ),
              if (saved) ...[
                const SizedBox(height: 12),
                const Text(
                  'บันทึกและเผยแพร่แล้ว',
                  style: TextStyle(
                    color: Colors.green,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: loading || saving ? null : () => Navigator.pop(context),
        child: const Text('ปิด'),
      ),
      if (result != null)
        OutlinedButton.icon(
          onPressed: loading || saving || saved ? null : _saveDraft,
          icon: saving
              ? const SizedBox.square(
                  dimension: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.save_outlined),
          label: Text(saving ? 'กำลังบันทึก...' : 'บันทึกและเผยแพร่'),
        ),
      FilledButton.icon(
        onPressed: loading || saving ? null : _parse,
        icon: loading
            ? const SizedBox.square(
                dimension: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.auto_awesome),
        label: Text(loading ? 'กำลังวิเคราะห์...' : 'วิเคราะห์'),
      ),
    ],
  );
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
  });
  final IconData icon;
  final String label;
  final int value;

  @override
  Widget build(BuildContext context) => Container(
    width: 210,
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
    ),
    child: Row(
      children: [
        CircleAvatar(child: Icon(icon)),
        const SizedBox(width: 14),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$value',
              style: const TextStyle(fontSize: 25, fontWeight: FontWeight.bold),
            ),
            Text(label, style: const TextStyle(color: Color(0xFF64748B))),
          ],
        ),
      ],
    ),
  );
}

class _LocationPanel extends StatelessWidget {
  const _LocationPanel({
    required this.title,
    required this.items,
    required this.onSelect,
    required this.onAdd,
    required this.onEdit,
    required this.onDelete,
    this.selected,
    this.enabled = true,
  });
  final String title;
  final List<String> items;
  final String? selected;
  final bool enabled;
  final ValueChanged<String> onSelect;
  final VoidCallback onAdd;
  final ValueChanged<String> onEdit;
  final ValueChanged<String> onDelete;

  @override
  Widget build(BuildContext context) => Card(
    elevation: 0,
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              FilledButton.icon(
                onPressed: enabled ? onAdd : null,
                icon: const Icon(Icons.add),
                label: const Text('เพิ่ม'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (!enabled)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'เลือกรายการก่อนหน้าเพื่อจัดการข้อมูล',
                textAlign: TextAlign.center,
                style: TextStyle(color: Color(0xFF94A3B8)),
              ),
            )
          else if (items.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Text('ยังไม่มีข้อมูล', textAlign: TextAlign.center),
            )
          else
            ...items.map(
              (item) => ListTile(
                selected: selected == item,
                selectedTileColor: const Color(0xFFDBEAFE),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                title: Text(item),
                onTap: () => onSelect(item),
                trailing: PopupMenuButton<String>(
                  onSelected: (action) =>
                      action == 'edit' ? onEdit(item) : onDelete(item),
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'edit', child: Text('แก้ไข')),
                    PopupMenuItem(value: 'delete', child: Text('ลบ')),
                  ],
                ),
              ),
            ),
        ],
      ),
    ),
  );
}
