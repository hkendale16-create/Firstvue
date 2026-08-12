import 'package:flutter/material.dart';

import '../data/us_locations.dart';

class LocationAutocompleteField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final LocationFieldType type;
  final int lines;

  const LocationAutocompleteField({
    super.key,
    required this.controller,
    required this.label,
    required this.type,
    this.lines = 1,
  });

  List<String> _options(String query) {
    return switch (type) {
      LocationFieldType.state => UsLocations.matchingStates(query),
      LocationFieldType.city => UsLocations.matchingCities(query),
      LocationFieldType.address => UsLocations.matchingAddresses(query),
    };
  }

  @override
  Widget build(BuildContext context) {
    return Autocomplete<String>(
      optionsBuilder: (textEditingValue) {
        return _options(textEditingValue.text);
      },
      onSelected: (selection) {
        controller.text = selection;
      },
      fieldViewBuilder: (context, textController, focusNode, onFieldSubmitted) {
        if (textController.text.isEmpty && controller.text.isNotEmpty) {
          textController.text = controller.text;
        }
        return TextField(
          controller: textController,
          focusNode: focusNode,
          maxLines: lines,
          onChanged: (value) => controller.text = value,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            labelText: label,
            helperText: 'Type ${UsLocations.minQueryLength}+ letters for suggestions',
            helperStyle: const TextStyle(color: Colors.white38, fontSize: 11),
            labelStyle: const TextStyle(color: Colors.white54),
            filled: true,
            fillColor: const Color(0xFF151B22),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
          ),
        );
      },
      optionsViewBuilder: (context, onSelected, options) {
        if (options.isEmpty) return const SizedBox.shrink();
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            color: const Color(0xFF151B22),
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
                      style: const TextStyle(color: Colors.white, fontSize: 14),
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
