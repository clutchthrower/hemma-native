import 'package:flutter/foundation.dart';

/// Whether the current view is in homescreen-style edit mode (entered by
/// long-pressing a card, badge, or the room title). While editing, cards
/// and badges show remove/edit affordances instead of performing their
/// normal actions.
class EditModeController extends ChangeNotifier {
  bool editing = false;

  void enter() {
    if (editing) return;
    editing = true;
    notifyListeners();
  }

  void exit() {
    if (!editing) return;
    editing = false;
    notifyListeners();
  }
}
