enum TimeType { pomodoro, short, long, custom }

class TimerSnapshot {
  const TimerSnapshot(
      {required this.phase,
      required this.totalSeconds,
      required this.remainingSeconds,
      required this.completedSessions,
      this.deadline,
      this.startedAt,
      this.sessionId,
      this.taskId,
      this.taskTitle,
      this.stopped = false});
  final TimeType phase;
  final int totalSeconds;
  final int remainingSeconds;
  final int completedSessions;
  final DateTime? deadline;
  final DateTime? startedAt;
  final String? sessionId;
  final String? taskId;
  final String? taskTitle;
  final bool stopped;

  factory TimerSnapshot.fromJson(Object? data) {
    if (data is! Map) throw const FormatException('Sessão inválida');
    int number(String name, int max, {int min = 0}) {
      final value = data[name];
      if (value is! int || value < min || value > max) {
        throw const FormatException('Sessão inválida');
      }
      return value;
    }

    DateTime? date(String name) {
      final value = data[name];
      if (value == null) return null;
      if (value is! String || DateTime.tryParse(value) == null) {
        throw const FormatException('Data inválida');
      }
      return DateTime.parse(value);
    }

    String? text(String name) {
      final value = data[name];
      if (value != null && (value is! String || value.isEmpty)) {
        throw const FormatException('Sessão inválida');
      }
      return value as String?;
    }

    final phase = TimeType.values
        .where((value) => value.name == data['phase'])
        .firstOrNull;
    final total = number('totalSeconds', 10800, min: 1);
    final remaining = number('remainingSeconds', total);
    final deadline = date('deadline');
    final startedAt = date('startedAt');
    final id = text('sessionId');
    if (phase == null ||
        data['stopped'] is! bool ||
        (deadline != null && (id == null || startedAt == null))) {
      throw const FormatException('Sessão inválida');
    }
    return TimerSnapshot(
        phase: phase,
        totalSeconds: total,
        remainingSeconds: remaining,
        completedSessions: number('completedSessions', 30),
        deadline: deadline,
        startedAt: startedAt,
        sessionId: id,
        taskId: text('taskId'),
        taskTitle: text('taskTitle'),
        stopped: data['stopped'] as bool);
  }

  Map<String, dynamic> toJson() => {
        'phase': phase.name,
        'totalSeconds': totalSeconds,
        'remainingSeconds': remainingSeconds,
        'completedSessions': completedSessions,
        'deadline': deadline?.toUtc().toIso8601String(),
        'startedAt': startedAt?.toUtc().toIso8601String(),
        'sessionId': sessionId,
        'taskId': taskId,
        'taskTitle': taskTitle,
        'stopped': stopped,
      };
}
