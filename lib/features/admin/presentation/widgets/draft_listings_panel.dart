import 'package:flutter/material.dart';
import 'package:room_rental/core/theme/app_colors.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Lists the admin's unpublished drafts. [onEdit] opens a draft in the
/// listing form and resolves to true when it was saved or published.
class DraftListingsPanel extends StatefulWidget {
  const DraftListingsPanel({super.key, required this.onEdit});

  final Future<bool> Function(Map<String, dynamic> draft) onEdit;

  @override
  State<DraftListingsPanel> createState() => _DraftListingsPanelState();
}

class _DraftListingsPanelState extends State<DraftListingsPanel> {
  List<Map<String, dynamic>>? _items;
  final Set<String> _deletingIds = {};
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
            'id,title,property_type,province,district,village,thumbnail_url,gallery_urls,contact_phone,monthly_price_min,monthly_price_max,currency,map_url,latitude,longitude,source_url,parsed_data,updated_at',
          )
          .eq('status', 'draft')
          .order('updated_at', ascending: false);
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

  Future<void> _edit(Map<String, dynamic> item) async {
    if (await widget.onEdit(item)) _load();
  }

  Future<void> _delete(Map<String, dynamic> item) async {
    final id = item['id']?.toString();
    if (id == null || _deletingIds.contains(id)) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('ลบแบบร่าง?'),
        content: Text('ลบ "${_title(item)}" ถาวร ไม่สามารถกู้คืนได้'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('ยกเลิก'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: dialogContext.colors.danger,
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('ลบ'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _deletingIds.add(id));
    try {
      await Supabase.instance.client
          .from('scraped_listings')
          .delete()
          .eq('id', id)
          .eq('status', 'draft');
      if (!mounted) return;
      setState(() => _items?.removeWhere((row) => row['id'] == id));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: context.colors.danger,
          content: Text('ลบแบบร่างไม่สำเร็จ: $error'),
        ),
      );
    } finally {
      if (mounted) setState(() => _deletingIds.remove(id));
    }
  }

  String _title(Map<String, dynamic> item) {
    final title = (item['title'] as String?)?.trim() ?? '';
    return title.isEmpty ? 'ไม่ระบุชื่อ' : title;
  }

  String _updatedLabel(Map<String, dynamic> item) {
    final updated = DateTime.tryParse(item['updated_at']?.toString() ?? '');
    if (updated == null) return '';
    final local = updated.toLocal();
    String two(int value) => value.toString().padLeft(2, '0');
    return 'แก้ไขล่าสุด ${two(local.day)}/${two(local.month)}/${local.year} '
        '${two(local.hour)}:${two(local.minute)}';
  }

  @override
  Widget build(BuildContext context) => Card(
    elevation: 0,
    color: context.colors.secondaryContainer,
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: context.colors.surface,
                child: const Icon(Icons.edit_note_outlined),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'แบบร่าง (${_items?.length ?? 0})',
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
          const SizedBox(height: 4),
          Text(
            'ยังไม่แสดงบนหน้าเว็บ เปิดเพื่อเติมข้อมูลให้ครบแล้วกดบันทึกและเผยแพร่',
            style: TextStyle(color: context.colors.textMuted),
          ),
          const SizedBox(height: 12),
          if (_error != null)
            Text(
              'โหลดข้อมูลไม่สำเร็จ: $_error',
              style: TextStyle(color: context.colors.danger),
            )
          else if (_items == null)
            const Center(child: CircularProgressIndicator())
          else if (_items!.isEmpty)
            const Padding(
              padding: EdgeInsets.all(20),
              child: Center(child: Text('ไม่มีแบบร่าง')),
            )
          else
            ..._items!.map((item) {
              final id = item['id']?.toString();
              final deleting = _deletingIds.contains(id);
              final thumbnailUrl = item['thumbnail_url'] as String?;
              return ListTile(
                contentPadding: EdgeInsets.zero,
                onTap: deleting ? null : () => _edit(item),
                leading: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: thumbnailUrl == null || thumbnailUrl.isEmpty
                      ? ColoredBox(
                          color: context.colors.border,
                          child: const SizedBox.square(
                            dimension: 58,
                            child: Icon(Icons.home_work_outlined),
                          ),
                        )
                      : Image.network(
                          thumbnailUrl,
                          width: 58,
                          height: 58,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => const SizedBox.square(
                            dimension: 58,
                            child: Icon(Icons.broken_image_outlined),
                          ),
                        ),
                ),
                title: Text(_title(item)),
                subtitle: Text(
                  [
                        item['village'],
                        item['district'],
                        item['province'],
                        _updatedLabel(item),
                      ]
                      .whereType<String>()
                      .where((value) => value.isNotEmpty)
                      .join(' • '),
                ),
                trailing: Wrap(
                  spacing: 8,
                  children: [
                    IconButton(
                      tooltip: 'ลบแบบร่าง',
                      onPressed: deleting ? null : () => _delete(item),
                      icon: deleting
                          ? const SizedBox.square(
                              dimension: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.delete_outline),
                    ),
                    FilledButton.icon(
                      onPressed: deleting ? null : () => _edit(item),
                      icon: const Icon(Icons.edit_outlined),
                      label: const Text('แก้ไขต่อ'),
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
