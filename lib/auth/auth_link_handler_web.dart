// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html' as html;

void replaceAuthUrl(String path) {
  final clean = path.isEmpty ? '/' : path;
  // replaceState avoids a full reload that would re-run Flutter bootstrap.
  html.window.history.replaceState(null, '', clean);
}

void installAuthLinkHandlerWeb() {}
