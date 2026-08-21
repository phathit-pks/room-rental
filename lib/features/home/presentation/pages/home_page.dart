import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:room_rental/core/utils/relative_date_formatter.dart';
import 'package:room_rental/features/auth/presentation/widgets/client_auth_button.dart';
import 'package:room_rental/features/favorites/data/favorite_store.dart';
import 'package:room_rental/features/listings/data/repositories/listing_repository.dart';
import 'package:room_rental/features/listings/domain/entities/rental_listing.dart';
import 'package:room_rental/features/listings/presentation/pages/listing_detail_page.dart';
import 'package:room_rental/features/locations/data/location_store.dart';
import 'package:room_rental/features/map_search/presentation/pages/map_search_page.dart';
import 'package:room_rental/shared/widgets/app_logo.dart';
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

  void _search(String? province, String? district, String? village) {
    setState(() {
      _isSearchMode = true;
      _province = province;
      _district = district;
      _village = village;
      _listings = _repository.searchPage(
        province: province,
        district: district,
        village: village,
        page: 1,
      );
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
      backgroundColor: const Color(0xFFF7FAFF),
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
      color: Colors.white,
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
    required this.advertisements,
  });

  final void Function(String?, String?, String?) onSearch;
  final Future<List<RentalListing>> advertisements;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFEFF6FF), Color(0xFFF8FAFC), Color(0xFFECFDF5)],
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
                    _SearchBox(onSearch: onSearch),
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x140F172A),
            blurRadius: 24,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 720;
          final preview = Container(
            height: compact ? 210 : 300,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFFBFDBFE), Color(0xFFDBEAFE)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Stack(
              children: [
                Positioned.fill(
                  child: room.imageUrl.isEmpty
                      ? const Center(
                          child: Icon(
                            Icons.apartment_rounded,
                            size: 132,
                            color: Color(0x662563EB),
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
                    const Icon(
                      Icons.location_on_outlined,
                      size: 19,
                      color: Color(0xFF64748B),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        room.location,
                        style: const TextStyle(color: Color(0xFF64748B)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    const Icon(
                      Icons.schedule_outlined,
                      size: 18,
                      color: Color(0xFF64748B),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'อัปเดต${formatRelativeDate(DateTime.now())}',
                      style: const TextStyle(color: Color(0xFF64748B)),
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
                    Expanded(
                      child: Text(
                        _price(room),
                        style: const TextStyle(
                          color: Color(0xFF2563EB),
                          fontSize: 21,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
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
                const SizedBox(height: 8),
                const _EstimatedPriceNotice(),
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

  String _price(RentalListing room) {
    String format(int value) => value.toString().replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
      (_) => ',',
    );
    final symbol = room.currency == 'LAK'
        ? '₭'
        : room.currency == 'THB'
        ? '฿'
        : r'$';
    if (room.monthlyPriceMin != room.monthlyPriceMax) {
      return '$symbol${format(room.monthlyPriceMin)} – ${format(room.monthlyPriceMax)} / เดือน';
    }
    return '$symbol${format(room.monthlyPrice)} / เดือน';
  }
}

class _SponsoredBadge extends StatelessWidget {
  const _SponsoredBadge();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(99),
    ),
    child: const Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.campaign_outlined, size: 17, color: Color(0xFF2563EB)),
        SizedBox(width: 6),
        Text('โฆษณา', style: TextStyle(fontWeight: FontWeight.bold)),
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
      Icon(icon, size: 18, color: const Color(0xFF475569)),
      const SizedBox(width: 5),
      Text(label, style: const TextStyle(color: Color(0xFF475569))),
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
        gradient: const LinearGradient(
          colors: [Color(0xFF172554), Color(0xFF2563EB)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(
            color: Color(0x292563EB),
            blurRadius: 24,
            offset: Offset(0, 10),
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
              const Text(
                'มีห้องว่างให้เช่า?',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 7),
              Text(
                'โปรโมตประกาศของคุณให้ผู้เช่าเห็นก่อนใคร',
                textAlign: compact ? TextAlign.center : TextAlign.left,
                style: const TextStyle(color: Color(0xFFDBEAFE), fontSize: 16),
              ),
            ],
          );
          final action = FilledButton.icon(
            onPressed: () => Navigator.pushNamed(context, '/contact'),
            icon: const Icon(Icons.add_home_work_outlined),
            label: const Text('ลงประกาศ'),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: const Color(0xFF1D4ED8),
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
              const Icon(
                Icons.campaign_outlined,
                color: Colors.white,
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

class _SearchBox extends StatefulWidget {
  const _SearchBox({required this.onSearch});

  final void Function(String?, String?, String?) onSearch;

  @override
  State<_SearchBox> createState() => _SearchBoxState();
}

class _SearchBoxState extends State<_SearchBox> {
  final _store = LocationStore.instance;

  Map<String, Map<String, List<String>>> get _locations => _store.data;

  String? _province;
  String? _district;
  String? _village;

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

  void _search() {
    final selections = [
      _province,
      _district,
      _village,
    ].whereType<String>().join(' • ');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          selections.isEmpty
              ? 'กรุณาเลือกแขวง เมือง หรือบ้านที่ต้องการค้นหา'
              : 'กำลังค้นหาห้องใน $selections',
        ),
      ),
    );
    widget.onSearch(_province, _district, _village);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 900),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(
            color: Color(0x180F172A),
            blurRadius: 26,
            offset: Offset(0, 10),
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
                onPressed: _search,
                icon: const Icon(Icons.search),
                label: const Text('ค้นหา'),
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
    return DropdownButtonFormField<String>(
      initialValue: value,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: const Color(0xFF2563EB)),
        fillColor: const Color(0xFFF8FAFC),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 10,
        ),
      ),
      hint: Text('เลือก$label'),
      items: items
          .map((item) => DropdownMenuItem(value: item, child: Text(item)))
          .toList(),
      onChanged: onChanged,
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
      Icon(icon, size: 19, color: const Color(0xFF16A34A)),
      const SizedBox(width: 6),
      Text(label, style: const TextStyle(color: Color(0xFF475569))),
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
                            ? 'แสดงหน้าละ 9 รายการ'
                            : widget.usingCurrentLocation
                            ? 'ที่พักใกล้ตำแหน่งปัจจุบันของคุณ • สูงสุด 9 รายการ'
                            : 'ประกาศล่าสุด • สูงสุด 9 รายการ',
                        style: const TextStyle(color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ),
                if (!widget.isSearchMode)
                  const Text(
                    'ต้องการดูเพิ่มเติม กรุณาใช้ช่องค้นหา',
                    style: TextStyle(color: Color(0xFF64748B), fontSize: 12),
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
                        return GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: rooms.length,
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: columns,
                                crossAxisSpacing: 20,
                                mainAxisSpacing: 20,
                                childAspectRatio: columns == 1 ? 1.35 : .92,
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
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _animation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, _) => Opacity(
        opacity: 0.58 + (_animation.value * 0.34),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth >= 900
                ? 3
                : constraints.maxWidth >= 560
                ? 2
                : 1;
            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: 9,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: columns,
                crossAxisSpacing: 20,
                mainAxisSpacing: 20,
                childAspectRatio: columns == 1 ? 1.35 : .92,
              ),
              itemBuilder: (_, _) => const _ListingSkeletonCard(),
            );
          },
        ),
      ),
    );
  }
}

class _ListingSkeletonCard extends StatelessWidget {
  const _ListingSkeletonCard();

  @override
  Widget build(BuildContext context) => Container(
    clipBehavior: Clip.antiAlias,
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: const Color(0xFFE2E8F0)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Expanded(
          flex: 6,
          child: ColoredBox(color: Color(0xFFDCE8FA), child: SizedBox.expand()),
        ),
        Expanded(
          flex: 5,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _SkeletonLine(widthFactor: .68, height: 15),
                const SizedBox(height: 12),
                const _SkeletonLine(widthFactor: .32, height: 10),
                const SizedBox(height: 12),
                const _SkeletonLine(widthFactor: .92, height: 10),
                const SizedBox(height: 7),
                const _SkeletonLine(widthFactor: .74, height: 10),
                const Spacer(),
                const _SkeletonLine(widthFactor: .58, height: 17),
              ],
            ),
          ),
        ),
      ],
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
        color: const Color(0xFFE2E8F0),
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
                disabledBackgroundColor: const Color(0xFF2563EB),
                disabledForegroundColor: Colors.white,
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

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      child: InkWell(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => ListingDetailPage(room: room)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Container(
                color: const Color(0xFFDCEAFE),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (room.imageUrl.isNotEmpty)
                      Image.network(
                        room.imageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => const Icon(
                          Icons.broken_image_outlined,
                          size: 64,
                          color: Color(0x552563EB),
                        ),
                      )
                    else
                      const Icon(
                        Icons.apartment_outlined,
                        size: 82,
                        color: Color(0x552563EB),
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
                            color: Colors.white.withValues(alpha: 0.92),
                            borderRadius: BorderRadius.circular(999),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x1A0F172A),
                                blurRadius: 10,
                                offset: Offset(0, 3),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.verified_user_outlined,
                                size: 15,
                                color: Color(0xFF2563EB),
                              ),
                              const SizedBox(width: 5),
                              Flexible(
                                child: Text(
                                  'เพิ่มโดย: ${room.submittedByName!.trim()}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF334155),
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
                      child: ListenableBuilder(
                        listenable: FavoriteStore.instance,
                        builder: (context, _) {
                          final liked = FavoriteStore.instance.contains(
                            room.id,
                          );
                          return IconButton.filledTonal(
                            tooltip: liked
                                ? 'นำออกจากรายการโปรด'
                                : 'บันทึกเป็นรายการโปรด',
                            onPressed: () async {
                              final next = await FavoriteStore.instance.toggle(
                                room.id,
                              );
                              if (!context.mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  duration: const Duration(milliseconds: 1200),
                                  content: Text(
                                    next
                                        ? 'บันทึก “${room.title}” เป็นรายการโปรดแล้ว'
                                        : 'นำ “${room.title}” ออกจากรายการโปรดแล้ว',
                                  ),
                                ),
                              );
                            },
                            icon: Icon(
                              liked ? Icons.favorite : Icons.favorite_border,
                              color: liked
                                  ? const Color(0xFFDC2626)
                                  : const Color(0xFF475569),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    room.title,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _propertyTypeLabel(room.propertyType),
                    style: const TextStyle(
                      color: Color(0xFF2563EB),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 7),
                  Row(
                    children: [
                      const Icon(
                        Icons.location_on_outlined,
                        size: 17,
                        color: Color(0xFF64748B),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          room.location,
                          style: const TextStyle(color: Color(0xFF64748B)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          _priceLabel(room),
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF2563EB),
                          ),
                        ),
                      ),
                      if (room.mapUrl?.isNotEmpty == true)
                        TextButton.icon(
                          onPressed: () => launchUrl(
                            Uri.parse(room.mapUrl!),
                            mode: LaunchMode.externalApplication,
                          ),
                          icon: const Icon(Icons.directions_outlined),
                          label: Text(
                            room.distanceMeters == null
                                ? 'นำทาง'
                                : 'นำทาง · ${_distanceLabel(room.distanceMeters!)}',
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _currencySymbol(String currency) => switch (currency) {
    'THB' => '฿',
    'USD' => r'$',
    _ => '₭',
  };

  String _propertyTypeLabel(String value) => switch (value) {
    'room' => 'ห้องแถว',
    'house' => 'บ้านเช่า',
    'condo' => 'คอนโด',
    _ => 'อพาร์ตเมนต์',
  };

  String _formatPrice(int value) {
    final digits = value.toString();
    return digits.replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ',');
  }

  String _distanceLabel(double meters) {
    if (meters < 1000) return '${meters.round()} ม.';
    final kilometers = meters / 1000;
    return kilometers < 10
        ? '${kilometers.toStringAsFixed(1)} กม.'
        : '${kilometers.round()} กม.';
  }

  String _priceLabel(RentalListing room) {
    final minimum = room.monthlyPriceMin;
    final maximum = room.monthlyPriceMax;
    final symbol = _currencySymbol(room.currency);
    if (minimum <= 0 && maximum <= 0) return 'สอบถามราคา';
    if (minimum > 0 && maximum > 0 && minimum != maximum) {
      return '$symbol${_formatPrice(minimum)} – ${_formatPrice(maximum)} / เดือน';
    }
    final price = minimum > 0 ? minimum : maximum;
    return '$symbol${_formatPrice(price)} / เดือน';
  }
}

class _EstimatedPriceNotice extends StatelessWidget {
  const _EstimatedPriceNotice();

  @override
  Widget build(BuildContext context) => Tooltip(
    message: 'ราคาอาจมีการเปลี่ยนแปลง กรุณาตรวจสอบกับผู้ให้เช่าอีกครั้ง',
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7ED),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: const Color(0xFFFED7AA)),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.info_outline, size: 14, color: Color(0xFF9A3412)),
          SizedBox(width: 5),
          Flexible(
            child: Text(
              'ราคาโดยประมาณ • โปรดตรวจสอบอีกครั้ง',
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Color(0xFF9A3412),
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    ),
  );
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
      color: Colors.white,
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
                          backgroundColor: const Color(0xFFDBEAFE),
                          child: Icon(
                            step.$1,
                            color: const Color(0xFF2563EB),
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
                          style: const TextStyle(color: Color(0xFF64748B)),
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
          color: const Color(0xFF0F172A),
          borderRadius: BorderRadius.circular(28),
        ),
        child: Column(
          children: [
            Text(
              'มีห้องแถวให้เช่า?',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'ลงทะเบียนเพื่ออัปโหลดห้องแถวของคุณฟรี',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFFCBD5E1), fontSize: 16),
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
            style: const TextStyle(color: Color(0xFF64748B)),
          ),
        ],
      ),
    ),
  );
}
