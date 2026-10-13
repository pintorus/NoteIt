import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:noteit/app.dart';
import 'package:noteit/core/image_store.dart';
import 'package:noteit/core/providers.dart';
import 'package:noteit/data/database.dart';
import 'package:noteit/features/editor/editor_page.dart';
import 'package:noteit/features/search/search_page.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  // Démonte l'app pour libérer les timers des streams Drift avant la fin du test.
  Future<void> finish(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
    await tester.runAsync(db.close);
  }

  // pumpAndSettle ne se stabilise pas avec le curseur qui clignote.
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> back(WidgetTester tester) async {
    await tester.tap(find.byType(BackButton));
    await settle(tester);
  }

  Future<void> pumpApp(WidgetTester tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(db),
        imageStoreProvider.overrideWithValue(ImageStore('/tmp/noteit_test')),
      ],
      child: const NoteItApp(),
    ));
    await settle(tester);
  }

  testWidgets('créer une note puis la retrouver dans la grille', (tester) async {
    await pumpApp(tester);
    expect(find.text('Aucune note'), findsOneWidget);

    await tester.tap(find.byTooltip('Nouvelle note'));
    await settle(tester);
    expect(find.byType(EditorPage), findsOneWidget);
    await tester.enterText(find.widgetWithText(TextField, 'Titre'), 'Courses');
    await tester.pump(const Duration(seconds: 1)); // sauvegarde auto

    await back(tester);
    expect(find.text('Courses'), findsOneWidget);
    final notes = await tester.runAsync(() => db.select(db.notes).get());
    expect(notes!.single.title, 'Courses');
    await finish(tester);
  });

  testWidgets('une note laissée vide est supprimée', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.byTooltip('Nouvelle note'));
    await settle(tester);
    expect(find.byType(EditorPage), findsOneWidget);
    await back(tester);
    final notes = await tester.runAsync(() => db.select(db.notes).get());
    expect(notes, isEmpty);
    await finish(tester);
  });

  testWidgets('ajouter une tâche puis la cocher', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.text('Tâches'));
    await settle(tester);
    await tester.tap(find.byTooltip('Nouvelle tâche'));
    await settle(tester);
    await tester.enterText(find.byType(TextField), 'Appeler Paul');
    await tester.tap(find.text('Enregistrer'));
    await settle(tester);
    expect(find.text('Appeler Paul'), findsOneWidget);

    await tester.tap(find.byType(Checkbox));
    await settle(tester);
    expect(find.text('Terminées (1)'), findsOneWidget);
    await finish(tester);
  });

  test('fold retire les accents sans changer la longueur', () {
    expect(fold('Réunion Été'), 'reunion ete');
    expect(fold('Œuf').length, 3);
  });
}
