/// Centralized industry catalog and template registry.
///
/// Keys are stable slugs, never display text. Shared by entity setup, public
/// profile tabs, Explore filters, search, recommendations, and analytics.
library;

enum IndustryTemplate {
  beauty,
  food,
  nightlife,
  event,
  rental,
  activity,
  professional,
  retail,
  community,
  general,
}

enum PricingMode { exact, startingAt, free, contact }

class IndustryDefinition {
  final String slug;
  final String name;
  final String? parentSlug;
  final IndustryTemplate template;
  final int sortOrder;

  const IndustryDefinition({
    required this.slug,
    required this.name,
    required this.template,
    this.parentSlug,
    this.sortOrder = 100,
  });

  bool get isBroad => parentSlug == null;
}

class TemplatePreview {
  final IndustryTemplate template;
  final List<String> tabs;
  final List<String> modules;
  final List<String> actions;

  const TemplatePreview({
    required this.template,
    required this.tabs,
    required this.modules,
    required this.actions,
  });
}

class TemplateChangePreview {
  final List<String> added;
  final List<String> hidden;
  final List<String> retained;

  const TemplateChangePreview({
    required this.added,
    required this.hidden,
    required this.retained,
  });
}

class IndustryCatalog {
  IndustryCatalog._();

  static const industries = <IndustryDefinition>[
    IndustryDefinition(
      slug: 'beauty-grooming',
      name: 'Beauty & Grooming',
      template: IndustryTemplate.beauty,
      sortOrder: 10,
    ),
    IndustryDefinition(
      slug: 'barbershop',
      name: 'Barbershop',
      template: IndustryTemplate.beauty,
      parentSlug: 'beauty-grooming',
      sortOrder: 11,
    ),
    IndustryDefinition(
      slug: 'salon',
      name: 'Salon',
      template: IndustryTemplate.beauty,
      parentSlug: 'beauty-grooming',
      sortOrder: 12,
    ),
    IndustryDefinition(
      slug: 'spa',
      name: 'Spa',
      template: IndustryTemplate.beauty,
      parentSlug: 'beauty-grooming',
      sortOrder: 13,
    ),
    IndustryDefinition(
      slug: 'nail-salon',
      name: 'Nail Salon',
      template: IndustryTemplate.beauty,
      parentSlug: 'beauty-grooming',
      sortOrder: 14,
    ),
    IndustryDefinition(
      slug: 'makeup-artist',
      name: 'Makeup Artist',
      template: IndustryTemplate.beauty,
      parentSlug: 'beauty-grooming',
      sortOrder: 15,
    ),
    IndustryDefinition(
      slug: 'hair-salon',
      name: 'Hair Salon',
      template: IndustryTemplate.beauty,
      parentSlug: 'beauty-grooming',
      sortOrder: 16,
    ),
    IndustryDefinition(
      slug: 'food-dining',
      name: 'Food & Dining',
      template: IndustryTemplate.food,
      sortOrder: 20,
    ),
    IndustryDefinition(
      slug: 'restaurant',
      name: 'Restaurant',
      template: IndustryTemplate.food,
      parentSlug: 'food-dining',
      sortOrder: 21,
    ),
    IndustryDefinition(
      slug: 'cafe',
      name: 'Cafe',
      template: IndustryTemplate.food,
      parentSlug: 'food-dining',
      sortOrder: 22,
    ),
    IndustryDefinition(
      slug: 'bakery',
      name: 'Bakery',
      template: IndustryTemplate.food,
      parentSlug: 'food-dining',
      sortOrder: 23,
    ),
    IndustryDefinition(
      slug: 'food-truck',
      name: 'Food Truck',
      template: IndustryTemplate.food,
      parentSlug: 'food-dining',
      sortOrder: 24,
    ),
    IndustryDefinition(
      slug: 'nightlife',
      name: 'Nightlife',
      template: IndustryTemplate.nightlife,
      sortOrder: 30,
    ),
    IndustryDefinition(
      slug: 'bar',
      name: 'Bar',
      template: IndustryTemplate.nightlife,
      parentSlug: 'nightlife',
      sortOrder: 31,
    ),
    IndustryDefinition(
      slug: 'lounge',
      name: 'Lounge',
      template: IndustryTemplate.nightlife,
      parentSlug: 'nightlife',
      sortOrder: 32,
    ),
    IndustryDefinition(
      slug: 'events',
      name: 'Events',
      template: IndustryTemplate.event,
      sortOrder: 40,
    ),
    IndustryDefinition(
      slug: 'event-organizer',
      name: 'Event Organizer',
      template: IndustryTemplate.event,
      parentSlug: 'events',
      sortOrder: 41,
    ),
    IndustryDefinition(
      slug: 'rentals',
      name: 'Rentals',
      template: IndustryTemplate.rental,
      sortOrder: 50,
    ),
    IndustryDefinition(
      slug: 'activities',
      name: 'Activities',
      template: IndustryTemplate.activity,
      sortOrder: 60,
    ),
    IndustryDefinition(
      slug: 'activity-provider',
      name: 'Activity Provider',
      template: IndustryTemplate.activity,
      parentSlug: 'activities',
      sortOrder: 61,
    ),
    IndustryDefinition(
      slug: 'professional-services',
      name: 'Professional Services',
      template: IndustryTemplate.professional,
      sortOrder: 70,
    ),
    IndustryDefinition(
      slug: 'consulting',
      name: 'Consulting',
      template: IndustryTemplate.professional,
      parentSlug: 'professional-services',
      sortOrder: 71,
    ),
    IndustryDefinition(
      slug: 'home-services',
      name: 'Home Services',
      template: IndustryTemplate.professional,
      sortOrder: 74,
    ),
    IndustryDefinition(
      slug: 'auto-services',
      name: 'Auto Services',
      template: IndustryTemplate.professional,
      parentSlug: 'home-services',
      sortOrder: 75,
    ),
    IndustryDefinition(
      slug: 'cleaning-services',
      name: 'Cleaning',
      template: IndustryTemplate.professional,
      parentSlug: 'home-services',
      sortOrder: 76,
    ),
    IndustryDefinition(
      slug: 'health-fitness',
      name: 'Health & Fitness',
      template: IndustryTemplate.activity,
      sortOrder: 78,
    ),
    IndustryDefinition(
      slug: 'fitness-studio',
      name: 'Fitness Studio',
      template: IndustryTemplate.activity,
      parentSlug: 'health-fitness',
      sortOrder: 79,
    ),
    IndustryDefinition(
      slug: 'gym',
      name: 'Gym',
      template: IndustryTemplate.activity,
      parentSlug: 'health-fitness',
      sortOrder: 80,
    ),
    IndustryDefinition(
      slug: 'entertainment',
      name: 'Entertainment',
      template: IndustryTemplate.event,
      sortOrder: 82,
    ),
    IndustryDefinition(
      slug: 'venue',
      name: 'Venue',
      template: IndustryTemplate.event,
      parentSlug: 'entertainment',
      sortOrder: 83,
    ),
    IndustryDefinition(
      slug: 'retail',
      name: 'Retail',
      template: IndustryTemplate.retail,
      sortOrder: 84,
    ),
    IndustryDefinition(
      slug: 'boutique',
      name: 'Boutique',
      template: IndustryTemplate.retail,
      parentSlug: 'retail',
      sortOrder: 85,
    ),
    IndustryDefinition(
      slug: 'community',
      name: 'Community',
      template: IndustryTemplate.community,
      sortOrder: 90,
    ),
    IndustryDefinition(
      slug: 'group',
      name: 'Group',
      template: IndustryTemplate.community,
      parentSlug: 'community',
      sortOrder: 91,
    ),
    IndustryDefinition(
      slug: 'general-business',
      name: 'General Business',
      template: IndustryTemplate.general,
      sortOrder: 200,
    ),
  ];

  static const _coreTabs = ['FEED', 'PHOTOS', 'REVIEWS', 'SHOUT-OUTS', 'ABOUT'];

  static IndustryDefinition bySlug(String? slug) {
    final key = (slug ?? '').trim().toLowerCase();
    for (final item in industries) {
      if (item.slug == key) return item;
    }
    // Unknown / free-text slug: map by keywords without recursing back into
    // bySlug (avoids stack overflows on values like "bartender").
    return _mapDisplayType(key);
  }

  static IndustryDefinition fromDisplayType(String? display) {
    return _mapDisplayType((display ?? '').toLowerCase());
  }

  static IndustryDefinition _resolveKnown(String slug) {
    for (final item in industries) {
      if (item.slug == slug) return item;
    }
    for (final item in industries) {
      if (item.slug == 'general-business') return item;
    }
    return industries.last;
  }

  static IndustryDefinition _mapDisplayType(String type) {
    if (type.contains('barber')) return _resolveKnown('barbershop');
    if (type.contains('salon') || type.contains('stylist')) {
      return _resolveKnown('salon');
    }
    if (type.contains('spa') ||
        type.contains('nail') ||
        type.contains('beauty')) {
      return _resolveKnown('spa');
    }
    // Food truck before generic food → restaurant.
    if (type.contains('food truck') ||
        type.contains('foodtruck') ||
        type.contains('food-truck')) {
      return _resolveKnown('food-truck');
    }
    if (type.contains('restaurant') ||
        type.contains('food') ||
        type.contains('dining') ||
        type.contains('bistro') ||
        type.contains('cater')) {
      return _resolveKnown('restaurant');
    }
    if (type.contains('cafe') ||
        type.contains('café') ||
        type.contains('bakery')) {
      return _resolveKnown('cafe');
    }
    if (type.contains('bar') ||
        type.contains('lounge') ||
        type.contains('nightlife') ||
        type.contains('club') ||
        type.contains('brewery') ||
        type.contains('pub')) {
      return _resolveKnown('bar');
    }
    if (type.contains('event')) return _resolveKnown('event-organizer');
    if (type.contains('rental')) return _resolveKnown('rentals');
    if (type.contains('activit') ||
        type.contains('attraction') ||
        type.contains('recreation') ||
        type.contains('experience')) {
      return _resolveKnown('activity-provider');
    }
    if (type.contains('retail') ||
        type.contains('shop') ||
        type.contains('store')) {
      return _resolveKnown('retail');
    }
    if (type.contains('community') || type.contains('group')) {
      return _resolveKnown('community');
    }
    return _resolveKnown('general-business');
  }

  static TemplatePreview previewFor(IndustryTemplate template) {
    return switch (template) {
      IndustryTemplate.beauty => const TemplatePreview(
        template: IndustryTemplate.beauty,
        tabs: [
          'SERVICES',
          'FEED',
          'PHOTOS',
          'PORTFOLIO',
          'REVIEWS',
          'SHOUT-OUTS',
          'ABOUT',
        ],
        modules: [
          'Services',
          'Duration',
          'Pricing',
          'Staff',
          'Portfolio',
          'Availability',
          'Hours',
          'Location',
          'Policies',
          'Reviews',
        ],
        actions: ['Book', 'Follow', 'Message'],
      ),
      IndustryTemplate.food => const TemplatePreview(
        template: IndustryTemplate.food,
        tabs: ['MENU', ..._coreTabs],
        modules: [
          'Menu',
          'Pricing',
          'Dietary tags',
          'Hours',
          'Address',
          'Contact',
          'Reservation link',
        ],
        actions: ['Order', 'Reserve', 'Follow', 'Message', 'Call'],
      ),
      IndustryTemplate.nightlife => const TemplatePreview(
        template: IndustryTemplate.nightlife,
        tabs: ['DRINKS', ..._coreTabs],
        modules: [
          'Drinks',
          'Happy hour',
          'Events',
          'Hours',
          'Age requirements',
          'Reservations',
          'Location',
        ],
        actions: ['Follow', 'Message', 'Reserve'],
      ),
      IndustryTemplate.event => const TemplatePreview(
        template: IndustryTemplate.event,
        tabs: _coreTabs,
        modules: [
          'Schedule',
          'Venue',
          'Host contact',
          'Tickets',
          'Capacity',
          'Accessibility',
          'Media',
        ],
        actions: ['Follow', 'Message', 'RSVP'],
      ),
      IndustryTemplate.rental => const TemplatePreview(
        template: IndustryTemplate.rental,
        tabs: ['PROPERTY', 'FEED', 'PHOTOS', 'REVIEWS', 'AMENITIES', 'ABOUT'],
        modules: [
          'Rental type',
          'Location privacy',
          'Pricing',
          'Deposits',
          'Availability',
          'Amenities',
          'Rules',
          'Inquiries',
        ],
        actions: ['Inquire', 'Follow', 'Message'],
      ),
      IndustryTemplate.activity => const TemplatePreview(
        template: IndustryTemplate.activity,
        tabs: ['EXPERIENCES', ..._coreTabs],
        modules: [
          'Activity type',
          'Schedule',
          'Duration',
          'Pricing',
          'Capacity',
          'Difficulty',
          'Meeting location',
        ],
        actions: ['Book', 'Follow', 'Message'],
      ),
      IndustryTemplate.professional => const TemplatePreview(
        template: IndustryTemplate.professional,
        tabs: [
          'SERVICES',
          'FEED',
          'PHOTOS',
          'PORTFOLIO',
          'REVIEWS',
          'SHOUT-OUTS',
          'ABOUT',
        ],
        modules: [
          'Services',
          'Pricing',
          'Credentials',
          'Specialties',
          'Portfolio',
          'Service area',
        ],
        actions: ['Consult', 'Follow', 'Message'],
      ),
      IndustryTemplate.retail => const TemplatePreview(
        template: IndustryTemplate.retail,
        tabs: ['SHOP', ..._coreTabs],
        modules: [
          'Collections',
          'Products',
          'Pricing',
          'Inventory',
          'Pickup',
          'Hours',
          'Address',
        ],
        actions: ['Follow', 'Message', 'Call'],
      ),
      IndustryTemplate.community => const TemplatePreview(
        template: IndustryTemplate.community,
        tabs: [
          'FEED',
          'PHOTOS',
          'REVIEWS',
          'SHOUT-OUTS',
          'ABOUT',
          'GROUPS',
          'MEMBERS',
        ],
        modules: [
          'About',
          'City',
          'Membership rules',
          'Privacy',
          'Leaders',
          'Isolated feed',
          'Events',
        ],
        actions: ['Join', 'Follow', 'Report'],
      ),
      IndustryTemplate.general => const TemplatePreview(
        template: IndustryTemplate.general,
        tabs: _coreTabs,
        modules: ['About', 'Hours', 'Location', 'Contact', 'Media', 'Reviews'],
        actions: ['Follow', 'Message'],
      ),
    };
  }

  static List<String> tabsFor({String? slug, String? displayType}) {
    final def = slug != null && slug.trim().isNotEmpty
        ? bySlug(slug)
        : fromDisplayType(displayType);
    return previewFor(def.template).tabs;
  }

  /// Changing industry never deletes data. This only describes UI modules.
  static TemplateChangePreview previewChange({
    required IndustryTemplate from,
    required IndustryTemplate to,
  }) {
    final current = previewFor(from);
    final next = previewFor(to);
    final retained = current.modules
        .where(next.modules.contains)
        .toList(growable: false);
    final hidden = current.modules
        .where((m) => !next.modules.contains(m))
        .toList(growable: false);
    final added = next.modules
        .where((m) => !current.modules.contains(m))
        .toList(growable: false);
    return TemplateChangePreview(
      added: added,
      hidden: hidden,
      retained: retained,
    );
  }

  static bool drinksTabAllowed(IndustryTemplate template) {
    return template == IndustryTemplate.nightlife;
  }

  /// Owner editor modules for the compact tabbed profile editor.
  static List<String> editorTabsFor({String? slug, String? displayType}) {
    final def = slug != null && slug.trim().isNotEmpty
        ? bySlug(slug)
        : fromDisplayType(displayType);
    return switch (def.template) {
      IndustryTemplate.beauty => const [
        'Basics',
        'Services',
        'Hours',
        'Amenities',
        'Links',
      ],
      IndustryTemplate.food || IndustryTemplate.nightlife => const [
        'Basics',
        'Hours',
        'Menu',
        'Amenities',
        'Links',
      ],
      IndustryTemplate.event => const ['Basics', 'Hours', 'Amenities', 'Links'],
      IndustryTemplate.rental => const [
        'Basics',
        'Amenities',
        'Hours',
        'Links',
      ],
      IndustryTemplate.activity => const [
        'Basics',
        'Services',
        'Hours',
        'Amenities',
        'Links',
      ],
      IndustryTemplate.professional => const [
        'Basics',
        'Services',
        'Hours',
        'Links',
      ],
      IndustryTemplate.retail => const [
        'Basics',
        'Hours',
        'Amenities',
        'Links',
      ],
      IndustryTemplate.community ||
      IndustryTemplate.general => const ['Basics', 'Hours', 'Links'],
    };
  }

  static bool editorShowsMenu(IndustryTemplate template) =>
      template == IndustryTemplate.food ||
      template == IndustryTemplate.nightlife;

  static bool editorShowsServices(IndustryTemplate template) =>
      template == IndustryTemplate.beauty ||
      template == IndustryTemplate.professional ||
      template == IndustryTemplate.activity;
}

extension PricingModeX on PricingMode {
  String get storageValue => switch (this) {
    PricingMode.exact => 'exact',
    PricingMode.startingAt => 'starting_at',
    PricingMode.free => 'free',
    PricingMode.contact => 'contact',
  };

  String get label => switch (this) {
    PricingMode.exact => 'Exact',
    PricingMode.startingAt => 'Starting at',
    PricingMode.free => 'Free',
    PricingMode.contact => 'Contact for price',
  };

  static PricingMode parse(String? value) {
    return switch (value) {
      'starting_at' => PricingMode.startingAt,
      'free' => PricingMode.free,
      'contact' => PricingMode.contact,
      _ => PricingMode.exact,
    };
  }
}
