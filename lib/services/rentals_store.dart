import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/media_config.dart';
import 'admin_auth_service.dart';
import 'activity_notifications_service.dart';
import 'media_storage_service.dart';

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
  final String ownerId;
  final String title;
  final String location;
  final String description;
  final String? weeklyPrice;
  final String? monthlyPrice;
  final String status;
  final List<RentalMedia> media;

  const RentalListing({
    required this.id,
    required this.ownerId,
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
      ownerId: (map['owner_id'] as String?) ?? '',
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

  RentalListing copyWith({List<RentalMedia>? media, String? ownerId}) {
    return RentalListing(
      id: id,
      ownerId: ownerId ?? this.ownerId,
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
        .asyncMap(_attachMediaSafely);
  }

  static Future<List<RentalListing>> fetchPendingListings() async {
    final rows = await _client
        .from('rentals')
        .select()
        .eq('status', 'pending')
        .order('created_at', ascending: false);
    return _attachMediaSafely(
      rows.map(RentalListing.fromMap).toList(),
    );
  }

  static Future<bool> isCurrentUserAdmin() => AdminAuthService.isAdmin();

  static Future<void> setRentalStatus({
    required String rentalId,
    required String status,
  }) async {
    if (!const {'approved', 'rejected', 'archived'}.contains(status)) {
      throw ArgumentError.value(status, 'status', 'Unsupported rental status');
    }
    if (!await AdminAuthService.isAdmin()) {
      throw const AuthException('Administrator access is required.');
    }

    final updated = await _client
        .from('rentals')
        .update({
          'status': status,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', rentalId)
        .select('id')
        .maybeSingle();
    if (updated == null) {
      throw const PostgrestException(
        message:
            'Rental status was not updated. Confirm admin access and Supabase rental policies.',
      );
    }
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
      final provider = MediaStorageProvider.parse(
        data['storage_provider'] as String?,
      );
      final rentalId = data['rental_id'] as String;
      final signedUrl = await MediaStorageService.createReadUrl(
        bucket: MediaBucket.rental,
        path: path,
        provider: provider,
        context: {'rental_id': rentalId},
      );
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

  static Future<List<RentalListing>> _attachMediaSafely(
    List<RentalListing> listings,
  ) async {
    try {
      return await _attachMedia(listings);
    } catch (_) {
      return listings;
    }
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
    final uploadedObjects = <MediaUploadResult>[];
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
        final upload = await MediaStorageService.uploadBytes(
          bucket: MediaBucket.rental,
          bytes: bytes,
          contentType: _mimeTypeFor(file, mediaType),
          fileName: file.name,
          index: index,
          context: {'rental_id': rentalId},
        );
        uploadedObjects.add(upload);
        await _client.from('rental_media').insert({
          'rental_id': rentalId,
          'storage_path': upload.path,
          'storage_provider': upload.provider.value,
          'media_type': mediaType,
          'sort_order': index,
        });
      }
    } catch (_) {
      for (final upload in uploadedObjects) {
        await MediaStorageService.deleteObject(
          bucket: MediaBucket.rental,
          path: upload.path,
          provider: upload.provider,
          context: {'rental_id': rentalId},
        );
      }
      await _client.from('rentals').delete().eq('id', rentalId);
      rethrow;
    }
  }

  static Future<String?> sendInquiry({
    required String rentalId,
    required String message,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw const AuthException('Sign in before sending an inquiry.');
    }

    final rental = await _client
        .from('rentals')
        .select('id, title, owner_id')
        .eq('id', rentalId)
        .maybeSingle();

    await _client.from('rental_inquiries').insert({
      'rental_id': rentalId,
      'requester_id': user.id,
      'message': message,
    });

    final ownerId = rental?['owner_id'] as String?;
    if (ownerId != null && ownerId != user.id) {
      final rentalTitle = rental?['title'] as String? ?? 'your rental';
      await ActivityNotificationsService.notifyUser(
        userId: ownerId,
        type: 'rental_inquiry',
        title: 'Inquiry on $rentalTitle',
        body: message,
        payload: {
          'rental_id': rentalId,
          'requester_id': user.id,
        },
      );
    }

    return ownerId;
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
