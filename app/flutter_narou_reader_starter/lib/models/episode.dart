// lib/models/episode.dart
class Episode {
  final String ncode;
  final int episodeNo;
  final String subtitle;
  final String bodyHtml;   // 保持はHTML、表示側でプレーン化/整形
  final int? prevEpisodeNo;
  final int? nextEpisodeNo;
  final DateTime? postedAt;    // 取得できる場合のみ
  final DateTime? updatedAt;   // 取得できる場合のみ
  final Uri url;

  Episode({
    required this.ncode,
    required this.episodeNo,
    required this.subtitle,
    required this.bodyHtml,
    required this.url,
    this.prevEpisodeNo,
    this.nextEpisodeNo,
    this.postedAt,
    this.updatedAt,
  });
}
