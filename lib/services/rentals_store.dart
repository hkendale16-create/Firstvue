import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class RentalMedia {
  final String mediaType;
  final String signedUrl;

  const RentalMedia({required this.mediaType, required this.signedUrl});

  bool get isVideo => mediaType == 'video';
}

class RentalInquiry {
  final String id;
  final String rentalTitle;
  final String message;
  final String status;

  const RentalInquiry({
    required this.id,
    required this.rentalTitle,
    required this.message,
    required this.status,
  });
}

class RentalListing {
  final String id;
  final String title;
  final String location;
  final String description;
  final String? weeklyPrice;
  final String? monthlyPrice;
  final String status;
  final List<RentalMedia> media;

  const RentalListing({
    required this.id,
    required this.title,
    required this.location,
    required this.description,
    required this.weeklyPrice,
    required this.monthlyPrice,
    required this.status,
    this.media = const [],
  });

  factory RentalListing.fromMap(Map<String, dynamic> map) {
    final locationParts = [
      map['city'] as String?,
      map['state'] as String?,
      map['postal_code'] as String?,
    ].whereType<String>().where((part) => part.isNotEmpty);

    return RentalListing(
      id: map['id'] as String,
      title: map['title'] as String,
      location: locationParts.join(', '),
      description:
          (map['description'] as String?) ??
          'Rental details provided by the poster.',
      weeklyPrice: _formatPrice(map['weekly_price_cents'] as int?, 'week'),
      monthlyPrice: _formatPrice(map['monthly_price_cents'] as int?, 'month'),
      status: map['status'] as String,
    );
  }

  RentalListing copyWith({List<RentalMedia>? media}) {
    return RentalListing(
      id: id,
      title: title,
      location: location,
      description: description,
      weeklyPrice: weeklyPrice,
      monthlyPrice: monthlyPrice,
      status: status,
      media: media ?? this.media,
    );
  }

  static String? _formatPrice(int? cents, String period) {
    if (cents == null) return null;
    final amount = cents / 100;
    final formatted = amount == amount.roundToDouble()
        ? amount.toStringAsFixed(0)
        : amount.toStringAsFixed(2);
    return '\$$formatted / $period';
  }
}

class RentalsStore {
  RentalsStore._();

  static const _bucket = 'rental-media';
  static const _maxMediaBytes = 50 * 1024 * 1024;
  static final _client = Supabase.instance.client;

  static Stream<List<RentalListing>> watchListings() {
    return _client
        .from('rentals')
        .stream(primaryKey: ['id'])
        .order('created_at', ascending: false)
        .map((rows) => rows.map(RentalListing.fromMap).toList())
        .asyncMap(_attachMedia);
  }

  static Stream<List<RentalListing>> watchMyListings() {
    final user = _client.auth.currentUser;
    if (user == null) return Stream.value(const []);

    return _client
        .from('rentals')
        .stream(primaryKey: ['id'])
        .eq('owner_id', user.id)
        .order('created_at', ascending: false)
        .map((rows) => rows.map(RentalListing.fromMap).toList())
        .asyncMap(_attachMedia);
  }

  static Stream<List<RentalListing>> watchPendingListings() {
    return _client
        .from('rentals')
        .stream(primaryKey: ['id'])
        .eq('status', 'pending')
        .order('created_at', ascending: false)
        .map((rows) => rows.map(RentalListing.fromMap).toList())
        .asyncMap(_attachMedia);
  }

  static Future<bool> isCurrentUserAdmin() async {
    final user = _client.auth.currentUser;
    if (user == null) return false;
    final profile = await _client
        .from('profiles')
        .select('account_type')
        .eq('id', user.id)
        .maybeSingle();
    return profile?['account_type'] == 'admin';
  }

  static Future<void> setRentalStatus({
    required String rentalId,
    required String status,
  }) async {
    if (!const {'approved', 'rejected', 'archived'}.contains(status)) {
      throw ArgumentError.value(status, 'status', 'Unsupported rental status');
    }
    await _client.from('rentals').update({'status': status}).eq('id', rentalId);
  }

  static Future<List<RentalInquiry>> fetchOwnerInquiries() async {
    final user = _client.auth.currentUser;
    if (user == null) return const [];
    final rentals = await _client
        .from('rentals')
        .select('id, title')
        .eq('owner_id', user.id);
    if (rentals.isEmpty) return const [];

    final rentalTitles = <String, String>{
      for (final rental in rentals)
        rental['id'] as String: rental['title'] as String,
    };
    final inquiries = await _client
        .from('rental_inquiries')
        .select('id, rental_id, message, status')
        .inFilter('rental_id', rentalTitles.keys.toList())
        .order('created_at', ascending: false);

    return inquiries
        .map(
          (inquiry) => RentalInquiry(
            id: inquiry['id'] as String,
            rentalTitle:
                rentalTitles[inquiry['rental_id'] as String] ??
                'Rental listing',
            message: (inquiry['message'] as String?) ?? 'No message provided.',
            status: inquiry['status'] as String,
          ),
        )
        .toList();
  }

  static Future<void> markInquiryRead(String inquiryId) async {
    await _client
        .from('rental_inquiries')
        .update({'status': 'read'})
        .eq('id', inquiryId);
  }

  static Future<List<RentalListing>> _attachMedia(
    List<RentalListing> listings,
  ) async {
    if (listings.isEmpty) return listings;
    final ids = listings.map((listing) => listing.id).toList();
    final rows = await _client
        .from('rental_media')
        .select()
        .inFilter('rental_id', ids)
        .order('sort_order');
    final mediaByRental = <String, List<RentalMedia>>{};

    for (final row in rows) {
      final data = row;
      final path = data['storage_path'] as String;
      final signedUrl = await _client.storage
          .from(_bucket)
          .createSignedUrl(path, 3600);
      final rentalId = data['rental_id'] as String;
      mediaByRental
          .putIfAbsent(rentalId, () => [])
          .add(
            RentalMedia(
              mediaType: data['media_type'] as String,
              signedUrl: signedUrl,
            ),
          );
    }

    return listings
        .map(
          (listing) =>
              listing.copyWith(media: mediaByRental[listing.id] ?? const []),
        )
        .toList();
  }

  static Future<void> recordAccessConsent() async {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw const AuthException('Sign in to view rental opportunities.');
    }

    await _client.from('rental_access_consents').upsert({
      'profile_id': user.id,
      'agreement_version': '2026-08-10',
      'accepted_at': DateTime.now().toUtc().toIso8601String(),
    });
  }

  static Future<void> postRental({
    required String title,
    required String location,
    required String description,
    required String? weeklyPrice,
    required String? monthlyPrice,
    required List<XFile> mediaFiles,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw const AuthException('Sign in before posting a rental.');
    }

    final place = _parseLocation(location);
    final rental = await _client
        .from('rentals')
        .insert({
          'owner_id': user.id,
          'title': title,
          'description': description,
          'city': place.city,
          'state': place.state,
          'postal_code': place.postalCode,
          'weekly_price_cents': _priceToCents(weeklyPrice),
          'monthly_price_cents': _priceToCents(monthlyPrice),
        })
        .select('id')
        .single();

    final rentalId = rental['id'] as String;
    final uploadedPaths = <String>[];
    try {
      for (var index = 0; index < mediaFiles.length; index++) {
        final file = mediaFiles[index];
        final bytes = await file.readAsBytes();
        if (bytes.length > _maxMediaBytes) {
          throw const StorageException(
            'Each photo or video must be 50 MB or smaller.',
          );
        }

        final mediaType = _mediaTypeFor(file);
        final path =
            '${user.id}/${DateTime.now().microsecondsSinceEpoch}_${index}_${_safeFileName(file.name)}';
        await _client.storage
            .from(_bucket)
            .uploadBinary(
              path,
              bytes,
              fileOptions: FileOptions(
                contentType: _mimeTypeFor(file, mediaType),
                upsert: false,
              ),
            );
        uploadedPaths.add(path);
        await _client.from('rental_media').insert({
          'rental_id': rentalId,
          'storage_path': path,
          'media_type': mediaType,
          'sort_order': index,
        });
      }
    } catch (_) {
      for (final path in uploadedPaths) {
        await _client.storage.from(_bucket).remove([path]);
      }
      await _client.from('rentals').delete().eq('id', rentalId);
      rethrow;
    }
  }

  static Future<void> sendInquiry({
    required String rentalId,
    required String message,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw const AuthException('Sign in before sending an inquiry.');
    }

    await _client.from('rental_inquiries').insert({
      'rental_id': rentalId,
      'requester_id': user.id,
      'message': message,
    });
  }

  static String _mediaTypeFor(XFile file) {
    final mimeType = file.mimeType?.toLowerCase() ?? '';
    if (mimeType.startsWith('video/')) return 'video';
    if (mimeType.startsWith('image/')) return 'image';
    final extension = file.name.split('.').last.toLowerCase();
    return ['mp4', 'mov'].contains(extension) ? 'video' : 'image';
  }

  static String _mimeTypeFor(XFile file, String mediaType) {
    if (file.mimeType != null && file.mimeType!.isNotEmpty) {
      return file.mimeType!;
    }
    final extension = file.name.split('.').last.toLowerCase();
    return switch (extension) {
      'png' => 'image/png',
      'webp' => 'image/webp',
      'mp4' => 'video/mp4',
      'mov' => 'video/quicktime',
      _ => mediaType == 'video' ? 'video/mp4' : 'image/jpeg',
    };
  }

  static String _safeFileName(String name) =>
      name.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');

  static int? _priceToCents(String? price) {
    if (price == null || price.trim().isEmpty) return null;
    final amount = double.tryParse(price.trim());
    return amount == null ? null : (amount * 100).round();
  }

  static _RentalPlace _parseLocation(String value) {
    final parts = value
        .split(',')
        .map((part) => part.trim())
        .where((part) => part.isNotEmpty)
        .toList();
    final city = parts.isEmpty ? null : parts.first;
    final stateAndZip = parts.length > 1
        ? parts[1].split(RegExp(r'\s+'))
        : const <String>[];
    return _RentalPlace(
      city: city,
      state: stateAndZip.isEmpty ? null : stateAndZip.first.toUpperCase(),
      postalCode: stateAndZip.length > 1 ? stateAndZip.last : null,
    );
  }
}

class _RentalPlace {
  final String? city;
  final String? state;
  final String? postalCode;

  const _RentalPlace({this.city, this.state, this.postalCode});
}
