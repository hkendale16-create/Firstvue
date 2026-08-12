import 'package:flutter/widgets.dart';

/// True while running `flutter test` widget/integration tests.
bool get isWidgetTestBinding {
  final binding = WidgetsBinding.instance;
  return binding.runtimeType.toString().contains('TestWidgetsFlutterBinding');
}
