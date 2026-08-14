/// Server-backed "New" badge: created_at plus 10 days. No stale booleans.
class NewLabel {
  NewLabel._();

  static const duration = Duration(days: 10);

  static bool isNew(DateTime? createdAt, {DateTime? now}) {
    if (createdAt == null) return false;
    final created = createdAt.toUtc();
    final current = (now ?? DateTime.now()).toUtc();
    return !current.isAfter(created.add(duration));
  }
}
