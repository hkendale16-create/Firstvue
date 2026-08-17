import '../models/growth_prompt.dart';

/// Context-aware copy for the reusable growth prompt system.
class GrowthPromptCatalog {
  GrowthPromptCatalog._();

  static const homeTypes = <GrowthPromptType>[
    GrowthPromptType.createPost,
    GrowthPromptType.uploadPhoto,
    GrowthPromptType.createStory,
    GrowthPromptType.exploreEvents,
    GrowthPromptType.inviteFriends,
  ];

  static const vueTypes = <GrowthPromptType>[
    GrowthPromptType.uploadVideo,
    GrowthPromptType.uploadPhoto,
    GrowthPromptType.createPost,
  ];

  static const exploreTypes = <GrowthPromptType>[
    GrowthPromptType.exploreEvents,
    GrowthPromptType.discoverNearby,
    GrowthPromptType.followPeople,
    GrowthPromptType.createPost,
    GrowthPromptType.joinCommunity,
  ];

  static const eventsTypes = <GrowthPromptType>[
    GrowthPromptType.exploreEvents,
    GrowthPromptType.discoverNearby,
    GrowthPromptType.inviteFriends,
  ];

  static const profileTypes = <GrowthPromptType>[
    GrowthPromptType.uploadPhoto,
    GrowthPromptType.createPost,
    GrowthPromptType.inviteFriends,
  ];

  static const newUserProgression = <GrowthPromptType>[
    GrowthPromptType.followPeople,
    GrowthPromptType.discoverNearby,
    GrowthPromptType.createPost,
    GrowthPromptType.uploadPhoto,
    GrowthPromptType.exploreEvents,
    GrowthPromptType.inviteFriends,
  ];

  static const returningSessionTypes = <GrowthPromptType>[
    GrowthPromptType.exploreEvents,
    GrowthPromptType.createPost,
    GrowthPromptType.discoverNearby,
    GrowthPromptType.inviteFriends,
  ];

  static List<GrowthPromptType> typesFor(GrowthPromptContext context) {
    return switch (context) {
      GrowthPromptContext.home => homeTypes,
      GrowthPromptContext.vue => vueTypes,
      GrowthPromptContext.explore => exploreTypes,
      GrowthPromptContext.events => eventsTypes,
      GrowthPromptContext.profile => profileTypes,
      GrowthPromptContext.session => returningSessionTypes,
    };
  }

  static GrowthCompletedAction? completedActionFor(GrowthPromptType type) {
    return switch (type) {
      GrowthPromptType.createPost => GrowthCompletedAction.createPost,
      GrowthPromptType.uploadPhoto ||
      GrowthPromptType.uploadVideo => GrowthCompletedAction.uploadMedia,
      GrowthPromptType.createStory => GrowthCompletedAction.createStory,
      GrowthPromptType.followPeople => GrowthCompletedAction.followPeople,
      GrowthPromptType.joinCommunity => GrowthCompletedAction.joinCommunity,
      GrowthPromptType.inviteFriends ||
      GrowthPromptType.shareApp => GrowthCompletedAction.inviteFriends,
      GrowthPromptType.exploreEvents ||
      GrowthPromptType.discoverNearby => null,
    };
  }

  static GrowthPromptSpec specFor(
    GrowthPromptType type, {
    required GrowthPromptContext context,
    String? city,
    bool returningUser = false,
  }) {
    final metro = _metroLabel(city);
    return switch (type) {
      GrowthPromptType.createPost => GrowthPromptSpec(
          type: type,
          context: context,
          title: returningUser
              ? 'Anything happening around you?'
              : "What's happening today?",
          description: returningUser
              ? 'Share it on FirstVue.'
              : 'Share a photo, video, or update with FirstVue.',
          actionLabel: 'Create Post',
        ),
      GrowthPromptType.uploadPhoto => GrowthPromptSpec(
          type: type,
          context: context,
          title: context == GrowthPromptContext.profile
              ? 'Add your first photo'
              : 'Show everyone what’s going on 📸',
          description: context == GrowthPromptContext.profile
              ? 'Introduce yourself with a photo people can discover.'
              : 'Upload a photo or video.',
          actionLabel: context == GrowthPromptContext.profile
              ? 'Add Photo'
              : 'Upload',
        ),
      GrowthPromptType.uploadVideo => GrowthPromptSpec(
          type: type,
          context: context,
          title: context == GrowthPromptContext.vue
              ? 'Your VUE is just getting started.'
              : 'Share something worth discovering',
          description: context == GrowthPromptContext.vue
              ? 'Upload a photo or video and help people discover what’s happening.'
              : 'Upload a video.',
          actionLabel: 'Upload',
        ),
      GrowthPromptType.createStory => const GrowthPromptSpec(
          type: GrowthPromptType.createStory,
          context: GrowthPromptContext.home,
          title: 'Going somewhere?',
          description: 'Share it with your followers.',
          actionLabel: 'Post Story',
        ),
      GrowthPromptType.exploreEvents => GrowthPromptSpec(
          type: type,
          context: context,
          title: returningUser
              ? 'Welcome back.'
              : metro == null
                  ? 'What’s happening near you?'
                  : 'Discover $metro',
          description: returningUser
              ? 'See what’s happening today.'
              : metro == null
                  ? 'Explore events and things happening around your area.'
                  : 'Explore tonight’s events and things to do in $metro.',
          actionLabel: 'Explore Events',
          secondaryActionLabel:
              context == GrowthPromptContext.events ||
                      context == GrowthPromptContext.explore
                  ? 'Create Event'
                  : null,
        ),
      GrowthPromptType.discoverNearby => GrowthPromptSpec(
          type: type,
          context: context,
          title: metro == null
              ? 'See what’s happening right now'
              : 'See what’s happening in $metro',
          description: 'Find something to do nearby.',
          actionLabel: 'Explore',
        ),
      GrowthPromptType.followPeople => const GrowthPromptSpec(
          type: GrowthPromptType.followPeople,
          context: GrowthPromptContext.explore,
          title: 'Follow people and businesses',
          description: 'See what’s happening with people you care about.',
          actionLabel: 'Find People',
        ),
      GrowthPromptType.joinCommunity => const GrowthPromptSpec(
          type: GrowthPromptType.joinCommunity,
          context: GrowthPromptContext.explore,
          title: 'Join a community',
          description: 'Participate in groups and communities near you.',
          actionLabel: 'Browse Communities',
        ),
      GrowthPromptType.inviteFriends ||
      GrowthPromptType.shareApp => const GrowthPromptSpec(
          type: GrowthPromptType.inviteFriends,
          context: GrowthPromptContext.session,
          title: 'Invite your friends',
          description:
              'FirstVue is better when the people you know are discovering what’s happening too.',
          actionLabel: 'Invite Friends',
        ),
    };
  }

  static GrowthPromptSpec emptyHome() {
    return const GrowthPromptSpec(
      type: GrowthPromptType.createPost,
      context: GrowthPromptContext.home,
      title: 'Nothing here yet.',
      description: "Be the first to share what's happening.",
      actionLabel: 'Create Post',
    );
  }

  static GrowthPromptSpec emptyVue() {
    return const GrowthPromptSpec(
      type: GrowthPromptType.uploadVideo,
      context: GrowthPromptContext.vue,
      title: 'Your VUE is just getting started.',
      description:
          'Upload a photo or video and help people discover what’s happening.',
      actionLabel: 'Upload',
    );
  }

  static GrowthPromptSpec emptyEvents({String? city}) {
    final metro = _metroLabel(city);
    return GrowthPromptSpec(
      type: GrowthPromptType.exploreEvents,
      context: GrowthPromptContext.events,
      title: 'No nearby events found.',
      description: metro == null
          ? 'Explore another area or create an event.'
          : 'Nothing listed in $metro yet. Explore another area or create an event.',
      actionLabel: 'Explore',
      secondaryActionLabel: 'Create Event',
      secondaryType: GrowthPromptType.exploreEvents,
    );
  }

  static GrowthPromptSpec emptyProfilePosts() {
    return const GrowthPromptSpec(
      type: GrowthPromptType.createPost,
      context: GrowthPromptContext.profile,
      title: 'Introduce yourself with a post',
      description: 'Share what’s happening so people can find you.',
      actionLabel: 'Create Post',
    );
  }

  static GrowthPromptSpec emptyProfilePhotos() {
    return const GrowthPromptSpec(
      type: GrowthPromptType.uploadPhoto,
      context: GrowthPromptContext.profile,
      title: 'Add your first photo',
      description: 'Help people discover what’s happening around you.',
      actionLabel: 'Upload',
    );
  }

  static GrowthPromptSpec emptyExplore({
    required String sectionLabel,
    String? city,
  }) {
    final lower = sectionLabel.toLowerCase();
    if (lower.contains('event') || lower.contains('things to do')) {
      return emptyEvents(city: city);
    }
    if (lower.contains('people')) {
      return specFor(
        GrowthPromptType.followPeople,
        context: GrowthPromptContext.explore,
        city: city,
      );
    }
    if (lower.contains('communit') || lower.contains('group')) {
      return specFor(
        GrowthPromptType.joinCommunity,
        context: GrowthPromptContext.explore,
        city: city,
      );
    }
    return GrowthPromptSpec(
      type: GrowthPromptType.createPost,
      context: GrowthPromptContext.explore,
      title: 'Nothing in $sectionLabel yet.',
      description: 'Know something happening around you? Share it with FirstVue.',
      actionLabel: 'Create Post',
      secondaryActionLabel: 'Create Event',
      secondaryType: GrowthPromptType.exploreEvents,
    );
  }

  static GrowthPromptSpec exploreContribution({String? city}) {
    return GrowthPromptSpec(
      type: GrowthPromptType.createPost,
      context: GrowthPromptContext.explore,
      title: 'Know something happening around you?',
      description: city == null
          ? 'Share it with FirstVue.'
          : 'Share what’s happening in ${_metroLabel(city)}.',
      actionLabel: 'Create Post',
      secondaryActionLabel: 'Create Event',
      secondaryType: GrowthPromptType.exploreEvents,
    );
  }

  static String? _metroLabel(String? city) {
    final value = city?.trim();
    if (value == null || value.isEmpty) return null;
    return value;
  }
}
