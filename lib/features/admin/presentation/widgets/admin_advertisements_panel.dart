import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AdminAdvertisementsPanel extends StatefulWidget {
  const AdminAdvertisementsPanel({super.key});

  @override
  State<AdminAdvertisementsPanel> createState() =>
      _AdminAdvertisementsPanelState();
}

class _AdminAdvertisementsPanelState extends State<AdminAdvertisementsPanel> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _ads = const [];
  List<Map<String, dynamic>> _listings = const [];

  SupabaseClient get _client => Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        _client
            .from('listing_advertisements')
            .select(
              'id,listing_id,starts_at,ends_at,active,priority,'
              'scraped_listings(title,thumbnail_url,province,district,village)',
            )
            .order('priority', ascending: false)
            .order('created_at', ascending: false),
        _client
            .from('scraped_listings')
            .select(
              'id,title,province,district,village,thumbnail_url,'
              'monthly_price_min,monthly_price_max,currency,property_type',
            )
            .eq('status', 'approved')
            .contains('parsed_data', const {'manual_entry': true})
            .order('created_at', ascending: false)
            .limit(500),
      ]);
      if (!mounted) return;
      setState(() {
        _ads = List<Map<String, dynamic>>.from(results[0]);
        _listings = List<Map<String, dynamic>>.from(results[1]);
      });
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _addAdvertisement() async {
    if (_listings.isEmpty) {
      _message('ยังไม่มีที่พักที่เผยแพร่สำหรับลงโฆษณา');
      return;
    }
    final result = await showDialog<_AdvertisementInput>(
      context: context,
      builder: (_) => _AdvertisementDialog(listings: _listings),
    );
    if (result == null) return;
    try {
      await _client.from('listing_advertisements').insert({
        'listing_id': result.listingId,
        'starts_at': result.startsAt.toUtc().toIso8601String(),
        'ends_at': result.endsAt.toUtc().toIso8601String(),
        'priority': result.priority,
        'active': true,
      });
      _message('เพิ่มโฆษณาแล้ว');
      await _load();
    } catch (error) {
      _message('เพิ่มโฆษณาไม่สำเร็จ: $error');
    }
  }

  Future<void> _toggle(Map<String, dynamic> ad, bool active) async {
    try {
      await _client
          .from('listing_advertisements')
          .update({'active': active})
          .eq('id', ad['id']);
      await _load();
    } catch (error) {
      _message('อัปเดตไม่สำเร็จ: $error');
    }
  }

  Future<void> _editAdvertisement(Map<String, dynamic> ad) async {
    final result = await showDialog<_AdvertisementInput>(
      context: context,
      builder: (_) =>
          _AdvertisementDialog(listings: _listings, initialAdvertisement: ad),
    );
    if (result == null) return;
    try {
      await _client
          .from('listing_advertisements')
          .update({
            'listing_id': result.listingId,
            'starts_at': result.startsAt.toUtc().toIso8601String(),
            'ends_at': result.endsAt.toUtc().toIso8601String(),
            'priority': result.priority,
          })
          .eq('id', ad['id']);
      _message('แก้ไขโฆษณาแล้ว');
      await _load();
    } catch (error) {
      _message('แก้ไขโฆษณาไม่สำเร็จ: $error');
    }
  }

  Future<void> _delete(Map<String, dynamic> ad) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('ลบโฆษณานี้?'),
        content: const Text('รายการห้องจะไม่ถูกลบ ลบเฉพาะกำหนดการโฆษณา'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('ยกเลิก'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('ลบ'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _client.from('listing_advertisements').delete().eq('id', ad['id']);
    await _load();
  }

  void _message(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: const Color(0xFFF5F3FF),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const CircleAvatar(
                  backgroundColor: Color(0xFFE0E7FF),
                  child: Icon(Icons.campaign_outlined),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'จัดการโฆษณา',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text('เลือกที่พักและกำหนดช่วงเวลาที่แสดงบนหน้าหลัก'),
                    ],
                  ),
                ),
                FilledButton.icon(
                  onPressed: _loading ? null : _addAdvertisement,
                  icon: const Icon(Icons.add),
                  label: const Text('เพิ่มโฆษณา'),
                ),
              ],
            ),
            const SizedBox(height: 18),
            if (_loading)
              const Center(child: CircularProgressIndicator())
            else if (_error != null)
              Text(
                'โหลดโฆษณาไม่สำเร็จ: $_error\nโปรดรันไฟล์ add_listing_advertisements.sql ใน Supabase ก่อน',
                style: const TextStyle(color: Colors.red),
              )
            else if (_ads.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: Text('ยังไม่มีโฆษณา')),
              )
            else
              ..._ads.map((ad) {
                final listing = Map<String, dynamic>.from(
                  ad['scraped_listings'] as Map? ?? const {},
                );
                final endsAt = DateTime.tryParse('${ad['ends_at']}')?.toLocal();
                final expired = endsAt?.isBefore(DateTime.now()) ?? false;
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: listing['thumbnail_url'] == null
                        ? const ColoredBox(
                            color: Color(0xFFDBEAFE),
                            child: SizedBox.square(
                              dimension: 58,
                              child: Icon(Icons.apartment),
                            ),
                          )
                        : Image.network(
                            listing['thumbnail_url'] as String,
                            width: 58,
                            height: 58,
                            fit: BoxFit.cover,
                          ),
                  ),
                  title: Text(listing['title'] as String? ?? 'ไม่ระบุชื่อ'),
                  subtitle: Text(
                    expired
                        ? 'หมดอายุแล้ว'
                        : 'สิ้นสุด ${_dateText(endsAt)} • ลำดับ ${ad['priority']}',
                  ),
                  trailing: Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Switch(
                        value: ad['active'] == true,
                        onChanged: (value) => _toggle(ad, value),
                      ),
                      IconButton(
                        tooltip: 'แก้ไขโฆษณา',
                        onPressed: () => _editAdvertisement(ad),
                        icon: const Icon(Icons.edit_outlined),
                      ),
                      IconButton(
                        tooltip: 'ลบโฆษณา',
                        onPressed: () => _delete(ad),
                        icon: const Icon(Icons.delete_outline),
                      ),
                    ],
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }

  String _dateText(DateTime? date) => date == null
      ? '-'
      : '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year} '
            '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
}

class _AdvertisementInput {
  const _AdvertisementInput(
    this.listingId,
    this.startsAt,
    this.endsAt,
    this.priority,
  );
  final String listingId;
  final DateTime startsAt;
  final DateTime endsAt;
  final int priority;
}

class _AdvertisementDialog extends StatefulWidget {
  const _AdvertisementDialog({
    required this.listings,
    this.initialAdvertisement,
  });
  final List<Map<String, dynamic>> listings;
  final Map<String, dynamic>? initialAdvertisement;

  @override
  State<_AdvertisementDialog> createState() => _AdvertisementDialogState();
}

class _AdvertisementDialogState extends State<_AdvertisementDialog> {
  String? _listingId;
  late DateTime _start;
  late DateTime _end;
  late final TextEditingController _priority;
  late final TextEditingController _search;

  @override
  void initState() {
    super.initState();
    final initial = widget.initialAdvertisement;
    _listingId = initial?['listing_id'] as String?;
    _start =
        DateTime.tryParse('${initial?['starts_at']}')?.toLocal() ??
        DateTime.now();
    _end =
        DateTime.tryParse('${initial?['ends_at']}')?.toLocal() ??
        DateTime.now().add(const Duration(days: 30));
    _priority = TextEditingController(text: '${initial?['priority'] ?? 0}');
    _search = TextEditingController();
  }

  @override
  void dispose() {
    _priority.dispose();
    _search.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> get _filteredListings {
    final query = _search.text.trim().toLowerCase();
    if (query.isEmpty) return widget.listings.take(30).toList();
    return widget.listings
        .where((item) {
          final searchable = [
            item['title'],
            item['village'],
            item['district'],
            item['province'],
          ].whereType<String>().join(' ').toLowerCase();
          return searchable.contains(query);
        })
        .take(50)
        .toList();
  }

  Map<String, dynamic>? get _selectedListing {
    if (_listingId == null) return null;
    for (final item in widget.listings) {
      if (item['id'] == _listingId) return item;
    }
    return null;
  }

  Future<void> _pickDate(bool start) async {
    final initial = start ? _start : _end;
    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
    );
    if (date == null) return;
    setState(() {
      if (start) {
        _start = DateTime(
          date.year,
          date.month,
          date.day,
          _start.hour,
          _start.minute,
        );
        if (!_end.isAfter(_start)) _end = _start.add(const Duration(days: 30));
      } else {
        _end = DateTime(
          date.year,
          date.month,
          date.day,
          _end.hour,
          _end.minute,
        );
      }
    });
  }

  Future<void> _pickTime(bool start) async {
    final current = start ? _start : _end;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(current),
      helpText: start ? 'เลือกเวลาเริ่มโฆษณา' : 'เลือกเวลาสิ้นสุดโฆษณา',
    );
    if (time == null) return;
    setState(() {
      final updated = DateTime(
        current.year,
        current.month,
        current.day,
        time.hour,
        time.minute,
      );
      if (start) {
        _start = updated;
        if (!_end.isAfter(_start)) {
          _end = _start.add(const Duration(hours: 1));
        }
      } else {
        _end = updated;
      }
    });
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(
      widget.initialAdvertisement == null ? 'เพิ่มโฆษณา' : 'แก้ไขโฆษณา',
    ),
    content: SizedBox(
      width: 680,
      height: MediaQuery.sizeOf(context).height * 0.7,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '1. เลือกที่พัก',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _search,
              autofocus: true,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: 'ค้นหาจากชื่อ แขวง เมือง หรือบ้าน',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _search.text.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'ล้างคำค้นหา',
                        onPressed: () {
                          _search.clear();
                          setState(() {});
                        },
                        icon: const Icon(Icons.close),
                      ),
              ),
            ),
            const SizedBox(height: 10),
            if (_selectedListing != null) ...[
              _SelectedListingCard(
                listing: _selectedListing!,
                location: _listingLocation(_selectedListing!),
                price: _priceLabel(_selectedListing!),
                onClear: () => setState(() => _listingId = null),
              ),
              const SizedBox(height: 10),
            ],
            Container(
              height: 210,
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                border: Border.all(color: const Color(0xFFE2E8F0)),
                borderRadius: BorderRadius.circular(14),
              ),
              child: _filteredListings.isEmpty
                  ? const Center(child: Text('ไม่พบที่พักที่ค้นหา'))
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      itemCount: _filteredListings.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final item = _filteredListings[index];
                        final selected = item['id'] == _listingId;
                        return ListTile(
                          selected: selected,
                          selectedTileColor: const Color(0xFFEEF2FF),
                          leading: ClipRRect(
                            borderRadius: BorderRadius.circular(9),
                            child: item['thumbnail_url'] == null
                                ? const ColoredBox(
                                    color: Color(0xFFE0E7FF),
                                    child: SizedBox.square(
                                      dimension: 46,
                                      child: Icon(Icons.apartment_outlined),
                                    ),
                                  )
                                : Image.network(
                                    item['thumbnail_url'] as String,
                                    width: 46,
                                    height: 46,
                                    fit: BoxFit.cover,
                                  ),
                          ),
                          title: Text(
                            item['title'] as String? ?? 'ไม่ระบุชื่อ',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(
                            '${_listingLocation(item)}\n${_priceLabel(item)}',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          isThreeLine: true,
                          trailing: Icon(
                            selected
                                ? Icons.check_circle
                                : Icons.radio_button_unchecked,
                            color: selected
                                ? const Color(0xFF16A34A)
                                : const Color(0xFF94A3B8),
                          ),
                          onTap: () =>
                              setState(() => _listingId = item['id'] as String),
                        );
                      },
                    ),
            ),
            const SizedBox(height: 18),
            const Text(
              '2. กำหนดวันและเวลา',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _pickDate(true),
                    icon: const Icon(Icons.calendar_today_outlined),
                    label: Text('เริ่ม ${_shortDate(_start)}'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _pickDate(false),
                    icon: const Icon(Icons.event_available_outlined),
                    label: Text('สิ้นสุด ${_shortDate(_end)}'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _pickTime(true),
                    icon: const Icon(Icons.schedule_outlined),
                    label: Text('เวลาเริ่ม ${_shortTime(_start)}'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _pickTime(false),
                    icon: const Icon(Icons.timer_off_outlined),
                    label: Text('เวลาสิ้นสุด ${_shortTime(_end)}'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '3. ตั้งลำดับการแสดงผล',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _priority,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'ลำดับความสำคัญ',
                helperText: 'เลขมากจะแสดงก่อน',
              ),
            ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('ยกเลิก'),
      ),
      FilledButton(
        onPressed: !_end.isAfter(_start) || _listingId == null
            ? null
            : () => Navigator.pop(
                context,
                _AdvertisementInput(
                  _listingId!,
                  _start,
                  _end,
                  int.tryParse(_priority.text) ?? 0,
                ),
              ),
        child: Text(
          widget.initialAdvertisement == null ? 'บันทึก' : 'บันทึกการแก้ไข',
        ),
      ),
    ],
  );

  String _shortDate(DateTime date) => '${date.day}/${date.month}/${date.year}';

  String _shortTime(DateTime date) =>
      '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';

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

  String _listingLocation(Map<String, dynamic> item) => [
    item['village'],
    item['district'],
    item['province'],
  ].whereType<String>().where((value) => value.isNotEmpty).join(' • ');
}

class _SelectedListingCard extends StatelessWidget {
  const _SelectedListingCard({
    required this.listing,
    required this.location,
    required this.price,
    required this.onClear,
  });

  final Map<String, dynamic> listing;
  final String location;
  final String price;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: const Color(0xFFECFDF5),
      border: Border.all(color: const Color(0xFF86EFAC)),
      borderRadius: BorderRadius.circular(14),
    ),
    child: Row(
      children: [
        const CircleAvatar(
          backgroundColor: Color(0xFFDCFCE7),
          child: Icon(Icons.check, color: Color(0xFF15803D)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'เลือกแล้ว',
                style: TextStyle(fontSize: 11, color: Color(0xFF15803D)),
              ),
              Text(
                listing['title'] as String? ?? 'ไม่ระบุชื่อ',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              Text(
                '$location • $price',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
              ),
            ],
          ),
        ),
        IconButton(
          tooltip: 'เปลี่ยนที่พัก',
          onPressed: onClear,
          icon: const Icon(Icons.close),
        ),
      ],
    ),
  );
}
