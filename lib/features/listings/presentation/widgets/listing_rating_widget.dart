import 'package:flutter/material.dart';
import 'package:room_rental/core/config/supabase_config.dart';
import 'package:room_rental/core/theme/app_colors.dart';
import 'package:room_rental/features/auth/presentation/widgets/client_auth_button.dart';
import 'package:room_rental/features/listings/data/repositories/listing_rating_repository.dart';

class ListingRatingWidget extends StatefulWidget {
  const ListingRatingWidget({required this.listingId, super.key});

  final String listingId;

  @override
  State<ListingRatingWidget> createState() => _ListingRatingWidgetState();
}

class _ListingRatingWidgetState extends State<ListingRatingWidget> {
  final _repository = const ListingRatingRepository();
  late Future<ListingRatingSummary> _summary;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _summary = _repository.fetchSummary(widget.listingId);
  }

  Future<void> _rate(int rating) async {
    if (SupabaseConfig.client?.auth.currentUser == null) {
      await showClientSignInDialog(context);
      return;
    }
    if (!mounted) return;
    setState(() => _submitting = true);
    try {
      await _repository.rate(widget.listingId, rating);
      if (mounted) {
        setState(() => _summary = _repository.fetchSummary(widget.listingId));
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('ให้คะแนนไม่สำเร็จ: $error')));
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<ListingRatingSummary>(
      future: _summary,
      builder: (context, snapshot) {
        final summary = snapshot.data;
        final average = summary?.average ?? 0;
        final count = summary?.count ?? 0;
        final myRating = summary?.myRating ?? 0;
        return Row(
          children: [
            Icon(Icons.star_rounded, color: context.colors.warning, size: 20),
            const SizedBox(width: 4),
            Text(
              count == 0
                  ? 'ยังไม่มีคะแนน'
                  : '${average.toStringAsFixed(1)} ($count คะแนน)',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: context.colors.textSecondary,
              ),
            ),
            const SizedBox(width: 16),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(5, (index) {
                final starIndex = index + 1;
                final filled = starIndex <= myRating;
                return GestureDetector(
                  onTap: _submitting ? null : () => _rate(starIndex),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 3,
                      vertical: 6,
                    ),
                    child: Icon(
                      filled ? Icons.star_rounded : Icons.star_outline_rounded,
                      color: context.colors.warning,
                      size: 24,
                    ),
                  ),
                );
              }),
            ),
          ],
        );
      },
    );
  }
}
