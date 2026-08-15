import 'package:flutter/material.dart';

/// Shared [GlobalKey]s so contextual tips can spotlight real UI.
class TutorialTargets {
  TutorialTargets._();

  static final homeNav = GlobalKey(debugLabel: 'tutorial-home-nav');
  static final feedsNav = GlobalKey(debugLabel: 'tutorial-feeds-nav');
  static final vueNav = GlobalKey(debugLabel: 'tutorial-vue-nav');
  static final exploreNav = GlobalKey(debugLabel: 'tutorial-explore-nav');

  static final vueLiveSwitch = GlobalKey(debugLabel: 'tutorial-vue-live');
  static final feedsTabs = GlobalKey(debugLabel: 'tutorial-feeds-tabs');
  static final exploreSections = GlobalKey(debugLabel: 'tutorial-explore-sections');
  static final messagesTabs = GlobalKey(debugLabel: 'tutorial-messages-tabs');
  static final settingsVerified = GlobalKey(debugLabel: 'tutorial-settings-verified');
  static final settingsMonetization =
      GlobalKey(debugLabel: 'tutorial-settings-monetization');
}
