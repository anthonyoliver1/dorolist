String dayKey(DateTime time) {
  final date = time.toLocal();
  return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}

class FocusRecord {
  const FocusRecord(
      {required this.id,
      required this.endedAt,
      required this.seconds,
      this.taskId,
      this.taskTitle});
  final String id;
  final DateTime endedAt;
  final int seconds;
  final String? taskId;
  final String? taskTitle;

  factory FocusRecord.fromJson(Object? data) {
    if (data is! Map ||
        data['id'] is! String ||
        (data['id'] as String).isEmpty ||
        data['seconds'] is! int ||
        (data['seconds'] as int) < 1 ||
        (data['seconds'] as int) > 10800 ||
        data['endedAt'] is! String ||
        DateTime.tryParse(data['endedAt']) == null ||
        (data['taskId'] != null && data['taskId'] is! String) ||
        (data['taskTitle'] != null && data['taskTitle'] is! String)) {
      throw const FormatException('Histórico inválido');
    }
    return FocusRecord(
        id: data['id'],
        endedAt: DateTime.parse(data['endedAt']),
        seconds: data['seconds'],
        taskId: data['taskId'],
        taskTitle: data['taskTitle']);
  }
  Map<String, dynamic> toJson() => {
        'id': id,
        'endedAt': endedAt.toUtc().toIso8601String(),
        'seconds': seconds,
        'taskId': taskId,
        'taskTitle': taskTitle
      };
}
