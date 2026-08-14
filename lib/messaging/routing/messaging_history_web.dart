// ignore_for_file: deprecated_member_use, avoid_web_libraries_in_flutter
import 'dart:html' as html;

void syncMessagingUrl({required String mode, String? conversationId}) {
  final uri = Uri.parse(html.window.location.href);
  final params = Map<String, String>.from(uri.queryParameters);
  params['msg'] = mode;
  if (conversationId != null && conversationId.isNotEmpty) {
    params['c'] = conversationId;
  } else {
    params.remove('c');
  }
  final next = uri.replace(queryParameters: params).toString();
  html.window.history.replaceState(null, '', next);
}

void listenMessagingUrl(
  void Function(String mode, String? conversationId) onChange,
) {
  html.window.onPopState.listen((_) {
    final uri = Uri.parse(html.window.location.href);
    onChange(
      uri.queryParameters['msg'] ?? 'messages',
      uri.queryParameters['c'],
    );
  });
}
