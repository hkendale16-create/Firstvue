import 'package:flutter/cupertino.dart';

/// App-wide page route with interactive swipe-from-left-edge back navigation.
///
/// Drop-in replacement for [MaterialPageRoute] on pushed detail screens.
class FirstVuePageRoute<T> extends CupertinoPageRoute<T> {
  FirstVuePageRoute({
    required super.builder,
    super.settings,
    super.maintainState = true,
    super.fullscreenDialog = false,
  });
}
