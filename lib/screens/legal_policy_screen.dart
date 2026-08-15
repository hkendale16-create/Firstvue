import 'package:flutter/material.dart';

enum LegalPolicyType { privacy, terms }

class LegalPolicyScreen extends StatelessWidget {
  final LegalPolicyType type;

  const LegalPolicyScreen({super.key, required this.type});

  String get _title =>
      type == LegalPolicyType.privacy ? 'PRIVACY POLICY' : 'TERMS OF SERVICE';

  String get _body => type == LegalPolicyType.privacy
      ? '''
Last updated: August 15, 2026

FirstVue ("we", "our", "us") helps you discover and connect with verified local businesses, professionals, communities, and events.

Information we collect
• Account information such as email, username, and display name when you sign up.
• Profile details you choose to add (bio, city, photos, portfolio, business or professional information).
• Location data when you allow it, used for nearby discovery and trending results.
• User-generated content including posts, comments, reactions, messages, reviews, listings, events, groups, and communities.
• Media you upload (photos and videos) for profiles, posts, VUE, events, and portfolios.
• Usage and engagement data needed to operate feeds, search, notifications, and security.

How we use information
• Provide discovery, search, messaging, events, groups, communities, and profile features.
• Verify businesses/professionals and moderate submitted content.
• Improve reliability, security, and product performance.
• Communicate account or service updates when applicable.

Sharing
• We use Supabase for authentication, database, storage, and related backend services.
• We do not sell personal information.
• We may disclose information when required by law or to protect users and the platform.
• Payments (Stripe) are not enabled in the current trial build.

Your choices
• You can sign out at any time from Profile.
• You can delete your account in Settings → Privacy (owned businesses, community hubs, or rental listings must be removed or transferred first).
• Location access is controlled by your device settings.

Age
• FirstVue is for users 13 and older.

Security
• Access is protected by authentication and database row-level security policies.
• No system is perfectly secure; please use a strong unique password.

Contact
• Privacy and support: hkendale16@gmail.com
'''
      : '''
Last updated: August 15, 2026

By using FirstVue, you agree to these Terms of Service.

Using FirstVue
• You must be at least 13 years old to use FirstVue.
• You must provide accurate account information and keep credentials secure.
• You may not impersonate others, scrape the platform, or attempt unauthorized access.
• Business owners, professionals, organizers, and community leaders are responsible for the accuracy of content they publish.

Content and moderation
• Submitted posts, reviews, media, listings, messages, events, groups, and communities may be moderated.
• We may remove content that is fraudulent, abusive, illegal, or misleading.
• FirstVue may approve, reject, or remove business, professional, organizer, and community applications at its discretion.

Bookings and payments
• Paid subscriptions and Stripe checkout are not enabled in this trial build.
• When payments are enabled later, transactions may be processed by third-party providers such as Stripe.
• FirstVue is not responsible for off-platform arrangements unless explicitly stated in a feature.

Availability
• The service is provided on an "as is" basis while we continue to improve and expand features.
• We may update, suspend, or discontinue features with reasonable notice when possible.

Termination
• We may suspend accounts that violate these terms or create security risk.
• You may delete your account in Settings → Privacy or stop using FirstVue at any time.

Governing law
• These terms are governed by applicable local laws where FirstVue operates.

Contact
• Legal and support: hkendale16@gmail.com
''';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
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
