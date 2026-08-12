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
}
