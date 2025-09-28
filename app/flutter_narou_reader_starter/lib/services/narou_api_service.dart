import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;

class NarouWork {
  final String ncode;
  final String title;
  final String author;
  NarouWork({required this.ncode, required this.title, required this.author});
}

class NarouApiService {
  Future<List<NarouWork>> search({required String keyword, int limit = 20}) async {
    // Web実行はローカルプロキシ、それ以外（Android/iOS）は本番APIへ直アクセス
    final base = kIsWeb
        ? 'http://127.0.0.1:8787/narou-api'            // ← 末尾スラッシュ無し
        : 'https://api.syosetu.com/novelapi/api';       // ← 本家

    final uri = Uri.parse(
      '$base/?out=json&lim=$limit&order=hyoka&word=${Uri.encodeQueryComponent(keyword)}',
    );

    final res = await http.get(uri, headers: {
      'User-Agent': 'NarouReaderStarter/0.1 (personal use)',
      'Accept': 'application/json',
    });

    if (res.statusCode != 200) {
      throw Exception('Narou API error: ${res.statusCode}');
    }

    final list = jsonDecode(utf8.decode(res.bodyBytes)) as List<dynamic>;
    if (list.isEmpty) return [];
    return list.skip(1).map((e) {
      final m = e as Map<String, dynamic>;
      return NarouWork(
        ncode: (m['ncode'] as String).toUpperCase(),
        title: m['title'] as String,
        author: m['writer'] as String,
      );
    }).toList();
  }
}
