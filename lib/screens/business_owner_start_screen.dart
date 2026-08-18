import 'dart:typed_data';

import 'package:flutter/material.dart';
import '../theme/firstvue_theme.dart';
import '../navigation/firstvue_page_route.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../constants/business_types.dart';
import '../services/business_media_service.dart';
import '../services/business_submission_service.dart';
import '../utils/entity_address_requirements.dart';
import '../utils/form_validators.dart';
import '../widgets/fv_ui.dart';
import '../widgets/media_picker_sheet.dart';
import '../widgets/smart_address_field.dart';
import '../auth/ensure_signed_in.dart';
import 'rentals_screen.dart';

class BusinessOwnerStartScreen extends StatelessWidget {
  const BusinessOwnerStartScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'BUSINESS TOOLS',
          style: TextStyle(
            fontFamily: 'CormorantGaramond',
            color: FirstVueColors.gold,
            fontSize: 22,
            fontWeight: FontWeight.w600,
            letterSpacing: 2.2,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          Text(
            'Choose how you want to get on FirstVue. Nothing is public until it is approved.',
            textAlign: TextAlign.center,
            style: TextStyle(color: context.fv.secondaryText, height: 1.45),
          ),
          const SizedBox(height: 20),
          _WorkflowOption(
            icon: Icons.storefront_outlined,
            title: 'Claim a listed business',
            description: 'Match your shop, then send a claim for review.',
            accent: FirstVueColors.gold,
            actionLabel: 'Claim',
            filledAction: false,
            onTap: () {
              Navigator.push(
                context,
                FirstVuePageRoute(
                  builder: (_) => const _ClaimBusinessScreen(),
                ),
              );
            },
          ),
          const SizedBox(height: 14),
          _WorkflowOption(
            icon: Icons.note_add_outlined,
            title: 'Add an unlisted business',
            description: 'Submit required details for FirstVue verification.',
            accent: FirstVueColors.teal,
            actionLabel: 'Start',
            filledAction: true,
            onTap: () {
              Navigator.push(
                context,
                FirstVuePageRoute(builder: (_) => const _NewBusinessScreen()),
              );
            },
          ),
          const SizedBox(height: 14),
          _WorkflowOption(
            icon: Icons.key_outlined,
            title: 'Post an available rental',
            description: 'Booth or suite with weekly or monthly pricing.',
            accent: FirstVueColors.gold,
            actionLabel: 'Create',
            filledAction: false,
            onTap: () {
              Navigator.push(
                context,
                FirstVuePageRoute(builder: (_) => const PostRentalScreen()),
              );
            },
          ),
          const SizedBox(height: 20),
          const _WorkflowNotice(),
        ],
      ),
    );
  }
}

class _WorkflowOption extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final Color accent;
  final String actionLabel;
  final bool filledAction;
  final VoidCallback onTap;

  const _WorkflowOption({
    required this.icon,
    required this.title,
    required this.description,
    required this.accent,
    required this.actionLabel,
    required this.filledAction,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final fv = context.fv;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Ink(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: fv.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: fv.borderSubtle),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: .04),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: accent,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: Colors.white, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: fv.primaryText,
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: TextStyle(
                        color: fv.secondaryText,
                        height: 1.35,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              filledAction
                  ? FilledButton(
                      onPressed: onTap,
                      style: FilledButton.styleFrom(
                        backgroundColor: accent,
                        foregroundColor: Colors.white,
                        visualDensity: VisualDensity.compact,
                      ),
                      child: Text(actionLabel),
                    )
                  : OutlinedButton(
                      onPressed: onTap,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: FirstVueColors.gold,
                        side: const BorderSide(color: FirstVueColors.gold),
                        visualDensity: VisualDensity.compact,
                      ),
                      child: Text(actionLabel),
                    ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ClaimBusinessScreen extends StatelessWidget {
  const _ClaimBusinessScreen();

  static const _businesses = [
    ('Elite Fade Studio', 'Atlanta, GA 30303'),
    ('The Groom Room', 'Atlanta, GA 30318'),
    ('Prime Cuts ATL', 'Decatur, GA 30030'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        surfaceTintColor: Colors.transparent,
        title: const Text('CLAIM A BUSINESS'),
      ),
      body: ListView.separated(
        padding: const EdgeInsets.all(20),
        itemCount: _businesses.length + 1,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          if (index == 0) {
            return const Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: Text(
                'Choose the prototype listing that best matches your business.',
                style: TextStyle(height: 1.4),
              ),
            );
          }

          final business = _businesses[index - 1];
          return ListTile(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(17),
              side: BorderSide(color: Colors.black12),
            ),
            leading: const Icon(Icons.content_cut, color: Color(0xFFD8B56A)),
            title: Text(
              business.$1,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(business.$2),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.push(
                context,
                FirstVuePageRoute(
                  builder: (_) => _VerificationFormScreen(
                    businessName: business.$1,
                    isClaim: true,
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _NewBusinessScreen extends StatefulWidget {
  const _NewBusinessScreen();

  @override
  State<_NewBusinessScreen> createState() => _NewBusinessScreenState();
}

class _NewBusinessScreenState extends State<_NewBusinessScreen> {
  final _businessController = TextEditingController();
  final _customTypeController = TextEditingController();
  final _industries = primaryIndustryOptions();
  late BusinessIndustryOption _industry;
  BusinessTypeOption? _businessType;
  final List<String> _services = [];
  XFile? _avatarFile;
  Uint8List? _avatarBytes;
  bool _industryFocused = false;
  bool _typeFocused = false;

  @override
  void initState() {
    super.initState();
    _industry = _industries.firstWhere(
      (i) => i.slug == 'beauty-grooming',
      orElse: () => _industries.first,
    );
    final types = businessTypesForIndustry(_industry.slug);
    _businessType = types.isEmpty ? null : types.first;
  }

  @override
  void dispose() {
    _businessController.dispose();
    _customTypeController.dispose();
    super.dispose();
  }

  Future<void> _pickAvatar() async {
    final files = await showImagePickerSheet(context);
    if (files == null || files.isEmpty || !mounted) return;
    final bytes = await files.first.readAsBytes();
    if (!mounted) return;
    setState(() {
      _avatarFile = files.first;
      _avatarBytes = bytes;
    });
  }

  Future<void> _pickIndustry() async {
    setState(() {
      _industryFocused = true;
      _typeFocused = false;
    });
    final selected = await showFvSearchablePicker(
      context: context,
      title: 'Choose primary industry',
      searchHint: 'Search industries',
      selectedId: _industry.slug,
      options: [
        for (final industry in _industries)
          FvPickerOption(
            id: industry.slug,
            label: industry.label,
            icon: industry.icon,
            iconColor: industry.accent,
          ),
      ],
    );
    if (!mounted) return;
    setState(() => _industryFocused = false);
    if (selected == null) return;
    final next = _industries.firstWhere((i) => i.slug == selected.id);
    final types = businessTypesForIndustry(next.slug);
    setState(() {
      _industry = next;
      _businessType = types.isEmpty ? null : types.first;
      _services.clear();
    });
  }

  Future<void> _pickBusinessType() async {
    setState(() {
      _typeFocused = true;
      _industryFocused = false;
    });
    final types = businessTypesForIndustry(_industry.slug);
    final selected = await showFvSearchablePicker(
      context: context,
      title: 'Choose business type',
      searchHint: 'Search business types',
      selectedId: _businessType?.slug,
      options: [
        for (final type in types)
          FvPickerOption(
            id: type.slug,
            label: type.label,
            icon: type.icon,
            iconColor: FirstVueColors.gold,
          ),
      ],
    );
    if (!mounted) return;
    setState(() => _typeFocused = false);
    if (selected == null) return;
    setState(() {
      _businessType = types.firstWhere((t) => t.slug == selected.id);
      if (!(_businessType?.isOther ?? false)) {
        _customTypeController.clear();
      }
    });
  }

  Future<void> _addService() async {
    final suggestions =
        industryServiceSuggestions[_industry.slug] ??
        industryServiceSuggestions['general-business']!;
    final available = suggestions.where((s) => !_services.contains(s)).toList();
    const customId = '__custom__';
    final selected = await showFvSearchablePicker(
      context: context,
      title: 'Add service',
      searchHint: 'Search or pick a service',
      continueLabel: 'Add',
      options: [
        for (final service in available)
          FvPickerOption(id: service, label: service, icon: Icons.spa_outlined),
        const FvPickerOption(
          id: customId,
          label: 'Custom service…',
          icon: Icons.edit_outlined,
        ),
      ],
    );
    if (!mounted || selected == null) return;
    if (selected.id == customId) {
      final controller = TextEditingController();
      final custom = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: ctx.fv.surface,
          title: const Text('Custom service'),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(hintText: 'Service name'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, controller.text.trim()),
              child: const Text('Add'),
            ),
          ],
        ),
      );
      if (custom == null || custom.isEmpty || !mounted) return;
      setState(() {
        if (!_services.contains(custom)) _services.add(custom);
      });
      return;
    }
    setState(() {
      if (!_services.contains(selected.label)) _services.add(selected.label);
    });
  }

  void _continue() {
    final name = _businessController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter your business name first.')),
      );
      return;
    }
    if (_businessType == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Choose a business type to continue.')),
      );
      return;
    }
    final customType = _customTypeController.text.trim();
    if (_businessType!.isOther && customType.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter your custom business type.')),
      );
      return;
    }
    final typeLabel = _businessType!.isOther ? customType : _businessType!.label;
    Navigator.push(
      context,
      FirstVuePageRoute(
        builder: (_) => _VerificationFormScreen(
          businessName: name,
          businessType: typeLabel,
          industrySlug: _industry.slug,
          services: List<String>.from(_services),
          avatarFile: _avatarFile,
          isClaim: false,
          stepLabel: '2 of 3',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final fv = context.fv;
    return Scaffold(
      backgroundColor: fv.background,
      appBar: fvAppBar(
        context: context,
        title: 'Add business',
        subtitle: '1 of 3',
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: FvUi.pagePadding(top: 12, bottom: 16),
              children: [
                Center(
                  child: FvCircularPhotoPicker(
                    image: _avatarBytes == null
                        ? null
                        : MemoryImage(_avatarBytes!),
                    onTap: _pickAvatar,
                    onRemove: _avatarBytes == null
                        ? null
                        : () => setState(() {
                            _avatarBytes = null;
                            _avatarFile = null;
                          }),
                  ),
                ),
                const SizedBox(height: 22),
                FvCompactField(
                  label: 'Business name',
                  hint: 'Enter business name',
                  controller: _businessController,
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 14),
                FvSelectorField(
                  label: 'Primary industry',
                  value: _industry.label,
                  hint: 'Select industry',
                  icon: _industry.icon,
                  iconColor: _industry.accent,
                  focused: _industryFocused,
                  onTap: _pickIndustry,
                ),
                const SizedBox(height: 14),
                FvSelectorField(
                  label: 'Business type',
                  value: _businessType?.label,
                  hint: 'Select business type',
                  icon: _businessType?.icon ?? Icons.storefront_outlined,
                  focused: _typeFocused,
                  onTap: _pickBusinessType,
                ),
                if (_businessType?.isOther ?? false) ...[
                  const SizedBox(height: 14),
                  FvCompactField(
                    label: 'Custom business type',
                    hint: 'Describe your business type',
                    controller: _customTypeController,
                    onChanged: (_) => setState(() {}),
                  ),
                ],
                const SizedBox(height: 18),
                Text(
                  'Additional services (optional)',
                  style: TextStyle(
                    color: fv.secondaryText,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final service in _services)
                      FvServiceChip(
                        label: service,
                        icon: Icons.content_cut,
                        onRemove: () =>
                            setState(() => _services.remove(service)),
                      ),
                    FvAddChip(label: 'Add service', onTap: _addService),
                  ],
                ),
              ],
            ),
          ),
          FvStickyCta(label: 'Continue', onPressed: _continue),
        ],
      ),
    );
  }
}

class _VerificationFormScreen extends StatefulWidget {
  final String businessName;
  final String? businessType;
  final String? industrySlug;
  final List<String> services;
  final XFile? avatarFile;
  final bool isClaim;
  final String stepLabel;

  const _VerificationFormScreen({
    required this.businessName,
    this.businessType,
    this.industrySlug,
    this.services = const [],
    this.avatarFile,
    required this.isClaim,
    this.stepLabel = '2 of 3',
  });

  @override
  State<_VerificationFormScreen> createState() =>
      _VerificationFormScreenState();
}

class _VerificationFormScreenState extends State<_VerificationFormScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _businessPhoneController = TextEditingController();
  final _businessEmailController = TextEditingController();
  final _websiteController = TextEditingController();
  final _addressController = TextEditingController();
  final _address2Controller = TextEditingController();
  final _cityController = TextEditingController();
  final _stateController = TextEditingController();
  final _zipController = TextEditingController();
  final _instagramController = TextEditingController();
  final _facebookController = TextEditingController();
  final _tiktokController = TextEditingController();
  final _xController = TextEditingController();
  final _youtubeController = TextEditingController();
  final _addressFieldKey = GlobalKey<SmartAddressFieldState>();

  AddressResult? _selectedAddress;
  double? _latitude;
  double? _longitude;
  String? _placeId;
  String? _formattedAddress;
  String? _contactPreference;
  bool _isSubmitting = false;
  bool _preferenceFocused = false;

  static const _preferences = <String>[
    'Phone',
    'Email',
    'Website',
    'Message in app',
  ];

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _businessPhoneController.dispose();
    _businessEmailController.dispose();
    _websiteController.dispose();
    _addressController.dispose();
    _address2Controller.dispose();
    _cityController.dispose();
    _stateController.dispose();
    _zipController.dispose();
    _instagramController.dispose();
    _facebookController.dispose();
    _tiktokController.dispose();
    _xController.dispose();
    _youtubeController.dispose();
    super.dispose();
  }

  void _onAddressSelected(AddressResult result) {
    setState(() {
      _selectedAddress = result;
      _latitude = result.lat;
      _longitude = result.lng;
      _placeId = result.placeId;
      _formattedAddress = result.formatted;
    });
  }

  Future<void> _pickPreference() async {
    setState(() => _preferenceFocused = true);
    final selected = await showFvSearchablePicker(
      context: context,
      title: 'Public contact preference',
      searchHint: 'Search',
      selectedId: _contactPreference,
      options: [
        for (final pref in _preferences)
          FvPickerOption(id: pref, label: pref, icon: Icons.contact_page_outlined),
      ],
    );
    if (!mounted) return;
    setState(() {
      _preferenceFocused = false;
      if (selected != null) _contactPreference = selected.id;
    });
  }

  String? _validationError() {
    if (_nameController.text.trim().isEmpty ||
        _emailController.text.trim().isEmpty) {
      return 'Enter your name and email to continue.';
    }
    if (!FormValidators.isEmail(_emailController.text)) {
      return 'Enter a valid verification email.';
    }
    final phoneErr = FormValidators.optionalPhone(_businessPhoneController.text);
    if (phoneErr != null) return phoneErr;
    final bizEmailErr = FormValidators.optionalEmail(
      _businessEmailController.text,
    );
    if (bizEmailErr != null) return bizEmailErr;
    final webErr = FormValidators.optionalWebsite(_websiteController.text);
    if (webErr != null) return webErr;
    final zipErr = FormValidators.optionalUsZip(_zipController.text);
    if (zipErr != null) return zipErr;
    if (widget.isClaim) return null;
    return EntityAddressRequirements.validate(
      _currentAddress(),
      kind: EntityAddressKind.business,
    );
  }

  AddressResult _currentAddress() {
    return (_selectedAddress ?? const AddressResult()).copyWith(
      street: _addressController.text.trim(),
      unit: _address2Controller.text.trim().isEmpty
          ? null
          : _address2Controller.text.trim(),
      city: _cityController.text.trim(),
      state: _stateController.text.trim(),
      zip: _zipController.text.trim(),
      formatted: _formattedAddress,
      lat: _latitude,
      lng: _longitude,
      placeId: _placeId,
    );
  }

  Future<void> _submit() async {
    final error = _validationError();
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
      return;
    }
    if (!widget.isClaim && Supabase.instance.client.auth.currentUser == null) {
      await ensureSignedIn(context);
      if (!mounted || Supabase.instance.client.auth.currentUser == null) return;
    }

    setState(() => _isSubmitting = true);
    try {
      if (!widget.isClaim) {
        final socials = <({String platform, String url})>[
          if (_instagramController.text.trim().isNotEmpty)
            (
              platform: 'instagram',
              url: FormValidators.normalizeWebsite(_instagramController.text),
            ),
          if (_facebookController.text.trim().isNotEmpty)
            (
              platform: 'facebook',
              url: FormValidators.normalizeWebsite(_facebookController.text),
            ),
          if (_tiktokController.text.trim().isNotEmpty)
            (
              platform: 'tiktok',
              url: FormValidators.normalizeWebsite(_tiktokController.text),
            ),
          if (_xController.text.trim().isNotEmpty)
            (
              platform: 'x',
              url: FormValidators.normalizeWebsite(_xController.text),
            ),
          if (_youtubeController.text.trim().isNotEmpty)
            (
              platform: 'youtube',
              url: FormValidators.normalizeWebsite(_youtubeController.text),
            ),
        ];

        final websiteRaw = _websiteController.text.trim();
        final businessId = await BusinessSubmissionService.submitNewBusiness(
          name: widget.businessName,
          businessType: widget.businessType ?? 'Other',
          contactName: _nameController.text.trim(),
          contactEmail: _emailController.text.trim(),
          services: widget.services,
          industrySlug: widget.industrySlug,
          businessPhone: _businessPhoneController.text.trim(),
          businessEmail: _businessEmailController.text.trim(),
          website: websiteRaw.isEmpty
              ? null
              : FormValidators.normalizeWebsite(websiteRaw),
          addressLine1: _addressController.text.trim(),
          addressLine2: _address2Controller.text.trim(),
          city: _cityController.text.trim(),
          state: _stateController.text.trim(),
          zip: _zipController.text.trim(),
          contactPreference: _contactPreference,
          socialLinks: socials,
          latitude: _latitude,
          longitude: _longitude,
          placeId: _placeId,
          formattedAddress: _formattedAddress,
        );
        if (widget.avatarFile != null) {
          try {
            await BusinessMediaService.setAvatar(
              businessId: businessId,
              file: widget.avatarFile!,
            );
          } catch (_) {}
        }
      }
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        FirstVuePageRoute(
          builder: (_) => _PendingVerificationScreen(
            businessName: widget.businessName,
            isClaim: widget.isClaim,
          ),
        ),
        (route) => route.isFirst,
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Unable to submit this business. Please try again.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final fv = context.fv;
    return Scaffold(
      backgroundColor: fv.background,
      appBar: fvAppBar(
        context: context,
        title: 'Verify ownership',
        subtitle: widget.stepLabel,
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: FvUi.pagePadding(top: 12),
              children: [
                Text(
                  widget.businessName,
                  style: TextStyle(
                    color: fv.primaryText,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (widget.businessType != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    widget.businessType!,
                    style: TextStyle(color: fv.secondaryText),
                  ),
                ],
                const SizedBox(height: 12),
                Text(
                  'Provide a contact person for this verification submission.',
                  style: TextStyle(color: fv.secondaryText, height: 1.4),
                ),
                const SizedBox(height: 22),
                FvCompactField(
                  label: 'Your full name',
                  hint: 'Full name',
                  controller: _nameController,
                ),
                const SizedBox(height: 14),
                FvCompactField(
                  label: 'Email address',
                  hint: 'name@email.com',
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 28),
                Text(
                  'CONTACT INFORMATION',
                  style: TextStyle(
                    color: FirstVueColors.gold,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Optional for the public profile — add what customers should use.',
                  style: TextStyle(color: fv.tertiaryText, fontSize: 12),
                ),
                const SizedBox(height: 14),
                FvCompactField(
                  label: 'Business phone',
                  hint: '(555) 555-5555',
                  controller: _businessPhoneController,
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 14),
                FvCompactField(
                  label: 'Business email',
                  hint: 'hello@business.com',
                  controller: _businessEmailController,
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 14),
                FvCompactField(
                  label: 'Website',
                  hint: 'https://',
                  controller: _websiteController,
                  keyboardType: TextInputType.url,
                ),
                const SizedBox(height: 14),
                SmartAddressField(
                  key: _addressFieldKey,
                  streetController: _addressController,
                  unitController: _address2Controller,
                  cityController: _cityController,
                  stateController: _stateController,
                  zipController: _zipController,
                  streetLabel: 'Business address',
                  onSelected: _onAddressSelected,
                ),
                const SizedBox(height: 14),
                FvSelectorField(
                  label: 'Public contact preference (optional)',
                  value: _contactPreference,
                  hint: 'How should customers reach you?',
                  icon: Icons.contact_page_outlined,
                  focused: _preferenceFocused,
                  onTap: _pickPreference,
                ),
                const SizedBox(height: 28),
                Text(
                  'SOCIAL LINKS (OPTIONAL)',
                  style: TextStyle(
                    color: FirstVueColors.gold,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 14),
                FvCompactField(
                  label: 'Instagram',
                  hint: 'instagram.com/…',
                  controller: _instagramController,
                  keyboardType: TextInputType.url,
                ),
                const SizedBox(height: 14),
                FvCompactField(
                  label: 'Facebook',
                  hint: 'facebook.com/…',
                  controller: _facebookController,
                  keyboardType: TextInputType.url,
                ),
                const SizedBox(height: 14),
                FvCompactField(
                  label: 'TikTok',
                  hint: 'tiktok.com/@…',
                  controller: _tiktokController,
                  keyboardType: TextInputType.url,
                ),
                const SizedBox(height: 14),
                FvCompactField(
                  label: 'X',
                  hint: 'x.com/…',
                  controller: _xController,
                  keyboardType: TextInputType.url,
                ),
                const SizedBox(height: 14),
                FvCompactField(
                  label: 'YouTube',
                  hint: 'youtube.com/…',
                  controller: _youtubeController,
                  keyboardType: TextInputType.url,
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
          FvStickyCta(
            label: 'Submit for review',
            loading: _isSubmitting,
            onPressed: _submit,
          ),
        ],
      ),
    );
  }
}

class _PendingVerificationScreen extends StatelessWidget {
  final String businessName;
  final bool isClaim;

  const _PendingVerificationScreen({
    required this.businessName,
    required this.isClaim,
  });

  @override
  Widget build(BuildContext context) {
    final fv = context.fv;
    return Scaffold(
      backgroundColor: fv.background,
      appBar: fvAppBar(
        context: context,
        title: 'Add business',
        subtitle: '3 of 3',
        onBack: () => Navigator.pop(context),
      ),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.pending_actions,
                  color: FirstVueColors.gold,
                  size: 58,
                ),
                const SizedBox(height: 20),
                Text(
                  'Pending verification',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: fv.primaryText,
                    fontSize: 21,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  '$businessName has a ${isClaim ? 'claim' : 'new business'} submission awaiting review. It has not been published or verified.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: fv.secondaryText, height: 1.5),
                ),
                const SizedBox(height: 26),
                OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Back to profile'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _WorkflowNotice extends StatelessWidget {
  const _WorkflowNotice();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color:
            Theme.of(context).extension<FirstVuePalette>()?.elevatedSurface ??
            FirstVueColors.elevatedSurface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Text(
        'Submissions stay pending until FirstVue reviews them.',
        style: TextStyle(height: 1.4, fontSize: 12),
      ),
    );
  }
}
