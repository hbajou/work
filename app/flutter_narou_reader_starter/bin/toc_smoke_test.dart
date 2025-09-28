// ==============================================
// File: bin/toc_smoke_test.dart
// ==============================================

import 'package:logging/logging.dart';
import 'package:narou_reader_starter/providers/narou_toc_provider.dart' as narou;

Future<void> main(List<String> args) async {
  // 使い方:
  // dart run bin/toc_smoke_test.dart n9669bk [maxPages]
  if (args.isEmpty) {
    print('usage: dart run bin/toc_smoke_test.dart <ncode> [maxPages]');
    return;
  }
  final ncode = args[0];
  final maxPages = args.length >= 2 ? int.tryParse(args[1]) : null;

  // 観測ログ（FINE）も見えるようにデフォルトFINE
  Logger.root.level = Level.INFO;
  Logger.root.onRecord.listen((r) {
    print('[${r.level.name}] ${r.time.toIso8601String()} ${r.loggerName} ${r.message}');
  });

  final provider = narou.NarouTocProvider();
  final episodes = await provider.fetchTocAllPages(ncode, maxPages: maxPages);

  print('--- RESULT ---');
  print('ncode=$ncode total=${episodes.length}');
  for (final e in episodes.take(10)) {
    print(e);
  }
  if (episodes.length > 10) {
    print('... (${episodes.length - 10} more)');
  }
}
