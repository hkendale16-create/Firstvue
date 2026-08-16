import 'package:flutter/material.dart';

import '../data/industry_catalog.dart';

/// Primary industry groups for Add Business onboarding.
/// Business types come from [businessTypesForIndustry] (catalog + extras).
class BusinessIndustryOption {
  final String slug;
  final String label;
  final IconData icon;
  final Color accent;

  const BusinessIndustryOption({
    required this.slug,
    required this.label,
    required this.icon,
    required this.accent,
  });
}

class BusinessTypeOption {
  final String slug;
  final String label;
  final String parentSlug;
  final IconData icon;
  final bool isOther;

  const BusinessTypeOption({
    required this.slug,
    required this.label,
    required this.parentSlug,
    required this.icon,
    this.isOther = false,
  });
}

/// Stable slug for the “Other” business type under any industry.
String otherBusinessTypeSlug(String parentSlug) => '$parentSlug-other';

/// Extra business types layered on [IndustryCatalog] children.
///
/// Keys are parent industry slugs. Labels are user-facing; slugs are derived.
/// Keep this map as the maintainable source for Add Business completeness.
const Map<String, List<String>> kExtraBusinessTypesByIndustry = {
  'food-dining': [
    'Restaurant',
    'Food Truck',
    'Coffee Shop',
    'Bakery',
    'Bar',
    'Lounge',
    'Nightclub',
    'Catering',
    'Fast Casual',
    'Fine Dining',
    'Ice Cream / Dessert',
    'Juice / Smoothie Bar',
    'Bistro',
    'Ghost Kitchen',
  ],
  'beauty-grooming': [
    'Hair Salon',
    'Massage',
    'Makeup Artist',
    'Esthetician',
    'Tattoo Shop',
    'Piercing Studio',
    'Beauty Studio',
    'Lash / Brow Studio',
    'Waxing Studio',
  ],
  'nightlife': [
    'Bar',
    'Lounge',
    'Nightclub',
    'Sports Bar',
    'Wine Bar',
    'Cocktail Bar',
    'Brewery',
    'Hookah Lounge',
  ],
  'events': [
    'Event Organizer',
    'Event Venue',
    'Event Planner',
    'Promoter',
    'Wedding Planner',
    'Party Planner',
    'Ticketing Company',
  ],
  'entertainment': [
    'Event Venue',
    'Club',
    'Lounge',
    'Arcade',
    'Bowling',
    'Movie Theater',
    'Live Music Venue',
    'Entertainment Company',
    'Promoter',
    'Comedy Club',
    'Escape Room',
  ],
  'rentals': [
    'Booth Rental',
    'Suite Rental',
    'Property Rental',
    'Equipment Rental',
    'Vehicle Rental',
    'Studio Rental',
    'Vacation Rental',
  ],
  'activities': [
    'Activity Provider',
    'Tour Company',
    'Outdoor Adventures',
    'Classes & Workshops',
    'Recreation Center',
    'Sports Facility',
    'Experience Host',
  ],
  'professional-services': [
    'Consulting',
    'Legal',
    'Accounting',
    'Marketing Agency',
    'Photography',
    'Videography',
    'Design Studio',
    'Real Estate',
    'Insurance',
    'Tech Services',
  ],
  'home-services': [
    'Home Repair',
    'Cleaning',
    'Auto Services',
    'Landscaping',
    'Plumbing',
    'Electrical',
    'HVAC',
    'Moving',
    'Pest Control',
  ],
  'health-fitness': [
    'Fitness Studio',
    'Gym',
    'Yoga Studio',
    'Personal Training',
    'Wellness Center',
    'Physical Therapy',
    'Nutrition Coaching',
    'Martial Arts',
  ],
  'retail': [
    'Boutique',
    'Shop',
    'Store',
    'Convenience Store',
    'Grocery',
    'Apparel',
    'Beauty Supply',
    'Electronics',
    'Gift Shop',
    'Marketplace Vendor',
  ],
  'general-business': [
    'Local Business',
    'Service Business',
    'Startup',
    'Nonprofit',
  ],
};

/// Suggested secondary services keyed by primary industry slug.
const Map<String, List<String>> industryServiceSuggestions = {
  'beauty-grooming': [
    'Haircuts',
    'Beard care',
    'Color',
    'Styling',
    'Nails',
    'Facials',
    'Massage',
    'Lashes',
  ],
  'food-dining': [
    'Dine-in',
    'Takeout',
    'Delivery',
    'Catering',
    'Brunch',
    'Late night',
    'Outdoor seating',
  ],
  'nightlife': [
    'Happy hour',
    'Live music',
    'Bottle service',
    'Dance floor',
    'Private events',
  ],
  'events': ['Weddings', 'Corporate', 'Private parties', 'Ticketing'],
  'rentals': ['Daily', 'Weekly', 'Monthly', 'Furnished', 'Short-term'],
  'activities': ['Tours', 'Classes', 'Experiences', 'Group bookings'],
  'professional-services': ['Consultations', 'On-site', 'Remote', 'Packages'],
  'home-services': ['Repair', 'Install', 'Maintenance', 'Emergency'],
  'health-fitness': ['Training', 'Classes', 'Memberships', 'Wellness'],
  'entertainment': ['Shows', 'Private events', 'VIP', 'Tickets'],
  'retail': ['In-store', 'Pickup', 'Shipping', 'Custom orders'],
  'general-business': ['Appointments', 'Walk-ins', 'Estimates'],
};

IconData iconForIndustrySlug(String slug) {
  return switch (slug) {
    'beauty-grooming' => Icons.content_cut,
    'food-dining' => Icons.restaurant,
    'nightlife' => Icons.local_bar,
    'events' => Icons.event,
    'rentals' => Icons.key_outlined,
    'activities' => Icons.hiking,
    'professional-services' => Icons.work_outline,
    'home-services' => Icons.home_repair_service_outlined,
    'health-fitness' => Icons.fitness_center,
    'entertainment' => Icons.theater_comedy_outlined,
    'retail' => Icons.storefront_outlined,
    'community' => Icons.groups_outlined,
    'barbershop' || 'barber-shop' => Icons.content_cut,
    'salon' || 'hair-salon' || 'nail-salon' => Icons.spa_outlined,
    'spa' || 'massage' || 'esthetician' => Icons.self_improvement,
    'makeup-artist' => Icons.face_retouching_natural,
    'tattoo-shop' || 'piercing-studio' => Icons.brush_outlined,
    'restaurant' || 'fine-dining' || 'fast-casual' => Icons.restaurant,
    'cafe' || 'café' || 'coffee-shop' => Icons.local_cafe,
    'bakery' || 'ice-cream-dessert' => Icons.bakery_dining,
    'food-truck' => Icons.local_shipping_outlined,
    'bar' || 'lounge' || 'nightclub' || 'club' || 'sports-bar' => Icons.local_bar,
    'catering' || 'juice-smoothie-bar' => Icons.room_service_outlined,
    'event-venue' || 'venue' || 'live-music-venue' || 'movie-theater' =>
      Icons.stadium_outlined,
    'arcade' || 'bowling' || 'escape-room' => Icons.sports_esports_outlined,
    'gym' || 'fitness-studio' || 'yoga-studio' || 'personal-training' =>
      Icons.fitness_center,
    'boutique' || 'shop' || 'store' || 'apparel' => Icons.shopping_bag_outlined,
    _ => Icons.business_center_outlined,
  };
}

String _slugify(String label) {
  return label
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'^-+|-+$'), '');
}

/// Display label overrides for primary industries (stable slugs unchanged).
const _primaryIndustryLabels = <String, String>{
  'beauty-grooming': 'Beauty & Personal Care',
  'general-business': 'Other',
};

List<BusinessIndustryOption> primaryIndustryOptions() {
  const accents = <String, Color>{
    'beauty-grooming': Color(0xFF3DD9C9),
    'food-dining': Color(0xFFE5C16F),
    'nightlife': Color(0xFFD68E98),
    'events': Color(0xFFE5C16F),
    'rentals': Color(0xFF3DD9C9),
    'activities': Color(0xFFE5C16F),
    'professional-services': Color(0xFF3DD9C9),
    'home-services': Color(0xFFE5C16F),
    'health-fitness': Color(0xFF3DD9C9),
    'entertainment': Color(0xFFD68E98),
    'retail': Color(0xFFE5C16F),
    'general-business': Color(0xFF8A9099),
  };

  final options = [
    for (final industry in IndustryCatalog.industries)
      if (industry.isBroad && industry.slug != 'community')
        BusinessIndustryOption(
          slug: industry.slug,
          label: _primaryIndustryLabels[industry.slug] ?? industry.name,
          icon: iconForIndustrySlug(industry.slug),
          accent: accents[industry.slug] ?? const Color(0xFFE5C16F),
        ),
  ];

  options.sort((a, b) {
    if (a.slug == 'general-business') return 1;
    if (b.slug == 'general-business') return -1;
    return a.label.compareTo(b.label);
  });
  return options;
}

String _normalizeLabel(String label) {
  return label.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
}

/// Business types for [parentSlug], catalog + extras, with Other last.
List<BusinessTypeOption> businessTypesForIndustry(String parentSlug) {
  final bySlug = <String, BusinessTypeOption>{};
  final seenLabels = <String>{};

  final children =
      IndustryCatalog.industries
          .where((i) => i.parentSlug == parentSlug)
          .toList()
        ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

  for (final child in children) {
    bySlug[child.slug] = BusinessTypeOption(
      slug: child.slug,
      label: child.name,
      parentSlug: parentSlug,
      icon: iconForIndustrySlug(child.slug),
    );
    seenLabels.add(_normalizeLabel(child.name));
  }

  for (final label in kExtraBusinessTypesByIndustry[parentSlug] ?? const []) {
    final slug = _slugify(label);
    if (slug.isEmpty || bySlug.containsKey(slug)) continue;
    final normalized = _normalizeLabel(label);
    if (seenLabels.contains(normalized)) continue;
    bySlug[slug] = BusinessTypeOption(
      slug: slug,
      label: label,
      parentSlug: parentSlug,
      icon: iconForIndustrySlug(slug),
    );
    seenLabels.add(normalized);
  }

  final types = bySlug.values.toList()
    ..sort((a, b) => a.label.compareTo(b.label));

  if (types.isEmpty) {
    final parent = IndustryCatalog.bySlug(parentSlug);
    types.add(
      BusinessTypeOption(
        slug: parent.slug,
        label: parent.name,
        parentSlug: parentSlug,
        icon: iconForIndustrySlug(parent.slug),
      ),
    );
  }

  types.add(
    BusinessTypeOption(
      slug: otherBusinessTypeSlug(parentSlug),
      label: 'Other',
      parentSlug: parentSlug,
      icon: Icons.more_horiz,
      isOther: true,
    ),
  );
  return types;
}

/// Legacy category map kept for older screens still reading group → types.
const businessCategoryGroups = <String, List<String>>{
  'Beauty & Personal Care': [
    'Barber Shop',
    'Hair Salon',
    'Nail Salon',
    'Spa',
    'Makeup Artist',
  ],
  'Food & Dining': [
    'Restaurant',
    'Café',
    'Bakery',
    'Food Truck',
    'Coffee Shop',
  ],
  'Nightlife': ['Bar', 'Lounge', 'Sports Bar', 'Nightclub'],
  'Professional Services': [
    'Consulting',
    'Legal',
    'Accounting',
    'Other Services',
  ],
  'Home Services': ['Home Repair', 'Auto Services', 'Cleaning'],
  'Health & Fitness': ['Fitness Studio', 'Gym', 'Wellness Center'],
  'Rentals': ['Booth Rental', 'Suite Rental', 'Property Rental'],
  'Events': ['Event Organizer', 'Event Venue'],
  'Retail': ['Boutique', 'Shop', 'Store'],
  'Entertainment': ['Venue', 'Live Music Venue', 'Arcade'],
};

const defaultBusinessCategoryGroup = 'Beauty & Personal Care';
