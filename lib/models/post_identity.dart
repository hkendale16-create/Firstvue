enum PostIdentityKind { personal, business, professional, community }

class PostIdentityOption {
  final PostIdentityKind kind;
  final String? businessId;
  final String? professionalProfileId;
  final String? communityId;
  final String label;
  final String? subtitle;

  const PostIdentityOption({
    required this.kind,
    this.businessId,
    this.professionalProfileId,
    this.communityId,
    required this.label,
    this.subtitle,
  });

  const PostIdentityOption.personal({
    required String displayName,
  }) : this(
          kind: PostIdentityKind.personal,
          label: displayName,
          subtitle: 'Personal',
        );

  bool get isPersonal => kind == PostIdentityKind.personal;

  String get storageKey {
    switch (kind) {
      case PostIdentityKind.personal:
        return 'personal';
      case PostIdentityKind.business:
        return 'business:${businessId ?? ''}';
      case PostIdentityKind.professional:
        return 'professional:${professionalProfileId ?? ''}';
      case PostIdentityKind.community:
        return 'community:${communityId ?? ''}';
    }
  }

  static PostIdentityOption? matchStoredKey(
    List<PostIdentityOption> options,
    String? key,
  ) {
    if (key == null || key.isEmpty) return null;
    for (final option in options) {
      if (option.storageKey == key) return option;
    }
    return null;
  }
}
