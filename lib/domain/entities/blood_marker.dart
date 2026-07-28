enum MarkerStatus {
  low,
  normal,
  high;

  String get label => switch (this) {
    MarkerStatus.low => 'Low',
    MarkerStatus.normal => 'Normal',
    MarkerStatus.high => 'High',
  };

  /// Whether this marker should be called out with the accent tag, matching
  /// the design's `tag-accent` (out of range) vs `tag-neutral` (normal) split.
  bool get needsAttention => this != MarkerStatus.normal;
}

class BloodMarker {
  const BloodMarker({
    required this.label,
    required this.value,
    required this.status,
  });

  final String label;
  final String value;
  final MarkerStatus status;
}
