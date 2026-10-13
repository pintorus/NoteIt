import 'dart:io';

import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

/// Images des notes : compressées et stockées dans le dossier documents.
/// Les notes ne référencent que le chemin relatif (`images/<uuid>.jpg`).
class ImageStore {
  ImageStore(this.root);
  final String root;

  static Future<ImageStore> open() async =>
      ImageStore((await getApplicationDocumentsDirectory()).path);

  File resolve(String relativePath) => File(p.join(root, relativePath));

  Future<String> import(String sourcePath) async {
    final relative = p.join('images', '${const Uuid().v4()}.jpg');
    final target = resolve(relative);
    await target.parent.create(recursive: true);
    final result = await FlutterImageCompress.compressAndGetFile(
      sourcePath,
      target.path,
      minWidth: 1600,
      minHeight: 1600,
      quality: 85,
    );
    if (result == null) await File(sourcePath).copy(target.path);
    return relative;
  }

  Future<void> deleteAll(Iterable<String> relativePaths) async {
    for (final path in relativePaths) {
      final file = resolve(path);
      if (await file.exists()) await file.delete();
    }
  }
}
