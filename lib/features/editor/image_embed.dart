import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';

import '../../core/image_store.dart';

/// Affiche les images insérées (`BlockEmbed.image(<chemin relatif>)`).
class LocalImageEmbedBuilder extends EmbedBuilder {
  LocalImageEmbedBuilder(this.store);
  final ImageStore store;

  @override
  String get key => BlockEmbed.imageType;

  @override
  Widget build(BuildContext context, EmbedContext embedContext) {
    final file = store.resolve(embedContext.node.value.data as String);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: GestureDetector(
        onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
          builder: (_) => _FullScreenImage(file),
        )),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.file(
            file,
            fit: BoxFit.contain,
            errorBuilder: (_, _, _) => Container(
              height: 120,
              alignment: Alignment.center,
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              child: const Icon(Icons.broken_image_outlined),
            ),
          ),
        ),
      ),
    );
  }
}

class _FullScreenImage extends StatelessWidget {
  const _FullScreenImage(this.file);
  final File file;

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
            backgroundColor: Colors.black, foregroundColor: Colors.white),
        body: InteractiveViewer(
          maxScale: 5,
          child: Center(child: Image.file(file)),
        ),
      );
}
