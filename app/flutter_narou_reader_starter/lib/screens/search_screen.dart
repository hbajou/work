import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../models/book.dart';
import '../services/bookshelf_service.dart';
import '../services/narou_api_service.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});
  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _query = TextEditingController();
  final _svc = BookshelfService();
  final _api = NarouApiService();

  bool _loading = false;
  List<NarouWork> _results = [];

  Future<void> _runSearch() async {
    final q = _query.text.trim();
    if (q.isEmpty) return;
    setState(() { _loading = true; _results = []; });
    try {
      final r = await _api.search(keyword: q, limit: 30);
      setState(() => _results = r);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('検索に失敗しました: $e')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _addToShelf(NarouWork w) async {
    await _svc.add(Book(ncode: w.ncode, title: w.title, author: w.author));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("本棚に追加しました")),
    );
    context.pop(); // 戻ると本棚が更新される
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('検索')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _query,
              decoration: InputDecoration(
                labelText: "キーワード",
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.search),
                  onPressed: _runSearch,
                ),
              ),
              onSubmitted: (_) => _runSearch(),
            ),
            const SizedBox(height: 12),
            if (_loading) const LinearProgressIndicator(),
            Expanded(
              child: _results.isEmpty
                  ? const Center(child: Text("検索結果がここに表示されます"))
                  : ListView.builder(
                      itemCount: _results.length,
                      itemBuilder: (context, i) {
                        final w = _results[i];
                        return ListTile(
                          title: Text(w.title),
                          subtitle: Text("${w.author} ・ ${w.ncode}"),
                          trailing: IconButton(
                            icon: const Icon(Icons.add),
                            onPressed: () => _addToShelf(w),
                            tooltip: "本棚に追加",
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
