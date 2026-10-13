import 'package:flutter/material.dart';

import '../notes/notes_view.dart';
import '../tasks/tasks_view.dart';

/// Deux onglets en haut, comme Mi Notes : Notes | Tâches.
class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          toolbarHeight: 0,
          bottom: const TabBar(
            tabs: [Tab(text: 'Notes'), Tab(text: 'Tâches')],
          ),
        ),
        body: const TabBarView(children: [NotesView(), TasksView()]),
      ),
    );
  }
}
