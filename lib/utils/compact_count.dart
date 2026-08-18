/// Compact count labels used in VUE / Reel chrome (1.8K, 12.4K, 1.8M).
String compactCount(int value) {
  if (value < 1000) return '$value';
  if (value < 10000) {
    final k = value / 1000;
    final label = k.toStringAsFixed(1);
    return '${label.endsWith('.0') ? label.substring(0, label.length - 2) : label}K';
  }
  if (value < 1000000) {
    return '${(value / 1000).floor()}K';
  }
  final m = value / 1000000;
  if (value < 10000000) {
    final label = m.toStringAsFixed(1);
    return '${label.endsWith('.0') ? label.substring(0, label.length - 2) : label}M';
  }
  return '${m.floor()}M';
}
