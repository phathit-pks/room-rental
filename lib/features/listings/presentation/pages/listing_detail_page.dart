import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:room_rental/core/theme/app_colors.dart';
import 'package:room_rental/core/utils/safe_external_uri.dart';
import 'package:room_rental/features/listings/data/recently_viewed_store.dart';
import 'package:room_rental/features/listings/domain/entities/rental_listing.dart';
import 'package:room_rental/features/listings/presentation/widgets/listing_rating_widget.dart';
import 'package:room_rental/features/listings/presentation/widgets/report_listing_dialog.dart';
import 'package:url_launcher/url_launcher.dart';

class ListingDetailPage extends StatelessWidget {
  const ListingDetailPage({required this.room, this.heroTag, super.key});

  final RentalListing room;

  /// When set, the cover image flies in from the [Hero] with the same tag on
  /// the previous page.
  final Object? heroTag;

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => RecentlyViewedStore.instance.recordView(room.id),
    );
    return Scaffold(
      appBar: AppBar(
        title: Text(room.title),
        actions: [
          IconButton(
            tooltip: 'รายงานประกาศนี้',
            onPressed: () =>
                showReportListingDialog(context, listingId: room.id),
            icon: const Icon(Icons.flag_outlined),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1100),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _heroImage(context),
                  if (room.galleryUrls.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    _gallerySection(context),
                  ],
                  const SizedBox(height: 24),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final details = Card(
                        elevation: 0,
                        color: context.colors.surface,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                          side: BorderSide(color: context.colors.border),
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

  Widget _heroImage(BuildContext context) {
    final image = ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: ColoredBox(
        color: context.colors.primaryContainer,
        child: room.imageUrl.isEmpty
            ? Icon(
                Icons.apartment_outlined,
                size: 120,
                color: context.colors.primary.withAlpha(0x55),
              )
            : Image.network(
                room.imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) =>
                    const Icon(Icons.broken_image_outlined, size: 90),
              ),
      ),
    );
    return AspectRatio(
      aspectRatio: 16 / 7,
      child: heroTag == null ? image : Hero(tag: heroTag!, child: image),
    );
  }

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
                  backgroundColor: context.colors.shadow,
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
                  errorBuilder: (_, _, _) => ColoredBox(
                    color: context.colors.border,
                    child: const Icon(Icons.broken_image_outlined),
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
      ListingRatingWidget(listingId: room.id),
      const SizedBox(height: 8),
      Text(
        _propertyTypeLabel(room.propertyType),
        style: TextStyle(
          color: context.colors.primary,
          fontWeight: FontWeight.bold,
        ),
      ),
      const SizedBox(height: 16),
      _infoRow(
        context,
        Icons.location_on_outlined,
        room.address?.trim().isNotEmpty == true ? room.address! : room.location,
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

  Widget _contactCard(BuildContext context) {
    final phoneUri = SafeExternalUri.telephone(room.contactPhone);
    final mapUri = SafeExternalUri.https(room.mapUrl);
    final sourceUri = SafeExternalUri.https(room.sourceUrl);
    return Card(
      elevation: 0,
      color: context.colors.background,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: context.colors.border),
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
            if (phoneUri != null)
              FilledButton.icon(
                onPressed: () => launchUrl(phoneUri),
                icon: const Icon(Icons.phone_outlined),
                label: Text(room.contactPhone!),
              )
            else
              const Text('ยังไม่มีเบอร์โทร กรุณาติดต่อผ่านลิงก์ต้นทาง'),
            if (mapUri != null) ...[
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: () =>
                    launchUrl(mapUri, mode: LaunchMode.externalApplication),
                icon: const Icon(Icons.directions_outlined),
                label: const Text('นำทางด้วย Google Maps'),
              ),
            ],
            if (sourceUri != null) ...[
              const SizedBox(height: 10),
              TextButton.icon(
                onPressed: () =>
                    launchUrl(sourceUri, mode: LaunchMode.externalApplication),
                icon: const Icon(Icons.open_in_new),
                label: const Text('ดูประกาศต้นทาง'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _contactSidebar(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _contactCard(context),
      if (room.submittedByName?.trim().isNotEmpty == true) ...[
        const SizedBox(height: 12),
        Card(
          elevation: 0,
          color: context.colors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: context.colors.border),
          ),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: context.colors.primaryContainer,
                  child: Text(
                    room.submittedByName!.trim().characters.first.toUpperCase(),
                    style: TextStyle(
                      color: context.colors.onSecondaryContainer,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'เพิ่มโดย',
                        style: TextStyle(
                          color: context.colors.textMuted,
                          fontSize: 12,
                        ),
                      ),
                      Text(
                        room.submittedByName!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      Text(
                        'สมาชิกที่ลงทะเบียนด้วย Google',
                        style: TextStyle(
                          color: context.colors.success,
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
                      child: Icon(
                        Icons.location_pin,
                        size: 52,
                        color: context.colors.danger,
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

  Widget _infoRow(BuildContext context, IconData icon, String text) => Row(
    children: [
      Icon(icon, color: context.colors.textMuted),
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
}
