import 'package:flutter/material.dart';
import 'package:room_rental/core/utils/google_maps_location.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

class PendingListingsPanel extends StatefulWidget {
  const PendingListingsPanel({super.key});

  @override
  State<PendingListingsPanel> createState() => _PendingListingsPanelState();
}

class _PendingListingsPanelState extends State<PendingListingsPanel> {
  List<Map<String, dynamic>>? _items;
  final Set<String> _updatingIds = {};
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final rows = await Supabase.instance.client
          .from('scraped_listings')
          .select(
            'id,title,property_type,province,district,village,thumbnail_url,contact_phone,monthly_price_min,monthly_price_max,currency,created_at,parsed_data,map_url,latitude,longitude,source_url,gallery_urls',
          )
          .eq('status', 'pending_review')
          .contains('parsed_data', const {'client_submission': true})
          .order('created_at');
      if (mounted) {
        setState(() {
          _items = List<Map<String, dynamic>>.from(rows);
          _error = null;
        });
      }
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    }
  }

  Future<void> _setStatus(Map<String, dynamic> item, String status) async {
    final id = item['id']?.toString();
    if (id == null || _updatingIds.contains(id)) return;
    setState(() {
      _updatingIds.add(id);
      _error = null;
    });
    try {
      final parsed = item['parsed_data'] is Map
          ? Map<String, dynamic>.from(item['parsed_data'] as Map)
          : const <String, dynamic>{};
      final mapLocation = GoogleMapsLocation.tryParse(
        (item['map_url'] ?? parsed['map_url'] ?? '').toString(),
      );
      await Supabase.instance.client
          .from('scraped_listings')
          .update({
            'status': status,
            'updated_at': DateTime.now().toUtc().toIso8601String(),
            if (status == 'approved' && mapLocation != null) ...{
              'map_url': mapLocation.url,
              'latitude': mapLocation.latitude,
              'longitude': mapLocation.longitude,
            },
          })
          .eq('id', id)
          .eq('status', 'pending_review');
      final verification = List<Map<String, dynamic>>.from(
        await Supabase.instance.client
            .from('scraped_listings')
            .select('id,status')
            .eq('id', id)
            .limit(1),
      );
      if (verification.isEmpty || verification.first['status'] != status) {
        throw StateError(
          'Supabase ไม่อนุญาตให้อัปเดต กรุณาตรวจสอบ role=admin และ RLS policy',
        );
      }
      if (!mounted) return;
      setState(() => _items?.removeWhere((row) => row['id'] == id));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            status == 'approved'
                ? 'อนุมัติประกาศแล้ว และพร้อมแสดงบนหน้าหลัก'
                : 'ไม่อนุมัติประกาศแล้ว',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = 'อัปเดตประกาศไม่สำเร็จ: $error');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.red.shade700,
          content: Text('อัปเดตไม่สำเร็จ: $error'),
        ),
      );
    } finally {
      if (mounted) setState(() => _updatingIds.remove(id));
    }
  }

  Future<void> _showDetails(Map<String, dynamic> item) async {
    final parsed = item['parsed_data'] is Map
        ? Map<String, dynamic>.from(item['parsed_data'] as Map)
        : const <String, dynamic>{};
    final gallery = item['gallery_urls'] is List
        ? List<String>.from(item['gallery_urls'] as List)
        : const <String>[];
    final imageUrls = <String>{
      if ((item['thumbnail_url'] as String?)?.isNotEmpty == true)
        item['thumbnail_url'] as String,
      ...gallery.where((url) => url.isNotEmpty),
    }.toList();
    final mapUrl = (item['map_url'] ?? parsed['map_url'])?.toString();
    final sourceUrl = item['source_url']?.toString();

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.fact_check_outlined),
            SizedBox(width: 10),
            Text('ตรวจสอบรายละเอียดประกาศ'),
          ],
        ),
        content: SizedBox(
          width: 720,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (imageUrls.isNotEmpty) ...[
                  SizedBox(
                    height: 220,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: imageUrls.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 10),
                      itemBuilder: (_, index) => ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: Image.network(
                          imageUrls[index],
                          width: 300,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => const ColoredBox(
                            color: Color(0xFFE2E8F0),
                            child: SizedBox(
                              width: 180,
                              child: Icon(Icons.broken_image_outlined),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                ],
                Text(
                  item['title'] as String? ?? 'ไม่ระบุชื่อ',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 14),
                _DetailRow(
                  icon: Icons.category_outlined,
                  label: 'ประเภท',
                  value: _propertyTypeLabel(item['property_type']?.toString()),
                ),
                _DetailRow(
                  icon: Icons.payments_outlined,
                  label: 'ราคา',
                  value: _priceLabel(item),
                ),
                _DetailRow(
                  icon: Icons.location_on_outlined,
                  label: 'พื้นที่',
                  value: [item['village'], item['district'], item['province']]
                      .whereType<String>()
                      .where((value) => value.isNotEmpty)
                      .join(' • '),
                ),
                _DetailRow(
                  icon: Icons.home_outlined,
                  label: 'ที่อยู่เพิ่มเติม',
                  value: parsed['address']?.toString() ?? '-',
                ),
                _DetailRow(
                  icon: Icons.phone_outlined,
                  label: 'เบอร์โทร',
                  value: item['contact_phone']?.toString() ?? '-',
                ),
                _DetailRow(
                  icon: Icons.person_outline,
                  label: 'ผู้ส่ง',
                  value: parsed['submitted_by_name']?.toString() ?? '-',
                ),
                _DetailRow(
                  icon: Icons.email_outlined,
                  label: 'อีเมล',
                  value: parsed['submitted_by_email']?.toString() ?? '-',
                ),
                if (mapUrl?.isNotEmpty == true || sourceUrl?.isNotEmpty == true)
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Wrap(
                      spacing: 10,
                      runSpacing: 8,
                      children: [
                        if (mapUrl?.isNotEmpty == true)
                          OutlinedButton.icon(
                            onPressed: () => launchUrl(
                              Uri.parse(mapUrl!),
                              mode: LaunchMode.externalApplication,
                            ),
                            icon: const Icon(Icons.map_outlined),
                            label: const Text('เปิด Google Maps'),
                          ),
                        if (sourceUrl?.isNotEmpty == true)
                          OutlinedButton.icon(
                            onPressed: () => launchUrl(
                              Uri.parse(sourceUrl!),
                              mode: LaunchMode.externalApplication,
                            ),
                            icon: const Icon(Icons.open_in_new),
                            label: const Text('เปิดลิงก์ต้นทาง'),
                          ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('ปิด'),
          ),
          OutlinedButton.icon(
            onPressed: () {
              Navigator.pop(dialogContext);
              _setStatus(item, 'rejected');
            },
            icon: const Icon(Icons.close),
            label: const Text('ไม่อนุมัติ'),
          ),
          FilledButton.icon(
            onPressed: () {
              Navigator.pop(dialogContext);
              _setStatus(item, 'approved');
            },
            icon: const Icon(Icons.check),
            label: const Text('อนุมัติ'),
          ),
        ],
      ),
    );
  }

  String _propertyTypeLabel(String? value) => switch (value) {
    'room' => 'ห้องแถว',
    'house' => 'บ้านเช่า',
    'apartment' => 'อพาร์ตเมนต์',
    'condo' => 'คอนโด',
    _ => value ?? '-',
  };

  String _priceLabel(Map<String, dynamic> item) {
    String format(dynamic value) {
      if (value is! num) return '-';
      return value.round().toString().replaceAllMapped(
        RegExp(r'\B(?=(\d{3})+(?!\d))'),
        (_) => ',',
      );
    }

    final minimum = format(item['monthly_price_min']);
    final maximum = format(item['monthly_price_max']);
    final currency = item['currency']?.toString() ?? 'LAK';
    return minimum == maximum
        ? '$minimum $currency / เดือน'
        : '$minimum – $maximum $currency / เดือน';
  }

  @override
  Widget build(BuildContext context) => Card(
    elevation: 0,
    color: const Color(0xFFFFFBEB),
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const CircleAvatar(
                backgroundColor: Color(0xFFFEF3C7),
                child: Icon(Icons.fact_check_outlined),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'ประกาศรอตรวจสอบ (${_items?.length ?? 0})',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              IconButton(
                onPressed: _load,
                tooltip: 'โหลดใหม่',
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_error != null)
            Text(
              'โหลดข้อมูลไม่สำเร็จ: $_error',
              style: const TextStyle(color: Colors.red),
            )
          else if (_items == null)
            const Center(child: CircularProgressIndicator())
          else if (_items!.isEmpty)
            const Padding(
              padding: EdgeInsets.all(20),
              child: Center(child: Text('ไม่มีประกาศที่รอตรวจสอบ')),
            )
          else
            ..._items!.map(
              (item) => ListTile(
                contentPadding: EdgeInsets.zero,
                leading: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: item['thumbnail_url'] == null
                      ? const ColoredBox(
                          color: Color(0xFFE2E8F0),
                          child: SizedBox.square(
                            dimension: 58,
                            child: Icon(Icons.home_work_outlined),
                          ),
                        )
                      : Image.network(
                          item['thumbnail_url'] as String,
                          width: 58,
                          height: 58,
                          fit: BoxFit.cover,
                        ),
                ),
                title: Text(item['title'] as String? ?? 'ไม่ระบุชื่อ'),
                subtitle: Builder(
                  builder: (_) {
                    final parsed = item['parsed_data'] is Map
                        ? Map<String, dynamic>.from(item['parsed_data'] as Map)
                        : const <String, dynamic>{};
                    return Text(
                      [
                            item['village'],
                            item['district'],
                            item['province'],
                            item['contact_phone'],
                            parsed['submitted_by_name'],
                            parsed['submitted_by_email'],
                          ]
                          .whereType<String>()
                          .where((value) => value.isNotEmpty)
                          .join(' • '),
                    );
                  },
                ),
                trailing: Wrap(
                  spacing: 8,
                  children: [
                    OutlinedButton.icon(
                      onPressed: _updatingIds.contains(item['id'])
                          ? null
                          : () => _showDetails(item),
                      icon: const Icon(Icons.visibility_outlined),
                      label: const Text('ดูรายละเอียด'),
                    ),
                    OutlinedButton.icon(
                      onPressed: _updatingIds.contains(item['id'])
                          ? null
                          : () => _setStatus(item, 'rejected'),
                      icon: const Icon(Icons.close),
                      label: const Text('ไม่อนุมัติ'),
                    ),
                    FilledButton.icon(
                      onPressed: _updatingIds.contains(item['id'])
                          ? null
                          : () => _setStatus(item, 'approved'),
                      icon: _updatingIds.contains(item['id'])
                          ? const SizedBox.square(
                              dimension: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.check),
                      label: const Text('อนุมัติ'),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    ),
  );
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 19, color: const Color(0xFF5267A3)),
        const SizedBox(width: 10),
        SizedBox(
          width: 125,
          child: Text(label, style: const TextStyle(color: Color(0xFF64748B))),
        ),
        Expanded(child: SelectableText(value.isEmpty ? '-' : value)),
      ],
    ),
  );
}
