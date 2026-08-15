import '../models/explore_section.dart';
import '../services/community_news_service.dart';
import '../utils/new_label.dart';

enum ExploreItemKind { post, profile, entity }

class ExploreProfileCard {
  final String id;
  final String displayName;
  final String? handle;
  final String? avatarUrl;
  final String? locationLabel;
  final bool verified;
  final DateTime? createdAt;

  const ExploreProfileCard({
    required this.id,
    required this.displayName,
    this.handle,
    this.avatarUrl,
    this.locationLabel,
    this.verified = false,
    this.createdAt,
  });

  bool get isNew => NewLabel.isNew(createdAt);
}

class ExploreEntityCard {
  final String id;
  final String kind; // business, event, rental, community, group
  final String name;
  final String? handle;
  final String? imageUrl;
  final String? subtitle;
  final bool verified;
  final DateTime? createdAt;

  const ExploreEntityCard({
    required this.id,
    required this.kind,
    required this.name,
    this.handle,
    this.imageUrl,
    this.subtitle,
    this.verified = false,
    this.createdAt,
  });
}

/// One row in an Explore section. [id] is unique within that section.
class ExploreItem {
  final String id;
  final ExploreItemKind kind;
  final ExploreSection section;
  final DateTime? createdAt;
  final CommunityNewsPost? post;
  final ExploreProfileCard? profile;
  final ExploreEntityCard? entity;
  final String? originalAuthorName;
  final String? originalSourceLabel;

  const ExploreItem({
    required this.id,
    required this.kind,
    required this.section,
    this.createdAt,
    this.post,
    this.profile,
    this.entity,
    this.originalAuthorName,
    this.originalSourceLabel,
  });

  factory ExploreItem.postItem({
    required ExploreSection section,
    required CommunityNewsPost post,
    String? originalSourceLabel,
    bool communityShare = false,
  }) {
    return ExploreItem(
      id: 'post:${post.id}',
      kind: ExploreItemKind.post,
      section: section,
      createdAt: post.createdAt,
      post: post,
      originalAuthorName: post.displayAuthorName,
      originalSourceLabel: originalSourceLabel ??
          (communityShare ? post.communityName : post.originalSourceLabel),
    );
  }

  factory ExploreItem.profileItem({
    required ExploreProfileCard profile,
  }) {
    return ExploreItem(
      id: 'profile:${profile.id}',
      kind: ExploreItemKind.profile,
      section: ExploreSection.people,
      createdAt: profile.createdAt,
      profile: profile,
    );
  }

  factory ExploreItem.entityItem({
    required ExploreSection section,
    required ExploreEntityCard entity,
  }) {
    return ExploreItem(
      id: 'entity:${entity.kind}:${entity.id}',
      kind: ExploreItemKind.entity,
      section: section,
      createdAt: entity.createdAt,
      entity: entity,
    );
  }

  String get title {
    return profile?.displayName ??
        entity?.name ??
        post?.displayAuthorName ??
        '';
  }

  String? get handle {
    return profile?.handle ??
        entity?.handle ??
        post?.displayAuthorHandle ??
        (post == null ? null : '@${post!.authorName}');
  }

  String? get imageUrl {
    if (profile != null) return profile!.avatarUrl;
    if (entity != null) return entity!.imageUrl;
    final media = post?.media;
    if (media == null || media.isEmpty) return post?.communityImageUrl;
    final first = media.first;
    return first.isVideo ? null : first.signedUrl;
  }

  String? get videoUrl {
    final media = post?.media;
    if (media == null || media.isEmpty) return null;
    final first = media.first;
    return first.isVideo ? first.signedUrl : null;
  }

  bool get isVideo => videoUrl != null;
}

class ExplorePageResult {
  final List<ExploreItem> items;
  final bool hasMore;
  final DateTime? cursorCreatedAt;
  final String? cursorId;

  const ExplorePageResult({
    required this.items,
    this.hasMore = false,
    this.cursorCreatedAt,
    this.cursorId,
  });

  static const empty = ExplorePageResult(items: []);
}

class ExploreSectionSnapshot {
  final List<ExploreItem> items;
  final bool loading;
  final bool loadingMore;
  final bool hasMore;
  final String? error;
  final DateTime? cursorCreatedAt;
  final String? cursorId;
  final Set<String> seenIds;

  const ExploreSectionSnapshot({
    this.items = const [],
    this.loading = false,
    this.loadingMore = false,
    this.hasMore = true,
    this.error,
    this.cursorCreatedAt,
    this.cursorId,
    this.seenIds = const {},
  });

  ExploreSectionSnapshot copyWith({
    List<ExploreItem>? items,
    bool? loading,
    bool? loadingMore,
    bool? hasMore,
    String? error,
    bool clearError = false,
    DateTime? cursorCreatedAt,
    String? cursorId,
    Set<String>? seenIds,
  }) {
    return ExploreSectionSnapshot(
      items: items ?? this.items,
      loading: loading ?? this.loading,
      loadingMore: loadingMore ?? this.loadingMore,
      hasMore: hasMore ?? this.hasMore,
      error: clearError ? null : (error ?? this.error),
      cursorCreatedAt: cursorCreatedAt ?? this.cursorCreatedAt,
      cursorId: cursorId ?? this.cursorId,
      seenIds: seenIds ?? this.seenIds,
    );
  }
}

typedef ExplorePageFetcher =
    Future<ExplorePageResult> Function({
      required ExploreSection section,
      DateTime? beforeCreatedAt,
      String? beforeId,
    });

/// Independent loading / pagination / cache per Explore section.
class ExploreSectionStore {
  ExploreSectionStore({this.pageSize = 24});

  final int pageSize;
  final Map<ExploreSection, ExploreSectionSnapshot> _pages = {
    for (final section in ExploreSectionX.visible)
      section: const ExploreSectionSnapshot(),
  };

  ExploreSectionSnapshot of(ExploreSection section) =>
      _pages[section] ?? const ExploreSectionSnapshot();

  void seed(ExploreSection section, ExploreSectionSnapshot snapshot) {
    _pages[section] = snapshot;
  }

  Future<void> load(
    ExploreSection section,
    ExplorePageFetcher fetcher, {
    bool refresh = false,
  }) async {
    final current = of(section);
    if (current.loading) return;
    if (!refresh && current.items.isNotEmpty && current.error == null) {
      return;
    }
    _pages[section] = current.copyWith(
      loading: true,
      clearError: true,
      hasMore: true,
    );
    try {
      final page = await fetcher(
        section: section,
        beforeCreatedAt: null,
        beforeId: null,
      );
      final seen = <String>{};
      final items = <ExploreItem>[];
      for (final item in page.items) {
        if (seen.add(item.id)) items.add(item);
      }
      _pages[section] = ExploreSectionSnapshot(
        items: items,
        loading: false,
        hasMore: page.hasMore,
        cursorCreatedAt: page.cursorCreatedAt,
        cursorId: page.cursorId,
        seenIds: seen,
      );
    } catch (error, stack) {
      assert(() {
        // ignore: avoid_print
        print('ExploreSectionStore.load($section) failed: $error\n$stack');
        return true;
      }());
      _pages[section] = of(section).copyWith(
        loading: false,
        error: 'Unable to load this section right now.',
        // Keep whatever was on screen — a failed refresh must not blank Explore.
        items: current.items,
      );
    }
  }

  Future<void> loadMore(
    ExploreSection section,
    ExplorePageFetcher fetcher,
  ) async {
    final current = of(section);
    if (current.loading || current.loadingMore || !current.hasMore) return;
    _pages[section] = current.copyWith(loadingMore: true, clearError: true);
    try {
      final page = await fetcher(
        section: section,
        beforeCreatedAt: current.cursorCreatedAt,
        beforeId: current.cursorId,
      );
      final seen = {...current.seenIds};
      final fresh = <ExploreItem>[];
      for (final item in page.items) {
        if (seen.add(item.id)) fresh.add(item);
      }
      final merged = [...current.items, ...fresh];
      _pages[section] = ExploreSectionSnapshot(
        items: merged,
        loading: false,
        loadingMore: false,
        hasMore: page.hasMore,
        cursorCreatedAt: page.cursorCreatedAt ?? current.cursorCreatedAt,
        cursorId: page.cursorId ?? current.cursorId,
        seenIds: seen,
      );
    } catch (_) {
      // Stop near-bottom retry loops; user can pull-to-refresh or change tabs.
      _pages[section] = of(section).copyWith(
        loadingMore: false,
        hasMore: false,
        error: 'Could not load more. Pull to refresh to retry.',
      );
    }
  }
}
