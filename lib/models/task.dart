class Task {
  final String id;
  final String title;
  final bool completed;
  final DateTime? completedAt;

  const Task(
      {required this.id,
      required this.title,
      this.completed = false,
      this.completedAt});

  Task copyWith(
          {String? title,
          bool? completed,
          DateTime? completedAt,
          bool clearCompletedAt = false}) =>
      Task(
        id: id,
        title: title ?? this.title,
        completed: completed ?? this.completed,
        completedAt: clearCompletedAt ? null : completedAt ?? this.completedAt,
      );

  factory Task.fromJson(Object? value, String fallbackId) {
    if (value is! Map ||
        value['title'] is! String ||
        (value['title'] as String).trim().isEmpty ||
        value['ok'] is! bool ||
        (value['id'] != null &&
            (value['id'] is! String || (value['id'] as String).isEmpty)) ||
        (value['completedAt'] != null &&
            (value['completedAt'] is! String ||
                DateTime.tryParse(value['completedAt']) == null))) {
      throw const FormatException('Tarefa inválida');
    }
    return Task(
      id: value['id'] is String && (value['id'] as String).isNotEmpty
          ? value['id'] as String
          : fallbackId,
      title: (value['title'] as String).trim(),
      completed: value['ok'] as bool,
      completedAt: value['completedAt'] == null
          ? null
          : DateTime.parse(value['completedAt'] as String),
    );
  }

  Map<String, Object?> toJson() => {
        'id': id,
        'title': title,
        'ok': completed,
        'completedAt': completedAt?.toUtc().toIso8601String()
      };
}
