class PomodoroSettings {
  const PomodoroSettings({
    this.focusMinutes = 25,
    this.shortBreakMinutes = 5,
    this.longBreakMinutes = 15,
    this.sessionsBeforeLongBreak = 4,
    this.autoStart = false,
  });

  final int focusMinutes;
  final int shortBreakMinutes;
  final int longBreakMinutes;
  final int sessionsBeforeLongBreak;
  final bool autoStart;

  factory PomodoroSettings.fromJson(Object? value) {
    if (value is! Map) throw const FormatException('Configurações inválidas');
    int read(String key, int maximum) {
      final number = value[key];
      if (number is! int || number < 1 || number > maximum) {
        throw const FormatException('Configuração fora do intervalo');
      }
      return number;
    }

    if (value['autoStart'] is! bool) {
      throw const FormatException('Avanço automático inválido');
    }
    return PomodoroSettings(
      focusMinutes: read('focusMinutes', 180),
      shortBreakMinutes: read('shortBreakMinutes', 60),
      longBreakMinutes: read('longBreakMinutes', 90),
      sessionsBeforeLongBreak: read('sessionsBeforeLongBreak', 30),
      autoStart: value['autoStart'] as bool,
    );
  }

  Map<String, Object> toJson() => {
        'focusMinutes': focusMinutes,
        'shortBreakMinutes': shortBreakMinutes,
        'longBreakMinutes': longBreakMinutes,
        'sessionsBeforeLongBreak': sessionsBeforeLongBreak,
        'autoStart': autoStart,
      };
}
