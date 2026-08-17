/// Logical growth / engagement prompt types. Rotate — never show all at once.
enum GrowthPromptType {
  createPost,
  uploadPhoto,
  uploadVideo,
  createStory,
  exploreEvents,
  discoverNearby,
  followPeople,
  joinCommunity,
  inviteFriends,
  shareApp,
}

enum GrowthPromptContext {
  home,
  vue,
  explore,
  events,
  profile,
  session,
}

enum GrowthCompletedAction {
  createPost,
  uploadMedia,
  createStory,
  createEvent,
  followPeople,
  joinCommunity,
  inviteFriends,
}

enum GrowthPromptVariant { card, banner, empty, composer, sheet }

/// Copy + actions for one prompt. Screens feed a [type] into the shared widget.
class GrowthPromptSpec {
  final GrowthPromptType type;
  final GrowthPromptContext context;
  final String title;
  final String description;
  final String actionLabel;
  final String? secondaryActionLabel;
  final GrowthPromptType? secondaryType;

  const GrowthPromptSpec({
    required this.type,
    required this.context,
    required this.title,
    required this.description,
    required this.actionLabel,
    this.secondaryActionLabel,
    this.secondaryType,
  });
}
