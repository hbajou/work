# 📚 Narou Reader (Flutter Starter)

自分用の「小説家になろう」ビューワアプリの最小スターターです。  
**Windows で開発 → Mac で iOS Ad Hoc ビルド**のワークフローを想定。

## できること（初期版）
- 画面遷移：本棚 / 検索 / リーダー / 設定
- 本棚：ローカルに保存されたタイトルの簡易リスト（SharedPreferencesに保存）
- リーダー：ダミー本文を表示、**文字サイズ**を調整（スライダー）
- テーマ：Light / Dark を切り替え（※セピアは後続）

> ※本文取得やAPI連携（なろう小説API）は後続で実装します。まずは UI とローカル保存の土台を固める最小構成です。

---

## セットアップ（Windows）
1. Flutter SDK をインストール → `flutter doctor`
2. エディタ（VS Code 推奨）に Flutter/Dart 拡張を追加
3. Android Studio を入れて **Android 仮想デバイス**(AVD) か、USB接続の実機を用意
4. このフォルダを任意の場所に展開し、プロジェクト直下で：
   ```bash
   flutter pub get
   flutter run
   ```

## iOS ビルド（Mac 2017）
1. Xcode と CocoaPods をインストール
2. プロジェクトをコピー（または Git pull）
3. 依存解決：
   ```bash
   flutter pub get
   cd ios && pod install && cd ..
   ```
4. ビルド：
   ```bash
   flutter build ipa
   ```
5. Xcode Organizerで **Ad Hoc 署名** → `.ipa` を出力
6. Finder で iPhone に **ドラッグ＆ドロップ**

> Apple Developer Program（有料）が必要。デバイスUDID登録とAd Hocプロファイル作成は事前に済ませてください。

---

## 今後の実装メモ（TODO）
- [ ] なろう小説APIで作品検索（ncode/タイトル/作者取得）
- [ ] 目次・各話HTMLの取得と本文抽出 → オフライン保存（SQLite/Driftに移行）
- [ ] 更新チェック（`lastup`差分取得）
- [ ] リーダーの **ページ送り（ページネーション）** 実装
- [ ] テーマ：セピア／行間・余白・段落字下げ／禁則処理
- [ ] 背景色の昼夜自動切替（システム設定に追従 or 時刻連動）
- [ ] ストレージ設定（全話保持／未読優先DL／自動間引き）

---

## 主要コマンド
```bash
flutter pub get
flutter run -d chrome           # Webデバッグ（UI確認用）
flutter run                     # 接続端末へ
flutter build apk               # Android用
flutter build ipa               # iOS(要Mac)
```

---

## ライセンス
自分用スターター。
