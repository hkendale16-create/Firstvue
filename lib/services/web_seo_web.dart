// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:html' as html;

void updateWebSeo({
  required String title,
  String? description,
  String? imageUrl,
  String? canonicalUrl,
}) {
  html.document.title = title;
  _upsertMetaName('description', description);
  _upsertMetaProperty('og:title', title);
  _upsertMetaProperty('og:description', description);
  _upsertMetaProperty('og:type', 'website');
  _upsertMetaName('twitter:card', 'summary_large_image');
  _upsertMetaName('twitter:title', title);
  _upsertMetaName('twitter:description', description);

  if (imageUrl != null && imageUrl.isNotEmpty) {
    _upsertMetaProperty('og:image', imageUrl);
  }
  if (canonicalUrl != null && canonicalUrl.isNotEmpty) {
    _upsertLink('canonical', canonicalUrl);
    _upsertMetaProperty('og:url', canonicalUrl);
  }
}

void _upsertMetaName(String name, String? content) {
  if (content == null || content.isEmpty) return;
  final existing = html.document.querySelector('meta[name="$name"]');
  if (existing is html.MetaElement) {
    existing.content = content;
    return;
  }
  html.document.head?.append(html.MetaElement()
    ..name = name
    ..content = content);
}

void _upsertMetaProperty(String property, String? content) {
  if (content == null || content.isEmpty) return;
  final existing = html.document.querySelector('meta[property="$property"]');
  if (existing is html.MetaElement) {
    existing.content = content;
    return;
  }
  final meta = html.MetaElement();
  meta.setAttribute('property', property);
  meta.content = content;
  html.document.head?.append(meta);
}

void _upsertLink(String rel, String href) {
  final existing = html.document.querySelector('link[rel="$rel"]');
  if (existing is html.LinkElement) {
    existing.href = href;
    return;
  }
  html.document.head?.append(html.LinkElement()
    ..rel = rel
    ..href = href);
}
