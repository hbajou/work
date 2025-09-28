// bin/read_smoke_test.dart
import 'dart:io';
import 'package:logging/logging.dart';
import 'package:html/parser.dart' as html; // 表示用にプレーンテキストへ落とす
import 'package:html/dom.dart' as dom;
import 'package:narou_reader_starter/providers/narou_episode_provider.dart' as narou;

void main(List<String> args) async {
  if (args.length < 2) {
    stderr.writeln('Usage: dart run bin/read_smoke_test.dart <ncode> <episodeNo>');
    exit(64);
  }
  final ncode = args[0].toLowerCase();
  final epNo = int.tryParse(args[1]) ?? 1;

  // ログ設定（既定をINFO）
  Logger.root.level = Level.INFO;
  Logger.root.onRecord.listen((r) {
    // 既存のログ整形に寄せる
    print('[${r.level.name}] ${r.time.toIso8601String()} ${r.loggerName} ${r.message}');
  });

  final provider = narou.NarouEpisodeProvider();

  try {
    final ep = await provider.fetchEpisode(ncode, epNo);
    print('========== EPISODE ==========');
    print('ncode: ${ep.ncode}  no: ${ep.episodeNo}');
    print('title: ${ep.subtitle}');
    print('url  : ${ep.url}');
    print('posted : ${ep.postedAt}');
    print('updated: ${ep.updatedAt}');

    // 表示だけプレーン化（<br>を改行扱い、pを段落扱い）
    final bodyDoc = html.parse('<div>${ep.bodyHtml}</div>');
    // 1) <br>を改行に
    for (final br in bodyDoc.querySelectorAll('br')) {
      br.replaceWith(dom.Element.tag('br')..text = '\n');
    }

    // 2) <p> … </p> の後に改行
    for (final p in bodyDoc.querySelectorAll('p')) {
      p.append(dom.Text('\n\n'));
    }

    final bodyText = bodyDoc.body?.text ?? '';

    print('\n---- BODY (first 800 chars) ----\n');
    final t = bodyText.replaceAll('\r', '');
    print(t.length <= 800 ? t : t.substring(0, 800) + '\n...[truncated]');

    print('\n---- NAV ----');
    print('prev: ${ep.prevEpisodeNo ?? '-'}  next: ${ep.nextEpisodeNo ?? '-'}');
  } catch (e, st) {
    stderr.writeln('ERROR: $e');
    stderr.writeln(st);
    exit(1);
  } finally {
    provider.close();
  }
}
