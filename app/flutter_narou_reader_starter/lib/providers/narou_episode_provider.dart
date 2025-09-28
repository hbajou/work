// lib/providers/narou_episode_provider.dart
import 'dart:async';
import 'package:html/parser.dart' as html;
import 'package:html/dom.dart' as dom;
import 'package:http/http.dart' as http;
import 'package:logging/logging.dart';
import '../models/episode.dart';

class NarouEpisodeProvider {
  final Logger _log = Logger('NarouEpisodeProvider');
  final http.Client _client;
  final Duration requestDelay;
  final String userAgent;

  NarouEpisodeProvider({
    http.Client? client,
    this.requestDelay = const Duration(milliseconds: 500),
    this.userAgent =
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',
  }) : _client = client ?? http.Client();

  /// ncode: 'n9669bk' のような小文字
  /// episodeNo: 1 始まりの通し番号
  Future<Episode> fetchEpisode(String ncode, int episodeNo) async {
    final url = Uri.https('ncode.syosetu.com', '/$ncode/$episodeNo/');
    _log.info('[HTTP] GET $url');
    final res = await _client.get(url, headers: {'User-Agent': userAgent});
    _log.info('[HTTP] status=${res.statusCode} final=$url');

    if (res.statusCode != 200) {
      throw Exception('Failed to load episode: HTTP ${res.statusCode}');
    }

    final doc = html.parse(res.body);

    // === デバッグ補助 ===
    final head = doc.querySelector('head')?.text ?? '';
    final headLen = head.length < 120 ? head.length : 120;
    _log.info('[HTML HEAD snippet] ${head.substring(0, headLen)}');
    final hasHonbun = res.body.contains('novel_honbun');
    final hasSubtitle = res.body.contains('novel_subtitle');
    _log.info('[HTML tokens] novel_honbun=$hasHonbun novel_subtitle=$hasSubtitle');

    // 小道具
    T? _first<T>(List<T?> items) =>
        items.firstWhere((e) => e != null, orElse: () => null);
    String _text(dom.Element? el) => el?.text.trim() ?? '';
    String _html(dom.Element? el) => el?.innerHtml.trim() ?? '';

    // サブタイトル
    dom.Element? subtitleEl = _first<dom.Element>([
      doc.querySelector('#novel_subtitle'),
      doc.querySelector('p.novel_subtitle'),
      doc.querySelector('.novel_subtitle'),
      doc.querySelector('h1#novel_subtitle'),
    ]);

    // 本文
    dom.Element? honbunEl = _first<dom.Element>([
      doc.querySelector('#novel_honbun'),
      doc.querySelector('div#novel_honbun'),
      doc.querySelector('.novel_honbun'),
      doc.querySelector('#honbun'),
      doc.querySelector('.honbun'),
      doc.querySelector('#novel_color'),
      doc.querySelector('#novel_p'),
    ]);

    // ===== フォールバック: h1 からナビまで =====
    String? fallbackBodyHtml;
    if (honbunEl == null) {
      final h = _first<dom.Element>([
        doc.querySelector('main h1'),
        doc.querySelector('#contents h1'),
        doc.querySelector('h1'),
        doc.querySelector('h2'),
      ]);
      subtitleEl ??= h;

      if (h != null && h.parent != null) {
        final siblings = h.parent!.nodes;
        final startIndex = siblings.indexOf(h);
        final buffer = StringBuffer();

        bool _isNav(dom.Element e) {
          final t = (e.text ?? '').trim();
          final cls = (e.className ?? '').toString();
          final id = (e.id ?? '').toString();
          return t.contains('目次') ||
              t.contains('次へ') ||
              t.contains('前へ') ||
              cls.contains('novel_bn') ||
              cls.contains('pager') ||
              id.contains('novel_bn') ||
              id.contains('pager');
        }

        for (var i = startIndex + 1; i < siblings.length; i++) {
          final node = siblings[i];
          if (node is dom.Element) {
            if (_isNav(node)) break;

            final tag = node.localName?.toLowerCase() ?? '';
            if (tag == 'script' ||
                tag == 'style' ||
                tag == 'noscript' ||
                tag == 'nav') {
              continue;
            }

            buffer.write(node.innerHtml);
            buffer.write('\n');
          }
        }

        final tmp = buffer.toString().trim();
        if (tmp.isNotEmpty) fallbackBodyHtml = tmp;
      }
    }

    final subtitle = _text(subtitleEl);
    final bodyHtml = _html(honbunEl).isNotEmpty
        ? _html(honbunEl)
        : (fallbackBodyHtml ?? '');

    // 前後リンク
    int? prevNo;
    int? nextNo;
    final nav = doc.querySelector('.novel_bn') ??
        doc.querySelector('.pager') ??
        doc.querySelector('nav');
    if (nav != null) {
      for (final a in nav.querySelectorAll('a')) {
        final href = a.attributes['href'] ?? '';
        final m = RegExp(r'^/([a-z0-9]+)/(\d+)/$').firstMatch(href);
        if (m != null) {
          final _ncode = m.group(1)!;
          final _no = int.tryParse(m.group(2)!);
          if (_no != null && _ncode.toLowerCase() == ncode.toLowerCase()) {
            final label = a.text.trim();
            if (label.contains('前へ') || _no < episodeNo) prevNo ??= _no;
            if (label.contains('次へ') || _no > episodeNo) nextNo ??= _no;
          }
        }
      }
    }

    // 掲載/更新日時
    DateTime? postedAt;
    DateTime? updatedAt;
    final infoText = doc.querySelector('.novel_info')?.text ?? '';
    DateTime? _parseDate(String s) {
      final m1 = RegExp(
              r'(\d{4})/(\d{1,2})/(\d{1,2})(?:\s+(\d{1,2}):(\d{2}))?')
          .firstMatch(s);
      if (m1 == null) return null;
      final y = int.parse(m1.group(1)!);
      final mo = int.parse(m1.group(2)!);
      final d = int.parse(m1.group(3)!);
      final hh = int.tryParse(m1.group(4) ?? '0') ?? 0;
      final mm = int.tryParse(m1.group(5) ?? '0') ?? 0;
      return DateTime(y, mo, d, hh, mm);
    }
    final postedMatch = RegExp(
            r'(公開日|掲載日)[^0-9]*(\d{4}/\d{1,2}/\d{1,2}(?:\s+\d{1,2}:\d{2})?)')
        .firstMatch(infoText);
    final updatedMatch = RegExp(
            r'(更新日)[^0-9]*(\d{4}/\d{1,2}/\d{1,2}(?:\s+\d{1,2}:\d{2})?)')
        .firstMatch(infoText);
    if (postedMatch != null) postedAt = _parseDate(postedMatch.group(2)!);
    if (updatedMatch != null) updatedAt = _parseDate(updatedMatch.group(2)!);

    if (bodyHtml.isEmpty) {
      final raw = res.body.replaceAll('\r', '').replaceAll('\n', ' ');
      final snipLen = raw.length < 500 ? raw.length : 500;
      _log.info('[HTML first 500 chars] ${raw.substring(0, snipLen)}');
      throw Exception(
          'Unexpected page structure: body not found (ncode=$ncode ep=$episodeNo)');
    }

    if (requestDelay.inMilliseconds > 0) {
      await Future.delayed(requestDelay);
    }

    return Episode(
      ncode: ncode,
      episodeNo: episodeNo,
      subtitle: subtitle,
      bodyHtml: bodyHtml,
      prevEpisodeNo: prevNo,
      nextEpisodeNo: nextNo,
      postedAt: postedAt,
      updatedAt: updatedAt,
      url: url,
    );
  }

  void close() => _client.close();
}
