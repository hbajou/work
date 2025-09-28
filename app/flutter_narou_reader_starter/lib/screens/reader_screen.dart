import 'package:flutter/material.dart';
import '../services/progress_service.dart';

class ReaderScreen extends StatefulWidget {
  final String title;
  final String content;
  const ReaderScreen({super.key, required this.title, required this.content});

  @override
  State<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends State<ReaderScreen> {
  final _scroll = ScrollController();
  final _progress = ProgressService();
  double _fontSize = 18;
  bool _showControls = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // ncodeは未実装なのでタイトルをキー代替
      final offset = await _progress.loadOffset(widget.title);
      if (_scroll.hasClients) _scroll.jumpTo(offset.toDouble());
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _saveProgress() async {
    await _progress.saveOffset(widget.title, _scroll.offset.toInt());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          IconButton(
            icon: const Icon(Icons.bookmark_added_outlined),
            onPressed: _saveProgress,
            tooltip: "ここまでを記録",
          )
        ],
      ),
      body: GestureDetector(
        onTap: () => setState(() => _showControls = !_showControls),
        child: Stack(
          children: [
            ListView(
              controller: _scroll,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
              children: [
                Text(
                  widget.content,
                  style: TextStyle(fontSize: _fontSize, height: 1.6),
                  textAlign: TextAlign.start,
                ),
                const SizedBox(height: 200),
              ],
            ),
            if (_showControls)
              Positioned(
                left: 0, right: 0, bottom: 0,
                child: Container(
                  color: Theme.of(context).colorScheme.surface.withOpacity(0.95),
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      const Icon(Icons.text_fields),
                      Expanded(
                        child: Slider(
                          min: 14, max: 28,
                          value: _fontSize,
                          onChanged: (v) => setState(() => _fontSize = v),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.save_outlined),
                        onPressed: _saveProgress,
                        tooltip: "進捗保存",
                      )
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
