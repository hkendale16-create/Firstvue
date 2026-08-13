import 'package:flutter/material.dart';
import '../theme/firstvue_theme.dart';
import '../navigation/firstvue_page_route.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../constants/business_types.dart';
import '../services/business_submission_service.dart';
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
              style: const TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),
            subtitle: Text(
              business.$2,
            ),
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
  String _categoryGroup = defaultBusinessCategoryGroup;
  late String _category;

  @override
  void initState() {
    super.initState();
    _category = businessCategoryGroups[_categoryGroup]!.first;
  }

  @override
  void dispose() {
    _businessController.dispose();
    super.dispose();
  }

  void _continue() {
    final name = _businessController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter your business name first.')),
      );
      return;
    }
    Navigator.push(
      context,
      FirstVuePageRoute(
        builder: (_) => _VerificationFormScreen(
          businessName: name,
          businessType: _category,
          isClaim: false,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        surfaceTintColor: Colors.transparent,
        title: const Text('ADD A BUSINESS'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            TextField(
              controller: _businessController,
              decoration: _fieldDecoration('Business name'),
            ),
            const SizedBox(height: 14),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'What type of business is this?',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              initialValue: _categoryGroup,
              decoration: _fieldDecoration('Business category'),
              items: businessCategoryGroups.keys
                  .map(
                    (group) => DropdownMenuItem(value: group, child: Text(group)),
                  )
                  .toList(),
              onChanged: (value) {
                if (value == null) return;
                setState(() {
                  _categoryGroup = value;
                  _category = businessCategoryGroups[value]!.first;
                });
              },
            ),
            const SizedBox(height: 14),
            DropdownButtonFormField<String>(
              initialValue: _category,
              decoration: _fieldDecoration('Specific business type'),
              items: businessCategoryGroups[_categoryGroup]!
                  .map(
                    (type) =>
                        DropdownMenuItem(value: type, child: Text(type)),
                  )
                  .toList(),
              onChanged: (value) =>
                  setState(() => _category = value ?? _category),
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                onPressed: _continue,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFD8B56A),
                  foregroundColor: Colors.black,
                ),
                child: const Text('CONTINUE TO VERIFICATION'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

InputDecoration _fieldDecoration(String label) {
  return InputDecoration(labelText: label);
}

class _VerificationFormScreen extends StatefulWidget {
  final String businessName;
  final String? businessType;
  final bool isClaim;

  const _VerificationFormScreen({
    required this.businessName,
    this.businessType,
    required this.isClaim,
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
        await BusinessSubmissionService.submitNewBusiness(
          name: widget.businessName,
          businessType: widget.businessType ?? 'Other',
          contactName: _nameController.text.trim(),
          contactEmail: _emailController.text.trim(),
        );
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
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        surfaceTintColor: Colors.transparent,
        title: const Text('VERIFY OWNERSHIP'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.businessName,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 9),
            const Text(
              'Provide a contact person for this prototype verification submission.',
              style: TextStyle(height: 1.4),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _nameController,
              decoration: _fieldDecoration('Your full name'),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: _fieldDecoration('Email address'),
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFD8B56A),
                  foregroundColor: Colors.black,
                ),
                child: Text(
                  _isSubmitting ? 'SUBMITTING...' : 'SUBMIT FOR REVIEW',
                ),
              ),
            ),
          ],
        ),
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
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.pending_actions,
                  color: Color(0xFFE5C16F),
                  size: 58,
                ),
                const SizedBox(height: 20),
                const Text(
                  'PENDING VERIFICATION',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.3,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  '$businessName has a ${isClaim ? 'claim' : 'new business'} submission awaiting review. It has not been published or verified.',
                  textAlign: TextAlign.center,
                  style: TextStyle(height: 1.5),
                ),
                const SizedBox(height: 26),
                OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('BACK TO PROFILE'),
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
        color: Theme.of(context).extension<FirstVuePalette>()?.elevatedSurface ?? FirstVueColors.elevatedSurface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Text(
        'New business submissions are saved as pending. Claiming a mock prototype listing remains a local demonstration until external business matching is added.',
        style: TextStyle(height: 1.4, fontSize: 12),
      ),
    );
  }
}
