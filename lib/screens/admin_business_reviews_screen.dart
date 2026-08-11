import 'package:flutter/material.dart';

import '../services/business_reviews_service.dart';
import '../services/rentals_store.dart';

class AdminBusinessReviewsScreen extends StatefulWidget {
  const AdminBusinessReviewsScreen({super.key});

  @override
  State<AdminBusinessReviewsScreen> createState() =>
      _AdminBusinessReviewsScreenState();
}

class _AdminBusinessReviewsScreenState
    extends State<AdminBusinessReviewsScreen> {
  late Future<List<PendingBusinessReview>> _reviews =
      BusinessReviewsService.fetchPendingReviews();

  Future<void> _refresh() async {
    setState(() => _reviews = BusinessReviewsService.fetchPendingReviews());
    await _reviews;
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFF080B0F),
    appBar: AppBar(
      backgroundColor: const Color(0xFF080B0F),
      surfaceTintColor: Colors.transparent,
      title: const Text('REVIEW APPROVALS'),
    ),
    body: FutureBuilder<bool>(
      future: RentalsStore.isCurrentUserAdmin(),
      builder: (context, adminSnapshot) {
        if (!adminSnapshot.hasData) {
          return const Center(
            child: CircularProgressIndicator(color: Color(0xFFD8B56A)),
          );
        }
        if (!adminSnapshot.data!) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(28),
              child: Text(
                'This area is restricted to FirstVue administrators.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white54),
              ),
            ),
          );
        }
        return FutureBuilder<List<PendingBusinessReview>>(
          future: _reviews,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Center(
                child: TextButton(
                  onPressed: _refresh,
                  child: const Text('Unable to load reviews. Tap to retry.'),
                ),
              );
            }
            if (!snapshot.hasData) {
              return const Center(
                child: CircularProgressIndicator(color: Color(0xFFD8B56A)),
              );
            }
            if (snapshot.data!.isEmpty) {
              return const Center(
                child: Text(
                  'No pending customer reviews.',
                  style: TextStyle(color: Colors.white54),
                ),
              );
            }
            return RefreshIndicator(
              color: const Color(0xFFD8B56A),
              onRefresh: _refresh,
              child: ListView.separated(
                padding: const EdgeInsets.all(20),
                itemCount: snapshot.data!.length + 1,
                separatorBuilder: (_, _) => const SizedBox(height: 14),
                itemBuilder: (context, index) => index == 0
                    ? const Text(
                        'Approve only authentic, relevant reviews that follow FirstVue standards.',
                        style: TextStyle(color: Colors.white54, height: 1.4),
                      )
                    : _ReviewApprovalCard(
                        review: snapshot.data![index - 1],
                        onReviewed: _refresh,
                      ),
              ),
            );
          },
        );
      },
    ),
  );
}

class _ReviewApprovalCard extends StatefulWidget {
  final PendingBusinessReview review;
  final Future<void> Function() onReviewed;

  const _ReviewApprovalCard({required this.review, required this.onReviewed});

  @override
  State<_ReviewApprovalCard> createState() => _ReviewApprovalCardState();
}

class _ReviewApprovalCardState extends State<_ReviewApprovalCard> {
  bool _saving = false;

  Future<void> _moderate(bool approved) async {
    setState(() => _saving = true);
    try {
      await BusinessReviewsService.moderateReview(
        reviewId: widget.review.id,
        approved: approved,
      );
      await widget.onReviewed();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to moderate this review.')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final review = widget.review;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF10151B),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFFE5C16F).withValues(alpha: .28),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            review.businessName,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              ...List.generate(
                5,
                (index) => Icon(
                  index < review.rating ? Icons.star : Icons.star_border,
                  color: const Color(0xFFE5C16F),
                  size: 19,
                ),
              ),
              const Spacer(),
              Text(
                '${review.createdAt.month}/${review.createdAt.day}/${review.createdAt.year}',
                style: const TextStyle(color: Colors.white38, fontSize: 11),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            review.body,
            style: const TextStyle(color: Colors.white70, height: 1.4),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _saving ? null : () => _moderate(false),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFD68E98),
                    side: const BorderSide(color: Color(0xFFD68E98)),
                  ),
                  child: const Text('REJECT'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: _saving ? null : () => _moderate(true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFD8B56A),
                    foregroundColor: Colors.black,
                  ),
                  child: Text(_saving ? 'SAVING...' : 'APPROVE'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
