import '../models/explore_section.dart';
import '../services/community_news_service.dart';
import 'explore_classifier.dart';

export '../models/explore_section.dart' show ExploreSection, ExploreSectionX;
export 'explore_classifier.dart'
    show ExploreClassifier, ExploreClassificationInput;

/// Legacy alias so older Explore chip code keeps compiling.
typedef ExploreCategory = ExploreSection;

class ExploreCategoryFilter {
  ExploreCategoryFilter._();

  static bool matches(CommunityNewsPost post, ExploreSection category) {
    return ExploreClassifier.belongsTo(post.exploreInput(), category);
  }
}

extension CommunityNewsPostExplore on CommunityNewsPost {
  ExploreClassificationInput exploreInput({
    bool communityShare = false,
    String? sourceLabel,
  }) {
    return ExploreClassificationInput(
      authorProfileType: resolvedAuthorProfileType,
      businessType: businessType,
      industrySlug: industrySlug,
      secondaryIndustrySlugs: secondaryIndustrySlugs,
      services: businessServices,
      publishCategory: publishCategory,
      offeringType: offeringType,
      eventType: eventType,
      body: body,
      visibility: visibility,
      isMine: isMine,
      viewerFollowsAuthor: viewerFollowsAuthor,
      hasBusinessId: businessId != null,
      hasProfessionalId: professionalProfileId != null,
      hasEventId: eventId != null,
      hasCommunityId: communityId != null,
      hasRentalId: rentalId != null,
      communityShare: communityShare,
      originalAuthorName: displayAuthorName,
      originalSourceLabel: sourceLabel ?? originalSourceLabel,
    );
  }
}
