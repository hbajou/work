# Video subtitle tool

このツールは、MP4 動画から音声を抽出し、Whisper で文字起こしを行い、
発話区間だけを残した動画を生成します。字幕の焼き込みは行いません。

## 依存関係

- FFmpeg が PATH にあること、または `--ffmpeg-path` で実行ファイルの場所を指定できること
- Python 3.10 以上
- `pip install -r tools/requirements.txt`

## 使い方

### コマンドライン版

```bash
python tools/video_subtitle_tool.py "C:/path/to/your/video.mp4" -o "C:/path/to/output.mp4"
```

### Windows GUI 版

```bat
tools\run_subtitle_gui.bat
```

ダブルクリックでも起動します。動画ファイルと出力先を選んで「処理開始」すれば動きます。

### 例

```bash
python tools/video_subtitle_tool.py "C:/path/to/video.mp4" -o "C:/path/to/result.mp4"
```

### オプション

- `--model`: Whisper のモデル名 (`tiny`, `base`, `small`, `medium`, `large`)
- `--language`: 文字起こし対象の言語 (`ja`, `en` など)
