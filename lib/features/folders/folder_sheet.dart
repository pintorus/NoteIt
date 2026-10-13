import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../data/database.dart';
import '../../data/note_repository.dart';

String filterLabel(NoteFilter filter, List<Folder> folders) => switch (filter) {
      AllNotes() => 'Toutes les notes',
      Unfiled() => 'Non classé',
      Trash() => 'Corbeille',
      InFolder(:final folderId) => folders
              .where((f) => f.id == folderId)
              .map((f) => f.name)
              .firstOrNull ??
          'Dossier',
    };

/// Sélection du dossier affiché + gestion (créer, renommer, supprimer).
Future<NoteFilter?> showFolderSheet(BuildContext context, NoteFilter current) =>
    showModalBottomSheet<NoteFilter>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _FolderSheet(current: current),
    );

class _FolderSheet extends ConsumerWidget {
  const _FolderSheet({required this.current});
  final NoteFilter current;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final folders = ref.watch(foldersProvider).value ?? const [];
    final counts = ref.watch(folderCountsProvider).value ?? const {};
    final total = counts.values.fold(0, (a, b) => a + b);

    Widget tile(NoteFilter filter, IconData icon, {int? count, Folder? folder}) =>
        ListTile(
          leading: Icon(icon),
          title: Text(filterLabel(filter, folders)),
          trailing: count == null ? null : Text('$count'),
          selected: filter == current,
          onTap: () => Navigator.pop(context, filter),
          onLongPress:
              folder == null ? null : () => _folderMenu(context, ref, folder),
        );

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.75),
        child: ListView(
          shrinkWrap: true,
          children: [
            tile(const AllNotes(), Icons.notes, count: total),
            tile(const Unfiled(), Icons.inbox_outlined, count: counts[null] ?? 0),
            for (final f in folders)
              tile(InFolder(f.id), Icons.folder_outlined,
                  count: counts[f.id] ?? 0, folder: f),
            ListTile(
              leading: const Icon(Icons.create_new_folder_outlined),
              title: const Text('Nouveau dossier'),
              onTap: () async {
                final name = await askFolderName(context);
                if (name != null) {
                  await ref.read(folderRepositoryProvider).create(name);
                }
              },
            ),
            const Divider(),
            tile(const Trash(), Icons.delete_outline),
          ],
        ),
      ),
    );
  }

  Future<void> _folderMenu(
      BuildContext context, WidgetRef ref, Folder folder) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (c) => SafeArea(
        child: Wrap(children: [
          ListTile(
            leading: const Icon(Icons.edit_outlined),
            title: const Text('Renommer'),
            onTap: () => Navigator.pop(c, 'rename'),
          ),
          ListTile(
            leading: const Icon(Icons.delete_outline),
            title: const Text('Supprimer le dossier'),
            subtitle: const Text('Les notes seront déplacées dans « Non classé »'),
            onTap: () => Navigator.pop(c, 'delete'),
          ),
        ]),
      ),
    );
    if (!context.mounted) return;
    final repo = ref.read(folderRepositoryProvider);
    if (action == 'rename') {
      final name = await askFolderName(context, initial: folder.name);
      if (name != null) await repo.rename(folder.id, name);
    } else if (action == 'delete') {
      await repo.delete(folder.id);
      if (current == InFolder(folder.id) && context.mounted) {
        Navigator.pop(context, const AllNotes());
      }
    }
  }
}

Future<String?> askFolderName(BuildContext context, {String initial = ''}) {
  final controller = TextEditingController(text: initial);
  return showDialog<String>(
    context: context,
    builder: (c) {
      void submit() {
        final name = controller.text.trim();
        if (name.isNotEmpty) Navigator.pop(c, name);
      }

      return AlertDialog(
        title: Text(initial.isEmpty ? 'Nouveau dossier' : 'Renommer'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 100,
          decoration: const InputDecoration(hintText: 'Nom du dossier'),
          onSubmitted: (_) => submit(),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c), child: const Text('Annuler')),
          FilledButton(onPressed: submit, child: const Text('OK')),
        ],
      );
    },
  );
}

/// Choix du dossier de destination (null = « Non classé »).
Future<({int? folderId})?> pickFolder(BuildContext context, WidgetRef ref) {
  final folders = ref.read(foldersProvider).value ?? const [];
  return showModalBottomSheet<({int? folderId})>(
    context: context,
    showDragHandle: true,
    builder: (c) => SafeArea(
      child: ListView(shrinkWrap: true, children: [
        ListTile(
          leading: const Icon(Icons.inbox_outlined),
          title: const Text('Non classé'),
          onTap: () => Navigator.pop(c, (folderId: null)),
        ),
        for (final f in folders)
          ListTile(
            leading: const Icon(Icons.folder_outlined),
            title: Text(f.name),
            onTap: () => Navigator.pop(c, (folderId: f.id)),
          ),
      ]),
    ),
  );
}
