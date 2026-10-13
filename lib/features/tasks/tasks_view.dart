import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../core/providers.dart';
import '../../data/database.dart';

const repeatLabels = {
  TaskRepeat.none: 'Jamais',
  TaskRepeat.daily: 'Tous les jours',
  TaskRepeat.weekly: 'Toutes les semaines',
  TaskRepeat.monthly: 'Tous les mois',
};

class TasksView extends ConsumerStatefulWidget {
  const TasksView({super.key});

  @override
  ConsumerState<TasksView> createState() => _TasksViewState();
}

class _TasksViewState extends ConsumerState<TasksView> {
  bool _showDone = true;

  Future<void> _toggle(Task task) async {
    final updated = await ref.read(taskRepositoryProvider).toggleDone(task.id);
    await ref.read(remindersProvider).sync(updated);
  }

  Future<void> _delete(Task task) async {
    await ref.read(taskRepositoryProvider).delete([task.id]);
    await ref.read(remindersProvider).cancel(task.id);
  }

  @override
  Widget build(BuildContext context) {
    final tasks = ref.watch(tasksProvider);
    return Scaffold(
      floatingActionButton: FloatingActionButton(
        tooltip: 'Nouvelle tâche',
        onPressed: () => showTaskSheet(context),
        child: const Icon(Icons.add),
      ),
      body: tasks.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Erreur : $e')),
        data: (list) {
          final todo = list.where((t) => !t.isDone).toList();
          final done = list.where((t) => t.isDone).toList();
          if (list.isEmpty) {
            return Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.task_alt,
                    size: 64, color: Theme.of(context).colorScheme.outline),
                const SizedBox(height: 12),
                const Text('Aucune tâche'),
              ]),
            );
          }
          return ListView(
            padding: const EdgeInsets.only(bottom: 88, top: 8),
            children: [
              for (final t in todo) _tile(t),
              if (done.isNotEmpty)
                ListTile(
                  title: Text('Terminées (${done.length})',
                      style: Theme.of(context).textTheme.titleSmall),
                  leading: Icon(
                      _showDone ? Icons.expand_less : Icons.expand_more),
                  onTap: () => setState(() => _showDone = !_showDone),
                  trailing: TextButton(
                    onPressed: () =>
                        ref.read(taskRepositoryProvider).deleteCompleted(),
                    child: const Text('Tout effacer'),
                  ),
                ),
              if (_showDone) for (final t in done) _tile(t),
            ],
          );
        },
      ),
    );
  }

  Widget _tile(Task t) {
    final scheme = Theme.of(context).colorScheme;
    final at = t.reminderAt;
    final overdue = at != null && !t.isDone && at.isBefore(DateTime.now());
    return Dismissible(
      key: ValueKey(t.id),
      direction: DismissDirection.endToStart,
      background: Container(
        color: scheme.errorContainer,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        child: Icon(Icons.delete_outline, color: scheme.onErrorContainer),
      ),
      onDismissed: (_) => _delete(t),
      child: ListTile(
        leading: Checkbox(value: t.isDone, onChanged: (_) => _toggle(t)),
        title: Text(
          t.title,
          style: t.isDone
              ? TextStyle(
                  decoration: TextDecoration.lineThrough,
                  color: scheme.outline)
              : null,
        ),
        subtitle: at == null
            ? null
            : Row(children: [
                Icon(Icons.alarm,
                    size: 14, color: overdue ? scheme.error : scheme.outline),
                const SizedBox(width: 4),
                Text(formatDateTime(context, at),
                    style: TextStyle(
                        color: overdue ? scheme.error : scheme.outline)),
                if (t.repeat != TaskRepeat.none) ...[
                  const SizedBox(width: 6),
                  Icon(Icons.repeat, size: 14, color: scheme.outline),
                ],
              ]),
        onTap: () => showTaskSheet(context, task: t),
      ),
    );
  }
}

/// Création / édition d'une tâche avec rappel.
Future<void> showTaskSheet(BuildContext context, {Task? task}) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => Padding(
        padding: EdgeInsets.only(
            bottom: MediaQuery.viewInsetsOf(context).bottom),
        child: _TaskSheet(task: task),
      ),
    );

class _TaskSheet extends ConsumerStatefulWidget {
  const _TaskSheet({this.task});
  final Task? task;

  @override
  ConsumerState<_TaskSheet> createState() => _TaskSheetState();
}

class _TaskSheetState extends ConsumerState<_TaskSheet> {
  late final _title = TextEditingController(text: widget.task?.title);
  late DateTime? _reminder = widget.task?.reminderAt;
  late TaskRepeat _repeat = widget.task?.repeat ?? TaskRepeat.none;

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  Future<void> _pickReminder() async {
    final now = DateTime.now();
    final initial = _reminder ?? now.add(const Duration(hours: 1));
    final date = await showDatePicker(
      context: context,
      initialDate: initial.isBefore(now) ? now : initial,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: DateTime(now.year + 10),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
        context: context, initialTime: TimeOfDay.fromDateTime(initial));
    if (time == null) return;
    setState(() => _reminder =
        DateTime(date.year, date.month, date.day, time.hour, time.minute));
  }

  Future<void> _submit() async {
    final title = _title.text.trim();
    if (title.isEmpty) return;
    final repo = ref.read(taskRepositoryProvider);
    final repeat = _reminder == null ? TaskRepeat.none : _repeat;
    final id = widget.task?.id ??
        await repo.create(title, reminderAt: _reminder, repeat: repeat);
    if (widget.task != null) {
      await repo.update(id,
          title: title, reminderAt: Value(_reminder), repeat: repeat);
    }
    final saved = await repo.get(id);
    if (saved != null) await ref.read(remindersProvider).sync(saved);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _title,
              autofocus: widget.task == null,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(hintText: 'Tâche'),
              onSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: 12),
            Wrap(spacing: 8, runSpacing: 8, children: [
              InputChip(
                avatar: const Icon(Icons.alarm, size: 18),
                label: Text(_reminder == null
                    ? 'Rappel'
                    : formatDateTime(context, _reminder!)),
                onPressed: _pickReminder,
                onDeleted:
                    _reminder == null ? null : () => setState(() => _reminder = null),
              ),
              if (_reminder != null)
                PopupMenuButton<TaskRepeat>(
                  initialValue: _repeat,
                  onSelected: (r) => setState(() => _repeat = r),
                  itemBuilder: (_) => [
                    for (final e in repeatLabels.entries)
                      PopupMenuItem(value: e.key, child: Text(e.value)),
                  ],
                  child: Chip(
                    avatar: const Icon(Icons.repeat, size: 18),
                    label: Text(repeatLabels[_repeat]!),
                  ),
                ),
            ]),
            const SizedBox(height: 16),
            Row(children: [
              if (widget.task != null)
                TextButton.icon(
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Supprimer'),
                  onPressed: () async {
                    await ref
                        .read(taskRepositoryProvider)
                        .delete([widget.task!.id]);
                    await ref.read(remindersProvider).cancel(widget.task!.id);
                    if (context.mounted) Navigator.pop(context);
                  },
                ),
              const Spacer(),
              FilledButton(onPressed: _submit, child: const Text('Enregistrer')),
            ]),
          ],
        ),
      ),
    );
  }
}
