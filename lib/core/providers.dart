import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/database.dart';
import '../data/folder_repository.dart';
import '../data/note_repository.dart';
import '../data/task_repository.dart';
import 'image_store.dart';
import 'reminders.dart';

/// Surchargé dans `main()` avec l'instance ouverte.
final databaseProvider =
    Provider<AppDatabase>((ref) => throw UnimplementedError());
final imageStoreProvider =
    Provider<ImageStore>((ref) => throw UnimplementedError());
final remindersProvider = Provider<Reminders>((ref) => Reminders.noop());

final noteRepositoryProvider =
    Provider((ref) => NoteRepository(ref.watch(databaseProvider)));
final folderRepositoryProvider =
    Provider((ref) => FolderRepository(ref.watch(databaseProvider)));
final taskRepositoryProvider =
    Provider((ref) => TaskRepository(ref.watch(databaseProvider)));

final foldersProvider = StreamProvider<List<Folder>>(
    (ref) => ref.watch(folderRepositoryProvider).watchAll());
final folderCountsProvider = StreamProvider<Map<int?, int>>(
    (ref) => ref.watch(folderRepositoryProvider).watchCounts());

final noteSortProvider =
    NotifierProvider<NoteSortNotifier, NoteSort>(NoteSortNotifier.new);

class NoteSortNotifier extends Notifier<NoteSort> {
  @override
  NoteSort build() => NoteSort.updated;
  void set(NoteSort sort) => state = sort;
}

final gridViewProvider =
    NotifierProvider<GridViewNotifier, bool>(GridViewNotifier.new);

class GridViewNotifier extends Notifier<bool> {
  @override
  bool build() => true;
  void toggle() => state = !state;
}

final notesProvider = StreamProvider.family<List<Note>, NoteFilter>((ref, f) =>
    ref.watch(noteRepositoryProvider).watch(f, sort: ref.watch(noteSortProvider)));

final tasksProvider = StreamProvider<List<Task>>(
    (ref) => ref.watch(taskRepositoryProvider).watchAll());

final currentFilterProvider =
    NotifierProvider<CurrentFilterNotifier, NoteFilter>(CurrentFilterNotifier.new);

class CurrentFilterNotifier extends Notifier<NoteFilter> {
  @override
  NoteFilter build() => const AllNotes();
  void set(NoteFilter filter) => state = filter;
}
