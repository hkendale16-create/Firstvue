import 'package:flutter/material.dart';

import '../data/industry_catalog.dart';

/// Primary industry groups for Add Business onboarding.
/// Business types are children from [IndustryCatalog].
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

  const BusinessTypeOption({
    required this.slug,
    required this.label,
    required this.parentSlug,
    required this.icon,
  });
}

/// Suggested secondary services keyed by primary industry slug.
const Map<String, List<String>> industryServiceSuggestions = {
  'beauty-grooming': [
    'Haircuts',
    'Beard care',
    'Color',
    'Styling',
    'Nails',
    'Facials',
  ],
  'food-dining': [
    'Dine-in',
    'Takeout',
    'Delivery',
    'Catering',
    'Brunch',
    'Late night',
  ],
  'nightlife': ['Happy hour', 'Live music', 'Bottle service', 'Dance floor'],
  'events': ['Weddings', 'Corporate', 'Private parties', 'Ticketing'],
  'rentals': ['Daily', 'Weekly', 'Monthly', 'Furnished'],
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
    'nightlife' => Icons.nightlife,
    'events' => Icons.event,
    'rentals' => Icons.key_outlined,
    'activities' => Icons.hiking,
    'professional-services' => Icons.work_outline,
    'home-services' => Icons.home_repair_service_outlined,
    'health-fitness' => Icons.fitness_center,
    'entertainment' => Icons.theater_comedy_outlined,
    'retail' => Icons.storefront_outlined,
    'community' => Icons.groups_outlined,
    'barbershop' => Icons.content_cut,
    'salon' || 'nail-salon' => Icons.spa_outlined,
    'spa' => Icons.self_improvement,
    'restaurant' => Icons.restaurant,
    'cafe' => Icons.local_cafe,
    'bakery' => Icons.bakery_dining,
    'bar' || 'lounge' => Icons.local_bar,
    _ => Icons.business_center_outlined,
  };
}

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

  return [
    for (final industry in IndustryCatalog.industries)
      if (industry.isBroad && industry.slug != 'community')
        BusinessIndustryOption(
          slug: industry.slug,
          label: industry.name,
          icon: iconForIndustrySlug(industry.slug),
          accent: accents[industry.slug] ?? const Color(0xFFE5C16F),
        ),
  ]..sort((a, b) => a.label.compareTo(b.label));
}

List<BusinessTypeOption> businessTypesForIndustry(String parentSlug) {
  final children =
      IndustryCatalog.industries
          .where((i) => i.parentSlug == parentSlug)
          .toList()
        ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

  if (children.isEmpty) {
    final parent = IndustryCatalog.bySlug(parentSlug);
    return [
      BusinessTypeOption(
        slug: parent.slug,
        label: parent.name,
        parentSlug: parentSlug,
        icon: iconForIndustrySlug(parent.slug),
      ),
    ];
  }

  return [
    for (final child in children)
      BusinessTypeOption(
        slug: child.slug,
        label: child.name,
        parentSlug: parentSlug,
        icon: iconForIndustrySlug(child.slug),
      ),
  ];
}

/// Legacy category map kept for older screens still reading group → types.
const businessCategoryGroups = <String, List<String>>{
  'Beauty & Grooming': [
    'Barbershop',
    'Salon',
    'Spa',
    'Nail Salon',
    'Beauty Studio',
  ],
  'Food & Dining': ['Restaurant', 'Cafe', 'Bakery', 'Food Truck', 'Bistro'],
  'Nightlife': ['Bar', 'Lounge', 'Sports Bar'],
  'Professional Services': [
    'Consulting',
    'Legal',
    'Accounting',
    'Other Services',
  ],
  'Home Services': ['Home Services', 'Auto Services', 'Cleaning'],
  'Health & Fitness': ['Fitness Studio', 'Gym', 'Wellness'],
  'Rentals': ['Booth Rental', 'Suite Rental', 'Property Rental'],
  'Events': ['Event Organizer', 'Venue'],
  'Retail': ['Boutique', 'Shop', 'Store'],
  'Entertainment': ['Venue', 'Attraction'],
};

const defaultBusinessCategoryGroup = 'Beauty & Grooming';
