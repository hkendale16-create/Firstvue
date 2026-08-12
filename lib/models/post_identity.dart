enum PostIdentityKind { personal, business, community }

class PostIdentityOption {
  final PostIdentityKind kind;
  final String? businessId;
  final String? communityId;
  final String label;
  final String? subtitle;

  const PostIdentityOption({
    required this.kind,
    this.businessId,
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
  bool get isBusiness => kind == PostIdentityKind.business;
  bool get isCommunity => kind == PostIdentityKind.community;

  String get storageKey {
    switch (kind) {
      case PostIdentityKind.personal:
        return 'personal';
      case PostIdentityKind.business:
        return 'business:${businessId ?? ''}';
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

/// Where a post is published (main feed vs a community group).
class PostDestinationOption {
  final String? communityId;
  final String label;
  final String? subtitle;

  const PostDestinationOption({
    this.communityId,
    required this.label,
    this.subtitle,
  });

  const PostDestinationOption.mainFeed()
      : communityId = null,
        label = 'News Feed',
        subtitle = 'Everyone';

  bool get isMainFeed => communityId == null || communityId!.isEmpty;

  String get storageKey =>
      isMainFeed ? 'feed' : 'community:${communityId ?? ''}';

  static PostDestinationOption? matchStoredKey(
    List<PostDestinationOption> options,
    String? key,
  ) {
    if (key == null || key.isEmpty) return null;
    for (final option in options) {
      if (option.storageKey == key) return option;
    }
    return null;
  }
}
