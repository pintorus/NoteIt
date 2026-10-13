import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../features/editor/editor_page.dart';
import '../features/home/home_page.dart';
import '../features/search/search_page.dart';

final router = GoRouter(
  routes: [
    GoRoute(path: '/', builder: (context, state) => const HomePage()),
    GoRoute(path: '/search', builder: (context, state) => const SearchPage()),
    GoRoute(
      path: '/note/:id',
      builder: (_, state) =>
          EditorPage(noteId: int.parse(state.pathParameters['id']!)),
    ),
  ],
  errorBuilder: (context, state) => const Scaffold(body: Center(child: Text('Page introuvable'))),
);
