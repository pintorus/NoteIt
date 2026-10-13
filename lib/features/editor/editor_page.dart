import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/format.dart';
import '../../core/providers.dart';
import '../../data/database.dart';
import '../../data/note_repository.dart';
import '../folders/folder_sheet.dart';
import 'image_embed.dart';

class EditorPage extends ConsumerStatefulWidget {
  const EditorPage({super.key, required this.noteId});
  final int noteId;

  @override
  ConsumerState<EditorPage> createState() => _EditorPageState();
}

class _EditorPageState extends ConsumerState<EditorPage> {
  static const _debounce = Duration(milliseconds: 500);

  late final NoteRepository _repo = ref.read(noteRepositoryProvider);
  final _title = TextEditingController();
  final _focus = FocusNode();
  final _scroll = ScrollController();
  QuillController? _controller;
  StreamSubscription<DocChange>? _changes;
  Timer? _timer;
  Note? _note;
  bool _dirty = false;

  bool get _readOnly => _note?.deletedAt != null;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final note = await _repo.get(widget.noteId);
    if (!mounted || note == null) return;
    final doc = _parse(note.contentDelta);
    // Le titre n'est affiché que s'il a été saisi (pas déduit de la 1re ligne).
    if (note.title != NoteRepository.deriveTitle(note.plainText)) {
      _title.text = note.title;
    }
    final controller = QuillController(
      document: doc,
      selection: const TextSelection.collapsed(offset: 0),
      readOnly: note.deletedAt != null,
    );
    _changes = controller.document.changes.listen((_) => _scheduleSave());
    _title.addListener(_scheduleSave);
    setState(() {
      _note = note;
      _controller = controller;
    });
    if (doc.isEmpty() && note.title.isEmpty && !_readOnly) {
      _focus.requestFocus();
    }
  }

  static Document _parse(String json) {
    try {
      final ops = jsonDecode(json) as List;
      return ops.isEmpty ? Document() : Document.fromJson(ops);
    } catch (_) {
      return Document();
    }
  }

  void _scheduleSave() {
    if (_readOnly) return;
    _dirty = true;
    _timer?.cancel();
    _timer = Timer(_debounce, _save);
  }

  Future<void> _save() async {
    final c = _controller;
    if (c == null || !_dirty) return;
    _dirty = false;
    await _repo.saveContent(
      widget.noteId,
      contentDelta: jsonEncode(c.document.toDelta().toJson()),
      plainText: c.document.toPlainText(),
      title: _title.text,
    );
  }

  bool get _isEmpty =>
      _title.text.trim().isEmpty &&
      (_controller?.document.toPlainText().trim().isEmpty ?? true);

  @override
  void dispose() {
    _timer?.cancel();
    // Note vide à la sortie : supprimée (comme Mi Notes), sinon sauvegardée.
    if (_note != null && !_readOnly && _isEmpty) {
      _repo.deleteForever([widget.noteId]);
    } else {
      _save();
    }
    _changes?.cancel();
    _controller?.dispose();
    _title.dispose();
    _focus.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _insertImage(ImageSource source) async {
    final c = _controller!;
    final picked = await ImagePicker().pickImage(source: source);
    if (picked == null) return;
    final path = await ref.read(imageStoreProvider).import(picked.path);
    await _repo.addAttachment(widget.noteId, path);
    final index = c.selection.baseOffset < 0 ? 0 : c.selection.baseOffset;
    c.replaceText(index, c.selection.extentOffset - index,
        BlockEmbed.image(path), TextSelection.collapsed(offset: index + 1));
  }

  Future<void> _pickImage() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (c) => SafeArea(
        child: Wrap(children: [
          ListTile(
            leading: const Icon(Icons.photo_library_outlined),
            title: const Text('Galerie'),
            onTap: () => Navigator.pop(c, ImageSource.gallery),
          ),
          ListTile(
            leading: const Icon(Icons.photo_camera_outlined),
            title: const Text('Appareil photo'),
            onTap: () => Navigator.pop(c, ImageSource.camera),
          ),
        ]),
      ),
    );
    if (source != null) await _insertImage(source);
  }

  Future<void> _menu(String action) async {
    final note = (await _repo.get(widget.noteId))!;
    switch (action) {
      case 'pin':
        await _repo.setPinned([note.id], !note.isPinned);
      case 'move':
        if (!mounted) return;
        final target = await pickFolder(context, ref);
        if (target != null) await _repo.move([note.id], target.folderId);
      case 'delete':
        await _save();
        await _repo.trash([note.id]);
        if (mounted) Navigator.of(context).pop();
        return;
      case 'restore':
        await _repo.restore([note.id]);
        if (mounted) Navigator.of(context).pop();
        return;
    }
    final updated = await _repo.get(widget.noteId);
    if (mounted) setState(() => _note = updated);
  }

  @override
  Widget build(BuildContext context) {
    final c = _controller;
    final note = _note;
    if (c == null || note == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final text = Theme.of(context).textTheme;
    final store = ref.read(imageStoreProvider);

    return Scaffold(
      appBar: AppBar(
        actions: [
          if (!_readOnly) ...[
            IconButton(
              tooltip: 'Annuler',
              icon: const Icon(Icons.undo),
              onPressed: c.hasUndo ? c.undo : null,
            ),
            IconButton(
              tooltip: 'Rétablir',
              icon: const Icon(Icons.redo),
              onPressed: c.hasRedo ? c.redo : null,
            ),
          ],
          PopupMenuButton<String>(
            onSelected: _menu,
            itemBuilder: (_) => _readOnly
                ? const [PopupMenuItem(value: 'restore', child: Text('Restaurer'))]
                : [
                    PopupMenuItem(
                        value: 'pin',
                        child: Text(note.isPinned ? 'Désépingler' : 'Épingler')),
                    const PopupMenuItem(value: 'move', child: Text('Déplacer')),
                    const PopupMenuItem(value: 'delete', child: Text('Supprimer')),
                  ],
          ),
        ],
      ),
      body: SafeArea(
        child: Column(children: [
          Expanded(
            child: ListView(
              controller: _scroll,
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
              children: [
                TextField(
                  controller: _title,
                  readOnly: _readOnly,
                  style: text.headlineSmall,
                  textInputAction: TextInputAction.next,
                  onSubmitted: (_) => _focus.requestFocus(),
                  decoration: const InputDecoration(
                      hintText: 'Titre', border: InputBorder.none),
                ),
                Text(formatDateTime(context, note.updatedAt),
                    style: text.labelSmall
                        ?.copyWith(color: Theme.of(context).colorScheme.outline)),
                const SizedBox(height: 12),
                QuillEditor(
                  controller: c,
                  focusNode: _focus,
                  scrollController: _scroll,
                  config: QuillEditorConfig(
                    scrollable: false,
                    placeholder: 'Commencez à écrire…',
                    embedBuilders: [LocalImageEmbedBuilder(store)],
                  ),
                ),
              ],
            ),
          ),
          if (!_readOnly) _toolbar(c),
        ]),
      ),
    );
  }

  Widget _toolbar(QuillController c) => Material(
        color: Theme.of(context).colorScheme.surfaceContainer,
        child: QuillSimpleToolbar(
          controller: c,
          config: QuillSimpleToolbarConfig(
            multiRowsDisplay: false,
            showDividers: false,
            showFontFamily: false,
            showFontSize: false,
            showSmallButton: false,
            showInlineCode: false,
            showColorButton: false,
            showBackgroundColorButton: true, // surlignage
            showClearFormat: true,
            showAlignmentButtons: false,
            showHeaderStyle: true,
            showListNumbers: true,
            showListBullets: true,
            showListCheck: true,
            showCodeBlock: false,
            showQuote: false,
            showIndent: false,
            showLink: false,
            showUndo: false, // dans l'AppBar
            showRedo: false,
            showDirection: false,
            showSearchButton: false,
            showSubscript: false,
            showSuperscript: false,
            customButtons: [
              QuillToolbarCustomButtonOptions(
                icon: const Icon(Icons.image_outlined),
                tooltip: 'Image',
                onPressed: _pickImage,
              ),
            ],
          ),
        ),
      );
}
