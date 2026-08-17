enum ShareContentKind { generic, event, invite }

class SharePayload {
  final String title;
  final String link;
  final String? subtitle;
  final String? detailLine;
  final ShareContentKind kind;
  final String? relatedEventId;

  const SharePayload({
    required this.title,
    required this.link,
    this.subtitle,
    this.detailLine,
    this.kind = ShareContentKind.generic,
    this.relatedEventId,
  });

  factory SharePayload.invite({required String link}) {
    return SharePayload(
      title: 'Invite your friends',
      subtitle:
          'FirstVue is better when the people you know are discovering what\'s happening too.',
      link: link,
      kind: ShareContentKind.invite,
    );
  }

  factory SharePayload.event({
    required String title,
    required String link,
    String? subtitle,
    String? detailLine,
    String? eventId,
  }) {
    return SharePayload(
      title: title,
      link: link,
      subtitle: subtitle,
      detailLine: detailLine,
      kind: ShareContentKind.event,
      relatedEventId: eventId,
    );
  }

  String get messageText {
    if (kind == ShareContentKind.invite) {
      return "See what's happening. Share what's happening. Bring people with you.\n"
          'Join me on FirstVue\n$link';
    }
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
