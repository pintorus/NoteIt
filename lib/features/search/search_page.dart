import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers.dart';
import '../../data/database.dart';

/// Recherche dans toutes les notes (hors corbeille), termes surlignés.
class SearchPage extends ConsumerStatefulWidget {
  const SearchPage({super.key});

  @override
  ConsumerState<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends ConsumerState<SearchPage> {
  final _query = TextEditingController();
  Timer? _debounce;
  List<Note> _results = const [];

  @override
  void dispose() {
    _debounce?.cancel();
    _query.dispose();
    super.dispose();
  }

  void _onChanged(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 200), _run);
  }

  Future<void> _run() async {
    final results = await ref.read(noteRepositoryProvider).search(_query.text);
    if (mounted) setState(() => _results = results);
  }

  @override
  Widget build(BuildContext context) {
    final terms = _query.text
        .trim()
        .split(RegExp(r'\s+'))
        .where((t) => t.isNotEmpty)
        .toList();
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _query,
          autofocus: true,
          onChanged: _onChanged,
          decoration: const InputDecoration(
              hintText: 'Rechercher dans les notes', border: InputBorder.none),
        ),
        actions: [
          if (_query.text.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.clear),
              onPressed: () {
                _query.clear();
                setState(() => _results = const []);
              },
            ),
        ],
      ),
      body: _results.isEmpty
          ? Center(
              child: Text(terms.isEmpty ? '' : 'Aucun résultat',
                  style: TextStyle(color: Theme.of(context).colorScheme.outline)))
          : ListView.separated(
              itemCount: _results.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (_, i) {
                final n = _results[i];
                return ListTile(
                  title: highlight(context, n.title.isEmpty ? 'Sans titre' : n.title,
                      terms, maxLines: 1),
                  subtitle: highlight(context, snippet(n.plainText, terms), terms,
                      maxLines: 2),
                  onTap: () async {
                    await context.push('/note/${n.id}');
                    _run();
                  },
                );
              },
            ),
    );
  }
}

/// Supprime les accents pour comparer comme FTS5 (remove_diacritics).
String fold(String s) {
  const from = 'àâäáãåçéèêëíìîïñóòôöõúùûüýÿœæÀÂÄÁÃÅÇÉÈÊËÍÌÎÏÑÓÒÔÖÕÚÙÛÜÝ';
  const to = 'aaaaaaceeeeiiiinooooouuuuyyoaAAAAAACEEEEIIIINOOOOOUUUUY';
  final b = StringBuffer();
  for (final ch in s.split('')) {
    final i = from.indexOf(ch);
    b.write(i < 0 ? ch : to[i]);
  }
  return b.toString().toLowerCase();
}

/// Extrait autour de la première occurrence.
String snippet(String text, List<String> terms) {
  final flat = text.replaceAll(RegExp(r'\s+'), ' ').replaceAll('￼', '').trim();
  final folded = fold(flat);
  final hit = terms
      .map((t) => folded.indexOf(fold(t)))
      .where((i) => i >= 0)
      .fold<int?>(null, (a, b) => a == null || b < a ? b : a);
  if (hit == null || hit < 40) return flat;
  return '…${flat.substring(hit - 30)}';
}

Widget highlight(BuildContext context, String text, List<String> terms,
    {int maxLines = 2}) {
  final scheme = Theme.of(context).colorScheme;
  final folded = fold(text); // même longueur que text (1 caractère ↔ 1 caractère)
  final marks = List.filled(text.length, false);
  for (final t in terms.map(fold)) {
    for (var i = folded.indexOf(t); i >= 0; i = folded.indexOf(t, i + 1)) {
      marks.fillRange(i, i + t.length, true);
    }
  }
  final spans = <TextSpan>[];
  var start = 0;
  for (var i = 1; i <= text.length; i++) {
    if (i == text.length || marks[i] != marks[start]) {
      spans.add(TextSpan(
        text: text.substring(start, i),
        style: marks[start]
            ? TextStyle(
                backgroundColor: scheme.primaryContainer,
                color: scheme.onPrimaryContainer)
            : null,
      ));
      start = i;
    }
  }
  return Text.rich(TextSpan(children: spans),
      maxLines: maxLines, overflow: TextOverflow.ellipsis);
}
