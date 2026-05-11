import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../data/local/db_helper.dart';
import '../data/remote/supabase_service.dart';
import '../data/models/category_model.dart';

class CategoryProvider extends ChangeNotifier {
  final DBHelper _db = DBHelper.instance;
  final SupabaseService _supabase = SupabaseService.instance;
  final _uuid = const Uuid();

  List<CategoryModel> _categories = [];
  bool _isLoading = false;
  String _error = '';

  List<CategoryModel> get categories => _categories;
  bool get isLoading => _isLoading;
  String get error => _error;

  /// Get a category by name (case-insensitive)
  CategoryModel? getCategoryByName(String name) {
    final lower = name.toLowerCase();
    final matches = _categories.where((c) => c.name.toLowerCase() == lower);
    return matches.isNotEmpty ? matches.first : null;
  }

  /// Check if a category name already exists (case-insensitive)
  bool categoryExists(String name, {String? excludeId}) {
    final lower = name.toLowerCase();
    return _categories.any((c) =>
        c.name.toLowerCase() == lower && (excludeId == null || c.id != excludeId));
  }

  Future<void> loadCategories() async {
    _isLoading = true;
    _error = '';
    notifyListeners();

    try {
      final maps = await _db.getCategories();
      _categories = maps.map((m) => CategoryModel.fromMap(m)).toList();
      debugPrint('📁 CategoryProvider: loaded ${_categories.length} categories');
    } catch (e) {
      _error = 'Failed to load categories: $e';
      debugPrint('❌ $_error');
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<bool> addCategory({
    required String name,
    bool requiresSize = false,
    bool requiresColor = false,
  }) async {
    // Validate
    if (name.trim().isEmpty) {
      _error = 'Category name cannot be empty';
      notifyListeners();
      return false;
    }

    if (categoryExists(name.trim())) {
      _error = 'Category "${name.trim()}" already exists';
      notifyListeners();
      return false;
    }

    try {
      final category = CategoryModel(
        id: _uuid.v4(),
        name: name.trim(),
        requiresSize: requiresSize,
        requiresColor: requiresColor,
      );

      debugPrint('➕ CategoryProvider: adding category "${category.name}"');

      // Save to local DB
      await _db.insertCategory(category.toMap());
      debugPrint('   ✓ Saved to local DB');

      // Add to in-memory list
      _categories.add(category);
      _categories.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      notifyListeners();

      // Sync to Supabase
      if (kIsWeb) {
        final synced = await _supabase.syncRecord(
            'categories', category.id, 'insert', category.toMap());
        debugPrint(synced
            ? '   ✓ Synced to Supabase'
            : '   ⚠️ Supabase sync queued');
      } else {
        _supabase.syncRecord('categories', category.id, 'insert', category.toMap());
      }

      _error = '';
      return true;
    } catch (e) {
      _error = 'Failed to add category: $e';
      debugPrint('❌ $_error');
      notifyListeners();
      return false;
    }
  }

  Future<bool> updateCategory(CategoryModel category, {
    String? name,
    bool? requiresSize,
    bool? requiresColor,
  }) async {
    // Validate
    final newName = name?.trim() ?? category.name;
    if (newName.isEmpty) {
      _error = 'Category name cannot be empty';
      notifyListeners();
      return false;
    }

    if (categoryExists(newName, excludeId: category.id)) {
      _error = 'Category "$newName" already exists';
      notifyListeners();
      return false;
    }

    try {
      final updated = category.copyWith(
        name: name?.trim(),
        requiresSize: requiresSize,
        requiresColor: requiresColor,
        updatedAt: DateTime.now(),
      );

      // Update local DB
      await _db.updateCategory(updated.toMap(), updated.id);

      // Update in-memory list
      final index = _categories.indexWhere((c) => c.id == updated.id);
      if (index != -1) {
        _categories[index] = updated;
        _categories.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      }
      notifyListeners();

      // Sync to Supabase
      if (kIsWeb) {
        await _supabase.syncRecord('categories', updated.id, 'update', updated.toMap());
      } else {
        _supabase.syncRecord('categories', updated.id, 'update', updated.toMap());
      }

      _error = '';
      return true;
    } catch (e) {
      _error = 'Failed to update category: $e';
      debugPrint('❌ $_error');
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteCategory(String id) async {
    try {
      final category = _categories.firstWhere((c) => c.id == id);

      // Soft delete in local DB
      await _db.deleteCategory(id);

      // Remove from in-memory list
      _categories.removeWhere((c) => c.id == id);
      notifyListeners();

      // Sync to Supabase
      if (kIsWeb) {
        await _supabase.syncRecord('categories', id, 'delete', category.toMap());
      } else {
        _supabase.syncRecord('categories', id, 'delete', category.toMap());
      }

      _error = '';
      return true;
    } catch (e) {
      _error = 'Failed to delete category: $e';
      debugPrint('❌ $_error');
      notifyListeners();
      return false;
    }
  }

  void clearError() {
    _error = '';
    notifyListeners();
  }
}
