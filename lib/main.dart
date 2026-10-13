import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/image_store.dart';
import 'core/providers.dart';
import 'core/reminders.dart';
import 'data/database.dart';
import 'data/note_repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final db = AppDatabase();
  final images = await ImageStore.open();
  final reminders = await Reminders.init();

  // Purge de la corbeille (> 30 jours) et reprogrammation des rappels.
  images.deleteAll(await NoteRepository(db).purgeExpired());
  reminders.resyncAll(await db.select(db.tasks).get());

  runApp(ProviderScope(
    overrides: [
      databaseProvider.overrideWithValue(db),
      imageStoreProvider.overrideWithValue(images),
      remindersProvider.overrideWithValue(reminders),
    ],
    child: const NoteItApp(),
  ));
}
