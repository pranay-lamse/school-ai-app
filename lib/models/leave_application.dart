class LeaveApplication {
  final int id;
  final int studentSessionId;
  final String fromDate;
  final String toDate;
  final String applyDate;
  final String reason;
  final int status; // 0 = Pending, 1 = Approved

  LeaveApplication({
    required this.id,
    required this.studentSessionId,
    required this.fromDate,
    required this.toDate,
    required this.applyDate,
    required this.reason,
    required this.status,
  });

  factory LeaveApplication.fromJson(Map<String, dynamic> json) {
    return LeaveApplication(
      id: json['id'],
      studentSessionId: json['student_session_id'] ?? 0,
      fromDate: json['from_date'] ?? '',
      toDate: json['to_date'] ?? '',
      applyDate: json['apply_date'] ?? '',
      reason: json['reason'] ?? '',
      status: json['status'] ?? 0,
    );
  }
}
