import '../data/industry_catalog.dart';
import '../models/explore_section.dart';
import '../services/post_metadata_service.dart';

/// Signals used to place Explore content. Hashtags never override identity.
class ExploreClassificationInput {
  /// Canonical publishing identity: user, business, professional, community,
  /// event, rental, group.
  final String authorProfileType;
  final String? businessType;
  final String? industrySlug;
  final List<String> secondaryIndustrySlugs;
  final List<String> services;
  final String? publishCategory;
  final String? offeringType;
  final String? eventType;
  final String body;
  final String visibility;
  final bool isMine;
  final bool viewerFollowsAuthor;
  final bool hasBusinessId;
  final bool hasProfessionalId;
  final bool hasEventId;
  final bool hasCommunityId;
  final bool hasRentalId;

  /// True when this appearance is a manual share into a Community hub.
  /// Original identity classification is preserved; Communities is added.
  final bool communityShare;
  final String? originalAuthorName;
  final String? originalSourceLabel;

  const ExploreClassificationInput({
    required this.authorProfileType,
    this.businessType,
    this.industrySlug,
    this.secondaryIndustrySlugs = const [],
    this.services = const [],
    this.publishCategory,
    this.offeringType,
    this.eventType,
    this.body = '',
    this.visibility = 'public',
    this.isMine = false,
    this.viewerFollowsAuthor = false,
    this.hasBusinessId = false,
    this.hasProfessionalId = false,
    this.hasEventId = false,
    this.hasCommunityId = false,
    this.hasRentalId = false,
    this.communityShare = false,
    this.originalAuthorName,
    this.originalSourceLabel,
  });

  String get resolvedIdentity {
    final explicit = authorProfileType.trim().toLowerCase();
    if (explicit.isNotEmpty && explicit != 'user') {
      if (explicit == 'group') return 'community';
      return explicit;
    }
    if (hasRentalId) return 'rental';
    if (hasBusinessId) return 'business';
    if (hasProfessionalId) return 'professional';
    if (hasEventId) return 'event';
    if (hasCommunityId) return 'community';
    return 'user';
  }

  bool get isPersonalIdentity => resolvedIdentity == 'user';

  bool get viewerCanAccess {
    final vis = visibility.trim().toLowerCase();
    if (vis.isEmpty || vis == 'public') return true;
    if (isMine) return true;
    if (vis == 'followers' && viewerFollowsAuthor) return true;
    return false;
  }
}

/// Places Explore content using identity → industry → services → category →
/// offering/event type → hashtags (supporting only).
class ExploreClassifier {
  ExploreClassifier._();

  static Set<ExploreSection> sectionsFor(ExploreClassificationInput input) {
    if (!input.viewerCanAccess) return const {};

    final identity = input.resolvedIdentity;
    final sections = <ExploreSection>{};

    if (identity == 'user') {
      return {ExploreSection.people};
    }
    if (identity == 'community' || identity == 'group') {
      sections.add(ExploreSection.groups);
    } else if (identity == 'event') {
      sections.add(ExploreSection.events);
    } else if (identity == 'rental') {
      sections.addAll(_entitySections(input, forceRental: true));
    } else if (identity == 'business' || identity == 'professional') {
      sections.addAll(_entitySections(input));
    } else if (input.hasCommunityId) {
      sections.add(ExploreSection.groups);
    } else if (input.hasEventId) {
      sections.add(ExploreSection.events);
    } else if (input.hasBusinessId || input.hasProfessionalId) {
      sections.addAll(_entitySections(input));
    } else {
      return {ExploreSection.people};
    }

    if (input.communityShare) {
      sections.add(ExploreSection.communities);
    }
    return sections;
  }

  static bool belongsTo(
    ExploreClassificationInput input,
    ExploreSection section,
  ) {
    return sectionsFor(input).contains(section);
  }

  static Set<ExploreSection> _entitySections(
    ExploreClassificationInput input, {
    bool forceRental = false,
  }) {
    final primary = _industryOf(
      slug: input.industrySlug,
      display: input.businessType ?? input.publishCategory ?? input.offeringType,
    );
    final secondary = <IndustryDefinition>[
      for (final slug in input.secondaryIndustrySlugs) _industryOf(slug: slug),
      for (final service in input.services)
        _industryOf(display: service, allowGeneral: false),
    ];

    final fromPrimary = _sectionsForIndustry(
      primary,
      eventType: input.eventType,
      offeringType: input.offeringType,
      publishCategory: input.publishCategory,
    );

    final fromSecondary = <ExploreSection>{};
    for (final def in secondary) {
      if (_isGeneral(def) && (input.services.isNotEmpty)) {
        // A free-text service like "Walk-ins" must not leak into Food/Bars.
        continue;
      }
      fromSecondary.addAll(
        _sectionsForIndustry(
          def,
          eventType: input.eventType,
          offeringType: input.offeringType,
          publishCategory: input.publishCategory,
        ),
      );
    }

    fromSecondary.addAll(
      _sectionsForStructuredHints(
        category: input.publishCategory,
        offering: input.offeringType,
        eventType: input.eventType,
      ),
    );

    final combined = <ExploreSection>{...fromPrimary, ...fromSecondary};

    if (forceRental) {
      combined
        ..remove(ExploreSection.people)
        ..add(ExploreSection.rentals);
    }

    if (combined.isEmpty) {
      combined.addAll(
        _supportingHashtagSections(input, primaryIsGeneral: _isGeneral(primary)),
      );
    } else if (_isGeneral(primary)) {
      combined.addAll(
        _supportingHashtagSections(input, primaryIsGeneral: true),
      );
    }

    combined.remove(ExploreSection.people);
    if (combined.isEmpty) combined.add(ExploreSection.businesses);
    return combined;
  }

  static IndustryDefinition _industryOf({
    String? slug,
    String? display,
    bool allowGeneral = true,
  }) {
    if (slug != null && slug.trim().isNotEmpty) {
      return IndustryCatalog.bySlug(slug);
    }
    if (display != null && display.trim().isNotEmpty) {
      final mapped = IndustryCatalog.fromDisplayType(display);
      if (allowGeneral || mapped.template != IndustryTemplate.general) {
        return mapped;
      }
    }
    return IndustryCatalog.bySlug('general-business');
  }

  static bool _isGeneral(IndustryDefinition def) {
    return def.template == IndustryTemplate.general ||
        def.slug == 'general-business';
  }

  static Set<ExploreSection> _sectionsForIndustry(
    IndustryDefinition def, {
    String? eventType,
    String? offeringType,
    String? publishCategory,
  }) {
    final slug = def.slug;
    final parent = def.parentSlug ?? '';
    final sections = <ExploreSection>{};

    if (slug == 'food-truck' ||
        def.name.toLowerCase().contains('food truck')) {
      sections.add(ExploreSection.foodTrucks);
    } else if (def.template == IndustryTemplate.food ||
        slug == 'food-dining' ||
        parent == 'food-dining') {
      sections.add(ExploreSection.food);
    }
    if (def.template == IndustryTemplate.nightlife ||
        slug == 'nightlife' ||
        parent == 'nightlife') {
      sections.add(ExploreSection.bars);
    }
    if (def.template == IndustryTemplate.activity ||
        slug == 'activities' ||
        slug == 'health-fitness' ||
        parent == 'activities' ||
        parent == 'health-fitness' ||
        slug == 'entertainment' ||
        parent == 'entertainment') {
      sections.add(ExploreSection.thingsToDo);
    }
    if (def.template == IndustryTemplate.rental ||
        slug == 'rentals' ||
        parent == 'rentals') {
      sections.add(ExploreSection.rentals);
    }
    if (slug == 'community' ||
        slug == 'group' ||
        parent == 'community' ||
        def.template == IndustryTemplate.community) {
      sections.add(ExploreSection.groups);
    }
    if (def.template == IndustryTemplate.event &&
        slug != 'entertainment' &&
        parent != 'entertainment') {
      sections.add(ExploreSection.events);
    }

    sections.addAll(
      _sectionsForStructuredHints(
        category: publishCategory,
        offering: offeringType,
        eventType: eventType,
      ),
    );

    if (sections.isEmpty) {
      sections.add(ExploreSection.businesses);
    }
    return sections;
  }

  static Set<ExploreSection> _sectionsForStructuredHints({
    String? category,
    String? offering,
    String? eventType,
  }) {
    final blob = [
      category,
      offering,
      eventType,
    ].whereType<String>().join(' ').toLowerCase();
    if (blob.isEmpty) return const {};
    final sections = <ExploreSection>{};
    if (_looksLikeFoodTruck(blob)) {
      sections.add(ExploreSection.foodTrucks);
    } else if (_looksLikeFood(blob)) {
      sections.add(ExploreSection.food);
    }
    if (_looksLikeBar(blob)) sections.add(ExploreSection.bars);
    if (_looksLikeActivity(blob)) sections.add(ExploreSection.thingsToDo);
    if (_looksLikeRental(blob)) sections.add(ExploreSection.rentals);
    if (_looksLikeEvent(blob)) sections.add(ExploreSection.events);
    return sections;
  }

  /// Hashtags/text may refine a general entity. They never move a personal
  /// post, and never override a specific primary industry.
  static Set<ExploreSection> _supportingHashtagSections(
    ExploreClassificationInput input, {
    required bool primaryIsGeneral,
  }) {
    if (input.isPersonalIdentity || !primaryIsGeneral) return const {};
    final tags = PostMetadataService.parse(input.body).hashtags;
    final blob = '${tags.join(' ')} ${input.body}'.toLowerCase();
    if (blob.trim().isEmpty) return const {};
    final sections = <ExploreSection>{};
    if (_looksLikeFoodTruck(blob)) {
      sections.add(ExploreSection.foodTrucks);
    } else if (_looksLikeFood(blob)) {
      sections.add(ExploreSection.food);
    }
    if (_looksLikeBar(blob)) sections.add(ExploreSection.bars);
    if (_looksLikeActivity(blob)) sections.add(ExploreSection.thingsToDo);
    if (_looksLikeRental(blob)) sections.add(ExploreSection.rentals);
    if (_looksLikeEvent(blob)) sections.add(ExploreSection.events);
    return sections;
  }

  static bool _looksLikeFood(String blob) {
    if (_looksLikeFoodTruck(blob)) return false;
    return RegExp(
      r'\b(restaurants?|food|dining|cafes?|cafés?|baker(?:y|ies)|cater(?:ing)?|bistros?)\b',
      caseSensitive: false,
    ).hasMatch(blob);
  }

  static bool _looksLikeFoodTruck(String blob) {
    return RegExp(
      r'food[\s_-]?trucks?',
      caseSensitive: false,
    ).hasMatch(blob);
  }

  static bool _looksLikeBar(String blob) {
    // "barber" / "barbershop" must never count as nightlife.
    if (RegExp(r'barber', caseSensitive: false).hasMatch(blob)) return false;
    return RegExp(
      r'\b(bars?|lounges?|nightlife|pubs?|brewer(?:y|ies)|clubs?)\b',
      caseSensitive: false,
    ).hasMatch(blob);
  }

  static bool _looksLikeActivity(String blob) {
    return RegExp(
      r'thingstodo|things to do|\b(activit(?:y|ies)|attractions?|recreation|entertainment|experiences?)\b',
      caseSensitive: false,
    ).hasMatch(blob);
  }

  static bool _looksLikeRental(String blob) {
    return RegExp(
      r'\b(rentals?|for rent)\b',
      caseSensitive: false,
    ).hasMatch(blob);
  }

  static bool _looksLikeEvent(String blob) {
    return RegExp(
      r'\b(events?|festivals?)\b',
      caseSensitive: false,
    ).hasMatch(blob);
  }
}
