# Video subtitle tool

このツールは、MP4 動画から音声を抽出し、Whisper で文字起こしを行い、
発話区間だけを残した動画を生成します。字幕の焼き込みは行いません。

## 依存関係

- FFmpeg が PATH にあること、または `--ffmpeg-path` で実行ファイルの場所を指定できること
- Python 3.10 以上
- `pip install -r tools/requirements.txt`

## FFmpeg のインストール（Windows）

WinGet を使う場合は次を実行します。

```powershell
winget install --id Gyan.Dev.FFmpeg -e
```

インストール後、FFmpeg が PATH に入っているか確認します。

```powershell
ffmpeg -version
```

PATH に入っていない場合は、以下のように直接指定できます。

```powershell
python tools/video_subtitle_tool.py "F:\編集動画\20260701\movie.mp4" -o "F:\編集動画\20260701\out.mp4" --ffmpeg-path "C:\ffmpeg\bin\ffmpeg.exe"
```

## 使い方

### コマンドライン版

```bash
python tools/video_subtitle_tool.py "C:/path/to/your/video.mp4" -o "C:/path/to/output.mp4"
```

### フォルダリ一括処理版

```bat
tools\run_subtitle_folder.bat "F:\編集動画\20260701" "F:\編集動画\20260701_out" --model small --language ja
```

1 つ目の引数が入力フォルダ、2 つ目が出力フォルダです。出力フォルダは事前に作成しておく必要があります。

### Windows GUI 版

```bat
tools\run_subtitle_gui.bat
```

ダブルクリックでも起動します。動画ファイルと出力先を選んで「処理開始」すれば動きます。

### 例

```bash
python tools/video_subtitle_tool.py "C:/path/to/video.mp4" -o "C:/path/to/result.mp4"
```

```bat
tools\run_subtitle_folder.bat "F:\編集動画\20260701" "F:\編集動画\20260701_out" --model small --language ja
```

### オプション

- `--model`: Whisper のモデル名 (`tiny`, `base`, `small`, `medium`, `large`)
- `--language`: 文字起こし対象の言語 (`ja`, `en` など)
- `--ffmpeg-path`: FFmpeg の実行ファイル直指定（PATH に入っていない場合）
