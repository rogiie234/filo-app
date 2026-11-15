class ExamIntegrity {
  const ExamIntegrity({
    this.limit,
    this.eventIds = const {},
    this.warningShown = false,
    this.forced = false,
    this.ready = false,
  });
  factory ExamIntegrity.fromJson(Map<String, dynamic> json) => ExamIntegrity(
    limit: json['leave_limit'] as int?,
    eventIds: Set<String>.from(json['leave_event_ids'] as List? ?? const []),
    warningShown: json['warning_shown'] == true,
    forced: json['forced'] == true,
    ready: json['ready'] == true,
  );
  final int? limit;
  final Set<String> eventIds;
  final bool warningShown, forced, ready;
  int get count => eventIds.length;
  bool get atLimit => forced || limit != null && count >= limit!;
  bool get needsWarning =>
      limit != null && count == limit! - 1 && !warningShown && !atLimit;
  Map<String, dynamic> toJson() => {
    'leave_limit': limit,
    'leave_event_ids': eventIds.toList(),
    'warning_shown': warningShown,
    'forced': atLimit,
    'ready': ready,
  };
  ExamIntegrity merge(Map<String, dynamic> json) => ExamIntegrity(
    limit: limit ?? json['leave_limit'] as int?,
    eventIds: {
      ...eventIds,
      ...Set<String>.from(json['leave_event_ids'] as List? ?? const []),
    },
    warningShown: warningShown || json['warning_shown'] == true,
    forced:
        atLimit ||
        json['forced'] == true ||
        json['auto_submit_reason'] == 'leave_limit',
    ready: ready || json['ready'] == true,
  );
}
