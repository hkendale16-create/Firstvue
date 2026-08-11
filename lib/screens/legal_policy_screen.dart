import 'package:flutter/material.dart';

enum LegalPolicyType { privacy, terms }

class LegalPolicyScreen extends StatelessWidget {
  final LegalPolicyType type;

  const LegalPolicyScreen({super.key, required this.type});

  String get _title =>
      type == LegalPolicyType.privacy ? 'PRIVACY POLICY' : 'TERMS OF SERVICE';

  String get _body => type == LegalPolicyType.privacy
      ? '''
Last updated: August 11, 2026

FirstVue ("we", "our", "us") helps you discover and connect with verified local businesses.

Information we collect
• Account information such as email and display name when you sign up.
• Location data when you allow it, used to show nearby businesses and trending results.
• Content you submit including reviews, messages, business listings, and media uploads.
• Usage data such as device type and interactions needed to operate the service.

How we use information
• Provide discovery, search, messaging, and profile features.
• Verify businesses and moderate submitted content.
• Improve reliability, security, and product performance.
• Communicate account, booking, or service updates when applicable.

Sharing
• We use Supabase for authentication, database, and file storage.
• We do not sell personal information.
• We may disclose information when required by law or to protect users and the platform.

Your choices
• You can sign out at any time from Profile.
• Location access is controlled by your device settings.
• Contact us to request account deletion or data questions.

Security
• Access is protected by authentication and database row-level security policies.
• No system is perfectly secure; please use a strong unique password.

Contact
• For privacy requests, contact your FirstVue administrator or support channel.
'''
      : '''
Last updated: August 11, 2026

By using FirstVue, you agree to these Terms of Service.

Using FirstVue
• You must provide accurate account information and keep credentials secure.
• You may not impersonate others, scrape the platform, or attempt unauthorized access.
• Business owners and professionals are responsible for the accuracy of listings they submit.

Content and moderation
• Submitted reviews, media, listings, and messages may be moderated before or after publication.
• We may remove content that is fraudulent, abusive, illegal, or misleading.
• FirstVue may approve, reject, or remove business and professional profiles at its discretion.

Bookings and payments
• When payments are enabled, transactions may be processed by third-party providers such as Stripe.
• FirstVue is not responsible for off-platform arrangements unless explicitly stated in a feature.

Availability
• The service is provided on an "as is" basis while we continue to improve and expand features.
• We may update, suspend, or discontinue features with reasonable notice when possible.

Termination
• We may suspend accounts that violate these terms or create security risk.
• You may stop using FirstVue at any time.

Governing law
• These terms are governed by applicable local laws where FirstVue operates.

Contact
• For legal or support questions, contact your FirstVue administrator or support channel.
''';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0E0B1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0E0B1A),
        surfaceTintColor: Colors.transparent,
        title: Text(_title),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        children: [
          Text(
            _body.trim(),
            style: const TextStyle(
              color: Colors.white70,
              height: 1.55,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}
