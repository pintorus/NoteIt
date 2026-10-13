import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:noteit/data/database.dart';
import 'package:noteit/data/folder_repository.dart';
import 'package:noteit/data/note_repository.dart';
import 'package:noteit/data/task_repository.dart';

void main() {
  late AppDatabase db;
  late DateTime now;
  late NoteRepository notes;
  late FolderRepository folders;
  late TaskRepository tasks;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    now = DateTime(2026, 1, 10, 9);
    notes = NoteRepository(db, clock: () => now);
    folders = FolderRepository(db);
    tasks = TaskRepository(db, clock: () => now);
  });
  tearDown(() => db.close());

  group('notes', () {
    test('titre déduit de la première ligne non vide', () async {
      final id = await notes.create();
      await notes.saveContent(id, contentDelta: '[]', plainText: '\n  Courses \nlait');
      expect((await notes.get(id))!.title, 'Courses');
    });

    test('épinglées en premier, puis par date de modification', () async {
      final a = await notes.create();
      now = now.add(const Duration(minutes: 1));
      final b = await notes.create();
      await notes.setPinned([a], true);
      final list = await notes.watch(const AllNotes()).first;
      expect(list.map((n) => n.id), [a, b]);
    });

    test('supprimer un dossier renvoie ses notes dans Non classé', () async {
      final f = await folders.create('Travail');
      final id = await notes.create(folderId: f);
      await folders.delete(f);
      expect((await notes.get(id))!.folderId, isNull);
      expect((await notes.watch(const Unfiled()).first).length, 1);
    });

    test('corbeille, restauration et purge après 30 jours', () async {
      final id = await notes.create();
      await notes.addAttachment(id, 'images/x.jpg');
      await notes.trash([id]);
      expect(await notes.watch(const AllNotes()).first, isEmpty);
      expect((await notes.watch(const Trash()).first).length, 1);

      await notes.restore([id]);
      expect((await notes.watch(const AllNotes()).first).length, 1);

      await notes.trash([id]);
      now = now.add(const Duration(days: 29));
      expect(await notes.purgeExpired(), isEmpty);
      now = now.add(const Duration(days: 2));
      expect(await notes.purgeExpired(), ['images/x.jpg']);
      expect(await notes.get(id), isNull);
      expect(await db.select(db.attachments).get(), isEmpty);
    });

    test('recherche FTS par préfixe, sans accents, hors corbeille', () async {
      final a = await notes.create();
      await notes.saveContent(a, contentDelta: '[]', plainText: 'Réunion équipe');
      final b = await notes.create();
      await notes.saveContent(b, contentDelta: '[]', plainText: 'Reunion budget');
      await notes.trash([b]);
      expect((await notes.search('reun')).map((n) => n.id), [a]);
      expect(await notes.search('  '), isEmpty);
    });

    test('compteurs par dossier', () async {
      final f = await folders.create('Perso');
      await notes.create(folderId: f);
      await notes.create(folderId: f);
      await notes.create();
      expect(await folders.watchCounts().first, {null: 1, f: 2});
    });
  });

  group('tâches', () {
    test('nouvelle tâche en haut, terminées en bas', () async {
      final a = await tasks.create('A');
      final b = await tasks.create('B');
      expect((await tasks.watchAll().first).map((t) => t.id), [b, a]);
      await tasks.toggleDone(b);
      final list = await tasks.watchAll().first;
      expect(list.map((t) => t.id), [a, b]);
      expect(list.last.completedAt, now);
    });

    test('cocher une tâche récurrente la reprogramme', () async {
      final id = await tasks.create('Sport',
          reminderAt: DateTime(2026, 1, 10, 8), repeat: TaskRepeat.daily);
      final t = await tasks.toggleDone(id);
      expect(t.isDone, isFalse);
      expect(t.reminderAt, DateTime(2026, 1, 11, 8));
    });

    test('modifier puis effacer le rappel', () async {
      final id = await tasks.create('X');
      await tasks.update(id, reminderAt: Value(DateTime(2026, 2, 1)));
      expect((await tasks.get(id))!.reminderAt, DateTime(2026, 2, 1));
      await tasks.update(id, reminderAt: const Value(null));
      expect((await tasks.get(id))!.reminderAt, isNull);
    });

    test('récurrence mensuelle bornée au dernier jour du mois', () {
      expect(
        TaskRepository.nextOccurrence(
            DateTime(2026, 1, 31, 8), TaskRepeat.monthly, DateTime(2026, 1, 31, 9)),
        DateTime(2026, 2, 28, 8),
      );
    });
  });
}
