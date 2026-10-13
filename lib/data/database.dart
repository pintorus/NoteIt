import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import 'tables.dart';

export 'tables.dart';

part 'database.g.dart';

@DriftDatabase(tables: [Folders, Notes, Attachments, Tasks])
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor])
      : super(executor ?? driftDatabase(name: 'noteit'));

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
          await _createFts();
        },
        beforeOpen: (details) async {
          await customStatement('PRAGMA foreign_keys = ON');
        },
      );

  /// Index plein texte sur titre + texte brut, synchronisé par triggers.
  Future<void> _createFts() async {
    await customStatement('''
      CREATE VIRTUAL TABLE notes_fts USING fts5(
        title, plain_text, content='notes', content_rowid='id',
        tokenize='unicode61 remove_diacritics 2'
      )''');
    await customStatement('''
      CREATE TRIGGER notes_ai AFTER INSERT ON notes BEGIN
        INSERT INTO notes_fts(rowid, title, plain_text)
        VALUES (new.id, new.title, new.plain_text);
      END''');
    await customStatement('''
      CREATE TRIGGER notes_ad AFTER DELETE ON notes BEGIN
        INSERT INTO notes_fts(notes_fts, rowid, title, plain_text)
        VALUES ('delete', old.id, old.title, old.plain_text);
      END''');
    await customStatement('''
      CREATE TRIGGER notes_au AFTER UPDATE ON notes BEGIN
        INSERT INTO notes_fts(notes_fts, rowid, title, plain_text)
        VALUES ('delete', old.id, old.title, old.plain_text);
        INSERT INTO notes_fts(rowid, title, plain_text)
        VALUES (new.id, new.title, new.plain_text);
      END''');
  }
}
