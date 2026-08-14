import 'dart:typed_data';

import 'package:flutter/material.dart';
import '../theme/firstvue_theme.dart';
import '../navigation/firstvue_page_route.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../constants/business_types.dart';
import '../services/business_media_service.dart';
import '../services/business_submission_service.dart';
import '../widgets/fv_ui.dart';
import '../widgets/media_picker_sheet.dart';
import 'auth_screen.dart';
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
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Showcase your business. Submit for verification — nothing is public until approved.',
              textAlign: TextAlign.center,
              style: TextStyle(color: context.fv.secondaryText, height: 1.5),
            ),
            const SizedBox(height: 28),
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
            const Spacer(),
            const _WorkflowNotice(),
          ],
        ),
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
    Navigator.push(
      context,
      FirstVuePageRoute(
        builder: (_) => _VerificationFormScreen(
          businessName: name,
          businessType: _businessType!.label,
          industrySlug: _businessType!.slug,
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
  bool _isSubmitting = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_nameController.text.trim().isEmpty ||
        _emailController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter your name and email to continue.')),
      );
      return;
    }
    if (!widget.isClaim && Supabase.instance.client.auth.currentUser == null) {
      await Navigator.push(
        context,
        FirstVuePageRoute(builder: (_) => const AuthScreen()),
      );
      if (!mounted || Supabase.instance.client.auth.currentUser == null) return;
    }

    setState(() => _isSubmitting = true);
    try {
      if (!widget.isClaim) {
        final businessId = await BusinessSubmissionService.submitNewBusiness(
          name: widget.businessName,
          businessType: widget.businessType ?? 'Other',
          contactName: _nameController.text.trim(),
          contactEmail: _emailController.text.trim(),
          services: widget.services,
          industrySlug: widget.industrySlug,
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
        'New business submissions are saved as pending. Claiming a mock prototype listing remains a local demonstration until external business matching is added.',
        style: TextStyle(height: 1.4, fontSize: 12),
      ),
    );
  }
}
