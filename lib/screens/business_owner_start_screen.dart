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
            fontSize: 22,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.5,
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'SHOWCASE YOUR BUSINESS',
              style: TextStyle(
                fontSize: 21,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Submit an unlisted business for verification. Nothing is public until FirstVue approves it.',
              style: TextStyle(color: context.fv.secondaryText, height: 1.5),
            ),
            const SizedBox(height: 28),
            _WorkflowOption(
              icon: Icons.fact_check_outlined,
              title: 'CLAIM A LISTED BUSINESS',
              description: 'Match your business, then send a claim for review.',
              accent: const Color(0xFFD8B56A),
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
              icon: Icons.add_business_outlined,
              title: 'ADD AN UNLISTED BUSINESS',
              description: 'Submit required details for FirstVue verification.',
              accent: const Color(0xFF78B9BE),
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
              title: 'POST AN AVAILABLE RENTAL',
              description:
                  'Create a booth or suite rental listing with weekly or monthly pricing.',
              accent: const Color(0xFF78B9BE),
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
  final VoidCallback onTap;

  const _WorkflowOption({
    required this.icon,
    required this.title,
    required this.description,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(21),
        onTap: onTap,
        child: Ink(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Theme.of(context).extension<FirstVuePalette>()?.surface ?? FirstVueColors.surface,
            borderRadius: BorderRadius.circular(21),
            border: Border.all(color: accent.withValues(alpha: .28)),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: .12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: accent),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: context.fv.primaryText,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      description,
                      style: TextStyle(
                        color: context.fv.secondaryText,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: FirstVueColors.gold),
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
                style: const TextStyle(fontWeight: FontWeight.w600),
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
