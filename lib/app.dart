import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_quill/flutter_quill.dart';

import 'core/router.dart';

class NoteItApp extends StatelessWidget {
  const NoteItApp({super.key});

  @override
  Widget build(BuildContext context) {
    ThemeData theme(Brightness b) => ThemeData(
          colorSchemeSeed: Colors.amber,
          brightness: b,
          useMaterial3: true,
        );
    return MaterialApp.router(
      title: 'NoteIt',
      theme: theme(Brightness.light),
      darkTheme: theme(Brightness.dark),
      routerConfig: router,
      locale: const Locale('fr'),
      supportedLocales: const [Locale('fr'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        FlutterQuillLocalizations.delegate,
      ],
    );
  }
}
