import 'package:flutter/material.dart';
import '../navigation/firstvue_page_route.dart';
import 'package:geolocator/geolocator.dart';

import 'business_profile_screen.dart';
import 'firstvue_business_profile_screen.dart';
import 'professional_public_profile_screen.dart';
import '../services/approved_businesses_service.dart';
import '../services/location_service.dart';
import '../services/professional_profiles_service.dart';
import '../widgets/firstvue_refresh_scaffold.dart';

enum _BarberFilter { nearMe, topRated, verified }

enum DiscoveryCategory {
  barbers,
  stylists,
  salons,
  barbershops,
  beautyProfessionals,
  beautyStudios,
  restaurants,
  otherServices;

  String get title => switch (this) {
    DiscoveryCategory.barbers => 'BARBERS',
    DiscoveryCategory.stylists => 'STYLISTS',
    DiscoveryCategory.salons => 'SALONS & SUITES',
    DiscoveryCategory.barbershops => 'BARBERSHOPS & SUITES',
    DiscoveryCategory.beautyProfessionals => 'BEAUTY PROFESSIONALS',
    DiscoveryCategory.beautyStudios => 'BEAUTY STUDIOS',
    DiscoveryCategory.restaurants => 'FINE AND DINE',
    DiscoveryCategory.otherServices => 'OTHER SERVICES',
  };

  IconData get icon => switch (this) {
    DiscoveryCategory.barbers => Icons.content_cut,
    DiscoveryCategory.stylists => Icons.face_retouching_natural_rounded,
    DiscoveryCategory.salons => Icons.chair_alt_rounded,
    DiscoveryCategory.barbershops => Icons.storefront_rounded,
    DiscoveryCategory.beautyProfessionals => Icons.auto_awesome_rounded,
    DiscoveryCategory.beautyStudios => Icons.spa_rounded,
    DiscoveryCategory.restaurants => Icons.restaurant_rounded,
    DiscoveryCategory.otherServices => Icons.home_repair_service_outlined,
  };

  bool get isIndividual =>
      this == DiscoveryCategory.barbers ||
      this == DiscoveryCategory.stylists ||
      this == DiscoveryCategory.beautyProfessionals;

  String get prototypeSectionTitle =>
      isIndividual ? 'PROTOTYPE PROFESSIONALS' : 'PROTOTYPE LOCATIONS';

  String get prototypeCountLabel =>
      isIndividual ? 'individual prototypes' : 'location prototypes';

  String get profileLabel =>
      isIndividual ? 'Independent professional' : 'Service location';

  String get aboutText => switch (this) {
    DiscoveryCategory.barbers =>
      'Independent barber profile shown as fictional prototype data for discovery testing.',
    DiscoveryCategory.stylists =>
      'Independent stylist profile shown as fictional prototype data for discovery testing.',
    DiscoveryCategory.salons =>
      'Salon or suite location shown as fictional prototype data for discovery testing.',
    DiscoveryCategory.barbershops =>
      'Barbershop or barber-suite location shown as fictional prototype data for discovery testing.',
    DiscoveryCategory.beautyProfessionals =>
      'Independent beauty professional shown as fictional prototype data for discovery testing.',
    DiscoveryCategory.beautyStudios =>
      'Beauty studio or suite location shown as fictional prototype data for discovery testing.',
    DiscoveryCategory.restaurants =>
      'Restaurant or dining spot shown as fictional prototype data for discovery testing.',
    DiscoveryCategory.otherServices =>
      'Local service business shown as fictional prototype data for discovery testing.',
  };

  bool _isBeautyBusinessType(String normalized) {
    return normalized.contains('barber') ||
        normalized.contains('salon') ||
        normalized.contains('beauty') ||
        normalized.contains('spa') ||
        normalized.contains('nail') ||
        normalized.contains('suite') && normalized.contains('barber') ||
        normalized.contains('stylist');
  }

  bool _isRestaurantBusinessType(String normalized) {
    return normalized.contains('restaurant') ||
        normalized.contains('dining') ||
        normalized.contains('food') ||
        normalized.contains('cafe') ||
        normalized.contains('café') ||
        normalized.contains('bistro') ||
        normalized.contains('grill');
  }

  bool matchesBusinessType(String businessType) {
    final normalized = businessType.toLowerCase();
    return switch (this) {
      DiscoveryCategory.barbers => normalized.contains('barber'),
      DiscoveryCategory.stylists => false,
      DiscoveryCategory.salons =>
        normalized.contains('salon') ||
            (normalized.contains('suite') && !normalized.contains('barber')),
      DiscoveryCategory.barbershops =>
        normalized.contains('barbershop') ||
            normalized.contains('barber shop') ||
            normalized.contains('barber suite'),
      DiscoveryCategory.beautyProfessionals => false,
      DiscoveryCategory.beautyStudios =>
        normalized.contains('beauty studio') ||
            normalized.contains('beauty suite') ||
            normalized.contains('spa') ||
            normalized.contains('nail salon'),
      DiscoveryCategory.restaurants => _isRestaurantBusinessType(normalized),
      DiscoveryCategory.otherServices =>
        !_isBeautyBusinessType(normalized) &&
            !_isRestaurantBusinessType(normalized),
    };
  }
}

class BarberResultsScreen extends StatefulWidget {
  final String initialQuery;
  final DiscoveryCategory category;

  const BarberResultsScreen({
    super.key,
    this.initialQuery = '',
    this.category = DiscoveryCategory.barbers,
  });

  @override
  State<BarberResultsScreen> createState() => _BarberResultsScreenState();
}

class _BarberResultsScreenState extends State<BarberResultsScreen> {
  static const _barberBusinesses = [
    _PrototypeBusiness(
      name: 'Marcus Reed',
      rating: 4.9,
      reviews: 328,
      distance: '1.2 mi',
      city: 'Atlanta',
      state: 'GA',
      zipCode: '30303',
      latitude: 33.7490,
      longitude: -84.3880,
      verified: false,
      specialty: 'Fades • Beard Work • Designs',
    ),
    _PrototypeBusiness(
      name: 'Darius Cole',
      rating: 4.8,
      reviews: 214,
      distance: '2.4 mi',
      city: 'Atlanta',
      state: 'GA',
      zipCode: '30318',
      latitude: 33.7987,
      longitude: -84.4286,
      verified: false,
      specialty: 'Tapers • Shear Cuts • Kids Cuts',
    ),
    _PrototypeBusiness(
      name: 'Andre Ellis',
      rating: 4.7,
      reviews: 187,
      distance: '3.1 mi',
      city: 'Decatur',
      state: 'GA',
      zipCode: '30030',
      latitude: 33.7748,
      longitude: -84.2963,
      verified: false,
      specialty: 'Classic Cuts • Beard Grooming',
    ),
  ];

  static const _stylistBusinesses = [
    _PrototypeBusiness(
      name: 'Nia Carter',
      rating: 4.9,
      reviews: 203,
      distance: '1.4 mi',
      city: 'Atlanta',
      state: 'GA',
      zipCode: '30308',
      latitude: 33.7719,
      longitude: -84.3849,
      verified: false,
      specialty: 'Silk Press • Color • Natural Hair',
    ),
    _PrototypeBusiness(
      name: 'Imani Brooks',
      rating: 4.8,
      reviews: 154,
      distance: '2.6 mi',
      city: 'Atlanta',
      state: 'GA',
      zipCode: '30309',
      latitude: 33.7897,
      longitude: -84.3874,
      verified: false,
      specialty: 'Locs • Twists • Protective Styles',
    ),
    _PrototypeBusiness(
      name: 'Avery James',
      rating: 4.7,
      reviews: 119,
      distance: '3.8 mi',
      city: 'Decatur',
      state: 'GA',
      zipCode: '30030',
      latitude: 33.7744,
      longitude: -84.2958,
      verified: false,
      specialty: 'Cuts • Extensions • Editorial Styling',
    ),
  ];

  static const _salonBusinesses = [
    _PrototypeBusiness(
      name: 'Velvet Room Salon',
      rating: 4.9,
      reviews: 186,
      distance: '1.6 mi',
      city: 'Atlanta',
      state: 'GA',
      zipCode: '30308',
      latitude: 33.7725,
      longitude: -84.3857,
      verified: false,
      specialty: 'Silk Press • Color • Natural Hair',
    ),
    _PrototypeBusiness(
      name: 'Muse Salon Suites',
      rating: 4.8,
      reviews: 142,
      distance: '2.8 mi',
      city: 'Atlanta',
      state: 'GA',
      zipCode: '30309',
      latitude: 33.7930,
      longitude: -84.3877,
      verified: false,
      specialty: 'Independent Suites • Hair • Nails',
    ),
    _PrototypeBusiness(
      name: 'The Texture House',
      rating: 4.7,
      reviews: 97,
      distance: '4.0 mi',
      city: 'Decatur',
      state: 'GA',
      zipCode: '30030',
      latitude: 33.7751,
      longitude: -84.2965,
      verified: false,
      specialty: 'Curls • Locs • Protective Styles',
    ),
  ];

  static const _barbershopBusinesses = [
    _PrototypeBusiness(
      name: 'District Barber Co.',
      rating: 4.9,
      reviews: 312,
      distance: '1.9 mi',
      city: 'Atlanta',
      state: 'GA',
      zipCode: '30303',
      latitude: 33.7501,
      longitude: -84.3902,
      verified: false,
      specialty: 'Walk-ins • Multiple Barbers • Grooming',
    ),
    _PrototypeBusiness(
      name: 'Westside Barber Suites',
      rating: 4.8,
      reviews: 176,
      distance: '3.0 mi',
      city: 'Atlanta',
      state: 'GA',
      zipCode: '30318',
      latitude: 33.7992,
      longitude: -84.4301,
      verified: false,
      specialty: 'Private Suites • Independent Barbers',
    ),
    _PrototypeBusiness(
      name: 'The Cut Collective',
      rating: 4.7,
      reviews: 128,
      distance: '4.2 mi',
      city: 'Decatur',
      state: 'GA',
      zipCode: '30030',
      latitude: 33.7755,
      longitude: -84.2972,
      verified: false,
      specialty: 'Appointments • Walk-ins • Family Cuts',
    ),
  ];

  static const _beautyProfessionals = [
    _PrototypeBusiness(
      name: 'Zoe Mitchell',
      rating: 4.9,
      reviews: 191,
      distance: '1.3 mi',
      city: 'Atlanta',
      state: 'GA',
      zipCode: '30308',
      latitude: 33.7731,
      longitude: -84.3839,
      verified: false,
      specialty: 'Makeup Artistry • Bridal • Editorial',
    ),
    _PrototypeBusiness(
      name: 'Camille Price',
      rating: 4.8,
      reviews: 147,
      distance: '2.5 mi',
      city: 'Atlanta',
      state: 'GA',
      zipCode: '30309',
      latitude: 33.7904,
      longitude: -84.3868,
      verified: false,
      specialty: 'Nail Art • Gel • Structured Manicures',
    ),
    _PrototypeBusiness(
      name: 'Taylor Monroe',
      rating: 4.7,
      reviews: 106,
      distance: '3.7 mi',
      city: 'Decatur',
      state: 'GA',
      zipCode: '30030',
      latitude: 33.7738,
      longitude: -84.2949,
      verified: false,
      specialty: 'Facials • Brows • Skin Consultations',
    ),
  ];

  static const _beautyStudios = [
    _PrototypeBusiness(
      name: 'Lumen Beauty Studio',
      rating: 4.9,
      reviews: 224,
      distance: '1.8 mi',
      city: 'Atlanta',
      state: 'GA',
      zipCode: '30308',
      latitude: 33.7740,
      longitude: -84.3861,
      verified: false,
      specialty: 'Skin • Brows • Makeup',
    ),
    _PrototypeBusiness(
      name: 'Polished Beauty Suites',
      rating: 4.8,
      reviews: 163,
      distance: '2.9 mi',
      city: 'Atlanta',
      state: 'GA',
      zipCode: '30309',
      latitude: 33.7921,
      longitude: -84.3882,
      verified: false,
      specialty: 'Private Suites • Nails • Lashes',
    ),
    _PrototypeBusiness(
      name: 'Aura Skin & Beauty',
      rating: 4.7,
      reviews: 131,
      distance: '4.1 mi',
      city: 'Decatur',
      state: 'GA',
      zipCode: '30030',
      latitude: 33.7762,
      longitude: -84.2980,
      verified: false,
      specialty: 'Facials • Waxing • Body Care',
    ),
  ];

  static const _restaurantBusinesses = [
    _PrototypeBusiness(
      name: 'District Kitchen',
      rating: 4.8,
      reviews: 412,
      distance: '1.1 mi',
      city: 'Atlanta',
      state: 'GA',
      zipCode: '30303',
      latitude: 33.7510,
      longitude: -84.3900,
      verified: false,
      specialty: 'Southern • Brunch • Cocktails',
    ),
    _PrototypeBusiness(
      name: 'Goldline Bistro',
      rating: 4.7,
      reviews: 286,
      distance: '2.3 mi',
      city: 'Atlanta',
      state: 'GA',
      zipCode: '30308',
      latitude: 33.7710,
      longitude: -84.3820,
      verified: false,
      specialty: 'Date Night • Patio • Wine',
    ),
    _PrototypeBusiness(
      name: 'Peachtree Grill',
      rating: 4.6,
      reviews: 198,
      distance: '3.4 mi',
      city: 'Decatur',
      state: 'GA',
      zipCode: '30030',
      latitude: 33.7750,
      longitude: -84.2960,
      verified: false,
      specialty: 'Grill • Family • Takeout',
    ),
  ];

  static const _otherServiceBusinesses = [
    _PrototypeBusiness(
      name: 'Metro Auto Detail',
      rating: 4.9,
      reviews: 156,
      distance: '1.8 mi',
      city: 'Atlanta',
      state: 'GA',
      zipCode: '30312',
      latitude: 33.7400,
      longitude: -84.3780,
      verified: false,
      specialty: 'Detailing • Ceramic Coating',
    ),
    _PrototypeBusiness(
      name: 'CleanPro Home Services',
      rating: 4.8,
      reviews: 221,
      distance: '2.7 mi',
      city: 'Atlanta',
      state: 'GA',
      zipCode: '30309',
      latitude: 33.7890,
      longitude: -84.3850,
      verified: false,
      specialty: 'Cleaning • Handyman • Move-out',
    ),
    _PrototypeBusiness(
      name: 'Pulse Fitness Studio',
      rating: 4.7,
      reviews: 143,
      distance: '3.2 mi',
      city: 'Decatur',
      state: 'GA',
      zipCode: '30030',
      latitude: 33.7730,
      longitude: -84.2970,
      verified: false,
      specialty: 'Training • Yoga • Recovery',
    ),
  ];

  List<_PrototypeBusiness> get _businesses => switch (widget.category) {
    DiscoveryCategory.barbers => _barberBusinesses,
    DiscoveryCategory.stylists => _stylistBusinesses,
    DiscoveryCategory.salons => _salonBusinesses,
    DiscoveryCategory.barbershops => _barbershopBusinesses,
    DiscoveryCategory.beautyProfessionals => _beautyProfessionals,
    DiscoveryCategory.beautyStudios => _beautyStudios,
    DiscoveryCategory.restaurants => _restaurantBusinesses,
    DiscoveryCategory.otherServices => _otherServiceBusinesses,
  };

  ProfessionalType? get _professionalType => switch (widget.category) {
    DiscoveryCategory.barbers => ProfessionalType.barber,
    DiscoveryCategory.stylists => ProfessionalType.stylist,
    DiscoveryCategory.beautyProfessionals =>
      ProfessionalType.beautyProfessional,
    _ => null,
  };

  Stream<List<ProfessionalProfile>> get _approvedProfessionalStream {
    final type = _professionalType;
    return type == null
        ? Stream<List<ProfessionalProfile>>.value(const [])
        : ProfessionalProfilesService.watchApproved(type);
  }

  String _searchQuery = '';
  String _cityFilter = '';
  String _stateFilter = '';
  String _zipCodeFilter = '';
  _BarberFilter? _selectedFilter = _BarberFilter.nearMe;
  late final TextEditingController _searchController;
  Position? _currentPosition;
  bool _isLocating = false;

  bool get _hasLocationFilter =>
      _cityFilter.isNotEmpty ||
      _stateFilter.isNotEmpty ||
      _zipCodeFilter.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _searchQuery = widget.initialQuery;
    _searchController = TextEditingController(text: widget.initialQuery);
  }

  List<_PrototypeBusiness> get _visibleBusinesses {
    final query = _searchQuery.trim().toLowerCase();
    final businesses = _businesses
        .where((business) {
          return query.isEmpty ||
              business.name.toLowerCase().contains(query) ||
              business.specialty.toLowerCase().contains(query) ||
              business.city.toLowerCase().contains(query) ||
              business.state.toLowerCase().contains(query) ||
              business.zipCode.contains(query);
        })
        .where((business) {
          return (_cityFilter.isEmpty ||
                  business.city.toLowerCase().contains(
                    _cityFilter.toLowerCase(),
                  )) &&
              (_stateFilter.isEmpty ||
                  business.state.toLowerCase().contains(
                    _stateFilter.toLowerCase(),
                  )) &&
              (_zipCodeFilter.isEmpty ||
                  business.zipCode.contains(_zipCodeFilter));
        })
        .toList();

    switch (_selectedFilter) {
      case _BarberFilter.nearMe:
        businesses.sort(
          (a, b) => _distanceMetersFor(a).compareTo(_distanceMetersFor(b)),
        );
      case _BarberFilter.topRated:
        businesses.sort((a, b) => b.rating.compareTo(a.rating));
      case _BarberFilter.verified:
        businesses.removeWhere((business) => !business.verified);
      case null:
        break;
    }

    return businesses;
  }

  List<ApprovedBusiness> _visibleApprovedBusinesses(
    List<ApprovedBusiness> businesses,
  ) {
    if (widget.category.isIndividual) return const [];
    final query = _searchQuery.trim().toLowerCase();
    return businesses.where((business) {
      final isCategoryMatch = widget.category.matchesBusinessType(
        business.businessType,
      );
      final matchesQuery =
          query.isEmpty ||
          business.name.toLowerCase().contains(query) ||
          business.businessType.toLowerCase().contains(query);
      return isCategoryMatch && matchesQuery;
    }).toList();
  }

  List<ProfessionalProfile> _visibleApprovedProfessionals(
    List<ProfessionalProfile> profiles,
  ) {
    if (!widget.category.isIndividual) return const [];
    final query = _searchQuery.trim().toLowerCase();
    return profiles.where((profile) {
      final matchesQuery =
          query.isEmpty ||
          profile.displayName.toLowerCase().contains(query) ||
          profile.services.any(
            (service) => service.toLowerCase().contains(query),
          ) ||
          profile.city.toLowerCase().contains(query) ||
          profile.state.toLowerCase().contains(query) ||
          profile.postalCode.contains(query);
      final matchesLocation =
          (_cityFilter.isEmpty ||
              profile.city.toLowerCase().contains(_cityFilter.toLowerCase())) &&
          (_stateFilter.isEmpty ||
              profile.state.toLowerCase().contains(
                _stateFilter.toLowerCase(),
              )) &&
          (_zipCodeFilter.isEmpty ||
              profile.postalCode.contains(_zipCodeFilter));
      return matchesQuery && matchesLocation;
    }).toList();
  }

  double _distanceMetersFor(_PrototypeBusiness business) {
    final position = _currentPosition;
    if (position == null) return business.distanceMiles * 1609.344;

    return Geolocator.distanceBetween(
      position.latitude,
      position.longitude,
      business.latitude,
      business.longitude,
    );
  }

  String _distanceLabelFor(_PrototypeBusiness business) {
    final miles = _distanceMetersFor(business) / 1609.344;
    return '${miles.toStringAsFixed(miles < 10 ? 1 : 0)} mi';
  }

  Future<void> _useCurrentLocation() async {
    if (_isLocating) return;

    setState(() => _isLocating = true);
    try {
      final position = await LocationService.getCurrentPosition();
      if (!mounted) return;
      setState(() {
        _currentPosition = position;
        _selectedFilter = _BarberFilter.nearMe;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Near Me now uses your current location and prototype coordinates.',
          ),
        ),
      );
    } on LocationAccessException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to get your current location. Try again.'),
        ),
      );
    } finally {
      if (mounted) setState(() => _isLocating = false);
    }
  }

  Future<void> _openLocationFilters() async {
    final filters = await showModalBottomSheet<_LocationFilters>(
      context: context,
      backgroundColor: const Color(0xFF10151B),
      isScrollControlled: true,
      builder: (_) => _LocationFiltersSheet(
        initialFilters: _LocationFilters(
          city: _cityFilter,
          state: _stateFilter,
          zipCode: _zipCodeFilter,
        ),
      ),
    );

    if (filters == null || !mounted) return;
    setState(() {
      _cityFilter = filters.city;
      _stateFilter = filters.state;
      _zipCodeFilter = filters.zipCode;
    });
  }

  void _resetSearchAndFilters() {
    setState(() {
      _searchController.clear();
      _searchQuery = '';
      _cityFilter = '';
      _stateFilter = '';
      _zipCodeFilter = '';
      _selectedFilter = _BarberFilter.nearMe;
    });
  }

  Future<void> _refreshResults() async {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final businesses = _visibleBusinesses;

    return Scaffold(
      backgroundColor: const Color(0xFF080B0F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF080B0F),
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.category.title,
          style: const TextStyle(
            fontFamily: 'CormorantGaramond',
            color: Colors.white,
            fontSize: 20,
            letterSpacing: 1.2,
          ),
        ),
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
              child: _SearchField(
                controller: _searchController,
                onChanged: (value) => setState(() => _searchQuery = value),
              ),
            ),
            SizedBox(
              height: 42,
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                scrollDirection: Axis.horizontal,
                children: [
                  _FilterChip(
                    label: 'Near Me',
                    icon: _isLocating
                        ? Icons.more_horiz
                        : Icons.near_me_outlined,
                    selected: _selectedFilter == _BarberFilter.nearMe,
                    onPressed: _useCurrentLocation,
                  ),
                  const SizedBox(width: 10),
                  _FilterChip(
                    label: 'Top Rated',
                    icon: Icons.star_outline,
                    selected: _selectedFilter == _BarberFilter.topRated,
                    onPressed: () => setState(
                      () => _selectedFilter = _BarberFilter.topRated,
                    ),
                  ),
                  if (!widget.category.isIndividual) ...[
                    const SizedBox(width: 10),
                    _FilterChip(
                      label: 'Verified',
                      icon: Icons.verified_outlined,
                      selected: _selectedFilter == _BarberFilter.verified,
                      onPressed: () => setState(
                        () => _selectedFilter = _BarberFilter.verified,
                      ),
                    ),
                  ],
                  const SizedBox(width: 10),
                  _FilterChip(
                    label: 'Filters',
                    icon: Icons.tune,
                    selected: _hasLocationFilter,
                    onPressed: _openLocationFilters,
                  ),
                ],
              ),
            ),
            Expanded(
              child: StreamBuilder<List<ProfessionalProfile>>(
                stream: _approvedProfessionalStream,
                builder: (context, professionalSnapshot) {
                  final approvedProfessionals = _visibleApprovedProfessionals(
                    professionalSnapshot.data ?? const [],
                  );
                  return StreamBuilder<List<ApprovedBusiness>>(
                    stream: ApprovedBusinessesService.watchApprovedBusinesses(),
                    builder: (context, businessSnapshot) {
                      final approvedBusinesses = _visibleApprovedBusinesses(
                        businessSnapshot.data ?? const [],
                      );
                      if (businesses.isEmpty &&
                          approvedBusinesses.isEmpty &&
                          approvedProfessionals.isEmpty) {
                        return _EmptySearchResults(
                          onReset: _resetSearchAndFilters,
                        );
                      }
                      return FirstVueRefreshScaffold(
                        onRefresh: _refreshResults,
                        child: ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(20, 25, 20, 28),
                          children: [
                          Row(
                            children: [
                              const Text(
                                'DISCOVER',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 17,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 2,
                                ),
                              ),
                              const Spacer(),
                              Text(
                                widget.category.isIndividual
                                    ? '${approvedProfessionals.length} verified • ${businesses.length} ${widget.category.prototypeCountLabel}'
                                    : '${approvedBusinesses.length} FirstVue verified • ${businesses.length} ${widget.category.prototypeCountLabel}',
                                style: const TextStyle(
                                  color: Colors.white54,
                                  fontSize: 12,
                                ),
                              ),
                              if (_currentPosition != null) ...[
                                const SizedBox(width: 8),
                                const Icon(
                                  Icons.my_location,
                                  color: Color(0xFFD8B56A),
                                  size: 14,
                                ),
                              ],
                            ],
                          ),
                          if (approvedBusinesses.isNotEmpty) ...[
                            const SizedBox(height: 16),
                            const Text(
                              'FIRSTVUE VERIFIED',
                              style: TextStyle(
                                color: Color(0xFFD8B56A),
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.5,
                              ),
                            ),
                            const SizedBox(height: 10),
                            ...approvedBusinesses.expand(
                              (business) => [
                                _ApprovedBusinessCard(
                                  business: business,
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      FirstVuePageRoute(
                                        builder: (_) =>
                                            FirstVueBusinessProfileScreen(
                                              businessId: business.id,
                                            ),
                                      ),
                                    );
                                  },
                                ),
                                const SizedBox(height: 14),
                              ],
                            ),
                          ],
                          if (approvedProfessionals.isNotEmpty) ...[
                            const SizedBox(height: 16),
                            const Text(
                              'FIRSTVUE VERIFIED PROFESSIONALS',
                              style: TextStyle(
                                color: Color(0xFFD8B56A),
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.5,
                              ),
                            ),
                            const SizedBox(height: 10),
                            ...approvedProfessionals.expand(
                              (profile) => [
                                _ApprovedProfessionalCard(
                                  profile: profile,
                                  icon: widget.category.icon,
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      FirstVuePageRoute(
                                        builder: (_) =>
                                            ProfessionalPublicProfileScreen(
                                              profile: profile,
                                              icon: widget.category.icon,
                                            ),
                                      ),
                                    );
                                  },
                                ),
                                const SizedBox(height: 14),
                              ],
                            ),
                          ],
                          if (businesses.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              widget.category.prototypeSectionTitle,
                              style: const TextStyle(
                                color: Colors.white54,
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.5,
                              ),
                            ),
                            const SizedBox(height: 10),
                            ...businesses.expand(
                              (business) => [
                                _BarberCard(
                                  business: business,
                                  icon: widget.category.icon,
                                  distanceLabel: _distanceLabelFor(business),
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      FirstVuePageRoute(
                                        builder: (_) => BusinessProfileScreen(
                                          businessName: business.name,
                                          rating: business.rating,
                                          reviews: business.reviews,
                                          verified: business.verified,
                                          distance: _distanceLabelFor(business),
                                          specialty: business.specialty,
                                          profileIcon: widget.category.icon,
                                          profileLabel:
                                              widget.category.profileLabel,
                                          aboutText: widget.category.aboutText,
                                        ),
                                      ),
                                    );
                                  },
                                ),
                                const SizedBox(height: 14),
                              ],
                            ),
                          ],
                        ],
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  const _SearchField({required this.controller, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 56,
      decoration: BoxDecoration(
        color: const Color(0xFF151B22),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xFFD8B56A).withValues(alpha: .22),
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFD8B56A).withValues(alpha: .05),
            blurRadius: 20,
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        style: TextStyle(color: Colors.white),
        decoration: InputDecoration(
          hintText: 'Search name, city, state, or ZIP...',
          hintStyle: TextStyle(color: Colors.white38),
          prefixIcon: Icon(Icons.search, color: Color(0xFFD8B56A)),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(vertical: 17),
        ),
      ),
    );
  }
}

class _EmptySearchResults extends StatelessWidget {
  final VoidCallback onReset;

  const _EmptySearchResults({required this.onReset});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.travel_explore,
              color: Color(0xFFD8B56A),
              size: 44,
            ),
            const SizedBox(height: 14),
            const Text(
              'NO MATCHES FOUND',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.4,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Try a different search or reset your location filters.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white54),
            ),
            const SizedBox(height: 18),
            OutlinedButton.icon(
              onPressed: onReset,
              icon: const Icon(Icons.restart_alt),
              label: const Text('RESET SEARCH'),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFFD8B56A),
                side: const BorderSide(color: Color(0xFFD8B56A)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onPressed;

  const _FilterChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 16),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        foregroundColor: selected ? const Color(0xFFD8B56A) : Colors.white70,
        side: BorderSide(
          color: selected
              ? const Color(0xFFD8B56A)
              : const Color(0xFFD8B56A).withValues(alpha: .24),
        ),
        backgroundColor: selected
            ? const Color(0xFFD8B56A).withValues(alpha: .10)
            : const Color(0xFF151B22),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }
}

class _ApprovedProfessionalCard extends StatelessWidget {
  final ProfessionalProfile profile;
  final IconData icon;
  final VoidCallback onPressed;

  const _ApprovedProfessionalCard({
    required this.profile,
    required this.icon,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final location = [
      profile.city,
      profile.state,
    ].where((part) => part.isNotEmpty).join(', ');
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(21),
        child: Ink(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF10151B),
            borderRadius: BorderRadius.circular(21),
            border: Border.all(
              color: const Color(0xFFD8B56A).withValues(alpha: .4),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 62,
                height: 62,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF151B22),
                  border: Border.all(
                    color: const Color(0xFFD8B56A).withValues(alpha: .65),
                  ),
                ),
                child: Icon(icon, color: const Color(0xFFD8B56A), size: 29),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            profile.displayName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const Icon(
                          Icons.verified,
                          color: Color(0xFFD8B56A),
                          size: 19,
                        ),
                      ],
                    ),
                    const SizedBox(height: 7),
                    Text(
                      profile.services.isEmpty
                          ? profile.type.label
                          : profile.services.take(3).join(' • '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white60,
                        fontSize: 12,
                      ),
                    ),
                    if (location.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        location,
                        style: const TextStyle(
                          color: Colors.white38,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ApprovedBusinessCard extends StatelessWidget {
  final ApprovedBusiness business;
  final VoidCallback onPressed;

  const _ApprovedBusinessCard({
    required this.business,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(21),
        child: Ink(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF10151B),
            borderRadius: BorderRadius.circular(21),
            border: Border.all(
              color: const Color(0xFFD8B56A).withValues(alpha: .34),
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFD8B56A).withValues(alpha: .06),
                blurRadius: 18,
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  color: const Color(0xFFD8B56A).withValues(alpha: .1),
                ),
                child: const Icon(
                  Icons.verified_outlined,
                  color: Color(0xFFD8B56A),
                  size: 30,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            business.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const Icon(
                          Icons.verified,
                          color: Color(0xFFD8B56A),
                          size: 18,
                        ),
                      ],
                    ),
                    const SizedBox(height: 7),
                    Text(
                      business.businessType,
                      style: const TextStyle(color: Colors.white70),
                    ),
                    const SizedBox(height: 5),
                    const Text(
                      'Verified FirstVue business',
                      style: TextStyle(color: Color(0xFFD8B56A), fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BarberCard extends StatefulWidget {
  final _PrototypeBusiness business;
  final IconData icon;
  final String distanceLabel;
  final VoidCallback onPressed;

  const _BarberCard({
    required this.business,
    required this.icon,
    required this.distanceLabel,
    required this.onPressed,
  });

  @override
  State<_BarberCard> createState() => _BarberCardState();
}

class _LocationFilters {
  final String city;
  final String state;
  final String zipCode;

  const _LocationFilters({
    required this.city,
    required this.state,
    required this.zipCode,
  });
}

class _LocationFiltersSheet extends StatefulWidget {
  final _LocationFilters initialFilters;

  const _LocationFiltersSheet({required this.initialFilters});

  @override
  State<_LocationFiltersSheet> createState() => _LocationFiltersSheetState();
}

class _LocationFiltersSheetState extends State<_LocationFiltersSheet> {
  late final TextEditingController _cityController;
  late final TextEditingController _stateController;
  late final TextEditingController _zipCodeController;

  @override
  void initState() {
    super.initState();
    _cityController = TextEditingController(text: widget.initialFilters.city);
    _stateController = TextEditingController(text: widget.initialFilters.state);
    _zipCodeController = TextEditingController(
      text: widget.initialFilters.zipCode,
    );
  }

  @override
  void dispose() {
    _cityController.dispose();
    _stateController.dispose();
    _zipCodeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          20,
          20,
          20 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'LOCATION FILTERS',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Filters apply to prototype location data only.',
              style: TextStyle(color: Colors.white54),
            ),
            const SizedBox(height: 18),
            _LocationTextField(controller: _cityController, label: 'City'),
            const SizedBox(height: 12),
            _LocationTextField(controller: _stateController, label: 'State'),
            const SizedBox(height: 12),
            _LocationTextField(
              controller: _zipCodeController,
              label: 'ZIP code',
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(
                      context,
                      const _LocationFilters(city: '', state: '', zipCode: ''),
                    ),
                    child: const Text('CLEAR'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(
                      context,
                      _LocationFilters(
                        city: _cityController.text.trim(),
                        state: _stateController.text.trim(),
                        zipCode: _zipCodeController.text.trim(),
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFD8B56A),
                      foregroundColor: Colors.black,
                    ),
                    child: const Text('APPLY'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _LocationTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final TextInputType? keyboardType;

  const _LocationTextField({
    required this.controller,
    required this.label,
    this.keyboardType,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white54),
        filled: true,
        fillColor: const Color(0xFF151B22),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color: const Color(0xFFD8B56A).withValues(alpha: .2),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFD8B56A)),
        ),
      ),
    );
  }
}

class _BarberCardState extends State<_BarberCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final business = widget.business;
    const cyan = Color(0xFFD8B56A);

    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapCancel: () => setState(() => _pressed = false),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onPressed();
      },
      child: AnimatedScale(
        scale: _pressed ? .98 : 1,
        duration: const Duration(milliseconds: 100),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            color: _pressed
                ? cyan.withValues(alpha: .11)
                : const Color(0xFF10151B),
            borderRadius: BorderRadius.circular(21),
            border: Border.all(
              color: _pressed ? cyan : Colors.white.withValues(alpha: .08),
              width: _pressed ? 1.5 : 1,
            ),
            boxShadow: _pressed
                ? [
                    BoxShadow(
                      color: cyan.withValues(alpha: .18),
                      blurRadius: 20,
                    ),
                  ]
                : [],
          ),
          child: Row(
            children: [
              Container(
                width: 78,
                height: 78,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF2A241B), Color(0xFF151B22)],
                  ),
                ),
                child: Icon(widget.icon, color: cyan, size: 34),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            business.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        if (business.verified)
                          const Padding(
                            padding: EdgeInsets.only(left: 6),
                            child: Icon(Icons.verified, color: cyan, size: 18),
                          ),
                      ],
                    ),
                    const SizedBox(height: 7),
                    Row(
                      children: [
                        const Icon(
                          Icons.star,
                          color: Color(0xFFE5C16F),
                          size: 17,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${business.rating}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          ' (${business.reviews})',
                          style: const TextStyle(color: Colors.white54),
                        ),
                        const Spacer(),
                        const Icon(
                          Icons.location_on_outlined,
                          color: cyan,
                          size: 15,
                        ),
                        const SizedBox(width: 3),
                        Text(
                          widget.distanceLabel,
                          style: const TextStyle(color: Colors.white54),
                        ),
                      ],
                    ),
                    const SizedBox(height: 9),
                    Text(
                      business.specialty,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      '${business.city}, ${business.state} ${business.zipCode}',
                      style: const TextStyle(
                        color: Colors.white38,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PrototypeBusiness {
  final String name;
  final double rating;
  final int reviews;
  final String distance;
  final bool verified;
  final String specialty;
  final String city;
  final String state;
  final String zipCode;
  final double latitude;
  final double longitude;

  double get distanceMiles => double.parse(distance.split(' ').first);

  const _PrototypeBusiness({
    required this.name,
    required this.rating,
    required this.reviews,
    required this.distance,
    required this.verified,
    required this.specialty,
    required this.city,
    required this.state,
    required this.zipCode,
    required this.latitude,
    required this.longitude,
  });
}
