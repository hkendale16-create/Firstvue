import 'package:firstvue/screens/member_public_profile_screen.dart';
import 'package:firstvue/screens/profile_screen.dart';
import 'package:firstvue/theme/firstvue_theme.dart';
import 'package:firstvue/widgets/social_chrome.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('personal profile keeps three tabs', () {
    expect(ProfileScreen.tabLabels, ['Posts', 'Photos', 'More']);
    expect(MemberPublicProfileScreen.tabLabels, ['Posts', 'Photos', 'More']);
  });

  testWidgets('own profile header is one gold CTA plus icons', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: FirstVueTheme.elegantDark,
        home: Scaffold(
          body: SocialProfileHeader(
            name: 'Kendale',
            handle: '@kendale',
            bio: 'Atlanta nights',
            actions: [
              FilledButton(
                onPressed: () {},
                child: const Text('Edit profile'),
              ),
            ],
            iconActions: [
              IconButton(
                onPressed: () {},
                tooltip: 'Share profile',
                icon: const Icon(Icons.ios_share_outlined),
              ),
              IconButton(
                onPressed: () {},
                tooltip: 'More',
                icon: const Icon(Icons.more_horiz),
              ),
            ],
          ),
        ),
      ),
    );

    expect(find.text('Edit profile'), findsOneWidget);
    expect(find.text('Share profile'), findsNothing);
    expect(find.text('Invite friends'), findsNothing);
    expect(find.byTooltip('Share profile'), findsOneWidget);
    expect(find.text('Atlanta nights'), findsOneWidget);
  });

  testWidgets('public profile header is Follow plus Message icon', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: FirstVueTheme.elegantDark,
        home: Scaffold(
          body: SocialProfileHeader(
            name: 'Kendale',
            handle: '@kendale',
            actions: [
              SocialFollowButton(label: 'Follow', compact: true, onPressed: () {}),
            ],
            iconActions: [
              IconButton(
                onPressed: () {},
                tooltip: 'Message',
                icon: const Icon(Icons.chat_bubble_outline),
              ),
            ],
          ),
        ),
      ),
    );

    expect(find.text('Follow'), findsOneWidget);
    expect(find.text('Message'), findsNothing);
    expect(find.byTooltip('Message'), findsOneWidget);
  });
}
