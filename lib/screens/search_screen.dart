import 'package:flutter/material.dart';
import '../navigation/firstvue_page_route.dart';

import 'barber_results_screen.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _searchController = TextEditingController();
  DiscoveryCategory _category = DiscoveryCategory.barbers;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _search([String? query]) {
    final value = (query ?? _searchController.text).trim();
    if (value.isEmpty) return;

    Navigator.push(
      context,
      FirstVuePageRoute(
        builder: (_) =>
            BarberResultsScreen(initialQuery: value, category: _category),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'SEARCH',
              style: TextStyle(
                fontFamily: 'CormorantGaramond',
                color: Colors.white,
                fontSize: 25,
                fontWeight: FontWeight.w600,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Choose people or places, then search by name, specialty, city, state, or ZIP.',
              style: TextStyle(color: Colors.white54, height: 1.4),
            ),
            const SizedBox(height: 22),
            DropdownButtonFormField<DiscoveryCategory>(
              initialValue: _category,
              dropdownColor: const Color(0xFF151B22),
              decoration: InputDecoration(
                labelText: 'Search category',
                prefixIcon: Icon(
                  _category.icon,
                  color: const Color(0xFFD8B56A),
                ),
                filled: true,
                fillColor: const Color(0xFF151B22),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(18),
                  borderSide: BorderSide(
                    color: const Color(0xFFD8B56A).withValues(alpha: .25),
                  ),
                ),
              ),
              items: DiscoveryCategory.values
                  .map(
                    (category) => DropdownMenuItem(
                      value: category,
                      child: Text(category.title),
                    ),
                  )
                  .toList(),
              onChanged: (category) {
                if (category != null) setState(() => _category = category);
              },
            ),
            const SizedBox(height: 14),
            Container(
              height: 58,
              decoration: BoxDecoration(
                color: const Color(0xFF151B22),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: const Color(0xFFD8B56A).withValues(alpha: .25),
                ),
              ),
              child: TextField(
                controller: _searchController,
                onSubmitted: _search,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  hintText: 'Search FirstVue...',
                  hintStyle: TextStyle(color: Colors.white38),
                  prefixIcon: Icon(Icons.search, color: Color(0xFFD8B56A)),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(vertical: 17),
                ),
              ),
            ),
            const SizedBox(height: 30),
            const Text(
              'QUICK SEARCHES',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _QuickSearch(
                  label: 'Barbers',
                  onPressed: () => _openCategory(DiscoveryCategory.barbers),
                ),
                _QuickSearch(
                  label: 'Stylists',
                  onPressed: () => _openCategory(DiscoveryCategory.stylists),
                ),
                _QuickSearch(
                  label: 'Salons',
                  onPressed: () => _openCategory(DiscoveryCategory.salons),
                ),
                _QuickSearch(
                  label: 'Barbershops',
                  onPressed: () => _openCategory(DiscoveryCategory.barbershops),
                ),
              ],
            ),
            const Spacer(),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF10151B),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: Colors.white.withValues(alpha: .07)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, color: Color(0xFFD8B56A)),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Individual results are prototype-only. Approved location results come from FirstVue business verification.',
                      style: TextStyle(color: Colors.white54, height: 1.35),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openCategory(DiscoveryCategory category) {
    Navigator.push(
      context,
      FirstVuePageRoute(
        builder: (_) => BarberResultsScreen(category: category),
      ),
    );
  }
}

class _QuickSearch extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;

  const _QuickSearch({required this.label, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: const Color(0xFFD8B56A),
        side: BorderSide(color: const Color(0xFFD8B56A).withValues(alpha: .3)),
        backgroundColor: const Color(0xFF151B22),
      ),
      child: Text(label),
    );
  }
}
