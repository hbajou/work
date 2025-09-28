// lib/services/toc_fetch.dart
//
// Narou (小説家になろう / ノクターン等 syosetu.com ドメイン) 用の TOC 取得。
// - 抽象 TocProvider
// - データモデル (ChapterRef / TocResult)
// - NarouTocProvider 実装
//
// 使い方（例: bin/toc_smoke_test.dart 側）
//   final provider = NarouTocProvider();
//   final uri = Uri.parse('https://ncode.syosetu.com/n9669bk/');
//   final toc = await provider.fetch(uri);
//   print(toc.title);
//   print(toc.author);
//   print(toc.chapters.length);

import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as html;
import 'package:html/dom.dart' as dom;

// ------------------------------------------------------------
// データモデル
// ------------------------------------------------------------

/// 1 話（チャプタ）への参照
class ChapterRef {
  final int index;     // 1-origin
  final String title;  // サブタイトル
  final Uri url;       // 各話URL

  const ChapterRef({
    required this.index,
    required this.title,
    required this.url,
  });

  @override
  String toString() => 'ChapterRef(index=$index, title="$title", url=$url)';
}

/// 作品の TOC 結果
class TocResult {
  final String title;            // 作品タイトル
  final String? author;          // 作者名（取れなければ null）
  final Uri canonicalUrl;        // 作品トップの正規化URL
  final List<ChapterRef> chapters;

  const TocResult({
    required this.title,
    required this.canonicalUrl,
    required this.chapters,
    this.author,
  });

  /// 便宜的に章数ゲッターを用意
  int get chapterCount => chapters.length;

  @override
  String toString() =>
      'TocResult(title="$title", author="${author ?? '-'}", '
      'canonicalUrl=$canonicalUrl, chapters=${chapters.length})';
}

// ------------------------------------------------------------
// 抽象プロバイダ
// ------------------------------------------------------------

/// 任意サイトの TOC を提供するプロバイダIF
abstract class TocProvider {
  /// この URL を自分が処理できるか？
  bool supports(Uri url);

  /// TOC を取得してパース
  Future<TocResult> fetch(Uri url, {http.Client? client});
}

// ------------------------------------------------------------
// Narou 実装
// ------------------------------------------------------------

class NarouTocProvider implements TocProvider {
  static const _ua =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/124.0 Safari/537.36 NarouReader/1.0';

  @override
  bool supports(Uri url) {
    final host = url.host.toLowerCase();
    // ncode.syosetu.com / novel18.syosetu.com 等
    return host.endsWith('syosetu.com');
  }

// ★★★ NarouTocProvider.fetch を丸ごと置き換え ★★★
@override
Future<TocResult> fetch(Uri url, {http.Client? client}) async {
  final httpClient = client ?? http.Client();
  try {
    final resp1 = await httpClient.get(
      url,
      headers: {
        'User-Agent': _ua,
        'Accept-Language': 'ja,en;q=0.8',
      },
    );

    final finalUrl = resp1.request?.url ?? url;
    print('[HTTP] GET $url -> ${resp1.statusCode}  final=$finalUrl');
    print('[HTTP] UA=$_ua');
    print('[HTTP] body.length=${resp1.body.length}');
    final headLen = resp1.body.length < 500 ? resp1.body.length : 500;
    final head = resp1.body.substring(0, headLen).replaceAll('\n', ' ');
    print('[HTML HEAD] $head');

    if (resp1.statusCode != 200) {
      throw Exception('HTTP ${resp1.statusCode} for $url');
    }

    final doc1 = html.parse(resp1.body);
    final canonical = _detectCanonicalUrl(doc1, fallback: finalUrl);

    // まず1ページ目を通常パース（タイトル・作者・chapters（ページ1ぶん））
    final first = _parseDocument(
      doc1,
      sourceUrl: canonical,
      rawLength: resp1.body.length,
    );

    // 追加ページ（?p=2,3,...）の章だけを収集してマージ
    final allChapters = <ChapterRef>[...first.chapters];
    for (var p = 2; p <= 99; p++) {
      final pageUrl = canonical.replace(queryParameters: {'p': '$p'});
      print('[HTTP] paging -> $pageUrl');
      final r = await httpClient.get(pageUrl, headers: {
        'User-Agent': _ua,
        'Accept-Language': 'ja,en;q=0.8',
      });
      if (r.statusCode != 200) {
        print('[HTTP] stop: status ${r.statusCode} on p=$p');
        break;
      }
      final doc = html.parse(r.body);
      final chunks = _parseChaptersOnly(doc, sourceUrl: canonical);
      print('[PAGE $p] chapters=${chunks.length}');
      if (chunks.isEmpty) {
        // これ以上ページがない
        break;
      }

      // 重複回避（URLで判断）
      final existing = allChapters.map((c) => c.url.toString()).toSet();
      for (final c in chunks) {
        if (!existing.contains(c.url.toString())) {
          allChapters.add(c);
        }
      }
    }

    // index昇順でソート
    allChapters.sort((a, b) => a.index.compareTo(b.index));

    // 返却（タイトル・作者は1ページ目のを採用）
    return TocResult(
      title: first.title,
      canonicalUrl: canonical,
      chapters: allChapters,
      author: first.author,
    );
  } finally {
    if (client == null) httpClient.close();
  }
}



  // --------------------------- 解析本体 ---------------------------

TocResult _parseDocument(
  dom.Document doc, {
  required Uri sourceUrl,
  required int rawLength,
}) {
  // --- デバッグ: ざっくりカウント（任意で残してOK） ---
  void _logCount(String sel) {
    print('[SEL] $sel = ${doc.querySelectorAll(sel).length}');
  }
  for (final sel in [
    'a[href*="mypage.syosetu.com"]',
    'a[href^="/${_extractNcode(sourceUrl) ?? ""}/"]',
  ]) {
    _logCount(sel);
  }

  // --- タイトル（従来どおり） ---
  final title = _firstText([
    () => doc.querySelector('meta[property="og:title"]')?.attributes['content'],
    () => doc.querySelector('title')?.text,
  ])?.trim();

  // --- 作者：mypage リンクから取得 ---
  String? author = doc
      .querySelector('a[href*="mypage.syosetu.com"]')
      ?.text
      .trim();
  if (author != null && author.isEmpty) author = null;

  // --- 章リンク：/ncode/数字/ だけを正規表現で抽出 ---
  final chapters = <ChapterRef>[];
  final ncode = _extractNcode(sourceUrl); // 例: n9669bk
  if (ncode != null) {
    final re = RegExp(r'^/' + RegExp.escape(ncode) + r'/(\d+)/?$'); // /n9669bk/123/ 形式
    final seen = <String>{};

    for (final a in doc.querySelectorAll('a[href]')) {
      final href = a.attributes['href']?.trim();
      if (href == null || href.isEmpty) continue;

      // 絶対/相対どちらも resolve
      final resolved = sourceUrl.resolve(href);
      // パスだけで判定（ドメイン違いを除外）
      if (resolved.host != sourceUrl.host) continue;

      final m = re.firstMatch(resolved.path);
      if (m == null) continue; // 数字話URLでない

      // 重複除外（ページ内で同じリンクが複数あることがある）
      final key = resolved.toString();
      if (!seen.add(key)) continue;

      final idx = int.tryParse(m.group(1)!);
      final chapTitle = a.text.trim().isEmpty ? 'Episode $idx' : a.text.trim();

      chapters.add(
        ChapterRef(
          index: idx ?? (chapters.length + 1),
          title: chapTitle,
          url: resolved,
        ),
      );
    }

    // indexで昇順ソート（安全のため）
    chapters.sort((a, b) => a.index.compareTo(b.index));
  }

  // --- 短編（本文のみ）の保険 ---
  if (chapters.isEmpty) {
    final hasHonbun = doc.querySelector('#novel_honbun') != null;
    if (hasHonbun) {
      chapters.add(
        ChapterRef(
          index: 1,
          title: (title ?? '本編').trim(),
          url: sourceUrl,
        ),
      );
    }
  }

  print('[PARSE] title="${title ?? ''}" author="${author ?? '-'}" '
      'chapters=${chapters.length} raw=$rawLength');

  return TocResult(
    title: title ?? '',
    canonicalUrl: sourceUrl,
    chapters: chapters,
    author: author,
  );
}


  // --------------------------- ヘルパ ---------------------------
  List<ChapterRef> _parseChaptersOnly(
    dom.Document doc, {
    required Uri sourceUrl,
  }) {
    final chapters = <ChapterRef>[];

    // ncode 抽出（例: n9669bk）
    final ncode = _extractNcode(sourceUrl);
    if (ncode == null) return chapters;

    // /n9669bk/123/ 形式の話URLだけ拾う
    final re = RegExp(r'^/' + RegExp.escape(ncode) + r'/(\d+)/?$');
    final seen = <String>{};

    for (final a in doc.querySelectorAll('a[href]')) {
      final href = a.attributes['href']?.trim();
      if (href == null || href.isEmpty) continue;

      final resolved = sourceUrl.resolve(href);
      if (resolved.host != sourceUrl.host) continue;

      final m = re.firstMatch(resolved.path);
      if (m == null) continue;

      final key = resolved.toString();
      if (!seen.add(key)) continue;

      final idx = int.tryParse(m.group(1)!);
      final chapTitle = a.text.trim().isEmpty
          ? 'Episode ${idx ?? (chapters.length + 1)}'
          : a.text.trim();

      chapters.add(
        ChapterRef(
          index: idx ?? (chapters.length + 1),
          title: chapTitle,
          url: resolved,
        ),
      );
    }

    // 念のため昇順ソート
    chapters.sort((a, b) => a.index.compareTo(b.index));
    return chapters;
  }

  /// <link rel="canonical"> を使って正規URLを作る。無ければ fallback。
  Uri _detectCanonicalUrl(dom.Document doc, {required Uri fallback}) {
    final link = doc
        .querySelector('link[rel="canonical"]')
        ?.attributes['href']
        ?.trim();
    if (link == null || link.isEmpty) return fallback;

    // 絶対/相対どちらも resolve して対応
    return fallback.resolve(link);
  }

  String? _firstText(List<String? Function()> getters) {
    for (final g in getters) {
      final v = g();
      if (v != null && v.trim().isNotEmpty) return v;
    }
    return null;
  }
}


/// 複数の TocProvider をまとめて扱うリポジトリ
class TocRepository {
  final List<TocProvider> providers;

  TocRepository(this.providers);

  /// デフォルトで使うプロバイダ集合
  factory TocRepository.defaultProviders() {
    return TocRepository([
      NarouTocProvider(),
      // 将来的に別サイト用の Provider を足すならここに追加
    ]);
  }

  /// URL に対応する Provider を探す
  TocProvider? _findProvider(Uri url) {
    for (final p in providers) {
      if (p.supports(url)) return p;
    }
    return null;
  }

  /// 与えられた URL の TOC を取得
  Future<TocResult> fetch(Uri url, {http.Client? client}) async {
    final provider = _findProvider(url);
    if (provider == null) {
      throw Exception('No provider found for $url');
    }
    return provider.fetch(url, client: client);
  }
}


String? _extractNcode(Uri url) {
  // パス先頭が n[0-9a-z]+ の形式（例: /n9669bk/）
  final segs = url.path.split('/').where((s) => s.isNotEmpty).toList();
  if (segs.isEmpty) return null;
  final head = segs.first.toLowerCase();
  return RegExp(r'^n[0-9a-z]+$').hasMatch(head) ? head : null;
}
