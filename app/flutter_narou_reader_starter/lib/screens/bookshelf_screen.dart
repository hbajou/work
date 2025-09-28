import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../models/book.dart';
import '../services/bookshelf_service.dart';

class BookshelfScreen extends StatefulWidget {
  const BookshelfScreen({super.key});

  @override
  State<BookshelfScreen> createState() => _BookshelfScreenState();
}

class _BookshelfScreenState extends State<BookshelfScreen> {
  final _svc = BookshelfService();
  List<Book> _books = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final list = await _svc.load();
    setState(() => _books = list);
  }

  void _addDummy() async {
    await _svc.add(const Book(ncode: "N0000AA", title: "ダミータイトル", author: "作者名"));
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('本棚'),
        actions: [
          IconButton(
            onPressed: () => context.push("/search").then((_) => _load()),
            icon: const Icon(Icons.search),
            tooltip: "検索して追加",
          ),
          IconButton(
            onPressed: _addDummy,
            icon: const Icon(Icons.add),
            tooltip: "ダミー追加",
          ),
          IconButton(
            onPressed: () => context.push("/settings"),
            icon: const Icon(Icons.settings),
          ),
        ],
      ),
      body: _books.isEmpty
          ? const Center(child: Text("本棚は空です。右上の検索または＋で追加してください。"))
          : ListView.builder(
              itemCount: _books.length,
              itemBuilder: (context, i) {
                final b = _books[i];
                return Dismissible(
                  key: ValueKey(b.ncode),
                  background: Container(color: Colors.redAccent),
                  onDismissed: (_) async {
                    await _svc.remove(b.ncode);
                    _load();
                  },
                  child: ListTile(
                    title: Text(b.title),
                    subtitle: Text("${b.author} ・ ${b.ncode}"),
                    onTap: () => context.push("/reader?title=${Uri.encodeComponent(b.title)}", extra: _dummyContent),
                  ),
                );
              },
            ),
    );
  }
}

const _dummyContent = "　ここに本文が入ります。スクロールで読めます。";
