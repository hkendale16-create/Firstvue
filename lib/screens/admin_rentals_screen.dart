import 'package:flutter/material.dart';
import '../theme/firstvue_theme.dart';

import '../services/rentals_store.dart';
import '../widgets/admin_gate.dart';

class AdminRentalsScreen extends StatefulWidget {
  const AdminRentalsScreen({super.key});

  @override
  State<AdminRentalsScreen> createState() => _AdminRentalsScreenState();
}

class _AdminRentalsScreenState extends State<AdminRentalsScreen> {
  late Future<List<RentalListing>> _pendingFuture;

  @override
  void initState() {
    super.initState();
    _pendingFuture = RentalsStore.fetchPendingListings();
  }

  Future<void> _refresh() async {
    setState(() => _pendingFuture = RentalsStore.fetchPendingListings());
    await _pendingFuture;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        surfaceTintColor: Colors.transparent,
        title: const Text('RENTAL APPROVALS'),
      ),
      body: AdminGate(
        child: FutureBuilder<List<RentalListing>>(
          future: _pendingFuture,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Unable to load pending rentals.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white54),
                      ),
                      const SizedBox(height: 12),
                      TextButton(
                        onPressed: _refresh,
                        child: const Text('Tap to retry'),
                      ),
                    ],
                  ),
                ),
              );
            }
            if (!snapshot.hasData) {
              return const Center(
                child: CircularProgressIndicator(color: Color(0xFFD8B56A)),
              );
            }
            final listings = snapshot.data!;
            if (listings.isEmpty) {
              return RefreshIndicator(
                color: const Color(0xFFD8B56A),
                onRefresh: _refresh,
                child: ListView(
                  children: const [
                    SizedBox(height: 240),
                    Center(
                      child: Text(
                        'No pending rental listings.',
                        style: TextStyle(color: Colors.white54),
                      ),
                    ),
                  ],
                ),
              );
            }
            return RefreshIndicator(
              color: const Color(0xFFD8B56A),
              onRefresh: _refresh,
              child: ListView.separated(
                padding: const EdgeInsets.all(20),
                itemCount: listings.length + 1,
                separatorBuilder: (_, _) => const SizedBox(height: 14),
                itemBuilder: (context, index) {
                  if (index == 0) {
                    return const Text(
                      'Review listings carefully. Approval makes a listing visible to signed-in rental viewers.',
                      style: TextStyle(color: Colors.white54, height: 1.4),
                    );
                  }
                  return _ApprovalCard(
                    listing: listings[index - 1],
                    onUpdated: _refresh,
                  );
                },
              ),
            );
          },
        ),
      ),
    );
  }
}

class _ApprovalCard extends StatefulWidget {
  final RentalListing listing;
  final Future<void> Function() onUpdated;

  const _ApprovalCard({required this.listing, required this.onUpdated});

  @override
  State<_ApprovalCard> createState() => _ApprovalCardState();
}

class _ApprovalCardState extends State<_ApprovalCard> {
  bool _updating = false;

  Future<void> _setStatus(String status) async {
    setState(() => _updating = true);
    try {
      await RentalsStore.setRentalStatus(
        rentalId: widget.listing.id,
        status: status,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              status == 'approved'
                  ? 'Rental approved.'
                  : 'Rental rejected.',
            ),
          ),
        );
      }
      await widget.onUpdated();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Unable to update this rental. Confirm admin access and try again.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _updating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final listing = widget.listing;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).extension<FirstVuePalette>()?.surface ?? FirstVueColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFFE5C16F).withValues(alpha: .28),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            listing.title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 5),
          Text(listing.location, style: const TextStyle(color: Colors.white54)),
          const SizedBox(height: 10),
          Text(
            listing.description,
            style: const TextStyle(color: Colors.white60, height: 1.35),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (listing.weeklyPrice != null)
                _PriceChip(text: listing.weeklyPrice!),
              if (listing.monthlyPrice != null)
                _PriceChip(text: listing.monthlyPrice!),
              if (listing.media.isNotEmpty)
                _PriceChip(text: '${listing.media.length} media item(s)'),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _updating ? null : () => _setStatus('rejected'),
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
                  onPressed: _updating ? null : () => _setStatus('approved'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFD8B56A),
                    foregroundColor: Colors.black,
                  ),
                  child: Text(_updating ? 'SAVING...' : 'APPROVE'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PriceChip extends StatelessWidget {
  final String text;

  const _PriceChip({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFD8B56A).withValues(alpha: .1),
        borderRadius: BorderRadius.circular(9),
      ),
      child: Text(
        text,
        style: const TextStyle(color: Color(0xFFD8B56A), fontSize: 12),
      ),
    );
  }
}
