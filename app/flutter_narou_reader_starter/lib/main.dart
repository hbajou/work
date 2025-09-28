import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'screens/bookshelf_screen.dart';
import 'screens/reader_screen.dart';
import 'screens/search_screen.dart';
import 'screens/settings_screen.dart';

void main() {
  runApp(const ProviderScope(child: AppRoot()));
}

class AppRoot extends ConsumerWidget {
  const AppRoot({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = GoRouter(
      initialLocation: "/",
      routes: [
        GoRoute(
          path: "/",
          builder: (context, state) => const BookshelfScreen(),
          routes: [
            GoRoute(
              path: "reader",
              builder: (context, state) {
                final title = state.uri.queryParameters["title"] ?? "Untitled";
                final content = state.extra as String? ?? _dummyContent;
                return ReaderScreen(title: title, content: content);
              },
            ),
            GoRoute(
              path: "search",
              builder: (context, state) => const SearchScreen(),
            ),
            GoRoute(
              path: "settings",
              builder: (context, state) => const SettingsScreen(),
            ),
          ],
        ),
      ],
    );

    return MaterialApp.router(
      title: 'Narou Reader',
      theme: ThemeData(useMaterial3: true, brightness: Brightness.light),
      darkTheme: ThemeData(useMaterial3: true, brightness: Brightness.dark),
      themeMode: ThemeMode.system,
      routerConfig: router,
    );
  }
}

const _dummyContent = '''
　ここはダミーの本文です。文字サイズスライダーで見た目を確認できます。

　ページ送りは後続で実装予定（まずは縦スクロールで検証）。
''';
