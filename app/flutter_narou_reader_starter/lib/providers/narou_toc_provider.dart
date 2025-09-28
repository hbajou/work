// ==============================================
// File: lib/narou_toc_provider.dart
// ==============================================

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as html;
import 'package:html/dom.dart';
import 'package:logging/logging.dart';

final _log = Logger('NarouTocProvider');

class Episode {
  final int index;
  final String title;
  final Uri url;
  final DateTime? publishedAt;
  Episode({
    required this.index,
    required this.title,
    required this.url,
    this.publishedAt,
  });
  @override
  String toString() =>
      '[$index] $title (${publishedAt?.toIso8601String() ?? "-"}) $url';
}

class NarouTocProvider {
  static const _base = 'https://ncode.syosetu.com';
  static const _ua =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/124.0 Safari/537.36 NarouReader/1.0';

  /// 1ページ分のTOCを取得（pageは1始まり）
  Future<_TocPageResult> _fetchTocPage(String ncode, int page) async {
    final currentCode = ncode.toLowerCase();
    final path = '/$currentCode/';
    final uri = page <= 1
        ? Uri.parse('$_base$path')
        : Uri.parse('$_base$path?p=$page');

    _log.info('[HTTP] GET $uri');
    final res = await http.get(uri, headers: {'User-Agent': _ua});
    final finalUrl = res.request?.url ?? uri;
    _log.info('[HTTP] status=${res.statusCode} final=$finalUrl');

    // ---- 観測ログ: HTTP/parse 直前 ----
    _log.fine('[HTTP][OBS p=$page] status=${res.statusCode} url=$finalUrl');
    _log.fine('[HTTP][OBS] UA=$_ua');
    _log.fine('[HTTP][OBS] body.length=${res.bodyBytes.length}');
    _log.fine('[TOC][OBS] currentCode(lower)=$currentCode');

    // 404 は「ページ無し」
    if (res.statusCode == 404) {
      return _TocPageResult(episodes: [], hasNext: false, maxPage: page - 1);
    }
    if (res.statusCode != 200) {
      throw StateError('HTTP ${res.statusCode} for $uri');
    }

    final body = utf8.decode(res.bodyBytes);
    final doc = html.parse(body);

    // ===== エピソード抽出（起点 a[href] → 段階フィルタ → Uri/セグメント厳密化） =====
    final episodes = <Episode>[];
    int localIdx = 0;

    // ---- 観測ログ: 参考セレクタのヒット数（従来の想定構造） ----
    _log.fine('[TOC][OBS p=$page] ncode(lower)=$currentCode');
    _log.fine('[TOC][OBS p=$page] selector="dl.novel_sublist2 .subtitle a[href]" hits=${doc.querySelectorAll('dl.novel_sublist2 .subtitle a[href]').length}');
    _log.fine('[TOC][OBS p=$page] selector="dl.novel_sublist2 a[href]" hits=${doc.querySelectorAll('dl.novel_sublist2 a[href]').length}');
    _log.fine('[TOC][OBS p=$page] selector="#novel_contents .index_box a[href]" hits=${doc.querySelectorAll('#novel_contents .index_box a[href]').length}');
    _log.fine('[TOC][OBS p=$page] selector="#novel_contents a[href]" hits=${doc.querySelectorAll('#novel_contents a[href]').length}');

    // 抽出候補（起点を最広に）
    final List<Element> allAnchors = doc.querySelectorAll('a[href]');

    // ---- 観測ログ: 段階フィルタ件数 & サンプル（起点 a[href]） ----
    final preSamples = allAnchors.take(3).map((e) => e.attributes['href'] ?? '').toList();
    _log.fine('[TOC][OBS p=$page] samples(pre-filter,3)=$preSamples');

    final allCandidates = allAnchors
        .map((e) => e.attributes['href'] ?? '')
        .where((s) => s.isNotEmpty)
        .toList();

    // 1) /<ncode>/ を含む（相対/絶対両対応）
    final containsNcode = allCandidates.where((href) {
      final h = href.toLowerCase();
      return h.contains('/$currentCode/');
    }).toList();

    // 2) 終端が数字（末尾スラッシュ許容）: /(?:\d+)(?:/|$)  ※観測用（本抽出はさらに厳密）
    final looseEnd = RegExp(r'(?:\d+)(?:/|$)');
    final endsWithNumLoose =
        containsNcode.where((h) => looseEnd.hasMatch(h)).toList();

    _log.fine(
      '[TOC][OBS p=$page] counts: total=${allCandidates.length} '
      '-> contains(/$currentCode/ or abs)=${containsNcode.length} '
      '-> end(' r'\d+(/|\$)' ')=${endsWithNumLoose.length}',
    );

    // 本抽出：Uri に解決し、?p= のページャ除外＆パスセグメントで ncode 直後が数字のみ
    final base = Uri.parse(_base);
    final seen = <String>{};
    final acceptedHrefs = <String>[];
    final epLinks = <Element>[];

    bool isEpisodeUrl(String hrefLower, Uri abs) {
      // ページャやその他のクエリは除外
      if (abs.queryParameters.containsKey('p')) return false;

      // パスセグメントで ncode の直後が「数字のみ」
      final segs = abs.pathSegments.map((s) => s.toLowerCase()).toList();
      final idx = segs.indexOf(currentCode);
      if (idx < 0 || idx + 1 >= segs.length) return false;
      final nextSeg = segs[idx + 1];
      return RegExp(r'^\d+$').hasMatch(nextSeg);
    }

    for (final a in allAnchors) {
      final href = a.attributes['href'] ?? '';
      if (href.isEmpty) continue;

      final hrefLower = href.toLowerCase();
      if (!hrefLower.contains('/$currentCode/')) continue; // 相対/絶対対応（粗フィルタ）

      final abs = href.startsWith('http') ? Uri.parse(href) : base.resolve(href);
      if (!isEpisodeUrl(hrefLower, abs)) continue;

      final key = abs.toString();
      if (seen.add(key)) {
        epLinks.add(a);
        acceptedHrefs.add(href);
      }
    }

    _log.fine('[TOC][OBS p=$page] samples(post-filter,3)=${acceptedHrefs.take(3).toList()}');

    for (final a in epLinks) {
      final href = a.attributes['href']!;
      final url = Uri.parse(_base).resolve(href);
      final title = a.text.trim().isNotEmpty ? a.text.trim() : '(無題)';
      final published = _extractDateTimeNearby(a);

      episodes.add(Episode(
        index: ++localIdx,
        title: title,
        url: url,
        publishedAt: published,
      ));
    }

    // ===== ページャ判定 =====
    final hasNext = _detectHasNext(
      doc,
      currentPage: page,
      epCountOnPage: episodes.length,
    );
    final maxP = _extractMaxPage(doc);

    _log.info('[TOC] page=$page episodes=${episodes.length} hasNext=$hasNext');
    return _TocPageResult(
      episodes: episodes,
      hasNext: hasNext,
      maxPage: maxP,
    );
  }

  /// 全ページ走査。maxPages=null なら尽きるまで
  Future<List<Episode>> fetchTocAllPages(String ncode, {int? maxPages}) async {
    final normalized = ncode.toLowerCase();
    final result = <Episode>[];
    var globalIndex = 0;
    var visitedPages = 0;

    // 1ページ目
    var page = 1;
    final r1 = await _fetchTocPage(normalized, page);
    if (r1.episodes.isNotEmpty) {
      visitedPages++;
      for (final e in r1.episodes) {
        result.add(Episode(
          index: ++globalIndex,
          title: e.title,
          url: e.url,
          publishedAt: e.publishedAt,
        ));
      }
    }

    // 上限を決める
    int lastPage = r1.maxPage ?? (r1.hasNext ? 9999 : 1);
    if (maxPages != null) {
      lastPage = lastPage.clamp(1, maxPages);
    }

    // 2ページ目以降
    for (page = 2; page <= lastPage; page++) {
      final r = await _fetchTocPage(normalized, page);
      if (r.episodes.isEmpty) {
        _log.info('[TOC] stop: empty page page=$page');
        break;
      }
      visitedPages++;
      for (final e in r.episodes) {
        result.add(Episode(
          index: ++globalIndex,
          title: e.title,
          url: e.url,
          publishedAt: e.publishedAt,
        ));
      }
    }

    _log.info('[TOC] total=${result.length} pages=$visitedPages');
    return result;
  }

  /// 1ページ版（後方互換）
  Future<List<Episode>> fetchToc(String ncode) async {
    final r = await _fetchTocPage(ncode, 1);
    var i = 0;
    return r.episodes
        .map((e) => Episode(
              index: ++i,
              title: e.title,
              url: e.url,
              publishedAt: e.publishedAt,
            ))
        .toList();
  }

  bool _detectHasNext(Document doc, {required int currentPage, int? epCountOnPage}) {
    // a[href*="?p="] から最大ページ番号推定
    int? maxP = _extractMaxPage(doc);
    if (maxP != null && maxP > currentPage) return true;
    if (maxP != null && maxP <= currentPage) return false;

    // 「次」テキスト
    for (final a in doc.querySelectorAll('a')) {
      final t = a.text.trim();
      final href = a.attributes['href'] ?? '';
      if (t == '›' || t == '»' || t == '>>' ||
          t.contains('次') || t.toLowerCase() == 'next') {
        if (href.isNotEmpty && href != '#' && !href.toLowerCase().startsWith('javascript')) {
          return true;
        }
      }
    }
    // 保険：1ページ100件なら次がある可能性
    if ((epCountOnPage ?? 0) >= 100 && currentPage == 1) return true;
    return false;
  }

  int? _extractMaxPage(Document doc) {
    int? maxP;
    for (final a in doc.querySelectorAll('a[href]')) {
      final href = a.attributes['href']!;
      final m = RegExp(r'[?&]p=(\d+)').firstMatch(href);
      if (m != null) {
        final p = int.tryParse(m.group(1)!);
        if (p != null) {
          maxP = (maxP == null) ? p : (p > maxP! ? p : maxP);
        }
      }
    }
    return maxP;
  }

  DateTime? _extractDateTimeNearby(Element a) {
    Element? cursor = a.parent;
    for (int depth = 0; depth < 3 && cursor != null; depth++) {
      final text = cursor.text;
      final dt = _parseLooseDateTime(text);
      if (dt != null) return dt;
      cursor = cursor.parent;
    }
    return null;
  }

  DateTime? _parseLooseDateTime(String text) {
    final re = RegExp(r'(\d{4})/(\d{1,2})/(\d{1,2})\s+(\d{1,2}):(\d{2})');
    final m = re.firstMatch(text);
    if (m == null) return null;
    final y = int.parse(m.group(1)!);
    final mo = int.parse(m.group(2)!);
    final d = int.parse(m.group(3)!);
    final h = int.parse(m.group(4)!);
    final mi = int.parse(m.group(5)!);
    try {
      return DateTime(y, mo, d, h, mi);
    } catch (_) {
      return null;
    }
  }
}

class _TocPageResult {
  final List<Episode> episodes;
  final bool hasNext;
  final int? maxPage;
  _TocPageResult({
    required this.episodes,
    required this.hasNext,
    this.maxPage,
  });
}
