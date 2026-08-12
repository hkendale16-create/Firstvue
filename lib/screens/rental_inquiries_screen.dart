import 'package:flutter/material.dart';
import '../theme/firstvue_theme.dart';

import '../services/rentals_store.dart';

class RentalInquiriesScreen extends StatefulWidget {
  const RentalInquiriesScreen({super.key});

  @override
  State<RentalInquiriesScreen> createState() => _RentalInquiriesScreenState();
}

class _RentalInquiriesScreenState extends State<RentalInquiriesScreen> {
  late Future<List<RentalInquiry>> _inquiriesFuture;

  @override
  void initState() {
    super.initState();
    _inquiriesFuture = RentalsStore.fetchOwnerInquiries();
  }

  Future<void> _refresh() async {
    setState(() => _inquiriesFuture = RentalsStore.fetchOwnerInquiries());
    await _inquiriesFuture;
  }

  Future<void> _markRead(RentalInquiry inquiry) async {
    if (inquiry.status != 'new') return;
    try {
      await RentalsStore.markInquiryRead(inquiry.id);
      await _refresh();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Unable to update this inquiry. Please try again.'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        surfaceTintColor: Colors.transparent,
        title: const Text('RENTAL INQUIRIES'),
      ),
      body: FutureBuilder<List<RentalInquiry>>(
        future: _inquiriesFuture,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: TextButton(
                onPressed: _refresh,
                child: const Text('Unable to load inquiries. Tap to retry.'),
              ),
            );
          }
          if (!snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(color: Color(0xFFD8B56A)),
            );
          }
          final inquiries = snapshot.data!;
          if (inquiries.isEmpty) {
            return RefreshIndicator(
              color: const Color(0xFFD8B56A),
              onRefresh: _refresh,
              child: ListView(
                children: const [
                  SizedBox(height: 260),
                  Center(
                    child: Text(
                      'No rental inquiries yet.',
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
              itemCount: inquiries.length,
              separatorBuilder: (_, _) => const SizedBox(height: 14),
              itemBuilder: (context, index) {
                final inquiry = inquiries[index];
                return _InquiryCard(
                  inquiry: inquiry,
                  onOpen: () => _markRead(inquiry),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class _InquiryCard extends StatelessWidget {
  final RentalInquiry inquiry;
  final VoidCallback onOpen;

  const _InquiryCard({required this.inquiry, required this.onOpen});

  @override
  Widget build(BuildContext context) {
    final isNew = inquiry.status == 'new';
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onOpen,
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).extension<FirstVuePalette>()?.surface ?? FirstVueColors.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isNew
                  ? const Color(0xFFD8B56A).withValues(alpha: .38)
                  : Colors.white.withValues(alpha: .08),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.mail_outline, color: Color(0xFFD8B56A)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      inquiry.rentalTitle,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  if (isNew)
                    const Text(
                      'NEW',
                      style: TextStyle(
                        color: Color(0xFFD8B56A),
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                inquiry.message,
                style: const TextStyle(color: Colors.white60, height: 1.35),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
