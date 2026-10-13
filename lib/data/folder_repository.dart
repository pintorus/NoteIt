import 'package:drift/drift.dart';

import 'database.dart';

class FolderRepository {
  FolderRepository(this._db);
  final AppDatabase _db;

  Stream<List<Folder>> watchAll() => (_db.select(_db.folders)
        ..orderBy([(f) => OrderingTerm(expression: f.sortOrder)]))
      .watch();

  /// Nombre de notes actives par dossier (clé null = « Non classé »).
  Stream<Map<int?, int>> watchCounts() {
    final count = _db.notes.id.count();
    final query = _db.selectOnly(_db.notes)
      ..addColumns([_db.notes.folderId, count])
      ..where(_db.notes.deletedAt.isNull())
      ..groupBy([_db.notes.folderId]);
    return query.watch().map((rows) => {
          for (final r in rows) r.read(_db.notes.folderId): r.read(count) ?? 0,
        });
  }

  Future<int> create(String name) async {
    final max = _db.folders.sortOrder.max();
    final row = await (_db.selectOnly(_db.folders)..addColumns([max]))
        .getSingle();
    return _db.into(_db.folders).insert(FoldersCompanion.insert(
          name: name,
          sortOrder: Value((row.read(max) ?? -1) + 1),
        ));
  }

  Future<void> rename(int id, String name) =>
      (_db.update(_db.folders)..where((f) => f.id.equals(id)))
          .write(FoldersCompanion(name: Value(name)));

  /// Les notes du dossier reviennent dans « Non classé » (ON DELETE SET NULL).
  Future<void> delete(int id) =>
      (_db.delete(_db.folders)..where((f) => f.id.equals(id))).go();
}
