import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:room_rental/core/theme/app_colors.dart';
import 'package:room_rental/core/theme/theme_store.dart';
import 'package:room_rental/core/utils/relative_date_formatter.dart';
import 'package:room_rental/core/utils/safe_external_uri.dart';
import 'package:room_rental/features/auth/presentation/widgets/client_auth_button.dart';
import 'package:room_rental/features/favorites/data/favorite_store.dart';
import 'package:room_rental/features/listings/data/repositories/listing_repository.dart';
import 'package:room_rental/features/listings/domain/entities/rental_listing.dart';
import 'package:room_rental/features/listings/presentation/pages/listing_detail_page.dart';
import 'package:room_rental/features/locations/data/location_store.dart';
import 'package:room_rental/features/map_search/presentation/pages/map_search_page.dart';
import 'package:room_rental/features/home/presentation/pages/nearby_search_cache.dart';
import 'package:room_rental/shared/widgets/app_logo.dart';
import 'package:room_rental/shared/widgets/day_night_toggle.dart';
import 'package:url_launcher/url_launcher.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _repository = const SupabaseListingRepository();
  final _searchSectionKey = GlobalKey();
  late Future<ListingPage> _listings;
  late Future<List<RentalListing>> _advertisements;
  bool _isSearchMode = false;
  bool _usingCurrentLocation = false;
  bool _searchInProgress = false;
  NearbySearchCache? _nearbySearchCache;
  String? _province;
  String? _district;
  String? _village;

  @override
  void initState() {
    super.initState();
    FavoriteStore.instance.load();
    _listings = _loadRecommendations();
    _advertisements = _repository.featuredAdvertisements();
  }

  Future<ListingPage> _loadRecommendations() async {
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission != LocationPermission.denied &&
          permission != LocationPermission.deniedForever) {
        final position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.medium,
            timeLimit: Duration(seconds: 8),
          ),
        );
        final nearby = await _repository.recommendNearby(
          latitude: position.latitude,
          longitude: position.longitude,
        );
        if (nearby.items.isNotEmpty) {
          if (mounted) setState(() => _usingCurrentLocation = true);
          return nearby;
        }
      }
    } catch (_) {
      // Permission denial, unsupported browsers, and timeouts use latest ads.
    }
    return _repository.searchPage(pageSize: 9);
  }

  Future<void> _search(
    String? province,
    String? district,
    String? village,
  ) async {
    if (_searchInProgress) return;
    _searchInProgress = true;
    late final Future<ListingPage> search;
    try {
      setState(() {
        _isSearchMode = true;
        _usingCurrentLocation = false;
        _province = province;
        _district = district;
        _village = village;
        search = _loadNearestSearch(
          province: province,
          district: district,
          village: village,
        );
        _listings = search;
      });
      await search;
    } finally {
      _searchInProgress = false;
    }
  }

  Future<ListingPage> _loadNearestSearch({
    String? province,
    String? district,
    String? village,
  }) async {
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission != LocationPermission.denied &&
          permission != LocationPermission.deniedForever) {
        final position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.medium,
            timeLimit: Duration(seconds: 8),
          ),
        );
        final cache = _nearbySearchCache;
        final canUseCache =
            cache != null &&
            DateTime.now().difference(cache.lastSynced) <
                const Duration(minutes: 5) &&
            cache.matches(
              province: province,
              district: district,
              village: village,
            ) &&
            _distanceBetweenMeters(
                  position.latitude,
                  position.longitude,
                  cache.latitude,
                  cache.longitude,
                ) <
                750;
        if (canUseCache) {
          try {
            final updates = await _repository.searchNearest(
              latitude: position.latitude,
              longitude: position.longitude,
              province: province,
              district: district,
              village: village,
              updatedAfter: cache.lastSynced,
            );
            cache.merge(updates.items);
            cache.lastSynced = DateTime.now();
          } catch (_) {
            // Keep using the local cache if an incremental refresh fails.
          }
          final page = _pageFromCache(
            cache,
            latitude: position.latitude,
            longitude: position.longitude,
          );
          if (page.items.isNotEmpty) {
            if (mounted) setState(() => _usingCurrentLocation = true);
            return page;
          }
        }
        final nearest = await _repository.searchNearest(
          latitude: position.latitude,
          longitude: position.longitude,
          province: province,
          district: district,
          village: village,
        );
        if (nearest.items.isNotEmpty) {
          _nearbySearchCache = NearbySearchCache(
            province: province,
            district: district,
            village: village,
            latitude: position.latitude,
            longitude: position.longitude,
            items: nearest.items,
          );
          if (mounted) setState(() => _usingCurrentLocation = true);
          return _pageFromCache(
            _nearbySearchCache!,
            latitude: position.latitude,
            longitude: position.longitude,
          );
        }
      }
    } catch (_) {
      // A denied location permission falls back to the latest local listings.
    }
    return _repository.searchPage(
      province: province,
      district: district,
      village: village,
      page: 1,
      pageSize: 9,
    );
  }

  ListingPage _pageFromCache(
    NearbySearchCache cache, {
    required double latitude,
    required double longitude,
  }) {
    final items =
        cache.items
            .where((item) => item.latitude != null && item.longitude != null)
            .map(
              (item) => item.withDistanceMeters(
                _distanceBetweenMeters(
                  latitude,
                  longitude,
                  item.latitude!,
                  item.longitude!,
                ),
              ),
            )
            .toList()
          ..sort(
            (first, second) =>
                first.distanceMeters!.compareTo(second.distanceMeters!),
          );
    return ListingPage(
      items: items.take(9).toList(),
      page: 1,
      pageSize: 9,
      totalItems: items.length > 9 ? 9 : items.length,
    );
  }

  double _distanceBetweenMeters(
    double firstLatitude,
    double firstLongitude,
    double secondLatitude,
    double secondLongitude,
  ) {
    final latitudeDelta = _toRadians(secondLatitude - firstLatitude);
    final longitudeDelta = _toRadians(secondLongitude - firstLongitude);
    final a =
        math.sin(latitudeDelta / 2) * math.sin(latitudeDelta / 2) +
        math.cos(_toRadians(firstLatitude)) *
            math.cos(_toRadians(secondLatitude)) *
            math.sin(longitudeDelta / 2) *
            math.sin(longitudeDelta / 2);
    return 12742000 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  }

  double _toRadians(double degrees) => degrees * math.pi / 180;

  void _clearSearch() {
    setState(() {
      _isSearchMode = false;
      _usingCurrentLocation = false;
      _province = null;
      _district = null;
      _village = null;
      _listings = _loadRecommendations();
    });
  }

  void _changePage(int page) {
    setState(() {
      _listings = _repository.searchPage(
        province: _province,
        district: _district,
        village: _village,
        page: page,
      );
    });
  }

  void _scrollToSearch() {
    final targetContext = _searchSectionKey.currentContext;
    if (targetContext == null) return;
    Scrollable.ensureVisible(
      targetContext,
      duration: const Duration(milliseconds: 650),
      curve: Curves.easeOutCubic,
      alignment: 0.08,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colors.background,
      body: _InteractivePageBackground(
        child: SelectionArea(
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: _NavigationBar(onSearchPressed: _scrollToSearch),
              ),
              SliverToBoxAdapter(
                child: _HeroSection(
                  key: _searchSectionKey,
                  onSearch: _search,
                  onClear: _clearSearch,
                  advertisements: _advertisements,
                ),
              ),
              SliverToBoxAdapter(
                child: _FeaturedSection(
                  listings: _listings,
                  isSearchMode: _isSearchMode,
                  usingCurrentLocation: _usingCurrentLocation,
                  onPageChanged: _changePage,
                ),
              ),
              const SliverToBoxAdapter(child: _HowItWorksSection()),
              const SliverToBoxAdapter(child: _CallToAction()),
              const SliverToBoxAdapter(child: _Footer()),
            ],
          ),
        ),
      ),
    );
  }
}

class _InteractivePageBackground extends StatefulWidget {
  const _InteractivePageBackground({required this.child});

  final Widget child;

  @override
  State<_InteractivePageBackground> createState() =>
      _InteractivePageBackgroundState();
}

class _InteractivePageBackgroundState extends State<_InteractivePageBackground>
    with SingleTickerProviderStateMixin {
  final _pointer = ValueNotifier<Offset>(const Offset(-1, -1));
  late final AnimationController _animation;

  @override
  void initState() {
    super.initState();
    _animation = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 22),
    )..repeat();
  }

  @override
  void dispose() {
    _animation.dispose();
    _pointer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => MouseRegion(
        onHover: (event) {
          if (constraints.maxWidth <= 0 || constraints.maxHeight <= 0) return;
          _pointer.value = Offset(
            (event.localPosition.dx / constraints.maxWidth).clamp(0.0, 1.0),
            (event.localPosition.dy / constraints.maxHeight).clamp(0.0, 1.0),
          );
        },
        onExit: (_) => _pointer.value = const Offset(-1, -1),
        child: Stack(
          fit: StackFit.expand,
          children: [
            RepaintBoundary(
              child: CustomPaint(
                painter: _ParticleBackgroundPainter(_animation, _pointer),
              ),
            ),
            widget.child,
          ],
        ),
      ),
    );
  }
}

class _ParticleBackgroundPainter extends CustomPainter {
  _ParticleBackgroundPainter(this.animation, this.pointer)
    : super(repaint: Listenable.merge([animation, pointer]));

  final Animation<double> animation;
  final ValueNotifier<Offset> pointer;

  @override
  void paint(Canvas canvas, Size size) {
    final bounds = Offset.zero & size;
    canvas.drawRect(
      bounds,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFF2F7FF), Color(0xFFFAFCFF), Color(0xFFF0FFF9)],
        ).createShader(bounds),
    );

    final count = size.width < 700 ? 22 : 48;
    final points = <Offset>[];
    final mouse = Offset(
      pointer.value.dx * size.width,
      pointer.value.dy * size.height,
    );
    final mouseIsActive = pointer.value.dx >= 0;
    final phase = animation.value * math.pi * 2;

    for (var i = 0; i < count; i++) {
      final seedX = ((i * 73) % 101) / 101;
      final seedY = ((i * 47 + 19) % 103) / 103;
      var point = Offset(
        (seedX * size.width + math.sin(phase + i * 1.7) * 24) % size.width,
        (seedY * size.height + math.cos(phase * 0.72 + i) * 18) % size.height,
      );
      if (mouseIsActive) {
        final delta = point - mouse;
        final distance = delta.distance;
        if (distance > 0 && distance < 125) {
          point += delta / distance * (125 - distance) * 0.22;
        }
      }
      points.add(point);
    }

    final linePaint = Paint()..strokeWidth = 0.8;
    for (var i = 0; i < points.length; i++) {
      for (var j = i + 1; j < points.length; j++) {
        final distance = (points[i] - points[j]).distance;
        if (distance < 115) {
          linePaint.color = const Color(
            0xFF4F6FAF,
          ).withValues(alpha: (1 - distance / 115) * 0.15);
          canvas.drawLine(points[i], points[j], linePaint);
        }
      }
    }

    for (var i = 0; i < points.length; i++) {
      final color = i % 3 == 0
          ? const Color(0xFF34D399)
          : i.isEven
          ? const Color(0xFF60A5FA)
          : const Color(0xFF818CF8);
      canvas.drawCircle(
        points[i],
        i % 5 == 0 ? 3.2 : 2.1,
        Paint()..color = color.withValues(alpha: 0.38),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ParticleBackgroundPainter oldDelegate) => false;
}

class _PageWidth extends StatelessWidget {
  const _PageWidth({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 1180),
      child: child,
    ),
  );
}

class _NavigationBar extends StatelessWidget {
  const _NavigationBar({required this.onSearchPressed});

  final VoidCallback onSearchPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: context.colors.surface,
      child: _PageWidth(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Row(
            children: [
              const AppLogo(),
              const Spacer(),
              if (MediaQuery.sizeOf(context).width > 920) ...[
                TextButton(
                  onPressed: onSearchPressed,
                  child: const Text('ค้นหาห้อง'),
                ),
                TextButton(
                  onPressed: () => Navigator.pushNamed(context, '/contact'),
                  child: const Text('ลงประกาศ'),
                ),
                TextButton(onPressed: () {}, child: const Text('เกี่ยวกับเรา')),
                const SizedBox(width: 12),
              ],
              AnimatedBuilder(
                animation: ThemeStore.instance,
                builder: (context, _) {
                  return DayNightToggle(
                    width: 52,
                    height: 26,
                    isDark: ThemeStore.instance.isDark,
                    onChanged: (value) => ThemeStore.instance.setDark(value),
                  );
                },
              ),
              const SizedBox(width: 12),
              const ClientAuthButton(),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeroSection extends StatelessWidget {
  const _HeroSection({
    super.key,
    required this.onSearch,
    required this.onClear,
    required this.advertisements,
  });

  final Future<void> Function(String?, String?, String?) onSearch;
  final VoidCallback onClear;
  final Future<List<RentalListing>> advertisements;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            context.colors.primaryContainer,
            context.colors.background,
            context.colors.successContainer,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: _PageWidth(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 64),
          child: Column(
            children: [
              const _PromotionBanner(),
              const SizedBox(height: 28),
              _SponsoredListing(advertisements: advertisements),
              const SizedBox(height: 30),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    _SearchBox(onSearch: onSearch, onClear: onClear),
                    const SizedBox(height: 22),
                    const Wrap(
                      spacing: 22,
                      runSpacing: 10,
                      alignment: WrapAlignment.center,
                      children: [
                        _TrustItem(
                          Icons.verified_outlined,
                          'ประกาศตรวจสอบแล้ว',
                        ),
                        _TrustItem(Icons.chat_bubble_outline, 'ติดต่อได้ทันที'),
                        _TrustItem(Icons.favorite_border, 'บันทึกห้องที่ชอบ'),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SponsoredListing extends StatefulWidget {
  const _SponsoredListing({required this.advertisements});

  final Future<List<RentalListing>> advertisements;

  @override
  State<_SponsoredListing> createState() => _SponsoredListingState();
}

class _SponsoredListingState extends State<_SponsoredListing> {
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
    if (_rooms!.isEmpty) return const SizedBox.shrink();
    final room = _rooms![_index];
    return AnimatedSwitcher(
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
      child: KeyedSubtree(
        key: ValueKey(room.id),
        child: _content(context, room),
      ),
    );
  }

  Widget _content(BuildContext context, RentalListing room) {
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
          final preview = Container(
            height: compact ? 210 : 300,
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
                const Positioned(left: 16, top: 16, child: _SponsoredBadge()),
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
              children: [preview, details],
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
      Text(label, style: TextStyle(color: context.colors.textSecondary)),
    ],
  );
}

class _PromotionBanner extends StatelessWidget {
  const _PromotionBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 150),
      padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          // Always a dark-to-primary accent gradient, in both light and dark mode.
          colors: [const Color(0xFF172554), context.colors.primary],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: context.colors.primary.withAlpha(0x29),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 640;
          final message = Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: compact
                ? CrossAxisAlignment.center
                : CrossAxisAlignment.start,
            children: [
              Text(
                'มีห้องว่างให้เช่า?',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: context.colors.onPrimary,
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 7),
              Text(
                'โปรโมตประกาศของคุณให้ผู้เช่าเห็นก่อนใคร',
                textAlign: compact ? TextAlign.center : TextAlign.left,
                style: const TextStyle(
                  // Fixed light tint: this banner stays dark in both themes.
                  color: Color(0xFFDBEAFE),
                  fontSize: 16,
                ),
              ),
            ],
          );
          final action = FilledButton.icon(
            onPressed: () => Navigator.pushNamed(context, '/contact'),
            icon: const Icon(Icons.add_home_work_outlined),
            label: const Text('ลงประกาศ'),
            style: FilledButton.styleFrom(
              backgroundColor: context.colors.surface,
              foregroundColor: context.colors.primary,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
            ),
          );

          if (compact) {
            return Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [message, const SizedBox(height: 20), action],
            );
          }
          return Row(
            children: [
              Icon(
                Icons.campaign_outlined,
                color: context.colors.onPrimary,
                size: 54,
              ),
              const SizedBox(width: 22),
              Expanded(child: message),
              const SizedBox(width: 24),
              action,
            ],
          );
        },
      ),
    );
  }
}

Future<void> _showNoticeDialog(
  BuildContext context, {
  required IconData icon,
  required String title,
  required String message,
}) {
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    barrierColor: context.colors.shadow.withAlpha(0x66),
    transitionDuration: const Duration(milliseconds: 220),
    pageBuilder: (context, _, _) =>
        _NoticeDialog(icon: icon, title: title, message: message),
    transitionBuilder: (context, animation, _, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutBack,
        reverseCurve: Curves.easeIn,
      );
      return FadeTransition(
        opacity: animation,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.9, end: 1).animate(curved),
          child: child,
        ),
      );
    },
  );
}

class _NoticeDialog extends StatelessWidget {
  const _NoticeDialog({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 380),
          child: Material(
            color: context.colors.surface,
            borderRadius: BorderRadius.circular(24),
            elevation: 0,
            child: Container(
              padding: const EdgeInsets.fromLTRB(28, 32, 28, 24),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: context.colors.shadow.withAlpha(0x29),
                    blurRadius: 40,
                    offset: const Offset(0, 20),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          context.colors.primaryContainer,
                          context.colors.primaryContainerStrong,
                        ],
                      ),
                    ),
                    child: Icon(icon, size: 36, color: context.colors.primary),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: context.colors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 15,
                      height: 1.5,
                      color: context.colors.textMuted,
                    ),
                  ),
                  const SizedBox(height: 28),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: FilledButton.styleFrom(
                        backgroundColor: context.colors.primary,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        textStyle: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      child: const Text('ตกลง'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SearchBox extends StatefulWidget {
  const _SearchBox({required this.onSearch, required this.onClear});

  final Future<void> Function(String?, String?, String?) onSearch;
  final VoidCallback onClear;

  @override
  State<_SearchBox> createState() => _SearchBoxState();
}

class _SearchBoxState extends State<_SearchBox> {
  final _store = LocationStore.instance;

  Map<String, Map<String, List<String>>> get _locations => _store.data;

  String? _province;
  String? _district;
  String? _village;
  bool _searching = false;

  @override
  void initState() {
    super.initState();
    _store.addListener(_locationsChanged);
  }

  @override
  void dispose() {
    _store.removeListener(_locationsChanged);
    super.dispose();
  }

  void _locationsChanged() {
    if (!mounted) return;
    if (_province != null && !_locations.containsKey(_province)) {
      _province = null;
      _district = null;
      _village = null;
    } else if (_province != null &&
        _district != null &&
        !_locations[_province]!.containsKey(_district)) {
      _district = null;
      _village = null;
    }
    setState(() {});
  }

  List<String> get _districts =>
      _province == null ? const [] : _locations[_province]!.keys.toList();

  List<String> get _villages => _province == null || _district == null
      ? const []
      : _locations[_province]![_district]!;

  Future<void> _search() async {
    if (_searching) return;
    final selections = [
      _province,
      _district,
      _village,
    ].whereType<String>().join(' • ');
    if (selections.isEmpty) {
      ScaffoldMessenger.of(context).clearSnackBars();
      await _showNoticeDialog(
        context,
        icon: Icons.location_on_rounded,
        title: 'เลือกพื้นที่ก่อนค้นหา',
        message:
            'กรุณาเลือกแขวง เมือง หรือบ้านที่ต้องการค้นหาอย่างน้อย 1 รายการ',
      );
      return;
    }
    setState(() => _searching = true);
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('กำลังค้นหาห้องใน $selections')));
    try {
      await widget.onSearch(_province, _district, _village);
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  void _clear() {
    setState(() {
      _province = null;
      _district = null;
      _village = null;
    });
    widget.onClear();
    ScaffoldMessenger.of(context).clearSnackBars();
    _showNoticeDialog(
      context,
      icon: Icons.filter_alt_off_rounded,
      title: 'ล้างตัวกรองแล้ว',
      message: 'แสดงห้องแนะนำทั้งหมดอีกครั้ง',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 900),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: context.colors.shadow.withAlpha(0x18),
            blurRadius: 26,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 700;
              final filters = [
                _LocationDropdown(
                  label: 'แขวง',
                  value: _province,
                  items: _locations.keys.toList(),
                  icon: Icons.map_outlined,
                  onChanged: (value) => setState(() {
                    _province = value;
                    _district = null;
                    _village = null;
                  }),
                ),
                _LocationDropdown(
                  label: 'เมือง',
                  value: _district,
                  items: _districts,
                  icon: Icons.location_city_outlined,
                  onChanged: _province == null
                      ? null
                      : (value) => setState(() {
                          _district = value;
                          _village = null;
                        }),
                ),
                _LocationDropdown(
                  label: 'บ้าน',
                  value: _village,
                  items: _villages,
                  icon: Icons.home_outlined,
                  onChanged: _district == null
                      ? null
                      : (value) => setState(() => _village = value),
                ),
              ];
              final searchButton = FilledButton.icon(
                onPressed: _searching ? null : _search,
                icon: _searching
                    ? SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: context.colors.onPrimary,
                        ),
                      )
                    : const Icon(Icons.search),
                label: Text(_searching ? 'กำลังค้นหา...' : 'ค้นหา'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 20,
                  ),
                ),
              );

              if (compact) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ...filters.expand(
                      (filter) => [filter, const SizedBox(height: 10)],
                    ),
                    searchButton,
                  ],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  for (final filter in filters) ...[
                    Expanded(child: filter),
                    const SizedBox(width: 10),
                  ],
                  searchButton,
                ],
              );
            },
          ),
          const Divider(height: 20),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 12,
            runSpacing: 6,
            children: [
              TextButton.icon(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const MapSearchPage()),
                ),
                icon: const Icon(Icons.gesture),
                label: const Text('วาดพื้นที่ค้นหาบนแผนที่'),
              ),
              TextButton.icon(
                onPressed: _clear,
                icon: const Icon(Icons.restart_alt),
                label: const Text('ล้างค่า'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LocationDropdown extends StatelessWidget {
  const _LocationDropdown({
    required this.label,
    required this.value,
    required this.items,
    required this.icon,
    required this.onChanged,
  });

  final String label;
  final String? value;
  final List<String> items;
  final IconData icon;
  final ValueChanged<String?>? onChanged;

  @override
  Widget build(BuildContext context) {
    // The label sits above the field: the theme's borderless outline would
    // otherwise float it across the field's top edge.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 6),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: context.colors.textSecondary,
            ),
          ),
        ),
        DropdownButtonFormField<String>(
          key: ValueKey('$label:$value'),
          initialValue: value,
          isExpanded: true,
          decoration: InputDecoration(
            prefixIcon: Icon(icon, color: context.colors.primary),
            fillColor: context.colors.surfaceMuted,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 14,
            ),
          ),
          hint: Text('เลือก$label'),
          items: items
              .map((item) => DropdownMenuItem(value: item, child: Text(item)))
              .toList(),
          onChanged: onChanged,
        ),
      ],
    );
  }
}

class _TrustItem extends StatelessWidget {
  const _TrustItem(this.icon, this.label);
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 19, color: context.colors.success),
      const SizedBox(width: 6),
      Text(label, style: TextStyle(color: context.colors.textSecondary)),
    ],
  );
}

class _FeaturedSection extends StatefulWidget {
  const _FeaturedSection({
    required this.listings,
    required this.isSearchMode,
    required this.usingCurrentLocation,
    required this.onPageChanged,
  });
  final Future<ListingPage> listings;
  final bool isSearchMode;
  final bool usingCurrentLocation;
  final ValueChanged<int> onPageChanged;

  @override
  State<_FeaturedSection> createState() => _FeaturedSectionState();
}

class _FeaturedSectionState extends State<_FeaturedSection> {
  String? selectedType;

  @override
  Widget build(BuildContext context) {
    return _PageWidth(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 72),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.isSearchMode ? 'ผลการค้นหา' : 'ห้องแนะนำ',
                        style: Theme.of(context).textTheme.headlineMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        widget.isSearchMode
                            ? widget.usingCurrentLocation
                                  ? 'แสดง 9 รายการที่อยู่ใกล้คุณที่สุด'
                                  : 'แสดงสูงสุด 9 รายการ'
                            : widget.usingCurrentLocation
                            ? 'ที่พักใกล้ตำแหน่งปัจจุบันของคุณ • สูงสุด 9 รายการ'
                            : 'ประกาศล่าสุด • สูงสุด 9 รายการ',
                        style: TextStyle(color: context.colors.textMuted),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 22),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children:
                  [
                    (null, 'ทั้งหมด', Icons.grid_view_outlined),
                    ('room', 'ห้องแถว', Icons.meeting_room_outlined),
                    ('apartment', 'อพาร์ตเมนต์', Icons.apartment_outlined),
                    ('house', 'บ้านเช่า', Icons.house_outlined),
                    ('condo', 'คอนโด', Icons.location_city_outlined),
                  ].map((category) {
                    return ChoiceChip(
                      selected: selectedType == category.$1,
                      avatar: Icon(category.$3, size: 18),
                      label: Text(category.$2),
                      onSelected: (_) =>
                          setState(() => selectedType = category.$1),
                    );
                  }).toList(),
            ),
            const SizedBox(height: 28),
            FutureBuilder<ListingPage>(
              future: widget.listings,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const _ListingsSkeleton();
                }
                if (snapshot.hasError) {
                  return Text('โหลดข้อมูลห้องไม่สำเร็จ: ${snapshot.error}');
                }
                final pageData = snapshot.data;
                final allRooms = pageData?.items ?? const [];
                final rooms = selectedType == null
                    ? allRooms
                    : allRooms
                          .where((room) => room.propertyType == selectedType)
                          .toList();
                if (rooms.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 42),
                    child: Center(child: Text('ยังไม่มีห้องที่ลงโฆษณา')),
                  );
                }
                return Column(
                  children: [
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final width = constraints.maxWidth;
                        final columns = width >= 900
                            ? 3
                            : width >= 560
                            ? 2
                            : 1;
                        final cardWidth =
                            (width - ((columns - 1) * 20)) / columns;
                        final cardHeight = math
                            .max(520.0, cardWidth / .78)
                            .toDouble();
                        return GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: rooms.length,
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: columns,
                                crossAxisSpacing: 20,
                                mainAxisSpacing: 20,
                                mainAxisExtent: cardHeight,
                              ),
                          itemBuilder: (context, index) =>
                              _RoomCard(room: rooms[index]),
                        );
                      },
                    ),
                    if (widget.isSearchMode &&
                        pageData != null &&
                        pageData.totalPages > 1) ...[
                      const SizedBox(height: 30),
                      _Pagination(
                        currentPage: pageData.page,
                        totalPages: pageData.totalPages,
                        onChanged: widget.onPageChanged,
                      ),
                    ],
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _ListingsSkeleton extends StatefulWidget {
  const _ListingsSkeleton();

  @override
  State<_ListingsSkeleton> createState() => _ListingsSkeletonState();
}

class _ListingsSkeletonState extends State<_ListingsSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animation;

  @override
  void initState() {
    super.initState();
    _animation = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
  }

  @override
  void dispose() {
    _animation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final animate = !MediaQuery.disableAnimationsOf(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 900
            ? 3
            : constraints.maxWidth >= 560
            ? 2
            : 1;
        final cardWidth =
            (constraints.maxWidth - ((columns - 1) * 20)) / columns;
        final cardHeight = math.max(520.0, cardWidth / .78).toDouble();
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: 9,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            crossAxisSpacing: 20,
            mainAxisSpacing: 20,
            mainAxisExtent: cardHeight,
          ),
          itemBuilder: (_, _) =>
              _ListingSkeletonCard(shimmer: animate ? _animation : null),
        );
      },
    );
  }
}

/// Mirrors the layout of [_RoomCard] so the page doesn't jump when the
/// real listings arrive.
class _ListingSkeletonCard extends StatelessWidget {
  const _ListingSkeletonCard({required this.shimmer});

  final Animation<double>? shimmer;

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: context.colors.border),
      ),
      child: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 11,
                child: ColoredBox(
                  color: context.colors.border,
                  child: const Align(
                    alignment: Alignment.topRight,
                    child: Padding(
                      padding: EdgeInsets.all(12),
                      child: _SkeletonBlock(width: 40, height: 40),
                    ),
                  ),
                ),
              ),
              Expanded(
                flex: 9,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(18, 14, 18, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const _SkeletonLine(widthFactor: .72, height: 20),
                      const SizedBox(height: 12),
                      const _SkeletonBlock(width: 84, height: 28),
                      const SizedBox(height: 14),
                      const _SkeletonLine(widthFactor: .9, height: 12),
                      const SizedBox(height: 10),
                      const _SkeletonLine(widthFactor: .45, height: 12),
                      const Spacer(),
                      Divider(height: 1, color: context.colors.border),
                      const SizedBox(height: 8),
                      const Row(
                        children: [
                          Expanded(child: _SkeletonBlock(height: 40)),
                          SizedBox(width: 10),
                          Expanded(child: _SkeletonBlock(height: 40)),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          if (shimmer != null)
            Positioned.fill(
              child: IgnorePointer(
                child: AnimatedBuilder(
                  animation: shimmer!,
                  builder: (context, _) => DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: const Alignment(-1, -0.4),
                        end: const Alignment(1, 0.4),
                        colors: const [
                          Color(0x00FFFFFF),
                          Color(0x99FFFFFF),
                          Color(0x00FFFFFF),
                        ],
                        stops: const [0.35, 0.5, 0.65],
                        transform: _SlidingGradientTransform(
                          shimmer!.value * 2 - 1,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _SlidingGradientTransform extends GradientTransform {
  const _SlidingGradientTransform(this.percent);

  final double percent;

  @override
  Matrix4? transform(Rect bounds, {TextDirection? textDirection}) =>
      Matrix4.translationValues(bounds.width * percent, 0, 0);
}

class _SkeletonBlock extends StatelessWidget {
  const _SkeletonBlock({this.width, required this.height});

  final double? width;
  final double height;

  @override
  Widget build(BuildContext context) => Container(
    width: width,
    height: height,
    decoration: BoxDecoration(
      color: context.colors.surfaceMuted,
      borderRadius: BorderRadius.circular(99),
    ),
  );
}

class _SkeletonLine extends StatelessWidget {
  const _SkeletonLine({required this.widthFactor, required this.height});

  final double widthFactor;
  final double height;

  @override
  Widget build(BuildContext context) => FractionallySizedBox(
    widthFactor: widthFactor,
    child: Container(
      height: height,
      decoration: BoxDecoration(
        color: context.colors.surfaceMuted,
        borderRadius: BorderRadius.circular(99),
      ),
    ),
  );
}

class _Pagination extends StatelessWidget {
  const _Pagination({
    required this.currentPage,
    required this.totalPages,
    required this.onChanged,
  });

  final int currentPage;
  final int totalPages;
  final ValueChanged<int> onChanged;

  List<int> get _visiblePages {
    final pages = <int>{1, totalPages};
    for (var page = currentPage - 2; page <= currentPage + 2; page++) {
      if (page >= 1 && page <= totalPages) pages.add(page);
    }
    final sorted = pages.toList()..sort();
    return sorted;
  }

  @override
  Widget build(BuildContext context) {
    final pages = _visiblePages;
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 7,
      runSpacing: 7,
      children: [
        IconButton.outlined(
          tooltip: 'หน้าก่อนหน้า',
          onPressed: currentPage > 1 ? () => onChanged(currentPage - 1) : null,
          icon: const Icon(Icons.chevron_left),
        ),
        for (var index = 0; index < pages.length; index++) ...[
          if (index > 0 && pages[index] - pages[index - 1] > 1)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 3),
              child: Text('…'),
            ),
          if (pages[index] == currentPage)
            FilledButton(
              onPressed: null,
              style: FilledButton.styleFrom(
                disabledBackgroundColor: context.colors.primary,
                disabledForegroundColor: context.colors.onPrimary,
                minimumSize: const Size(44, 44),
              ),
              child: Text('${pages[index]}'),
            )
          else
            OutlinedButton(
              onPressed: () => onChanged(pages[index]),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(44, 44),
                padding: EdgeInsets.zero,
              ),
              child: Text('${pages[index]}'),
            ),
        ],
        IconButton.outlined(
          tooltip: 'หน้าถัดไป',
          onPressed: currentPage < totalPages
              ? () => onChanged(currentPage + 1)
              : null,
          icon: const Icon(Icons.chevron_right),
        ),
      ],
    );
  }
}

class _RoomCard extends StatelessWidget {
  const _RoomCard({required this.room});
  final RentalListing room;

  Object get _heroTag => 'listing-cover-${room.id}';

  void _openDetail(BuildContext context) => Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => ListingDetailPage(room: room, heroTag: _heroTag),
    ),
  );

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: BorderSide(color: context.colors.border),
      ),
      child: InkWell(
        onTap: () => _openDetail(context),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 11,
              child: Container(
                color: context.colors.primaryContainer,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Hero(
                      tag: _heroTag,
                      child: ColoredBox(
                        color: context.colors.primaryContainer,
                        child: room.imageUrl.isNotEmpty
                            ? Image.network(
                                room.imageUrl,
                                fit: BoxFit.cover,
                                errorBuilder: (_, _, _) => Icon(
                                  Icons.broken_image_outlined,
                                  size: 64,
                                  color: context.colors.primary.withAlpha(0x55),
                                ),
                              )
                            : Icon(
                                Icons.apartment_outlined,
                                size: 82,
                                color: context.colors.primary.withAlpha(0x55),
                              ),
                      ),
                    ),
                    if (room.submittedByName?.trim().isNotEmpty == true)
                      Positioned(
                        top: 12,
                        left: 12,
                        child: Container(
                          constraints: const BoxConstraints(maxWidth: 180),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 7,
                          ),
                          decoration: BoxDecoration(
                            color: context.colors.surface.withValues(
                              alpha: 0.92,
                            ),
                            borderRadius: BorderRadius.circular(999),
                            boxShadow: [
                              BoxShadow(
                                color: context.colors.shadow.withAlpha(0x1A),
                                blurRadius: 10,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.verified_user_outlined,
                                size: 15,
                                color: context.colors.primary,
                              ),
                              const SizedBox(width: 5),
                              Flexible(
                                child: Text(
                                  'เพิ่มโดย: ${room.submittedByName!.trim()}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: context.colors.textSecondary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    Positioned(
                      top: 12,
                      right: 12,
                      child: _FavoriteButton(room: room),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              flex: 9,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 14, 18, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      room.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: context.colors.primaryContainer,
                        borderRadius: BorderRadius.circular(99),
                      ),
                      child: Text(
                        _propertyTypeLabel(room.propertyType),
                        style: TextStyle(
                          color: context.colors.primary,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.location_on_outlined,
                          size: 17,
                          color: context.colors.textMuted,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            room.location,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: context.colors.textMuted,
                              height: 1.35,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (room.distanceMeters != null) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(
                            Icons.near_me_outlined,
                            size: 16,
                            color: context.colors.primary,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            'ห่างจากคุณ ${_distanceLabel(room.distanceMeters!)}',
                            style: TextStyle(
                              color: context.colors.primary,
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ],
                    const Spacer(),
                    Divider(height: 1, color: context.colors.border),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        if (SafeExternalUri.https(room.mapUrl) != null)
                          Expanded(
                            child: _NavigateButton(
                              onLaunch: () => launchUrl(
                                SafeExternalUri.https(room.mapUrl)!,
                                mode: LaunchMode.externalApplication,
                              ),
                            ),
                          ),
                        if (SafeExternalUri.https(room.mapUrl) != null)
                          const SizedBox(width: 10),
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: () => _openDetail(context),
                            icon: const Icon(Icons.arrow_forward_rounded),
                            label: const Text('รายละเอียด'),
                            style: FilledButton.styleFrom(
                              minimumSize: const Size.fromHeight(40),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                              ),
                            ),
                          ),
                        ),
                      ],
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

  String _propertyTypeLabel(String value) => switch (value) {
    'room' => 'ห้องแถว',
    'house' => 'บ้านเช่า',
    'condo' => 'คอนโด',
    _ => 'อพาร์ตเมนต์',
  };

  String _distanceLabel(double meters) {
    if (meters < 1000) return '${meters.round()} ม.';
    final kilometers = meters / 1000;
    return kilometers < 10
        ? '${kilometers.toStringAsFixed(1)} กม.'
        : '${kilometers.round()} กม.';
  }
}

class _HowItWorksSection extends StatelessWidget {
  const _HowItWorksSection();

  @override
  Widget build(BuildContext context) {
    const steps = [
      (Icons.search_rounded, 'ค้นหา', 'เลือกทำเลและงบประมาณที่ต้องการ'),
      (Icons.tune_rounded, 'เปรียบเทียบ', 'ดูรายละเอียดและสิ่งอำนวยความสะดวก'),
      (Icons.chat_outlined, 'ติดต่อ', 'พูดคุยกับเจ้าของห้องได้โดยตรง'),
    ];
    return Container(
      color: context.colors.surface,
      child: _PageWidth(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 72),
          child: Column(
            children: [
              Text(
                'หาห้องง่ายใน 3 ขั้นตอน',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 42),
              Wrap(
                spacing: 32,
                runSpacing: 36,
                alignment: WrapAlignment.center,
                children: steps.indexed.map((entry) {
                  final (index, step) = entry;
                  return SizedBox(
                    width: 320,
                    child: Column(
                      children: [
                        CircleAvatar(
                          radius: 34,
                          backgroundColor: context.colors.primaryContainer,
                          child: Icon(
                            step.$1,
                            color: context.colors.primary,
                            size: 30,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          '${index + 1}. ${step.$2}',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 7),
                        Text(
                          step.$3,
                          textAlign: TextAlign.center,
                          style: TextStyle(color: context.colors.textMuted),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CallToAction extends StatelessWidget {
  const _CallToAction();

  @override
  Widget build(BuildContext context) => _PageWidth(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 54),
        decoration: BoxDecoration(
          // Always a dark accent panel, in both light and dark mode.
          color: const Color(0xFF0F172A),
          borderRadius: BorderRadius.circular(28),
        ),
        child: Column(
          children: [
            Text(
              'มีห้องแถวให้เช่า?',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                color: context.colors.onPrimary,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'ลงทะเบียนเพื่ออัปโหลดห้องแถวของคุณฟรี',
              textAlign: TextAlign.center,
              style: TextStyle(color: context.colors.borderStrong, fontSize: 16),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () => Navigator.pushNamed(context, '/contact'),
              child: const Text('ลงทะเบียนลงประกาศฟรี'),
            ),
          ],
        ),
      ),
    ),
  );
}

class _Footer extends StatelessWidget {
  const _Footer();

  @override
  Widget build(BuildContext context) => _PageWidth(
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: Row(
        children: [
          const AppLogo(),
          const Spacer(),
          Text(
            '© ${DateTime.now().year} Room Rental',
            style: TextStyle(color: context.colors.textMuted),
          ),
        ],
      ),
    ),
  );
}

class _NavigateButton extends StatefulWidget {
  const _NavigateButton({required this.onLaunch});

  final Future<void> Function() onLaunch;

  @override
  State<_NavigateButton> createState() => _NavigateButtonState();
}

class _NavigateButtonState extends State<_NavigateButton>
    with TickerProviderStateMixin {
  late final _fill = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 450),
  );
  late final _shoot = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 420),
  );
  bool _launching = false;

  @override
  void dispose() {
    _fill.dispose();
    _shoot.dispose();
    super.dispose();
  }

  Future<void> _play() async {
    await _fill.forward().orCancel.catchError((_) {});
    if (!mounted || _fill.value < 1) return;
    await _shoot.forward(from: 0).orCancel.catchError((_) {});
  }

  Future<void> _onTap() async {
    if (_launching) return;
    _launching = true;
    try {
      if (!MediaQuery.disableAnimationsOf(context)) await _play();
      if (mounted) await widget.onLaunch();
    } finally {
      _launching = false;
      if (mounted) {
        _shoot.reset();
        _fill.reverse();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final outline = Theme.of(context).colorScheme.outline;
    final accent = context.colors.primary;
    return AnimatedBuilder(
      animation: Listenable.merge([_fill, _shoot]),
      builder: (context, _) {
        final fill = Curves.easeOutCubic.transform(_fill.value);
        final shape = StadiumBorder(
          side: BorderSide(color: Color.lerp(outline, accent, fill)!),
        );
        return Material(
          shape: shape,
          clipBehavior: Clip.antiAlias,
          color: Colors.transparent,
          child: InkWell(
            onTap: _onTap,
            onTapDown: (_) => _fill.forward(),
            onTapCancel: () {
              if (!_launching) _fill.reverse();
            },
            child: SizedBox(
              height: 40,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: FractionallySizedBox(
                      alignment: Alignment.centerLeft,
                      widthFactor: fill,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              context.colors.primaryContainer,
                              context.colors.primaryContainerStrong,
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  Center(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _ShootingArrow(progress: _shoot.value),
                        const SizedBox(width: 8),
                        Text(
                          'นำทาง',
                          style: TextStyle(
                            color: accent,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// The arrow flies off to the top-right, then glides back into place.
class _ShootingArrow extends StatelessWidget {
  const _ShootingArrow({required this.progress});

  final double progress;

  @override
  Widget build(BuildContext context) {
    final Offset offset;
    final double opacity;
    if (progress < 0.5) {
      final t = Curves.easeInCubic.transform(progress / 0.5);
      offset = Offset(22 * t, -22 * t);
      opacity = 1 - t;
    } else {
      final t = Curves.easeOutCubic.transform((progress - 0.5) / 0.5);
      offset = Offset(-14 * (1 - t), 14 * (1 - t));
      opacity = t;
    }
    return Transform.translate(
      offset: offset,
      child: Opacity(
        opacity: opacity,
        child: Icon(
          Icons.near_me_rounded,
          size: 20,
          color: context.colors.primary,
        ),
      ),
    );
  }
}

class _FavoriteButton extends StatefulWidget {
  const _FavoriteButton({required this.room});

  final RentalListing room;

  @override
  State<_FavoriteButton> createState() => _FavoriteButtonState();
}

class _FavoriteButtonState extends State<_FavoriteButton>
    with SingleTickerProviderStateMixin {
  static final _likeScale = TweenSequence<double>([
    TweenSequenceItem(
      tween: Tween(
        begin: 1.0,
        end: 1.35,
      ).chain(CurveTween(curve: Curves.easeOut)),
      weight: 30,
    ),
    TweenSequenceItem(
      tween: Tween(
        begin: 1.35,
        end: 0.9,
      ).chain(CurveTween(curve: Curves.easeInOut)),
      weight: 25,
    ),
    TweenSequenceItem(
      tween: Tween(
        begin: 0.9,
        end: 1.0,
      ).chain(CurveTween(curve: Curves.easeOut)),
      weight: 45,
    ),
  ]);
  static final _unlikeScale = TweenSequence<double>([
    TweenSequenceItem(
      tween: Tween(
        begin: 1.0,
        end: 0.75,
      ).chain(CurveTween(curve: Curves.easeOut)),
      weight: 40,
    ),
    TweenSequenceItem(
      tween: Tween(
        begin: 0.75,
        end: 1.0,
      ).chain(CurveTween(curve: Curves.easeOutBack)),
      weight: 60,
    ),
  ]);

  late final _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 650),
  );
  bool _liking = false;
  bool _busy = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Ignores taps until the current toggle has been saved and its animation
  /// has finished, so rapid tapping can't flicker the heart or the snackbar.
  Future<void> _toggle() async {
    if (_busy) return;
    _busy = true;
    try {
      _liking = !FavoriteStore.instance.contains(widget.room.id);
      final animation = MediaQuery.disableAnimationsOf(context)
          ? Future<void>.value()
          : _controller.forward(from: 0).orCancel.catchError((_) {});
      final next = await FavoriteStore.instance.toggle(widget.room.id);
      if (mounted) _showSnackBar(next);
      await animation;
    } finally {
      _busy = false;
    }
  }

  void _showSnackBar(bool liked) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          duration: const Duration(milliseconds: 1200),
          content: Text(
            liked
                ? 'บันทึก “${widget.room.title}” เป็นรายการโปรดแล้ว'
                : 'นำ “${widget.room.title}” ออกจากรายการโปรดแล้ว',
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: FavoriteStore.instance,
      builder: (context, _) {
        final liked = FavoriteStore.instance.contains(widget.room.id);
        return AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            final scale = (_liking ? _likeScale : _unlikeScale).transform(
              _controller.value,
            );
            return Stack(
              alignment: Alignment.center,
              clipBehavior: Clip.none,
              children: [
                if (_liking && _controller.isAnimating)
                  Positioned.fill(
                    child: CustomPaint(
                      painter: _HeartBurstPainter(
                        _controller.value,
                        context.colors.danger,
                      ),
                    ),
                  ),
                Transform.scale(scale: scale, child: child),
              ],
            );
          },
          child: Container(
            decoration: BoxDecoration(
              color: context.colors.background,
              shape: BoxShape.circle,
            ),
            child: IconButton(
              tooltip: liked ? 'นำออกจากรายการโปรด' : 'บันทึกเป็นรายการโปรด',
              onPressed: _toggle,
              icon: Icon(
                liked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                color: liked
                    ? context.colors.danger
                    : context.colors.textSecondary,
              ),
            ),
          ),
        );
      },
    );
  }
}

/// An expanding ring followed by a burst of dots around the heart.
class _HeartBurstPainter extends CustomPainter {
  _HeartBurstPainter(this.progress, this.ringColor);

  final double progress;
  final Color ringColor;

  static const _colors = [
    Color(0xFFDC2626),
    Color(0xFFF472B6),
    Color(0xFFF59E0B),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);

    final ring = (progress / 0.45).clamp(0.0, 1.0);
    if (ring < 1) {
      final eased = Curves.easeOut.transform(ring);
      canvas.drawCircle(
        center,
        16 + 16 * eased,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 5 * (1 - eased)
          ..color = ringColor.withValues(alpha: 0.5 * (1 - ring)),
      );
    }

    final dots = ((progress - 0.15) / 0.85).clamp(0.0, 1.0);
    if (dots > 0 && dots < 1) {
      final distance = 18 + 14 * Curves.easeOutCubic.transform(dots);
      final radius = 3.5 * (1 - dots);
      for (var i = 0; i < 8; i++) {
        final angle = i * math.pi / 4 - math.pi / 2;
        canvas.drawCircle(
          center + Offset(math.cos(angle), math.sin(angle)) * distance,
          radius,
          Paint()..color = _colors[i % _colors.length],
        );
      }
    }
  }

  @override
  bool shouldRepaint(_HeartBurstPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.ringColor != ringColor;
}
