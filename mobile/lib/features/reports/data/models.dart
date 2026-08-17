// Report DTOs — mirror app/reports/routes.py responses.

class ReportTargetTypes {
  static const listing = 'listing';
  static const broker = 'broker';
}

class ReportReasons {
  static const fraud = 'fraud';
  static const spam = 'spam';
  static const inappropriate = 'inappropriate';
  static const wrongInfo = 'wrong_info';
  static const other = 'other';

  static const all = [fraud, spam, inappropriate, wrongInfo, other];
}

class ReportStatuses {
  static const open = 'open';
  static const dismissed = 'dismissed';
  static const resolvedAction = 'resolved_action';
  static const resolvedNoAction = 'resolved_no_action';
}

class ReportReporter {
  ReportReporter({required this.id, required this.fullName});
  final int id;
  final String fullName;

  factory ReportReporter.fromJson(Map<String, dynamic> j) => ReportReporter(
        id: j['id'] as int,
        fullName: j['full_name'] as String,
      );
}

class ReportDto {
  ReportDto({
    required this.id,
    this.reporter,
    required this.targetType,
    required this.targetId,
    required this.reason,
    this.note,
    required this.status,
    this.resolutionNote,
    this.resolvedAt,
    this.resolvedBy,
    this.createdAt,
  });

  final int id;
  final ReportReporter? reporter;
  final String targetType;
  final int targetId;
  final String reason;
  final String? note;
  final String status;
  final String? resolutionNote;
  final DateTime? resolvedAt;
  final int? resolvedBy;
  final DateTime? createdAt;

  factory ReportDto.fromJson(Map<String, dynamic> j) => ReportDto(
        id: j['id'] as int,
        reporter: j['reporter'] == null
            ? null
            : ReportReporter.fromJson(j['reporter'] as Map<String, dynamic>),
        targetType: j['target_type'] as String,
        targetId: j['target_id'] as int,
        reason: j['reason'] as String,
        note: j['note'] as String?,
        status: j['status'] as String,
        resolutionNote: j['resolution_note'] as String?,
        resolvedAt: _dt(j['resolved_at']),
        resolvedBy: j['resolved_by'] as int?,
        createdAt: _dt(j['created_at']),
      );

  static DateTime? _dt(dynamic v) => v is String ? DateTime.tryParse(v) : null;
}
