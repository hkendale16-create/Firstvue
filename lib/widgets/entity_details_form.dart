import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/firstvue_theme.dart';

/// Conditional entity-detail fields rendered from a schema (not one giant form).
class EntityDetailField {
  final String key;
  final String label;
  final EntityDetailFieldType type;
  final String? hint;
  final List<String>? options;

  const EntityDetailField({
    required this.key,
    required this.label,
    this.type = EntityDetailFieldType.text,
    this.hint,
    this.options,
  });
}

enum EntityDetailFieldType { text, multiline, number, toggle, chips, dropdown }

/// Built-in schemas keyed by entity category / professional type / property.
class EntityDetailSchemas {
  EntityDetailSchemas._();

  static List<EntityDetailField> forBusinessType(String? businessType) {
    final type = (businessType ?? '').toLowerCase();
    final common = <EntityDetailField>[
      const EntityDetailField(key: 'hours', label: 'Hours', hint: 'Mon–Fri 9–5'),
      const EntityDetailField(key: 'service_area', label: 'Service area'),
      const EntityDetailField(
        key: 'price_range',
        label: 'Price range',
        type: EntityDetailFieldType.dropdown,
        options: ['\$', '\$\$', '\$\$\$', '\$\$\$\$'],
      ),
      const EntityDetailField(
        key: 'payment_methods',
        label: 'Payment methods',
        type: EntityDetailFieldType.chips,
        hint: 'Cash, Card, Venmo',
      ),
      const EntityDetailField(
        key: 'amenities',
        label: 'Amenities',
        type: EntityDetailFieldType.chips,
      ),
      const EntityDetailField(
        key: 'languages',
        label: 'Languages',
        type: EntityDetailFieldType.chips,
      ),
    ];

    if (type.contains('restaurant') ||
        type.contains('bar') ||
        type.contains('food') ||
        type.contains('dining')) {
      return [
        const EntityDetailField(key: 'cuisine', label: 'Cuisine'),
        ...common,
        const EntityDetailField(
          key: 'reservations',
          label: 'Takes reservations',
          type: EntityDetailFieldType.toggle,
        ),
        const EntityDetailField(
          key: 'walk_ins',
          label: 'Walk-ins welcome',
          type: EntityDetailFieldType.toggle,
        ),
        const EntityDetailField(
          key: 'dine_in',
          label: 'Dine-in',
          type: EntityDetailFieldType.toggle,
        ),
        const EntityDetailField(
          key: 'takeout',
          label: 'Takeout',
          type: EntityDetailFieldType.toggle,
        ),
        const EntityDetailField(
          key: 'delivery',
          label: 'Delivery',
          type: EntityDetailFieldType.toggle,
        ),
        const EntityDetailField(key: 'happy_hour', label: 'Happy hour'),
        const EntityDetailField(key: 'parking', label: 'Parking'),
        const EntityDetailField(
          key: 'dietary_options',
          label: 'Dietary options',
          type: EntityDetailFieldType.chips,
        ),
      ];
    }

    if (type.contains('barber') ||
        type.contains('beauty') ||
        type.contains('salon') ||
        type.contains('spa')) {
      return [
        const EntityDetailField(key: 'specialty', label: 'Specialty'),
        ...common,
        const EntityDetailField(
          key: 'booking',
          label: 'Booking info',
          hint: 'Book via app / walk-ins',
        ),
        const EntityDetailField(
          key: 'walk_ins',
          label: 'Walk-ins welcome',
          type: EntityDetailFieldType.toggle,
        ),
        const EntityDetailField(
          key: 'mobile_service',
          label: 'Mobile service',
          type: EntityDetailFieldType.toggle,
        ),
        const EntityDetailField(
          key: 'experience',
          label: 'Experience',
          hint: 'Years in business',
        ),
      ];
    }

    return common;
  }

  static List<EntityDetailField> forProfessionalType(String? professionalType) {
    return const [
      EntityDetailField(key: 'title', label: 'Title'),
      EntityDetailField(key: 'company', label: 'Company'),
      EntityDetailField(key: 'specialty', label: 'Specialty'),
      EntityDetailField(
        key: 'experience_years',
        label: 'Years of experience',
        type: EntityDetailFieldType.number,
      ),
      EntityDetailField(
        key: 'credentials',
        label: 'Credentials',
        type: EntityDetailFieldType.chips,
      ),
      EntityDetailField(
        key: 'licenses',
        label: 'Licenses',
        type: EntityDetailFieldType.chips,
      ),
      EntityDetailField(key: 'service_area', label: 'Service area'),
    ];
  }

  static List<EntityDetailField> forRental() {
    return const [
      EntityDetailField(
        key: 'property_type',
        label: 'Property type',
        type: EntityDetailFieldType.dropdown,
        options: ['Apartment', 'House', 'Condo', 'Studio', 'Room', 'Other'],
      ),
      EntityDetailField(
        key: 'bedrooms',
        label: 'Bedrooms',
        type: EntityDetailFieldType.number,
      ),
      EntityDetailField(
        key: 'bathrooms',
        label: 'Bathrooms',
        type: EntityDetailFieldType.number,
      ),
      EntityDetailField(
        key: 'square_footage',
        label: 'Square footage',
        type: EntityDetailFieldType.number,
      ),
      EntityDetailField(key: 'lease_length', label: 'Lease length'),
      EntityDetailField(
        key: 'utilities',
        label: 'Utilities',
        type: EntityDetailFieldType.chips,
      ),
      EntityDetailField(key: 'parking', label: 'Parking'),
      EntityDetailField(key: 'pet_policy', label: 'Pet policy'),
      EntityDetailField(
        key: 'amenities',
        label: 'Amenities',
        type: EntityDetailFieldType.chips,
      ),
    ];
  }

  static List<EntityDetailField> forGroupOrCommunity() {
    return const [
      EntityDetailField(
        key: 'rules_summary',
        label: 'Rules summary',
        type: EntityDetailFieldType.multiline,
      ),
      EntityDetailField(
        key: 'membership_details',
        label: 'Membership details',
        type: EntityDetailFieldType.multiline,
      ),
    ];
  }
}

class EntityDetailsForm extends StatefulWidget {
  final List<EntityDetailField> fields;
  final Map<String, dynamic> initialValues;
  final ValueChanged<Map<String, dynamic>>? onChanged;

  const EntityDetailsForm({
    super.key,
    required this.fields,
    this.initialValues = const {},
    this.onChanged,
  });

  @override
  State<EntityDetailsForm> createState() => _EntityDetailsFormState();
}

class _EntityDetailsFormState extends State<EntityDetailsForm> {
  late Map<String, dynamic> _values;
  final _controllers = <String, TextEditingController>{};

  @override
  void initState() {
    super.initState();
    _values = Map<String, dynamic>.from(widget.initialValues);
    for (final field in widget.fields) {
      if (field.type == EntityDetailFieldType.toggle) continue;
      final raw = _values[field.key];
      final text = raw is List ? raw.join(', ') : (raw?.toString() ?? '');
      _controllers[field.key] = TextEditingController(text: text);
    }
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _emit() => widget.onChanged?.call(Map<String, dynamic>.from(_values));

  @override
  Widget build(BuildContext context) {
    final fv = context.fv;
    if (widget.fields.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'DETAILS',
          style: TextStyle(
            color: fv.primaryText,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.4,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Only fields relevant to this profile type are shown.',
          style: TextStyle(color: fv.tertiaryText, fontSize: 12, height: 1.4),
        ),
        const SizedBox(height: 14),
        for (final field in widget.fields) ...[
          _buildField(context, field),
          const SizedBox(height: 12),
        ],
      ],
    );
  }

  Widget _buildField(BuildContext context, EntityDetailField field) {
    final fv = context.fv;
    switch (field.type) {
      case EntityDetailFieldType.toggle:
        final value = _values[field.key] == true;
        return SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(field.label, style: TextStyle(color: fv.primaryText)),
          value: value,
          activeThumbColor: FirstVueColors.gold,
          onChanged: (v) {
            setState(() => _values[field.key] = v);
            _emit();
          },
        );
      case EntityDetailFieldType.dropdown:
        final options = field.options ?? const <String>[];
        final current = (_values[field.key] as String?) ?? '';
        return DropdownButtonFormField<String>(
          initialValue: options.contains(current) ? current : null,
          dropdownColor: fv.elevatedSurface,
          decoration: InputDecoration(
            labelText: field.label,
            labelStyle: TextStyle(color: fv.secondaryText),
            filled: true,
            fillColor: fv.inputFill,
          ),
          items: [
            for (final opt in options)
              DropdownMenuItem(
                value: opt,
                child: Text(opt, style: TextStyle(color: fv.primaryText)),
              ),
          ],
          onChanged: (v) {
            setState(() => _values[field.key] = v);
            _emit();
          },
        );
      case EntityDetailFieldType.number:
        return TextField(
          controller: _controllers[field.key],
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
          ],
          style: TextStyle(color: fv.primaryText),
          decoration: InputDecoration(
            labelText: field.label,
            hintText: field.hint,
            labelStyle: TextStyle(color: fv.secondaryText),
            hintStyle: TextStyle(color: fv.tertiaryText),
            filled: true,
            fillColor: fv.inputFill,
          ),
          onChanged: (v) {
            _values[field.key] = num.tryParse(v.trim());
            _emit();
          },
        );
      case EntityDetailFieldType.chips:
        return TextField(
          controller: _controllers[field.key],
          style: TextStyle(color: fv.primaryText),
          decoration: InputDecoration(
            labelText: field.label,
            hintText: field.hint ?? 'Separate with commas',
            labelStyle: TextStyle(color: fv.secondaryText),
            hintStyle: TextStyle(color: fv.tertiaryText),
            filled: true,
            fillColor: fv.inputFill,
          ),
          onChanged: (v) {
            _values[field.key] = v
                .split(',')
                .map((e) => e.trim())
                .where((e) => e.isNotEmpty)
                .toList();
            _emit();
          },
        );
      case EntityDetailFieldType.multiline:
        return TextField(
          controller: _controllers[field.key],
          minLines: 3,
          maxLines: 5,
          style: TextStyle(color: fv.primaryText),
          decoration: InputDecoration(
            labelText: field.label,
            hintText: field.hint,
            labelStyle: TextStyle(color: fv.secondaryText),
            hintStyle: TextStyle(color: fv.tertiaryText),
            filled: true,
            fillColor: fv.inputFill,
          ),
          onChanged: (v) {
            _values[field.key] = v.trim().isEmpty ? null : v.trim();
            _emit();
          },
        );
      case EntityDetailFieldType.text:
        return TextField(
          controller: _controllers[field.key],
          style: TextStyle(color: fv.primaryText),
          decoration: InputDecoration(
            labelText: field.label,
            hintText: field.hint,
            labelStyle: TextStyle(color: fv.secondaryText),
            hintStyle: TextStyle(color: fv.tertiaryText),
            filled: true,
            fillColor: fv.inputFill,
          ),
          onChanged: (v) {
            _values[field.key] = v.trim().isEmpty ? null : v.trim();
            _emit();
          },
        );
    }
  }
}

/// Read-only display of entity_details for public profiles.
class EntityDetailsSection extends StatelessWidget {
  final String title;
  final Map<String, dynamic> details;
  final List<EntityDetailField> fields;

  const EntityDetailsSection({
    super.key,
    this.title = 'About',
    required this.details,
    required this.fields,
  });

  @override
  Widget build(BuildContext context) {
    final fv = context.fv;
    final rows = <MapEntry<String, String>>[];
    for (final field in fields) {
      final raw = details[field.key];
      if (raw == null) continue;
      if (raw is bool) {
        rows.add(MapEntry(field.label, raw ? 'Yes' : 'No'));
      } else if (raw is List) {
        if (raw.isEmpty) continue;
        rows.add(MapEntry(field.label, raw.join(', ')));
      } else {
        final text = raw.toString().trim();
        if (text.isEmpty) continue;
        rows.add(MapEntry(field.label, text));
      }
    }
    if (rows.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title.toUpperCase(),
            style: TextStyle(
              color: fv.secondaryText,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.1,
            ),
          ),
          const SizedBox(height: 10),
          for (final row in rows) ...[
            Text(row.key, style: TextStyle(color: fv.tertiaryText, fontSize: 12)),
            const SizedBox(height: 2),
            Text(
              row.value,
              style: TextStyle(color: fv.primaryText, height: 1.35),
            ),
            const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }
}

Map<String, dynamic> parseEntityDetails(dynamic raw) {
  if (raw is Map<String, dynamic>) return Map<String, dynamic>.from(raw);
  if (raw is Map) return Map<String, dynamic>.from(raw);
  if (raw is String && raw.trim().isNotEmpty) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    } catch (_) {}
  }
  return {};
}
