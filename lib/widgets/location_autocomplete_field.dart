import 'package:flutter/material.dart';
import '../theme/firstvue_theme.dart';

import '../data/us_locations.dart';

class LocationAutocompleteField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final LocationFieldType type;
  final int lines;
  final String? stateHint;
  final bool enabled;
  final String? helperOverride;

  const LocationAutocompleteField({
    super.key,
    required this.controller,
    required this.label,
    required this.type,
    this.lines = 1,
    this.stateHint,
    this.enabled = true,
    this.helperOverride,
  });

  List<String> _options(String query) {
    return switch (type) {
      LocationFieldType.state => UsLocations.matchingStates(query),
      LocationFieldType.city =>
        UsLocations.matchingCities(query, stateHint: stateHint),
      LocationFieldType.address => UsLocations.matchingAddresses(query),
    };
  }

  String get _helperText {
    if (helperOverride != null) return helperOverride!;
    if (type == LocationFieldType.city &&
        stateHint != null &&
        stateHint!.trim().isNotEmpty) {
      return 'Select a city or type to filter';
    }
    return 'Type ${UsLocations.minQueryLength}+ letters for suggestions';
  }

  @override
  Widget build(BuildContext context) {
    final fv = context.fv;
    return Autocomplete<String>(
      optionsBuilder: (textEditingValue) {
        if (!enabled) return const Iterable<String>.empty();
        return _options(textEditingValue.text);
      },
      onSelected: (selection) {
        controller.text = selection;
      },
      fieldViewBuilder: (context, textController, focusNode, onFieldSubmitted) {
        if (textController.text != controller.text) {
          textController.value = textController.value.copyWith(
            text: controller.text,
            selection: TextSelection.collapsed(offset: controller.text.length),
          );
        }
        return TextField(
          controller: textController,
          focusNode: focusNode,
          enabled: enabled,
          maxLines: lines,
          onChanged: (value) => controller.text = value,
          style: TextStyle(color: fv.primaryText),
          decoration: InputDecoration(
            labelText: label,
            helperText: enabled ? _helperText : 'Select a state first',
            helperStyle: TextStyle(color: fv.tertiaryText, fontSize: 11),
            labelStyle: TextStyle(color: fv.secondaryText),
            hintText: type == LocationFieldType.city ? 'Select a city' : null,
            hintStyle: TextStyle(color: fv.tertiaryText),
            filled: true,
            fillColor: fv.inputFill,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: fv.borderSubtle),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: fv.borderSubtle),
            ),
            disabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(
                color: fv.borderSubtle.withValues(alpha: 0.5),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(
                color: FirstVueColors.teal.withValues(alpha: .55),
              ),
            ),
            suffixIcon: type == LocationFieldType.city
                ? Icon(Icons.arrow_drop_down, color: fv.secondaryText)
                : null,
          ),
        );
      },
      optionsViewBuilder: (context, onSelected, options) {
        if (options.isEmpty) return const SizedBox.shrink();
        final optionsFv = context.fv;
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            color: optionsFv.elevatedSurface,
            elevation: 6,
            borderRadius: BorderRadius.circular(12),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 220, maxWidth: 400),
              child: ListView.builder(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                itemCount: options.length,
                itemBuilder: (context, index) {
                  final option = options.elementAt(index);
                  return ListTile(
                    dense: true,
                    title: Text(
                      option,
                      style: TextStyle(
                        color: optionsFv.primaryText,
                        fontSize: 14,
                      ),
                    ),
                    onTap: () => onSelected(option),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }
}

enum LocationFieldType { state, city, address }
