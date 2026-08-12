/// Entity-specific profile completion scoring from existing fields only.
class ProfileCompletionResult {
  final double ratio;
  final List<String> missingLabels;
  final int filledCount;
  final int totalCount;

  const ProfileCompletionResult({
    required this.ratio,
    required this.missingLabels,
    required this.filledCount,
    required this.totalCount,
  });

  int get percent => (ratio * 100).round().clamp(0, 100);

  String? get nextMissing =>
      missingLabels.isEmpty ? null : missingLabels.first;

  bool get isComplete => missingLabels.isEmpty && totalCount > 0;
}

enum ProfileEntityType {
  user,
  business,
  professional,
  rental,
  group,
  community,
}

class ProfileCompletionService {
  ProfileCompletionService._();

  static ProfileCompletionResult score({
    required ProfileEntityType type,
    required Map<String, dynamic> fields,
  }) {
    final checklist = switch (type) {
      ProfileEntityType.user => _userChecks(fields),
      ProfileEntityType.business => _businessChecks(fields),
      ProfileEntityType.professional => _professionalChecks(fields),
      ProfileEntityType.rental => _rentalChecks(fields),
      ProfileEntityType.group => _groupChecks(fields),
      ProfileEntityType.community => _communityChecks(fields),
    };

    final filled = checklist.where((c) => c.filled).length;
    final total = checklist.length;
    final missing =
        checklist.where((c) => !c.filled).map((c) => c.label).toList();
    final ratio = total == 0 ? 0.0 : filled / total;

    return ProfileCompletionResult(
      ratio: ratio,
      missingLabels: missing,
      filledCount: filled,
      totalCount: total,
    );
  }

  static List<_Check> _userChecks(Map<String, dynamic> fields) {
    return [
      _Check('Display name', _hasText(fields['display_name'] ?? fields['displayName'])),
      _Check('Username', _hasText(fields['username'])),
      _Check('Bio', _hasText(fields['bio'])),
      _Check('City', _hasText(fields['city'])),
      _Check('Website', _hasText(fields['website'])),
      if (fields.containsKey('phone') || fields.containsKey('Phone'))
        _Check('Phone', _hasText(fields['phone'])),
      if (fields.containsKey('birthday'))
        _Check('Birthday', _hasValue(fields['birthday'])),
      if (fields.containsKey('avatar_url') ||
          fields.containsKey('avatarUrl') ||
          fields.containsKey('has_avatar'))
        _Check(
          'Profile photo',
          _hasText(fields['avatar_url'] ?? fields['avatarUrl']) ||
              fields['has_avatar'] == true,
        ),
    ];
  }

  static List<_Check> _businessChecks(Map<String, dynamic> fields) {
    return [
      _Check('Business name', _hasText(fields['name'] ?? fields['display_name'])),
      _Check('Description', _hasText(fields['description'] ?? fields['bio'])),
      _Check(
        'Services',
        _hasList(fields['services']) || _hasText(fields['services']),
      ),
      _Check('City', _hasText(fields['city'])),
      _Check('State', _hasText(fields['state'])),
      if (fields.containsKey('phone'))
        _Check('Phone', _hasText(fields['phone'])),
      if (fields.containsKey('website'))
        _Check('Website', _hasText(fields['website'])),
      if (fields.containsKey('address') || fields.containsKey('address_line_1'))
        _Check(
          'Address',
          _hasText(fields['address'] ?? fields['address_line_1']),
        ),
    ];
  }

  static List<_Check> _professionalChecks(Map<String, dynamic> fields) {
    return [
      _Check(
        'Display name',
        _hasText(fields['display_name'] ?? fields['displayName']),
      ),
      _Check('Bio', _hasText(fields['bio'])),
      _Check('City', _hasText(fields['city'])),
      _Check('State', _hasText(fields['state'])),
      _Check(
        'Services',
        _hasList(fields['services']) || _hasText(fields['services']),
      ),
      if (fields.containsKey('booking_url') || fields.containsKey('bookingUrl'))
        _Check(
          'Booking link',
          _hasText(fields['booking_url'] ?? fields['bookingUrl']),
        ),
      if (fields.containsKey('specialty') || fields.containsKey('title'))
        _Check(
          'Specialty',
          _hasText(fields['specialty'] ?? fields['title']),
        ),
    ];
  }

  static List<_Check> _rentalChecks(Map<String, dynamic> fields) {
    return [
      _Check('Title', _hasText(fields['title'] ?? fields['name'])),
      _Check('Description', _hasText(fields['description'])),
      _Check(
        'Location',
        _hasText(fields['location']) ||
            _hasText(fields['city']) ||
            (_hasText(fields['city']) && _hasText(fields['state'])),
      ),
      _Check(
        'Price',
        _hasValue(fields['weekly_price_cents']) ||
            _hasValue(fields['monthly_price_cents']) ||
            _hasText(fields['weeklyPrice']) ||
            _hasText(fields['monthlyPrice']),
      ),
      if (fields.containsKey('property_type'))
        _Check('Property type', _hasText(fields['property_type'])),
      if (fields.containsKey('media') || fields.containsKey('has_media'))
        _Check(
          'Photos',
          _hasList(fields['media']) || fields['has_media'] == true,
        ),
    ];
  }

  static List<_Check> _groupChecks(Map<String, dynamic> fields) {
    return [
      _Check('Name', _hasText(fields['name'])),
      _Check('Description', _hasText(fields['description'])),
      _Check('Category', _hasText(fields['category'])),
      _Check('City', _hasText(fields['city'])),
      if (fields.containsKey('image_url') ||
          fields.containsKey('imageUrl') ||
          fields.containsKey('image_storage_path') ||
          fields.containsKey('has_image'))
        _Check(
          'Group photo',
          _hasText(
                fields['image_url'] ??
                    fields['imageUrl'] ??
                    fields['image_storage_path'],
              ) ||
              fields['has_image'] == true,
        ),
      if (fields.containsKey('rules'))
        _Check('Rules', _hasText(fields['rules'])),
    ];
  }

  static List<_Check> _communityChecks(Map<String, dynamic> fields) {
    return [
      _Check('Name', _hasText(fields['name'])),
      _Check('Description', _hasText(fields['description'])),
      _Check('Category', _hasText(fields['category'])),
      _Check('City', _hasText(fields['city'])),
      if (fields.containsKey('image_url') ||
          fields.containsKey('imageUrl') ||
          fields.containsKey('image_storage_path') ||
          fields.containsKey('has_image'))
        _Check(
          'Community photo',
          _hasText(
                fields['image_url'] ??
                    fields['imageUrl'] ??
                    fields['image_storage_path'],
              ) ||
              fields['has_image'] == true,
        ),
      if (fields.containsKey('rules'))
        _Check('Rules', _hasText(fields['rules'])),
    ];
  }

  static bool _hasText(dynamic value) {
    if (value == null) return false;
    if (value is List || value is Map) return false;
    return value.toString().trim().isNotEmpty;
  }

  static bool _hasValue(dynamic value) {
    if (value == null) return false;
    if (value is String) return value.trim().isNotEmpty;
    if (value is List) return value.isNotEmpty;
    if (value is Map) return value.isNotEmpty;
    return true;
  }

  static bool _hasList(dynamic value) {
    if (value is! List) return false;
    return value.any((item) => item != null && _hasText(item));
  }
}

class _Check {
  final String label;
  final bool filled;

  const _Check(this.label, this.filled);
}
