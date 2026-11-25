import 'dart:async';

import 'package:flutter/material.dart';
import 'package:room_rental/core/theme/app_colors.dart';
import 'package:room_rental/core/utils/relative_date_formatter.dart';
import 'package:room_rental/features/listings/domain/entities/rental_listing.dart';
import 'package:room_rental/features/listings/presentation/pages/listing_detail_page.dart';

class SponsoredListing extends StatefulWidget {
  const SponsoredListing({super.key, required this.advertisements});

  final Future<List<RentalListing>> advertisements;

  @override
  State<SponsoredListing> createState() => _SponsoredListingState();
}

class _SponsoredListingState extends State<SponsoredListing> {
  List<RentalListing>? _rooms;
  int _index = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final now = DateTime.now().toUtc();
      final rooms = (await widget.advertisements)
          .where(
            (room) =>
                room.advertisementEndsAt == null ||
                room.advertisementEndsAt!.toUtc().isAfter(now),
          )
          .toList();
      if (!mounted) return;
      setState(() => _rooms = rooms);
      if (rooms.isNotEmpty) {
        _timer = Timer.periodic(const Duration(seconds: 5), (_) {
          if (!mounted) return;
          final currentTime = DateTime.now().toUtc();
          setState(() {
            _rooms = _rooms!
                .where(
                  (room) =>
                      room.advertisementEndsAt == null ||
                      room.advertisementEndsAt!.toUtc().isAfter(currentTime),
                )
                .toList();
            if (_rooms!.isEmpty) {
              _index = 0;
              _timer?.cancel();
            } else {
              _index = (_index + 1) % _rooms!.length;
            }
          });
        });
      }
    } catch (_) {
      if (mounted) setState(() => _rooms = const []);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_rooms == null) {
      return const SizedBox(
        height: 220,
        child: Center(child: CircularProgressIndicator()),
      );
    }
    final rooms = _rooms!;
    if (rooms.isEmpty) return const SizedBox.shrink();
    final room = rooms[_index];

    return Stack(
      children: [
        // Reserve the tallest card's space without loading its image.
        IndexedStack(
          index: null,
          children: [
            for (final item in rooms)
              _content(context, item, measureOnly: true),
          ],
        ),
        Positioned.fill(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 1100),
            switchInCurve: Curves.easeInOutCubic,
            switchOutCurve: Curves.easeInOutCubic,
            transitionBuilder: (child, animation) {
              final slide = Tween<Offset>(
                begin: const Offset(0.045, 0),
                end: Offset.zero,
              ).animate(animation);
              return ClipRect(
                child: FadeTransition(
                  opacity: animation,
                  child: SlideTransition(position: slide, child: child),
                ),
              );
            },
            layoutBuilder: (current, previous) => Stack(
              fit: StackFit.expand,
              children: [...previous, ?current],
            ),
            child: KeyedSubtree(
              key: ValueKey(room.id),
              child: _content(context, room),
            ),
          ),
        ),
      ],
    );
  }

  Widget _content(
    BuildContext context,
    RentalListing room, {
    bool measureOnly = false,
  }) {
    return Container(
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: context.colors.border),
        boxShadow: [
          BoxShadow(
            color: context.colors.shadow.withAlpha(0x14),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 720;
          final previewHeight = compact ? 210.0 : 300.0;
          final preview = measureOnly
              ? SizedBox(height: previewHeight)
              : Container(
                  height: previewHeight,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        context.colors.primaryContainerStrong,
                        context.colors.primaryContainer,
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: room.imageUrl.isEmpty
                            ? Center(
                                child: Icon(
                                  Icons.apartment_rounded,
                                  size: 132,
                                  color: context.colors.primary.withAlpha(0x66),
                                ),
                              )
                            : Image.network(room.imageUrl, fit: BoxFit.cover),
                      ),
                      const Positioned(
                        left: 16,
                        top: 16,
                        child: _SponsoredBadge(),
                      ),
                    ],
                  ),
                );
          final details = Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  room.title,
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Icon(
                      Icons.location_on_outlined,
                      size: 19,
                      color: context.colors.textMuted,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        room.location,
                        style: TextStyle(color: context.colors.textMuted),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Icon(
                      Icons.schedule_outlined,
                      size: 18,
                      color: context.colors.textMuted,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'อัปเดต${formatRelativeDate(DateTime.now())}',
                      style: TextStyle(color: context.colors.textMuted),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Wrap(
                  spacing: 16,
                  runSpacing: 8,
                  children: room.amenities.isEmpty
                      ? const [
                          _Amenity(
                            icon: Icons.verified_outlined,
                            label: 'ประกาศตรวจสอบแล้ว',
                          ),
                        ]
                      : room.amenities
                            .take(3)
                            .map(
                              (item) => _Amenity(
                                icon: Icons.check_circle_outline,
                                label: item,
                              ),
                            )
                            .toList(),
                ),
                const SizedBox(height: 24),
                if (compact && !measureOnly) const Spacer(),
                Row(
                  children: [
                    const Spacer(),
                    FilledButton(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ListingDetailPage(room: room),
                        ),
                      ),
                      child: const Text('ดูรายละเอียด'),
                    ),
                  ],
                ),
              ],
            ),
          );

          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                preview,
                if (measureOnly) details else Expanded(child: details),
              ],
            );
          }
          return Row(
            children: [
              Expanded(flex: 11, child: preview),
              Expanded(flex: 9, child: details),
            ],
          );
        },
      ),
    );
  }
}

class _SponsoredBadge extends StatelessWidget {
  const _SponsoredBadge();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
    decoration: BoxDecoration(
      color: context.colors.surface,
      borderRadius: BorderRadius.circular(99),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.campaign_outlined, size: 17, color: context.colors.primary),
        const SizedBox(width: 6),
        const Text('โฆษณา', style: TextStyle(fontWeight: FontWeight.bold)),
      ],
    ),
  );
}

class _Amenity extends StatelessWidget {
  const _Amenity({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 18, color: context.colors.textSecondary),
      const SizedBox(width: 5),
      Flexible(
        child: Text(
          label,
          style: TextStyle(color: context.colors.textSecondary),
        ),
      ),
    ],
  );
}
