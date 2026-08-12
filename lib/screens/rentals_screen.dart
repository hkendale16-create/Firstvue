import 'package:flutter/material.dart';
import '../navigation/firstvue_page_route.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'auth_screen.dart';
import '../services/rentals_store.dart';

enum _RentalPriceFilter { weekly, monthly }

class RentalsScreen extends StatefulWidget {
  const RentalsScreen({super.key});

  @override
  State<RentalsScreen> createState() => _RentalsScreenState();
}

class _RentalsScreenState extends State<RentalsScreen> {
  bool _agreedToAccess = false;
  String _query = '';
  _RentalPriceFilter? _priceFilter;

  Future<void> _agreeToAccess() async {
    if (Supabase.instance.client.auth.currentUser == null) {
      await Navigator.push(
        context,
        FirstVuePageRoute(builder: (_) => const AuthScreen()),
      );
      if (Supabase.instance.client.auth.currentUser == null) return;
    }

    try {
      await RentalsStore.recordAccessConsent();
      if (mounted) setState(() => _agreedToAccess = true);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Unable to save your rental access choice. Please try again.',
            ),
          ),
        );
      }
    }
  }

  List<RentalListing> _visibleListings(List<RentalListing> listings) {
    final query = _query.trim().toLowerCase();
    return listings.where((listing) {
      final matchesQuery =
          query.isEmpty ||
          listing.title.toLowerCase().contains(query) ||
          listing.location.toLowerCase().contains(query) ||
          listing.description.toLowerCase().contains(query);
      final matchesPrice = switch (_priceFilter) {
        _RentalPriceFilter.weekly => listing.weeklyPrice != null,
        _RentalPriceFilter.monthly => listing.monthlyPrice != null,
        null => true,
      };
      return matchesQuery && matchesPrice;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    if (!_agreedToAccess) {
      return _RentalAccessGate(onAgree: _agreeToAccess);
    }

    return Scaffold(
      backgroundColor: const Color(0xFF080B0F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF080B0F),
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'AVAILABLE RENTALS',
          style: TextStyle(
            fontFamily: 'CormorantGaramond',
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.2,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Post a rental',
            icon: const Icon(
              Icons.add_business_outlined,
              color: Color(0xFFD8B56A),
            ),
            onPressed: () {
              Navigator.push(
                context,
                FirstVuePageRoute(builder: (_) => const PostRentalScreen()),
              );
            },
          ),
        ],
      ),
      body: StreamBuilder<List<RentalListing>>(
        stream: RentalsStore.watchListings(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Unable to load rentals right now. Please try again.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white54),
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
          final visibleListings = _visibleListings(listings);
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 10),
                child: TextField(
                  onChanged: (value) => setState(() => _query = value),
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    hintText: 'Search rentals by city or workspace...',
                    hintStyle: TextStyle(color: Colors.white38),
                    prefixIcon: Icon(Icons.search, color: Color(0xFFD8B56A)),
                    border: InputBorder.none,
                  ),
                ),
              ),
              SizedBox(
                height: 42,
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  scrollDirection: Axis.horizontal,
                  children: [
                    _RentalFilterChip(
                      label: 'Weekly',
                      selected: _priceFilter == _RentalPriceFilter.weekly,
                      onPressed: () => setState(
                        () => _priceFilter = _RentalPriceFilter.weekly,
                      ),
                    ),
                    const SizedBox(width: 10),
                    _RentalFilterChip(
                      label: 'Monthly',
                      selected: _priceFilter == _RentalPriceFilter.monthly,
                      onPressed: () => setState(
                        () => _priceFilter = _RentalPriceFilter.monthly,
                      ),
                    ),
                    const SizedBox(width: 10),
                    _RentalFilterChip(
                      label: 'All pricing',
                      selected: _priceFilter == null,
                      onPressed: () => setState(() => _priceFilter = null),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: visibleListings.isEmpty
                    ? const Center(
                        child: Text(
                          'No approved rentals match your search.',
                          style: TextStyle(color: Colors.white54),
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
                        itemCount: visibleListings.length + 1,
                        separatorBuilder: (_, _) => const SizedBox(height: 14),
                        itemBuilder: (context, index) {
                          if (index == 0) {
                            return const Text(
                              'Live rental opportunities for owners, barbers, stylists, and other beauty professionals.',
                              style: TextStyle(
                                color: Colors.white54,
                                height: 1.4,
                              ),
                            );
                          }
                          return _RentalCard(
                            listing: visibleListings[index - 1],
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _RentalFilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onPressed;

  const _RentalFilterChip({
    required this.label,
    required this.selected,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: selected ? const Color(0xFFD8B56A) : Colors.white70,
        backgroundColor: selected
            ? const Color(0xFFD8B56A).withValues(alpha: .1)
            : const Color(0xFF151B22),
        side: BorderSide(
          color: selected
              ? const Color(0xFFD8B56A)
              : Colors.white.withValues(alpha: .15),
        ),
      ),
      child: Text(label),
    );
  }
}

class _RentalAccessGate extends StatefulWidget {
  final Future<void> Function() onAgree;

  const _RentalAccessGate({required this.onAgree});

  @override
  State<_RentalAccessGate> createState() => _RentalAccessGateState();
}

class _RentalAccessGateState extends State<_RentalAccessGate> {
  bool _accepted = false;
  bool _saving = false;

  Future<void> _submit() async {
    setState(() => _saving = true);
    await widget.onAgree();
    if (mounted) setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF080B0F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF080B0F),
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(26),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.key_outlined,
                color: Color(0xFFD8B56A),
                size: 54,
              ),
              const SizedBox(height: 20),
              const Text(
                'AVAILABLE RENTALS',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.4,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'This space is designed for owners and service professionals seeking booth or suite rentals. Customers must opt in before viewing rental information.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white54, height: 1.5),
              ),
              const SizedBox(height: 20),
              CheckboxListTile(
                value: _accepted,
                activeColor: const Color(0xFFD8B56A),
                checkColor: Colors.black,
                contentPadding: EdgeInsets.zero,
                title: const Text(
                  'I agree to view rental opportunities intended for service professionals.',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                    height: 1.35,
                  ),
                ),
                onChanged: (value) =>
                    setState(() => _accepted = value ?? false),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _accepted && !_saving ? _submit : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFD8B56A),
                    foregroundColor: Colors.black,
                    disabledBackgroundColor: const Color(0xFF211D18),
                  ),
                  child: Text(_saving ? 'SAVING...' : 'VIEW AVAILABLE RENTALS'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class PostRentalScreen extends StatefulWidget {
  const PostRentalScreen({super.key});

  @override
  State<PostRentalScreen> createState() => _PostRentalScreenState();
}

class _PostRentalScreenState extends State<PostRentalScreen> {
  final _titleController = TextEditingController();
  final _locationController = TextEditingController();
  final _weeklyController = TextEditingController();
  final _monthlyController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _imagePicker = ImagePicker();
  final List<XFile> _mediaFiles = [];
  bool _isPosting = false;

  @override
  void dispose() {
    _titleController.dispose();
    _locationController.dispose();
    _weeklyController.dispose();
    _monthlyController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _selectMedia() async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF10151B),
      builder: (sheetContext) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'ADD RENTAL MEDIA',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Choose photos or a video from your device. Each file can be up to 50 MB.',
              style: TextStyle(color: Colors.white54),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 14),
            ListTile(
              leading: const Icon(
                Icons.photo_library_outlined,
                color: Color(0xFFD8B56A),
              ),
              title: const Text(
                'Add photos',
                style: TextStyle(color: Colors.white),
              ),
              onTap: () async {
                Navigator.pop(sheetContext);
                final photos = await _imagePicker.pickMultiImage(
                  imageQuality: 85,
                );
                if (!mounted || photos.isEmpty) return;
                setState(() => _mediaFiles.addAll(photos));
              },
            ),
            ListTile(
              leading: const Icon(
                Icons.videocam_outlined,
                color: Color(0xFF78B9BE),
              ),
              title: const Text(
                'Add a video',
                style: TextStyle(color: Colors.white),
              ),
              onTap: () async {
                Navigator.pop(sheetContext);
                final video = await _imagePicker.pickVideo(
                  source: ImageSource.gallery,
                );
                if (!mounted || video == null) return;
                setState(() => _mediaFiles.add(video));
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _post() async {
    if (_titleController.text.trim().isEmpty ||
        _locationController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add a rental title and location first.')),
      );
      return;
    }
    if (_weeklyController.text.trim().isEmpty &&
        _monthlyController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Add weekly, monthly, or both pricing options.'),
        ),
      );
      return;
    }

    if (Supabase.instance.client.auth.currentUser == null) {
      await Navigator.push(
        context,
        FirstVuePageRoute(builder: (_) => const AuthScreen()),
      );
      if (Supabase.instance.client.auth.currentUser == null) return;
    }

    setState(() => _isPosting = true);
    try {
      await RentalsStore.postRental(
        title: _titleController.text.trim(),
        location: _locationController.text.trim(),
        description: _descriptionController.text.trim().isEmpty
            ? 'Rental details provided by the poster.'
            : _descriptionController.text.trim(),
        weeklyPrice: _weeklyController.text.trim(),
        monthlyPrice: _monthlyController.text.trim(),
        mediaFiles: _mediaFiles,
      );
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Rental submitted for approval.')),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Unable to post this rental. Please try again.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isPosting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF080B0F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF080B0F),
        surfaceTintColor: Colors.transparent,
        title: const Text('POST A RENTAL'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            'Create a rental listing for a booth, suite, or workspace. New listings require approval before other users can view them.',
            style: TextStyle(color: Colors.white54, height: 1.4),
          ),
          const SizedBox(height: 20),
          _RentalField(controller: _titleController, label: 'Rental title'),
          const SizedBox(height: 12),
          _RentalField(
            controller: _locationController,
            label: 'City, state, ZIP',
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _RentalField(
                  controller: _weeklyController,
                  label: 'Weekly price',
                  numeric: true,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _RentalField(
                  controller: _monthlyController,
                  label: 'Monthly price',
                  numeric: true,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _RentalField(
            controller: _descriptionController,
            label: 'Description',
            maxLines: 4,
          ),
          const SizedBox(height: 18),
          OutlinedButton.icon(
            onPressed: _selectMedia,
            icon: const Icon(Icons.perm_media_outlined),
            label: const Text('ADD PHOTO OR VIDEO'),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFFD8B56A),
              side: const BorderSide(color: Color(0xFFD8B56A)),
            ),
          ),
          if (_mediaFiles.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              '${_mediaFiles.length} media file(s) selected',
              style: const TextStyle(color: Color(0xFFD8B56A)),
            ),
            const SizedBox(height: 6),
            ..._mediaFiles.map(
              (file) => Text(
                file.name,
                style: const TextStyle(color: Colors.white54, fontSize: 12),
              ),
            ),
          ],
          const SizedBox(height: 10),
          const Text(
            'Media is stored privately and is visible to signed-in users only after this rental is approved.',
            style: TextStyle(color: Colors.white38, fontSize: 12, height: 1.4),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _isPosting ? null : _post,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFD8B56A),
              foregroundColor: Colors.black,
            ),
            child: Text(
              _isPosting ? 'POSTING...' : 'SUBMIT RENTAL FOR APPROVAL',
            ),
          ),
        ],
      ),
    );
  }
}

class _RentalField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final bool numeric;
  final int maxLines;

  const _RentalField({
    required this.controller,
    required this.label,
    this.numeric = false,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: numeric ? TextInputType.number : TextInputType.text,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white54),
        filled: true,
        fillColor: const Color(0xFF151B22),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color: const Color(0xFFD8B56A).withValues(alpha: .2),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFD8B56A)),
        ),
      ),
    );
  }
}

class MyRentalListingsScreen extends StatelessWidget {
  const MyRentalListingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF080B0F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF080B0F),
        surfaceTintColor: Colors.transparent,
        title: const Text('MY RENTAL LISTINGS'),
      ),
      body: StreamBuilder<List<RentalListing>>(
        stream: RentalsStore.watchMyListings(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(
              child: Text(
                'Unable to load your rentals.',
                style: TextStyle(color: Colors.white54),
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
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(28),
                child: Text(
                  'You have not posted a rental yet. New listings are reviewed before being visible to other users.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white54, height: 1.45),
                ),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(20),
            itemCount: listings.length + 1,
            separatorBuilder: (_, _) => const SizedBox(height: 14),
            itemBuilder: (context, index) {
              if (index == 0) {
                return const Text(
                  'Your rentals update live. Pending listings are visible only to you and FirstVue administrators.',
                  style: TextStyle(color: Colors.white54, height: 1.4),
                );
              }
              return _RentalCard(
                listing: listings[index - 1],
                showInquiry: false,
              );
            },
          );
        },
      ),
    );
  }
}

class _RentalCard extends StatelessWidget {
  final RentalListing listing;
  final bool showInquiry;

  const _RentalCard({required this.listing, this.showInquiry = true});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF10151B),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFFD8B56A).withValues(alpha: .16),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 108,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              gradient: const LinearGradient(
                colors: [Color(0xFF28221A), Color(0xFF151B22)],
              ),
            ),
            child: _RentalMediaPreview(media: listing.media),
          ),
          const SizedBox(height: 14),
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
          _RentalStatusBadge(status: listing.status),
          const SizedBox(height: 10),
          Text(
            listing.description,
            style: const TextStyle(color: Colors.white60, height: 1.35),
          ),
          const SizedBox(height: 13),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (listing.weeklyPrice != null)
                _PriceTag(text: listing.weeklyPrice!),
              if (listing.monthlyPrice != null)
                _PriceTag(text: listing.monthlyPrice!),
              if (listing.media.isNotEmpty)
                _PriceTag(text: '${listing.media.length} media item(s)'),
            ],
          ),
          if (showInquiry) ...[
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _showInquiry(context, listing),
                icon: const Icon(Icons.mail_outline),
                label: const Text('INQUIRE'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFD8B56A),
                  side: const BorderSide(color: Color(0xFFD8B56A)),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _showInquiry(BuildContext context, RentalListing listing) {
    final messageController = TextEditingController();
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF10151B),
      builder: (sheetContext) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'INQUIRE: ${listing.title}',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: messageController,
              style: const TextStyle(color: Colors.white),
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Message to the rental owner',
                labelStyle: TextStyle(color: Colors.white54),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () async {
                if (Supabase.instance.client.auth.currentUser == null) {
                  Navigator.pop(sheetContext);
                  await Navigator.push(
                    context,
                    FirstVuePageRoute(builder: (_) => const AuthScreen()),
                  );
                  if (!context.mounted) return;
                  if (Supabase.instance.client.auth.currentUser == null) return;
                  _showInquiry(context, listing);
                  return;
                }

                try {
                  await RentalsStore.sendInquiry(
                    rentalId: listing.id,
                    message: messageController.text.trim(),
                  );
                  if (!sheetContext.mounted) return;
                  Navigator.pop(sheetContext);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Inquiry sent to the rental owner.'),
                    ),
                  );
                } catch (_) {
                  if (sheetContext.mounted) {
                    ScaffoldMessenger.of(sheetContext).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Unable to send the inquiry. Please try again.',
                        ),
                      ),
                    );
                  }
                }
              },
              child: const Text('SEND INQUIRY'),
            ),
          ],
        ),
      ),
    ).whenComplete(messageController.dispose);
  }
}

class _RentalStatusBadge extends StatelessWidget {
  final String status;

  const _RentalStatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final normalized = status.toLowerCase();
    final color = switch (normalized) {
      'approved' => const Color(0xFFD8B56A),
      'rejected' => const Color(0xFFD68E98),
      'archived' => Colors.white54,
      _ => const Color(0xFFE5C16F),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: color.withValues(alpha: .38)),
      ),
      child: Text(
        normalized.toUpperCase(),
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.bold,
          letterSpacing: .8,
        ),
      ),
    );
  }
}

class _RentalMediaPreview extends StatelessWidget {
  final List<RentalMedia> media;

  const _RentalMediaPreview({required this.media});

  @override
  Widget build(BuildContext context) {
    if (media.isEmpty) {
      return const Center(
        child: Icon(Icons.image_outlined, color: Color(0xFFD8B56A), size: 42),
      );
    }

    final first = media.first;
    if (first.isVideo) {
      return const Center(
        child: Icon(
          Icons.play_circle_outline,
          color: Color(0xFFD8B56A),
          size: 42,
        ),
      );
    }

    return Image.network(
      first.signedUrl,
      width: double.infinity,
      height: double.infinity,
      fit: BoxFit.cover,
      errorBuilder: (_, _, _) => const Center(
        child: Icon(
          Icons.broken_image_outlined,
          color: Color(0xFFD8B56A),
          size: 42,
        ),
      ),
    );
  }
}

class _PriceTag extends StatelessWidget {
  final String text;

  const _PriceTag({required this.text});

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
