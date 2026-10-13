# NoteIt — Design (clone de Mi Notes)

## Plateformes
Android + iOS (v1).

## Stockage
- Éditeur : `flutter_quill`, contenu stocké en **Delta JSON**.
- Base : **Drift (SQLite)**, colonne `plainText` extraite du Delta pour l'aperçu et la recherche **FTS5**.

## Modèle de données
```
folders(id, name, color?, sortOrder, createdAt)
notes(id, folderId?, title, contentDelta, plainText, isPinned, createdAt, updatedAt, deletedAt?)
attachments(id, noteId, path)
```
- Dossiers **à un seul niveau** ; note sans dossier = « Non classé ».
- Vues système : **Toutes les notes**, **Corbeille**.
- Suppression d'une note = soft delete (`deletedAt`), purge auto après **30 jours** (fichiers images supprimés avec).
- Suppression d'un dossier : ses notes reviennent dans **« Non classé »**.

## Éditeur (v1)
Gras, italique, souligné, barré · H1/H2 · listes à puces/numérotées · **checklists** · surlignage · undo/redo · barre d'outils au-dessus du clavier · **images**.

Images :
- Source : galerie / appareil photo (`image_picker`).
- Compression : max 1600 px, JPEG qualité 85.
- Copie dans `appDocs/images/<uuid>.jpg` ; le Delta stocke le **chemin relatif**.
- Tap = plein écran avec zoom.

Sauvegarde automatique : 500 ms après la dernière frappe + à la sortie de l'écran.

## Liste des notes
- Grille 2 colonnes (titre, aperçu, date), bascule en liste.
- Épinglées en haut ; tri par date de modification (option : création, titre).
- Recherche globale FTS5 avec surlignage.
- Appui long → multi-sélection (déplacer, épingler, supprimer).
- Titre auto = première ligne si vide.
- Pas de couleurs de note ; thème clair/sombre.

## Architecture
- État : **Riverpod** (`StreamProvider` sur les `watch()` Drift).
- Navigation : **go_router** (dossiers → liste → éditeur).
- Arborescence :
  ```
  lib/core/       thème, utilitaires
  lib/data/       base Drift, dépôts
  lib/features/   folders, notes, editor, search, trash
  ```
- Tests : dépôts sur Drift en mémoire + tests widgets.

## Hors v1
Mémos vocaux, verrouillage (code/biométrie), synchronisation cloud, couleurs de note, dossiers imbriqués, tags.
