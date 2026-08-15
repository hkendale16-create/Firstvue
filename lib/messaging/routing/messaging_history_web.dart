// ignore_for_file: deprecated_member_use, avoid_web_libraries_in_flutter
import 'dart:async';
import 'dart:html' as html;

String? _lastSyncedUrl;
StreamSubscription<html.PopStateEvent>? _popSub;
bool _handlingPop = false;

/// Writes messaging mode into the query string without reloading the page.
/// Skips no-op writes — repeated replaceState on iOS Safari can destabilize
/// the tab (especially while scrolling heavy Flutter canvases).
void syncMessagingUrl({required String mode, String? conversationId}) {
  if (_handlingPop) return;
  final uri = Uri.parse(html.window.location.href);
  final params = Map<String, String>.from(uri.queryParameters);
  params['msg'] = mode;
  if (conversationId != null && conversationId.isNotEmpty) {
    params['c'] = conversationId;
  } else {
    params.remove('c');
  }
  final next = uri.replace(queryParameters: params).toString();
  if (next == _lastSyncedUrl || next == uri.toString()) return;
  _lastSyncedUrl = next;
  html.window.history.replaceState(null, '', next);
}

/// Removes messaging query params when leaving the Messages shell so a
/// Safari remount / refresh does not keep `?msg=messages` around.
void clearMessagingUrl() {
  final uri = Uri.parse(html.window.location.href);
  if (!uri.queryParameters.containsKey('msg') &&
      !uri.queryParameters.containsKey('c')) {
    return;
  }
  final params = Map<String, String>.from(uri.queryParameters)
    ..remove('msg')
    ..remove('c');
  final next = uri.replace(queryParameters: params).toString();
  _lastSyncedUrl = next;
  html.window.history.replaceState(null, '', next);
}

/// Listen once for browser back/forward. Returns a cancel callback.
/// Replaces any previous listener so stacked Messaging shells cannot
/// accumulate popstate handlers.
void Function() listenMessagingUrl(
  void Function(String mode, String? conversationId) onChange,
) {
  _popSub?.cancel();
  _popSub = html.window.onPopState.listen((_) {
    if (_handlingPop) return;
    _handlingPop = true;
    try {
      final uri = Uri.parse(html.window.location.href);
      _lastSyncedUrl = uri.toString();
      onChange(
        uri.queryParameters['msg'] ?? 'messages',
        uri.queryParameters['c'],
      );
    } finally {
      _handlingPop = false;
    }
  });
  return () {
    _popSub?.cancel();
    _popSub = null;
  };
}
