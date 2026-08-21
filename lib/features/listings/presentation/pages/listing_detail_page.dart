import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:room_rental/features/listings/domain/entities/rental_listing.dart';
import 'package:url_launcher/url_launcher.dart';

class ListingDetailPage extends StatelessWidget {
  const ListingDetailPage({required this.room, super.key});

  final RentalListing room;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(room.title)),
      body: SingleChildScrollView(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1100),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _heroImage(),
                  if (room.galleryUrls.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    _gallerySection(context),
                  ],
                  const SizedBox(height: 24),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final details = Card(
                        elevation: 0,
                        color: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                          side: const BorderSide(color: Color(0xFFE2E8F0)),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: _details(context),
                        ),
                      );
                      final contact = _contactSidebar(context);
                      if (constraints.maxWidth < 760) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            details,
                            const SizedBox(height: 18),
                            contact,
                          ],
                        );
                      }
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(flex: 2, child: details),
                          const SizedBox(width: 22),
                          SizedBox(width: 320, child: contact),
                        ],
                      );
                    },
                  ),
                  if (room.latitude != null && room.longitude != null) ...[
                    const SizedBox(height: 28),
                    _mapSection(context),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _heroImage() => ClipRRect(
    borderRadius: BorderRadius.circular(24),
    child: AspectRatio(
      aspectRatio: 16 / 7,
      child: ColoredBox(
        color: const Color(0xFFDCEAFE),
        child: room.imageUrl.isEmpty
            ? const Icon(
                Icons.apartment_outlined,
                size: 120,
                color: Color(0x552563EB),
              )
            : Image.network(
                room.imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) =>
                    const Icon(Icons.broken_image_outlined, size: 90),
              ),
      ),
    ),
  );

  Widget _gallerySection(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        'รูปภายในห้อง',
        style: Theme.of(
          context,
        ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
      ),
      const SizedBox(height: 12),
      LayoutBuilder(
        builder: (context, constraints) {
          Widget galleryImage(int index) {
            final url = room.galleryUrls[index];
            return InkWell(
              onTap: () => showDialog<void>(
                context: context,
                builder: (_) => Dialog(
                  backgroundColor: Colors.black,
                  insetPadding: const EdgeInsets.all(24),
                  child: Stack(
                    children: [
                      InteractiveViewer(
                        child: Center(child: Image.network(url)),
                      ),
                      Positioned(
                        top: 8,
                        right: 8,
                        child: IconButton.filled(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.close),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              borderRadius: BorderRadius.circular(16),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.network(
                  url,
                  width: double.infinity,
                  height: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => const ColoredBox(
                    color: Color(0xFFE2E8F0),
                    child: Icon(Icons.broken_image_outlined),
                  ),
                ),
              ),
            );
          }

          if (constraints.maxWidth >= 700) {
            return SizedBox(
              height: 175,
              child: Row(
                children: List.generate(room.galleryUrls.length, (index) {
                  return Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(
                        right: index == room.galleryUrls.length - 1 ? 0 : 12,
                      ),
                      child: galleryImage(index),
                    ),
                  );
                }),
              ),
            );
          }
          return SizedBox(
            height: 165,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: room.galleryUrls.length,
              separatorBuilder: (_, _) => const SizedBox(width: 12),
              itemBuilder: (_, index) => SizedBox(
                width: constraints.maxWidth * 0.72,
                child: galleryImage(index),
              ),
            ),
          );
        },
      ),
    ],
  );

  Widget _details(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        room.title,
        style: Theme.of(
          context,
        ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
      ),
      const SizedBox(height: 8),
      Text(
        _propertyTypeLabel(room.propertyType),
        style: const TextStyle(
          color: Color(0xFF2563EB),
          fontWeight: FontWeight.bold,
        ),
      ),
      const SizedBox(height: 16),
      _infoRow(
        Icons.location_on_outlined,
        room.address?.trim().isNotEmpty == true ? room.address! : room.location,
      ),
      const SizedBox(height: 12),
      Text(
        _priceLabel(),
        style: const TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w800,
          color: Color(0xFF2563EB),
        ),
      ),
      const SizedBox(height: 8),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF7ED),
          borderRadius: BorderRadius.circular(99),
          border: Border.all(color: const Color(0xFFFED7AA)),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.info_outline, size: 16, color: Color(0xFF9A3412)),
            SizedBox(width: 6),
            Flexible(
              child: Text(
                'ราคาโดยประมาณ ไม่ใช่ราคายืนยัน กรุณาตรวจสอบกับผู้ให้เช่า',
                style: TextStyle(
                  color: Color(0xFF9A3412),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
      if (room.description?.trim().isNotEmpty == true) ...[
        const SizedBox(height: 24),
        Text('รายละเอียด', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        Text(room.description!),
      ],
      if (room.amenities.isNotEmpty) ...[
        const SizedBox(height: 24),
        Text(
          'สิ่งอำนวยความสะดวก',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: room.amenities
              .map(
                (item) => Chip(
                  avatar: const Icon(Icons.check_circle_outline, size: 18),
                  label: Text(item),
                ),
              )
              .toList(),
        ),
      ],
    ],
  );

  Widget _contactCard(BuildContext context) => Card(
    elevation: 0,
    color: const Color(0xFFF8FAFC),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(20),
      side: const BorderSide(color: Color(0xFFE2E8F0)),
    ),
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'ติดต่อที่พัก',
            style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          if (room.contactPhone?.isNotEmpty == true)
            FilledButton.icon(
              onPressed: () => launchUrl(Uri.parse('tel:${room.contactPhone}')),
              icon: const Icon(Icons.phone_outlined),
              label: Text(room.contactPhone!),
            )
          else
            const Text('ยังไม่มีเบอร์โทร กรุณาติดต่อผ่านลิงก์ต้นทาง'),
          if (room.mapUrl?.isNotEmpty == true) ...[
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: () => launchUrl(
                Uri.parse(room.mapUrl!),
                mode: LaunchMode.externalApplication,
              ),
              icon: const Icon(Icons.directions_outlined),
              label: const Text('นำทางด้วย Google Maps'),
            ),
          ],
          if (room.sourceUrl?.isNotEmpty == true) ...[
            const SizedBox(height: 10),
            TextButton.icon(
              onPressed: () => launchUrl(
                Uri.parse(room.sourceUrl!),
                mode: LaunchMode.externalApplication,
              ),
              icon: const Icon(Icons.open_in_new),
              label: const Text('ดูประกาศต้นทาง'),
            ),
          ],
        ],
      ),
    ),
  );

  Widget _contactSidebar(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _contactCard(context),
      if (room.submittedByName?.trim().isNotEmpty == true) ...[
        const SizedBox(height: 12),
        Card(
          elevation: 0,
          color: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: Color(0xFFE2E8F0)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: const Color(0xFFE0E7FF),
                  child: Text(
                    room.submittedByName!.trim().characters.first.toUpperCase(),
                    style: const TextStyle(
                      color: Color(0xFF3730A3),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'เพิ่มโดย',
                        style: TextStyle(
                          color: Color(0xFF64748B),
                          fontSize: 12,
                        ),
                      ),
                      Text(
                        room.submittedByName!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const Text(
                        'สมาชิกที่ลงทะเบียนด้วย Google',
                        style: TextStyle(
                          color: Color(0xFF16A34A),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    ],
  );

  Widget _mapSection(BuildContext context) {
    final point = LatLng(room.latitude!, room.longitude!);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'แผนที่และตำแหน่ง',
          style: Theme.of(
            context,
          ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(22),
          child: SizedBox(
            height: 360,
            child: FlutterMap(
              options: MapOptions(initialCenter: point, initialZoom: 16),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.example.room_rental',
                ),
                MarkerLayer(
                  markers: [
                    Marker(
                      point: point,
                      width: 52,
                      height: 58,
                      child: const Icon(
                        Icons.location_pin,
                        size: 52,
                        color: Color(0xFFDC2626),
                      ),
                    ),
                  ],
                ),
                RichAttributionWidget(
                  attributions: const [
                    TextSourceAttribution('OpenStreetMap contributors'),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _infoRow(IconData icon, String text) => Row(
    children: [
      Icon(icon, color: const Color(0xFF64748B)),
      const SizedBox(width: 8),
      Expanded(child: Text(text)),
    ],
  );

  String _propertyTypeLabel(String value) => switch (value) {
    'room' => 'ห้องแถว',
    'house' => 'บ้านเช่า',
    'condo' => 'คอนโด',
    _ => 'อพาร์ตเมนต์',
  };

  String _priceLabel() {
    final symbol = switch (room.currency) {
      'THB' => '฿',
      'USD' => r'$',
      _ => '₭',
    };
    String format(int value) => value.toString().replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
      (_) => ',',
    );
    if (room.monthlyPriceMin <= 0 && room.monthlyPriceMax <= 0) {
      return 'สอบถามราคา';
    }
    if (room.monthlyPriceMin != room.monthlyPriceMax) {
      return '$symbol${format(room.monthlyPriceMin)} – ${format(room.monthlyPriceMax)} / เดือน';
    }
    return '$symbol${format(room.monthlyPriceMin)} / เดือน';
  }
}
