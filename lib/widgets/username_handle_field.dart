import 'dart:async';

import 'package:flutter/material.dart';

import '../services/username_service.dart';
import '../theme/firstvue_theme.dart';

class UsernameHandleField extends StatefulWidget {
  final TextEditingController controller;
  final String? errorText;
  final ValueChanged<UsernameAvailability>? onAvailabilityChanged;

  const UsernameHandleField({
    super.key,
    required this.controller,
    this.errorText,
    this.onAvailabilityChanged,
  });

  @override
  State<UsernameHandleField> createState() => _UsernameHandleFieldState();
}

class _UsernameHandleFieldState extends State<UsernameHandleField> {
  Timer? _debounce;
  UsernameAvailability _availability = UsernameAvailability.empty;
  String? _initialUsername;
  bool _loadingInitial = true;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onChanged);
    _loadInitial();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    widget.controller.removeListener(_onChanged);
    super.dispose();
  }

  Future<void> _loadInitial() async {
    final current = await UsernameService.fetchUsername();
    if (!mounted) return;
    setState(() {
      _initialUsername = current;
      _loadingInitial = false;
    });
    if (widget.controller.text.trim().isNotEmpty) {
      _scheduleCheck();
    }
  }

  void _onChanged() {
    _scheduleCheck();
  }

  void _scheduleCheck() {
    _debounce?.cancel();
    setState(() => _availability = UsernameAvailability.checking);
    _debounce = Timer(const Duration(milliseconds: 400), _checkNow);
  }

  Future<void> _checkNow() async {
    final raw = widget.controller.text;
    final normalized = UsernameService.normalize(raw);
    if (_initialUsername != null && normalized == _initialUsername) {
      if (!mounted) return;
      setState(() => _availability = UsernameAvailability.available);
      widget.onAvailabilityChanged?.call(UsernameAvailability.available);
      return;
    }

    final availability = await UsernameService.checkAvailability(raw);
    if (!mounted) return;
    setState(() => _availability = availability);
    widget.onAvailabilityChanged?.call(availability);
  }

  Widget? _suffixIcon() {
    if (_loadingInitial || _availability == UsernameAvailability.checking) {
      return const Padding(
        padding: EdgeInsets.all(12),
        child: SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }

    return switch (_availability) {
      UsernameAvailability.available => const Icon(
          Icons.check_circle_outline,
          color: FirstVueColors.teal,
        ),
      UsernameAvailability.taken => const Icon(
          Icons.error_outline,
          color: FirstVueColors.coral,
        ),
      UsernameAvailability.invalid => const Icon(
          Icons.error_outline,
          color: FirstVueColors.coral,
        ),
      UsernameAvailability.error => Icon(
          Icons.warning_amber_outlined,
          color: context.fv.tertiaryText,
        ),
      _ => null,
    };
  }

  String? _helperText() {
    if (widget.errorText != null) return widget.errorText;
    return switch (_availability) {
      UsernameAvailability.available =>
        'This @handle is available. Display names can be shared; handles cannot.',
      UsernameAvailability.taken =>
        'That @handle is already taken. Try another one.',
      UsernameAvailability.invalid =>
        'Use 3–30 lowercase letters, numbers, or underscores.',
      UsernameAvailability.error =>
        'Could not verify availability right now.',
      UsernameAvailability.empty =>
        'Your unique @handle — required for mentions and search.',
      _ => 'Display names can match other users; @handles must be unique.',
    };
  }

  Color _helperColor() {
    if (widget.errorText != null) return FirstVueColors.coral;
    return switch (_availability) {
      UsernameAvailability.available => FirstVueColors.teal,
      UsernameAvailability.taken => FirstVueColors.coral,
      UsernameAvailability.invalid => FirstVueColors.coral,
      _ => context.fv.tertiaryText,
    };
  }

  @override
  Widget build(BuildContext context) {
    final fv = context.fv;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: widget.controller,
          style: TextStyle(color: fv.primaryText),
          decoration: InputDecoration(
            labelText: '@handle',
            hintText: 'your_unique_tag',
            prefixText: '@',
            prefixStyle: const TextStyle(color: FirstVueColors.teal),
            labelStyle: TextStyle(color: fv.secondaryText),
            errorText: widget.errorText,
            suffixIcon: _suffixIcon(),
            filled: true,
            fillColor: fv.inputFill,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: fv.borderSubtle),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: FirstVueColors.teal.withValues(alpha: .55),
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          _helperText() ?? '',
          style: TextStyle(color: _helperColor(), fontSize: 12, height: 1.35),
        ),
      ],
    );
  }
}
