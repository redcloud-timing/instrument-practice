import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../models/library_item.dart';
import '../services/database_service.dart';
import '../services/document_library_service.dart';

class LibraryController extends ChangeNotifier {
  LibraryController(this._databaseService, this._documentService);

  final DatabaseService _databaseService;
  final DocumentLibraryService _documentService;
  DocumentLibraryService get documentService => _documentService;

  static const _documentsKey = 'library_documents_v1';
  static const _maxItems = 60;

  bool isLoading = true;
  bool isBusy = false;
  List<LibraryItem> items = [];

  List<LibraryItem> get favoriteItems {
    final values = items.where((item) => item.isFavorite).toList();
    values.sort(_sortByOpenedAtDesc);
    return values;
  }

  List<LibraryItem> get recentItems {
    final values = List<LibraryItem>.of(items);
    values.sort(_sortByOpenedAtDesc);
    return values;
  }

  LibraryItem? itemByUri(String uri) {
    for (final item in items) {
      if (item.uri == uri) return item;
    }
    return null;
  }

  Future<void> init() async {
    isLoading = true;
    notifyListeners();

    final raw = await _databaseService.getSetting(_documentsKey);
    if (raw != null) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          items = [
            for (final value in decoded)
              if (value is Map)
                LibraryItem.fromMap(Map<String, dynamic>.from(value)),
          ].where((item) => item.uri.isNotEmpty).toList();
        }
      } catch (e) {
        debugPrint('LibraryController.init decode error: $e');
        items = [];
      }
    }

    isLoading = false;
    notifyListeners();
  }

  Future<LibraryItem?> addDocumentFromDevice() async {
    if (isBusy) return null;

    isBusy = true;
    notifyListeners();

    try {
      final picked = await _documentService.pickDocument();
      if (picked == null) return null;

      final existing = itemByUri(picked.uri);
      final now = DateTime.now().toIso8601String();
      final next = picked.copyWith(
        addedAtIso: existing?.addedAtIso ?? now,
        openedAtIso: now,
        isFavorite: existing?.isFavorite ?? false,
        note: existing?.note ?? '',
      );

      items = [
        next,
        for (final item in items)
          if (item.uri != next.uri) item,
      ];
      _trimItems();
      notifyListeners();
      await _save();

      return next;
    } finally {
      isBusy = false;
      notifyListeners();
    }
  }

  Future<void> openItem(LibraryItem item) async {
    await markOpened(item);
    await _documentService.openDocument(item);
  }

  Future<void> markOpened(LibraryItem item) async {
    if (isBusy) return;

    isBusy = true;
    notifyListeners();

    try {
      final now = DateTime.now().toIso8601String();
      items = [
        for (final current in items)
          if (current.uri == item.uri)
            current.copyWith(openedAtIso: now)
          else
            current,
      ];
      notifyListeners();
      await _save();
    } finally {
      isBusy = false;
      notifyListeners();
    }
  }

  Future<void> saveNote(LibraryItem item, String note) async {
    items = [
      for (final current in items)
        if (current.uri == item.uri)
          current.copyWith(note: note.trim())
        else
          current,
    ];

    notifyListeners();
    await _save();
  }

  Future<void> toggleFavorite(LibraryItem item) async {
    items = [
      for (final current in items)
        if (current.uri == item.uri)
          current.copyWith(isFavorite: !current.isFavorite)
        else
          current,
    ];

    notifyListeners();
    await _save();
  }

  Future<void> deleteItem(LibraryItem item) async {
    items = [
      for (final current in items)
        if (current.uri != item.uri) current,
    ];

    notifyListeners();
    await _save();
  }

  void _trimItems() {
    items.sort(_sortByOpenedAtDesc);
    if (items.length > _maxItems) {
      items = items.take(_maxItems).toList();
    }
  }

  Future<void> _save() async {
    await _databaseService.setSetting(
      _documentsKey,
      jsonEncode(items.map((item) => item.toMap()).toList()),
    );
  }

  static int _sortByOpenedAtDesc(LibraryItem left, LibraryItem right) {
    final leftDate = DateTime.tryParse(left.openedAtIso) ?? DateTime(1970);
    final rightDate = DateTime.tryParse(right.openedAtIso) ?? DateTime(1970);
    return rightDate.compareTo(leftDate);
  }
}
