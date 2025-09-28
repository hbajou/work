class Book {
  final String ncode;
  final String title;
  final String author;

  const Book({required this.ncode, required this.title, required this.author});

  Map<String, dynamic> toJson() => {'ncode': ncode, 'title': title, 'author': author};
  factory Book.fromJson(Map<String, dynamic> j) => Book(
        ncode: j['ncode'] as String,
        title: j['title'] as String,
        author: j['author'] as String,
      );
}
