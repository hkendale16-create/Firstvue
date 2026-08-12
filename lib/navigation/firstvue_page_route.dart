import 'package:flutter/cupertino.dart';

import '../widgets/swipe_back_wrapper.dart';

/// App-wide page route with interactive swipe-back navigation.
///
/// Uses [CupertinoPageRoute] for native iOS edge swipe, plus [SwipeBackWrapper]
/// for swipe-left back on web/desktop and the right-edge strip on mobile.
class FirstVuePageRoute<T> extends CupertinoPageRoute<T> {
  FirstVuePageRoute({
    required WidgetBuilder builder,
    super.settings,
    super.maintainState = true,
    super.fullscreenDialog = false,
  }) : super(
          builder: (context) =>
              SwipeBackWrapper(child: builder(context)),
        );
}
