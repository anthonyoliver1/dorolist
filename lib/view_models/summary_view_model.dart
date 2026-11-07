import 'package:flutter/foundation.dart';

import '../models/activity.dart';
import '../repositories/activity_journal.dart';

class SummaryViewModel implements Listenable {
  const SummaryViewModel(this._journal, {this.now = DateTime.now});

  final ActivityJournal _journal;
  final DateTime Function() now;

  bool get loaded => _journal.loaded;
  String? get error => _journal.error;
  ({DateTime date, int completed, List<FocusRecord> sessions, int seconds})
      get today {
    final date = now().toLocal();
    final sessions = _journal.sessionsOn(date);
    return (
      date: date,
      completed: _journal.tasksOn(date),
      sessions: sessions,
      seconds: sessions.fold(0, (total, record) => total + record.seconds),
    );
  }

  Future<void> retryLoad() async {
    try {
      await _journal.load();
    } catch (_) {
      // The repository exposes the error through its observable state.
    }
  }

  Future<void> retrySave() async {
    try {
      await _journal.persist();
    } catch (_) {
      // The repository exposes the error through its observable state.
    }
  }

  @override
  void addListener(VoidCallback listener) => _journal.addListener(listener);

  @override
  void removeListener(VoidCallback listener) =>
      _journal.removeListener(listener);

  static String duration(int seconds) =>
      '${seconds ~/ 60} min${seconds % 60 == 0 ? '' : ' ${seconds % 60} s'}';

  static String dateLabel(DateTime date) {
    const weekdays = [
      'segunda-feira',
      'terça-feira',
      'quarta-feira',
      'quinta-feira',
      'sexta-feira',
      'sábado',
      'domingo'
    ];
    const months = [
      'janeiro',
      'fevereiro',
      'março',
      'abril',
      'maio',
      'junho',
      'julho',
      'agosto',
      'setembro',
      'outubro',
      'novembro',
      'dezembro'
    ];
    return '${weekdays[date.weekday - 1]} · ${date.day} de ${months[date.month - 1]}';
  }

  static String sessionTime(FocusRecord record) {
    final time = record.endedAt.toLocal();
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }
}
