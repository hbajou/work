import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/book.dart';

class BookshelfService {
  static const _key = 'bookshelf';

  Future<List<Book>> load() async {
    final sp = await SharedPreferences.getInstance();
    final raw = sp.getStringList(_key) ?? <String>[];
    return raw.map((e) => Book.fromJson(jsonDecode(e) as Map<String, dynamic>)).toList();
  }

  Future<void> save(List<Book> books) async {
    final sp = await SharedPreferences.getInstance();
    final raw = books.map((b) => jsonEncode(b.toJson())).toList();
    await sp.setStringList(_key, raw);
  }

  Future<void> add(Book b) async {
    final list = await load();
    if (!list.any((x) => x.ncode == b.ncode)) {
      list.add(b);
      await save(list);
    }
  }

  Future<void> remove(String ncode) async {
    final list = await load();
    list.removeWhere((b) => b.ncode == ncode);
    await save(list);
  }
}
