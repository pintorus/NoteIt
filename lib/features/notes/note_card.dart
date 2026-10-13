import 'package:flutter/material.dart';

import '../../core/format.dart';
import '../../data/database.dart';

/// Carte d'une note : titre, aperçu, date ; contour si sélectionnée.
class NoteCard extends StatelessWidget {
  const NoteCard({
    super.key,
    required this.note,
    required this.selected,
    required this.onTap,
    required this.onLongPress,
    this.maxPreviewLines = 6,
  });

  final Note note;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final int maxPreviewLines;

  /// Texte affiché sous le titre (sans répéter la première ligne).
  static String preview(Note note) {
    final lines = note.plainText
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty && l != '￼') // ￼ = image
        .toList();
    if (lines.isNotEmpty && lines.first == note.title) lines.removeAt(0);
    return lines.join('\n');
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final body = preview(note);
    return Card(
      elevation: 0,
      color: scheme.surfaceContainerHigh,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: selected
            ? BorderSide(color: scheme.primary, width: 2)
            : BorderSide.none,
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (note.title.isNotEmpty)
                Text(note.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: text.titleMedium),
              if (body.isNotEmpty) ...[
                const SizedBox(height: 6),
                Flexible(
                  child: Text(body,
                      maxLines: maxPreviewLines,
                      overflow: TextOverflow.ellipsis,
                      style: text.bodyMedium
                          ?.copyWith(color: scheme.onSurfaceVariant)),
                ),
              ],
              if (note.title.isEmpty && body.isEmpty)
                Text('Note vide',
                    style: text.bodyMedium?.copyWith(
                        color: scheme.outline, fontStyle: FontStyle.italic)),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(
                  child: Text(formatDate(context, note.updatedAt),
                      style: text.labelSmall?.copyWith(color: scheme.outline)),
                ),
                if (note.isPinned)
                  Icon(Icons.push_pin, size: 14, color: scheme.primary),
              ]),
            ],
          ),
        ),
      ),
    );
  }
}
