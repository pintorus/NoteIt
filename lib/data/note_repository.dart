import 'package:drift/drift.dart';

import 'database.dart';

/// Filtre de la liste : un dossier, « Non classé », tout, ou la corbeille.
sealed class NoteFilter {
  const NoteFilter();
}

class AllNotes extends NoteFilter {
  const AllNotes();
}

class Unfiled extends NoteFilter {
  const Unfiled();
}

class InFolder extends NoteFilter {
  const InFolder(this.folderId);
  final int folderId;

  @override
  bool operator ==(Object other) =>
      other is InFolder && other.folderId == folderId;

  @override
  int get hashCode => folderId.hashCode;
}

class Trash extends NoteFilter {
  const Trash();
}

enum NoteSort { updated, created, title }

class NoteRepository {
  NoteRepository(this._db, {DateTime Function()? clock})
      : _now = clock ?? DateTime.now;
  final AppDatabase _db;
  final DateTime Function() _now;

  static const trashRetention = Duration(days: 30);

  Stream<List<Note>> watch(NoteFilter filter,
      {NoteSort sort = NoteSort.updated}) {
    final q = _db.select(_db.notes);
    switch (filter) {
      case AllNotes():
        q.where((n) => n.deletedAt.isNull());
      case Unfiled():
        q.where((n) => n.deletedAt.isNull() & n.folderId.isNull());
      case InFolder(:final folderId):
        q.where((n) => n.deletedAt.isNull() & n.folderId.equals(folderId));
      case Trash():
        q.where((n) => n.deletedAt.isNotNull());
    }
    q.orderBy([
      if (filter is! Trash)
        (n) => OrderingTerm.desc(n.isPinned),
      switch (sort) {
        NoteSort.updated => (n) => OrderingTerm.desc(n.updatedAt),
        NoteSort.created => (n) => OrderingTerm.desc(n.createdAt),
        NoteSort.title => (n) => OrderingTerm.asc(n.title.lower()),
      },
    ]);
    return q.watch();
  }

  Future<Note?> get(int id) =>
      (_db.select(_db.notes)..where((n) => n.id.equals(id))).getSingleOrNull();

  Future<int> create({int? folderId}) {
    final now = _now();
    return _db.into(_db.notes).insert(NotesCompanion.insert(
          folderId: Value(folderId),
          createdAt: Value(now),
          updatedAt: Value(now),
        ));
  }

  /// Sauvegarde le contenu. Sans titre explicite, le titre est la première ligne.
  Future<void> saveContent(int id,
      {required String contentDelta, required String plainText, String? title}) {
    final effectiveTitle = (title != null && title.trim().isNotEmpty)
        ? title.trim()
        : deriveTitle(plainText);
    return (_db.update(_db.notes)..where((n) => n.id.equals(id))).write(
      NotesCompanion(
        contentDelta: Value(contentDelta),
        plainText: Value(plainText),
        title: Value(effectiveTitle),
        updatedAt: Value(_now()),
      ),
    );
  }

  static String deriveTitle(String plainText) {
    final line = plainText
        .split('\n')
        .map((l) => l.trim())
        .firstWhere((l) => l.isNotEmpty, orElse: () => '');
    return line.length > 80 ? line.substring(0, 80) : line;
  }

  Future<void> setPinned(Iterable<int> ids, bool pinned) =>
      (_db.update(_db.notes)..where((n) => n.id.isIn(ids)))
          .write(NotesCompanion(isPinned: Value(pinned)));

  Future<void> move(Iterable<int> ids, int? folderId) =>
      (_db.update(_db.notes)..where((n) => n.id.isIn(ids)))
          .write(NotesCompanion(folderId: Value(folderId)));

  Future<void> trash(Iterable<int> ids) =>
      (_db.update(_db.notes)..where((n) => n.id.isIn(ids)))
          .write(NotesCompanion(deletedAt: Value(_now()), isPinned: const Value(false)));

  Future<void> restore(Iterable<int> ids) =>
      (_db.update(_db.notes)..where((n) => n.id.isIn(ids)))
          .write(const NotesCompanion(deletedAt: Value(null)));

  /// Supprime définitivement et renvoie les chemins des pièces jointes à effacer du disque.
  Future<List<String>> deleteForever(Iterable<int> ids) =>
      _db.transaction(() async {
        final paths = await (_db.select(_db.attachments)
              ..where((a) => a.noteId.isIn(ids)))
            .map((a) => a.path)
            .get();
        await (_db.delete(_db.notes)..where((n) => n.id.isIn(ids))).go();
        return paths;
      });

  /// Purge les notes en corbeille depuis plus de 30 jours.
  Future<List<String>> purgeExpired() async {
    final limit = _now().subtract(trashRetention);
    final ids = await (_db.select(_db.notes)
          ..where((n) => n.deletedAt.isSmallerThanValue(limit)))
        .map((n) => n.id)
        .get();
    return ids.isEmpty ? const [] : deleteForever(ids);
  }

  /// Recherche plein texte (hors corbeille), insensible aux accents.
  Future<List<Note>> search(String query) {
    final terms = query
        .trim()
        .split(RegExp(r'\s+'))
        .where((t) => t.isNotEmpty)
        .map((t) => '"${t.replaceAll('"', '""')}"*')
        .join(' ');
    if (terms.isEmpty) return Future.value(const []);
    return _db
        .customSelect(
          'SELECT notes.* FROM notes_fts '
          'JOIN notes ON notes.id = notes_fts.rowid '
          'WHERE notes_fts MATCH ? AND notes.deleted_at IS NULL '
          'ORDER BY rank',
          variables: [Variable.withString(terms)],
          readsFrom: {_db.notes},
        )
        .asyncMap((row) => _db.notes.mapFromRow(row))
        .get();
  }

  Future<void> addAttachment(int noteId, String relativePath) => _db
      .into(_db.attachments)
      .insert(AttachmentsCompanion.insert(noteId: noteId, path: relativePath));
}
