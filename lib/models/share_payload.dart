class SharePayload {
  final String title;
  final String link;
  final String? subtitle;
  final String? detailLine;

  const SharePayload({
    required this.title,
    required this.link,
    this.subtitle,
    this.detailLine,
  });

  String get messageText {
    final buffer = StringBuffer('Check out $title on FirstVue');
    if (detailLine != null && detailLine!.trim().isNotEmpty) {
      buffer.write('\n${detailLine!.trim()}');
    }
    if (subtitle != null && subtitle!.trim().isNotEmpty) {
      buffer.write('\n${subtitle!.trim()}');
    }
    buffer.write('\n$link');
    return buffer.toString();
  }

  String get emailSubject => '$title on FirstVue';
}
