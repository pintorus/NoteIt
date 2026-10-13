import 'package:drift/drift.dart';

import 'database.dart';

class TaskRepository {
  TaskRepository(this._db, {DateTime Function()? clock})
      : _now = clock ?? DateTime.now;
  final AppDatabase _db;
  final DateTime Function() _now;

  /// Tâches à faire d'abord (par ordre), puis terminées (les plus récentes d'abord).
  Stream<List<Task>> watchAll() => (_db.select(_db.tasks)
        ..orderBy([
          (t) => OrderingTerm.asc(t.isDone),
          (t) => OrderingTerm.asc(t.sortOrder),
          (t) => OrderingTerm.desc(t.completedAt),
        ]))
      .watch();

  Future<Task?> get(int id) =>
      (_db.select(_db.tasks)..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<int> create(String title,
      {DateTime? reminderAt, TaskRepeat repeat = TaskRepeat.none}) async {
    final min = _db.tasks.sortOrder.min();
    final row =
        await (_db.selectOnly(_db.tasks)..addColumns([min])).getSingle();
    return _db.into(_db.tasks).insert(TasksCompanion.insert(
          title: title,
          reminderAt: Value(reminderAt),
          repeat: Value(repeat),
          sortOrder: Value((row.read(min) ?? 1) - 1), // nouvelle tâche en haut
          createdAt: Value(_now()),
        ));
  }

  Future<void> update(int id,
          {String? title, Value<DateTime?> reminderAt = const Value.absent(),
          TaskRepeat? repeat}) =>
      (_db.update(_db.tasks)..where((t) => t.id.equals(id))).write(
        TasksCompanion(
          title: title == null ? const Value.absent() : Value(title),
          reminderAt: reminderAt,
          repeat: repeat == null ? const Value.absent() : Value(repeat),
        ),
      );

  /// Cocher une tâche récurrente la reprogramme au lieu de la terminer.
  /// Renvoie la tâche mise à jour (pour replanifier la notification).
  Future<Task> toggleDone(int id) => _db.transaction(() async {
        final task = (await get(id))!;
        final TasksCompanion change;
        if (!task.isDone &&
            task.repeat != TaskRepeat.none &&
            task.reminderAt != null) {
          change = TasksCompanion(
              reminderAt: Value(nextOccurrence(task.reminderAt!, task.repeat, _now())));
        } else {
          change = TasksCompanion(
            isDone: Value(!task.isDone),
            completedAt: Value(task.isDone ? null : _now()),
          );
        }
        await (_db.update(_db.tasks)..where((t) => t.id.equals(id)))
            .write(change);
        return (await get(id))!;
      });

  Future<void> delete(Iterable<int> ids) =>
      (_db.delete(_db.tasks)..where((t) => t.id.isIn(ids))).go();

  Future<void> deleteCompleted() =>
      (_db.delete(_db.tasks)..where((t) => t.isDone)).go();

  /// Prochaine occurrence strictement après [now].
  static DateTime nextOccurrence(DateTime from, TaskRepeat repeat, DateTime now) {
    var next = from;
    do {
      next = switch (repeat) {
        TaskRepeat.none => next,
        TaskRepeat.daily => DateTime(next.year, next.month, next.day + 1,
            next.hour, next.minute),
        TaskRepeat.weekly => DateTime(next.year, next.month, next.day + 7,
            next.hour, next.minute),
        TaskRepeat.monthly => _addMonth(next),
      };
    } while (repeat != TaskRepeat.none && !next.isAfter(now));
    return next;
  }

  static DateTime _addMonth(DateTime d) {
    final lastDay = DateTime(d.year, d.month + 2, 0).day;
    return DateTime(d.year, d.month + 1, d.day > lastDay ? lastDay : d.day,
        d.hour, d.minute);
  }
}
