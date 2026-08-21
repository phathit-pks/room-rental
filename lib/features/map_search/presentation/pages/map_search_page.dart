import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:room_rental/features/listings/data/repositories/listing_repository.dart';
import 'package:room_rental/features/listings/domain/entities/rental_listing.dart';
import 'package:room_rental/features/listings/presentation/pages/listing_detail_page.dart';
import 'package:url_launcher/url_launcher.dart';

class MapSearchPage extends StatefulWidget {
  const MapSearchPage({super.key});

  @override
  State<MapSearchPage> createState() => _MapSearchPageState();
}

class _MapSearchPageState extends State<MapSearchPage> {
  static const _vientiane = LatLng(17.9757, 102.6331);
  static const _distance = Distance();
  final MapController _mapController = MapController();
  final _repository = const SupabaseListingRepository();

  LatLng? _center;
  double _radiusMeters = 0;
  bool _drawing = false;
  bool _adjusting = false;
  bool _pointerDown = false;
  bool _searching = false;
  List<RentalListing> _results = const [];

  void _startDrawing() {
    setState(() {
      _drawing = true;
      _adjusting = false;
      _center = null;
      _radiusMeters = 0;
      _results = const [];
    });
  }

  void _clearArea() {
    setState(() {
      _drawing = false;
      _adjusting = false;
      _pointerDown = false;
      _center = null;
      _radiusMeters = 0;
      _results = const [];
    });
  }

  void _onPointerDown(LatLng point) {
    if (!_drawing) return;
    setState(() {
      _pointerDown = true;
      _center = point;
      _radiusMeters = 0;
      _results = const [];
    });
  }

  void _onPointerMove(LatLng point) {
    if (!_drawing || !_pointerDown || _center == null) return;
    setState(
      () => _radiusMeters = _distance(
        _center!,
        point,
      ).clamp(100, 20000).toDouble(),
    );
  }

  void _onPointerUp(LatLng point) {
    if (!_drawing || !_pointerDown || _center == null) return;
    setState(() {
      _radiusMeters = _distance(_center!, point).clamp(100, 20000).toDouble();
      _pointerDown = false;
      _drawing = false;
    });
  }

  void _toggleAdjusting() {
    setState(() {
      _drawing = false;
      _adjusting = !_adjusting;
      _pointerDown = false;
    });
  }

  void _moveCircle(DragUpdateDetails details) {
    if (!_adjusting || _center == null) return;
    final camera = _mapController.camera;
    final currentOffset = camera.latLngToScreenOffset(_center!);
    setState(() {
      _center = camera.screenOffsetToLatLng(currentOffset + details.delta);
      _results = const [];
    });
  }

  void _resizeCircle(DragUpdateDetails details) {
    if (!_adjusting || _center == null) return;
    final camera = _mapController.camera;
    final edge = _distance.offset(_center!, _radiusMeters, 90);
    final edgeOffset = camera.latLngToScreenOffset(edge) + details.delta;
    final newEdge = camera.screenOffsetToLatLng(edgeOffset);
    setState(() {
      _radiusMeters = _distance(_center!, newEdge).clamp(100, 20000).toDouble();
      _results = const [];
    });
  }

  String get _radiusLabel {
    if (_radiusMeters >= 1000) {
      return '${(_radiusMeters / 1000).toStringAsFixed(1)} กม.';
    }
    return '${_radiusMeters.round()} ม.';
  }

  Future<void> _searchWithinArea() async {
    final center = _center;
    if (center == null || _radiusMeters <= 0 || _searching) return;
    setState(() => _searching = true);
    try {
      final results = await _repository.searchWithinRadius(
        latitude: center.latitude,
        longitude: center.longitude,
        radiusMeters: _radiusMeters,
      );
      if (!mounted) return;
      setState(() => _results = results);
      if (MediaQuery.sizeOf(context).width < 800) {
        _showResults(results);
      } else if (results.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('ไม่พบที่พักที่มีพิกัดอยู่ในวงนี้')),
        );
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.red.shade700,
          content: Text('ค้นหาห้องไม่สำเร็จ: $error'),
        ),
      );
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  void _showResults(List<RentalListing> results) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: SizedBox(
          height: 360,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'พบที่พัก ${results.length} รายการในรัศมี $_radiusLabel',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (results.length == 30)
                      const Padding(
                        padding: EdgeInsets.only(top: 4),
                        child: Text(
                          'แสดงเฉพาะ 30 ห้องที่ใกล้จุดศูนย์กลางที่สุด',
                          style: TextStyle(color: Color(0xFF64748B)),
                        ),
                      ),
                  ],
                ),
              ),
              Expanded(
                child: results.isEmpty
                    ? const Center(
                        child: Text('ไม่พบที่พักที่มีพิกัดอยู่ในวงนี้'),
                      )
                    : ListView.separated(
                        itemCount: results.length,
                        separatorBuilder: (_, _) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final room = results[index];
                          final distance = room.distanceMeters ?? 0;
                          final distanceLabel = distance >= 1000
                              ? '${(distance / 1000).toStringAsFixed(1)} กม.'
                              : '${distance.round()} ม.';
                          return ListTile(
                            leading: const CircleAvatar(
                              child: Icon(Icons.home_work_outlined),
                            ),
                            title: Text(room.title),
                            subtitle: Text('${room.location} • $distanceLabel'),
                            trailing: room.mapUrl?.isNotEmpty == true
                                ? IconButton(
                                    tooltip: 'นำทาง',
                                    onPressed: () => launchUrl(
                                      Uri.parse(room.mapUrl!),
                                      mode: LaunchMode.externalApplication,
                                    ),
                                    icon: const Icon(Icons.directions_outlined),
                                  )
                                : null,
                            onTap: () => _openListing(room),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openListing(RentalListing room) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => ListingDetailPage(room: room)));
  }

  Widget _desktopResultsPanel() => Card(
    elevation: 8,
    clipBehavior: Clip.antiAlias,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 16, 8, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'พบที่พัก ${_results.length} รายการ',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      _results.length == 30
                          ? '30 ห้องที่ใกล้ศูนย์กลางที่สุด • $_radiusLabel'
                          : 'ภายในรัศมี $_radiusLabel • กดเพื่อดูรายละเอียด',
                      style: const TextStyle(
                        color: Color(0xFF64748B),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'ปิดผลการค้นหา',
                onPressed: () => setState(() => _results = const []),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 6),
            itemCount: _results.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final room = _results[index];
              final distance = room.distanceMeters ?? 0;
              final distanceLabel = distance >= 1000
                  ? '${(distance / 1000).toStringAsFixed(1)} กม.'
                  : '${distance.round()} ม.';
              return ListTile(
                dense: true,
                leading: ClipRRect(
                  borderRadius: BorderRadius.circular(9),
                  child: room.imageUrl.isEmpty
                      ? const ColoredBox(
                          color: Color(0xFFE0E7FF),
                          child: SizedBox.square(
                            dimension: 44,
                            child: Icon(Icons.home_work_outlined),
                          ),
                        )
                      : Image.network(
                          room.imageUrl,
                          width: 44,
                          height: 44,
                          fit: BoxFit.cover,
                        ),
                ),
                title: Text(
                  room.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  '${room.location} • $distanceLabel',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _openListing(room),
              );
            },
          ),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    final hasArea = _center != null && _radiusMeters > 0;
    final desktop = MediaQuery.sizeOf(context).width >= 800;
    return Scaffold(
      appBar: AppBar(
        title: const Text('วาดพื้นที่ค้นหา'),
        actions: [
          if (_center != null)
            TextButton.icon(
              onPressed: _clearArea,
              icon: const Icon(Icons.delete_outline),
              label: const Text('ล้างพื้นที่'),
            ),
          const SizedBox(width: 12),
        ],
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _vientiane,
              initialZoom: 12,
              minZoom: 5,
              maxZoom: 18,
              interactionOptions: InteractionOptions(
                flags: (_drawing || _adjusting)
                    ? InteractiveFlag.none
                    : InteractiveFlag.all,
              ),
              onPointerDown: (_, point) => _onPointerDown(point),
              onPointerMove: (_, point) => _onPointerMove(point),
              onPointerUp: (_, point) => _onPointerUp(point),
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.room_rental',
              ),
              if (_center != null)
                CircleLayer(
                  circles: [
                    CircleMarker(
                      point: _center!,
                      radius: _radiusMeters,
                      useRadiusInMeter: true,
                      color: const Color(0x382563EB),
                      borderColor: const Color(0xFF2563EB),
                      borderStrokeWidth: 3,
                    ),
                  ],
                ),
              if (hasArea)
                MarkerLayer(
                  markers: [
                    Marker(
                      point: _center!,
                      width: 46,
                      height: 46,
                      child: _MapHandle(
                        icon: Icons.open_with_rounded,
                        active: _adjusting,
                        tooltip: 'ลากเพื่อย้ายวง',
                        onPanUpdate: _moveCircle,
                      ),
                    ),
                    Marker(
                      point: _distance.offset(_center!, _radiusMeters, 90),
                      width: 42,
                      height: 42,
                      child: _MapHandle(
                        icon: Icons.horizontal_rule_rounded,
                        active: _adjusting,
                        tooltip: 'ลากเพื่อปรับรัศมี',
                        onPanUpdate: _resizeCircle,
                      ),
                    ),
                  ],
                ),
              if (_results.isNotEmpty)
                MarkerLayer(
                  markers: _results
                      .where(
                        (room) =>
                            room.latitude != null && room.longitude != null,
                      )
                      .map(
                        (room) => Marker(
                          point: LatLng(room.latitude!, room.longitude!),
                          width: 44,
                          height: 52,
                          child: Tooltip(
                            message: room.title,
                            child: GestureDetector(
                              onTap: () => _openListing(room),
                              child: const Icon(
                                Icons.location_pin,
                                size: 44,
                                color: Color(0xFFDC2626),
                              ),
                            ),
                          ),
                        ),
                      )
                      .toList(),
                ),
              RichAttributionWidget(
                attributions: const [
                  TextSourceAttribution('OpenStreetMap contributors'),
                ],
              ),
            ],
          ),
          Positioned(
            top: 18,
            left: 18,
            right: 18,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: Card(
                  elevation: 5,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: const Color(0xFFDBEAFE),
                          child: Icon(
                            _drawing || _adjusting
                                ? Icons.gesture
                                : Icons.location_searching,
                            color: const Color(0xFF2563EB),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _drawing
                                    ? 'ลากนิ้วหรือเมาส์เพื่อวาดวงกลม'
                                    : _adjusting
                                    ? 'ปรับตำแหน่งหรือขนาดวง • $_radiusLabel'
                                    : hasArea
                                    ? 'พื้นที่ค้นหา รัศมี $_radiusLabel'
                                    : 'กำหนดพื้นที่ที่ต้องการค้นหา',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                _drawing
                                    ? 'กดค้างที่จุดศูนย์กลาง แล้วลากออกด้านข้าง'
                                    : _adjusting
                                    ? 'ลากจุดกลางเพื่อย้าย • ลากจุดขอบเพื่อขยาย/ย่อ'
                                    : 'คุณยังสามารถเลื่อนและซูมแผนที่ได้',
                                style: const TextStyle(
                                  color: Color(0xFF64748B),
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (!_drawing && !_adjusting && hasArea) ...[
                          OutlinedButton.icon(
                            onPressed: _toggleAdjusting,
                            icon: const Icon(Icons.tune),
                            label: const Text('ปรับวง'),
                          ),
                          const SizedBox(width: 8),
                        ],
                        if (_adjusting)
                          FilledButton.icon(
                            onPressed: _toggleAdjusting,
                            icon: const Icon(Icons.check),
                            label: const Text('เสร็จสิ้น'),
                          )
                        else if (!_drawing)
                          FilledButton.icon(
                            onPressed: _startDrawing,
                            icon: const Icon(Icons.edit_location_alt_outlined),
                            label: Text(hasArea ? 'วาดใหม่' : 'เริ่มวาด'),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (desktop && _results.isNotEmpty)
            Positioned(
              left: 18,
              top: 112,
              bottom: 104,
              width: 390,
              child: _desktopResultsPanel(),
            ),
          if (hasArea)
            Positioned(
              left: 18,
              right: 18,
              bottom: 26,
              child: Center(
                child: FilledButton.icon(
                  onPressed: _searching ? null : _searchWithinArea,
                  icon: _searching
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.search),
                  label: Text(
                    _searching
                        ? 'กำลังค้นหา...'
                        : _results.isEmpty
                        ? 'ค้นหาห้องในพื้นที่นี้ • $_radiusLabel'
                        : 'ค้นหาอีกครั้ง • พบ ${_results.length} รายการ',
                  ),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 28,
                      vertical: 20,
                    ),
                    elevation: 6,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _MapHandle extends StatelessWidget {
  const _MapHandle({
    required this.icon,
    required this.active,
    required this.tooltip,
    required this.onPanUpdate,
  });

  final IconData icon;
  final bool active;
  final String tooltip;
  final GestureDragUpdateCallback onPanUpdate;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: active ? SystemMouseCursors.move : SystemMouseCursors.basic,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onPanUpdate: active ? onPanUpdate : null,
        child: Tooltip(
          message: tooltip,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            decoration: BoxDecoration(
              color: active ? const Color(0xFF2563EB) : Colors.white,
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFF2563EB), width: 3),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x330F172A),
                  blurRadius: 10,
                  offset: Offset(0, 3),
                ),
              ],
            ),
            child: Icon(
              icon,
              size: 21,
              color: active ? Colors.white : const Color(0xFF2563EB),
            ),
          ),
        ),
      ),
    );
  }
}
