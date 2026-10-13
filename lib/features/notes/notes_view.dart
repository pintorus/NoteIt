import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers.dart';
import '../../data/database.dart';
import '../../data/note_repository.dart';
import '../folders/folder_sheet.dart';
import 'note_card.dart';

class NotesView extends ConsumerStatefulWidget {
  const NotesView({super.key});

  @override
  ConsumerState<NotesView> createState() => _NotesViewState();
}

class _NotesViewState extends ConsumerState<NotesView> {
  final _selected = <int>{};

  bool get _selecting => _selected.isNotEmpty;

  void _toggle(int id) => setState(
      () => _selected.contains(id) ? _selected.remove(id) : _selected.add(id));

  void _clear() => setState(_selected.clear);

  Future<void> _newNote(NoteFilter filter) async {
    final folderId = filter is InFolder ? filter.folderId : null;
    final id = await ref.read(noteRepositoryProvider).create(folderId: folderId);
    if (mounted) context.push('/note/$id');
  }

  @override
  Widget build(BuildContext context) {
    final filter = ref.watch(currentFilterProvider);
    final folders = ref.watch(foldersProvider).value ?? const [];
    final notes = ref.watch(notesProvider(filter));
    final grid = ref.watch(gridViewProvider);
    final inTrash = filter is Trash;

    return PopScope(
      canPop: !_selecting,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _clear();
      },
      child: Scaffold(
        appBar: _selecting
            ? _selectionBar(inTrash, notes.value ?? const [])
            : AppBar(
                title: InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () async {
                    final f = await showFolderSheet(context, filter);
                    if (f != null) {
                      _clear();
                      ref.read(currentFilterProvider.notifier).set(f);
                    }
                  },
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Flexible(
                      child: Text(filterLabel(filter, folders),
                          overflow: TextOverflow.ellipsis),
                    ),
                    const Icon(Icons.arrow_drop_down),
                  ]),
                ),
                actions: [
                  IconButton(
                    tooltip: 'Rechercher',
                    icon: const Icon(Icons.search),
                    onPressed: () => context.push('/search'),
                  ),
                  IconButton(
                    tooltip: grid ? 'Affichage liste' : 'Affichage grille',
                    icon: Icon(grid ? Icons.view_agenda_outlined : Icons.grid_view),
                    onPressed: () => ref.read(gridViewProvider.notifier).toggle(),
                  ),
                  _sortMenu(),
                ],
              ),
        floatingActionButton: inTrash || _selecting
            ? null
            : FloatingActionButton(
                tooltip: 'Nouvelle note',
                onPressed: () => _newNote(filter),
                child: const Icon(Icons.add),
              ),
        body: notes.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Erreur : $e')),
          data: (list) => list.isEmpty
              ? _empty(inTrash)
              : _notes(list, grid, inTrash),
        ),
      ),
    );
  }

  Widget _notes(List<Note> list, bool grid, bool inTrash) {
    Widget card(Note n) => NoteCard(
          note: n,
          selected: _selected.contains(n.id),
          maxPreviewLines: grid ? 6 : 2,
          onTap: () {
            if (_selecting) {
              _toggle(n.id);
            } else if (inTrash) {
              _toggle(n.id); // en corbeille : sélection pour restaurer/supprimer
            } else {
              context.push('/note/${n.id}');
            }
          },
          onLongPress: () => _toggle(n.id),
        );

    final banner = inTrash
        ? const Padding(
            padding: EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: Text(
                'Les notes sont supprimées définitivement après 30 jours.'),
          )
        : null;

    if (!grid) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 88),
        children: [?banner, for (final n in list) card(n)],
      );
    }
    // Grille « masonry » sur deux colonnes, en alternance.
    final left = <Note>[], right = <Note>[];
    for (var i = 0; i < list.length; i++) {
      (i.isEven ? left : right).add(list[i]);
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 88),
      children: [
        ?banner,
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(child: Column(children: [for (final n in left) card(n)])),
          Expanded(child: Column(children: [for (final n in right) card(n)])),
        ]),
      ],
    );
  }

  Widget _empty(bool inTrash) => Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(inTrash ? Icons.delete_outline : Icons.note_alt_outlined,
              size: 64, color: Theme.of(context).colorScheme.outline),
          const SizedBox(height: 12),
          Text(inTrash ? 'La corbeille est vide' : 'Aucune note'),
        ]),
      );

  Widget _sortMenu() {
    final sort = ref.watch(noteSortProvider);
    return PopupMenuButton<NoteSort>(
      tooltip: 'Trier',
      icon: const Icon(Icons.sort),
      initialValue: sort,
      onSelected: ref.read(noteSortProvider.notifier).set,
      itemBuilder: (_) => const [
        PopupMenuItem(value: NoteSort.updated, child: Text('Date de modification')),
        PopupMenuItem(value: NoteSort.created, child: Text('Date de création')),
        PopupMenuItem(value: NoteSort.title, child: Text('Titre')),
      ],
    );
  }

  AppBar _selectionBar(bool inTrash, List<Note> visible) {
    final repo = ref.read(noteRepositoryProvider);
    final ids = _selected.toList();
    final allPinned = visible
        .where((n) => _selected.contains(n.id))
        .every((n) => n.isPinned);

    Future<void> run(Future<void> Function() action) async {
      await action();
      _clear();
    }

    return AppBar(
      leading: IconButton(icon: const Icon(Icons.close), onPressed: _clear),
      title: Text('${_selected.length} sélectionnée(s)'),
      actions: [
        IconButton(
          tooltip: 'Tout sélectionner',
          icon: const Icon(Icons.select_all),
          onPressed: () =>
              setState(() => _selected.addAll(visible.map((n) => n.id))),
        ),
        if (inTrash) ...[
          IconButton(
            tooltip: 'Restaurer',
            icon: const Icon(Icons.restore),
            onPressed: () => run(() => repo.restore(ids)),
          ),
          IconButton(
            tooltip: 'Supprimer définitivement',
            icon: const Icon(Icons.delete_forever),
            onPressed: () async {
              final ok = await _confirm(
                  'Supprimer définitivement ${ids.length} note(s) ?');
              if (!ok) return;
              await run(() async => ref
                  .read(imageStoreProvider)
                  .deleteAll(await repo.deleteForever(ids)));
            },
          ),
        ] else ...[
          IconButton(
            tooltip: allPinned ? 'Désépingler' : 'Épingler',
            icon: Icon(allPinned ? Icons.push_pin : Icons.push_pin_outlined),
            onPressed: () => run(() => repo.setPinned(ids, !allPinned)),
          ),
          IconButton(
            tooltip: 'Déplacer',
            icon: const Icon(Icons.drive_file_move_outline),
            onPressed: () async {
              final target = await pickFolder(context, ref);
              if (target != null) await run(() => repo.move(ids, target.folderId));
            },
          ),
          IconButton(
            tooltip: 'Supprimer',
            icon: const Icon(Icons.delete_outline),
            onPressed: () async {
              await run(() => repo.trash(ids));
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text('${ids.length} note(s) déplacée(s) dans la corbeille'),
                action: SnackBarAction(
                    label: 'Annuler', onPressed: () => repo.restore(ids)),
              ));
            },
          ),
        ],
      ],
    );
  }

  Future<bool> _confirm(String message) async =>
      await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          content: Text(message),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(c, false),
                child: const Text('Annuler')),
            FilledButton(
                onPressed: () => Navigator.pop(c, true),
                child: const Text('Supprimer')),
          ],
        ),
      ) ??
      false;
}
