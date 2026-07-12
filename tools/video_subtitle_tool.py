import argparse
import os
import re
import shutil
import subprocess
from pathlib import Path
from typing import Any, Dict, List, Tuple


def format_timestamp(seconds: float) -> str:
    hours = int(seconds // 3600)
    minutes = int((seconds % 3600) // 60)
    secs = int(seconds % 60)
    millis = int(round((seconds - int(seconds)) * 1000))
    return f"{hours:02d}:{minutes:02d}:{secs:02d},{millis:03d}"


def segments_to_srt(segments: List[Dict[str, Any]]) -> str:
    lines: List[str] = []
    for idx, segment in enumerate(segments, 1):
        start = format_timestamp(float(segment["start"]))
        end = format_timestamp(float(segment["end"]))
        text = re.sub(r"\s+", " ", str(segment.get("text", "")).strip())
        lines.append(str(idx))
        lines.append(f"{start} --> {end}")
        lines.append(text)
        lines.append("")
    return "\n".join(lines).rstrip() + "\n"


def resolve_ffmpeg_path(ffmpeg_path: str | None = None) -> str:
    if ffmpeg_path:
        candidate = Path(ffmpeg_path).expanduser().resolve()
        if candidate.exists():
            return str(candidate)
        raise RuntimeError(f"ffmpeg executable not found at: {candidate}")

    for executable_name in ("ffmpeg", "ffmpeg.exe"):
        resolved = shutil.which(executable_name)
        if resolved:
            return resolved

    if os.name == "nt":
        local_appdata = os.environ.get("LOCALAPPDATA")
        if local_appdata:
            win_get_packages = Path(local_appdata) / "Microsoft" / "WinGet" / "Packages"
            if win_get_packages.exists():
                for candidate in sorted(win_get_packages.rglob("ffmpeg.exe")):
                    if candidate.is_file():
                        return str(candidate)

        for candidate_path in (
            Path("C:/ffmpeg/bin/ffmpeg.exe"),
            Path("C:/Program Files/ffmpeg/bin/ffmpeg.exe"),
            Path("C:/Program Files/FFmpeg/bin/ffmpeg.exe"),
            Path("C:/Program Files (x86)/ffmpeg/bin/ffmpeg.exe"),
            Path("C:/Program Files (x86)/FFmpeg/bin/ffmpeg.exe"),
        ):
            if candidate_path.exists():
                return str(candidate_path)

    raise RuntimeError("ffmpeg not found. Install ffmpeg and make sure it is on PATH, or pass --ffmpeg-path.")


def ensure_ffmpeg(ffmpeg_path: str | None = None) -> str:
    return resolve_ffmpeg_path(ffmpeg_path)


def escape_ffmpeg_filter_path(path: Path | str) -> str:
    path_str = str(path).replace("\\", "/")
    if os.name == "nt" and re.match(r"^[A-Za-z]:/", path_str):
        path_str = path_str[0] + "\\:" + path_str[2:]
    return f"'{path_str}'"


def prepare_ffmpeg_environment(ffmpeg_path: str | None = None) -> str:
    resolved_ffmpeg = ensure_ffmpeg(ffmpeg_path)
    ffmpeg_path_obj = Path(resolved_ffmpeg).expanduser().resolve()
    ffmpeg_dir = str(ffmpeg_path_obj.parent)

    os.environ["FFMPEG_BINARY"] = str(ffmpeg_path_obj)

    current_path = os.environ.get("PATH", "")
    path_entries = [entry for entry in current_path.split(os.pathsep) if entry]
    if ffmpeg_dir not in path_entries:
        os.environ["PATH"] = os.pathsep.join([ffmpeg_dir, *path_entries])

    return str(ffmpeg_path_obj)


def extract_audio(input_video: Path, output_audio: Path, ffmpeg_path: str | None = None) -> None:
    ffmpeg_exe = ensure_ffmpeg(ffmpeg_path)
    subprocess.run(
        [
            ffmpeg_exe,
            "-y",
            "-i",
            str(input_video),
            "-vn",
            "-ac",
            "1",
            "-ar",
            "16000",
            str(output_audio),
        ],
        check=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        text=True,
    )


def transcribe_with_whisper(audio_path: Path, model_name: str = "base", language: str = "ja", ffmpeg_path: str | None = None) -> List[Dict[str, Any]]:
    try:
        import whisper
    except ImportError as exc:
        raise RuntimeError("whisper package is required. Install it with: pip install -r tools/requirements.txt") from exc

    prepare_ffmpeg_environment(ffmpeg_path)
    model = whisper.load_model(model_name)
    result = model.transcribe(str(audio_path), fp16=False, language=language)
    return result.get("segments", [])


def filtered_segments(segments: List[Dict[str, Any]], min_duration: float = 0.3) -> List[Dict[str, Any]]:
    cleaned: List[Dict[str, Any]] = []
    for segment in segments:
        text = re.sub(r"\s+", " ", str(segment.get("text", "")).strip())
        if not text:
            continue
        duration = float(segment.get("end", 0)) - float(segment.get("start", 0))
        if duration < min_duration:
            continue
        cleaned.append({**segment, "text": text})
    return cleaned


def merge_segments(segments: List[Dict[str, Any]], gap_threshold: float = 0.8, min_keep_duration: float = 0.6) -> List[Dict[str, Any]]:
    if not segments:
        return []

    merged: List[Dict[str, Any]] = []
    for segment in segments:
        if not merged:
            merged.append(dict(segment))
            continue

        previous = merged[-1]
        gap = float(segment.get("start", 0)) - float(previous.get("end", 0))
        previous_duration = float(previous.get("end", 0)) - float(previous.get("start", 0))
        segment_duration = float(segment.get("end", 0)) - float(segment.get("start", 0))
        if gap <= gap_threshold and previous_duration >= min_keep_duration and segment_duration >= min_keep_duration:
            previous["end"] = max(float(previous.get("end", 0)), float(segment.get("end", 0)))
            previous["text"] = f"{previous.get('text', '').strip()} {str(segment.get('text', '')).strip()}".strip()
        else:
            merged.append(dict(segment))

    return merged


def build_crop_filter(crop_bottom_px: int = 180, output_width: int | None = None, output_height: int | None = None) -> str:
    if crop_bottom_px <= 0:
        return ""
    if output_width and output_height:
        return (
            f"crop=iw:ih-{crop_bottom_px}:0:0,"
            f"scale={output_width}:{output_height}:force_original_aspect_ratio=increase,"
            f"crop={output_width}:{output_height}"
        )
    return f"crop=iw:ih-{crop_bottom_px}:0:0"


def get_video_resolution(input_video: Path, ffmpeg_path: str | None = None) -> Tuple[int, int]:
    ffmpeg_exe = ensure_ffmpeg(ffmpeg_path)
    ffprobe_exe = Path(ffmpeg_exe).with_name("ffprobe.exe")
    if not ffprobe_exe.exists():
        ffprobe_exe = Path(ffmpeg_exe).with_name("ffprobe")
    if not ffprobe_exe.exists():
        raise RuntimeError("ffprobe not found next to ffmpeg")

    completed = subprocess.run(
        [
            str(ffprobe_exe),
            "-v",
            "error",
            "-select_streams",
            "v:0",
            "-show_entries",
            "stream=width,height",
            "-of",
            "csv=p=0",
            str(input_video),
        ],
        check=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        text=True,
    )
    width_str, height_str = completed.stdout.strip().split(",")
    return int(width_str), int(height_str)


def build_reencode_command(input_video: Path, output_video: Path, ffmpeg_exe: str) -> List[str]:
    return [
        ffmpeg_exe,
        "-y",
        "-i",
        str(input_video),
        "-map",
        "0:v:0",
        "-map",
        "0:a:0?",
        "-c:v",
        "libx264",
        "-preset",
        "fast",
        "-crf",
        "23",
        "-c:a",
        "aac",
        "-movflags",
        "+faststart",
        str(output_video),
    ]


def build_speech_video(input_video: Path, output_video: Path, segments: List[Dict[str, Any]], temp_dir: Path, ffmpeg_path: str | None = None) -> None:
    ffmpeg_exe = ensure_ffmpeg(ffmpeg_path)
    if not segments:
        raise RuntimeError("No speech segments were detected, so no output video could be created.")

    clips_dir = temp_dir / "clips"
    clips_dir.mkdir(parents=True, exist_ok=True)
    concat_list = clips_dir / "concat.txt"
    clip_paths: List[Path] = []
    for index, segment in enumerate(segments):
        start = max(0.0, float(segment.get("start", 0)) - 0.15)
        end = max(start + 0.2, float(segment.get("end", start)) + 0.15)
        clip_path = clips_dir / f"clip_{index:03d}.mp4"
        ffmpeg_cmd = [
            ffmpeg_exe,
            "-y",
            "-ss",
            str(start),
            "-i",
            str(input_video),
            "-to",
            str(end - start),
            "-map",
            "0:v:0",
            "-map",
            "0:a:0?",
            "-c:v",
            "libx264",
            "-preset",
            "fast",
            "-crf",
            "23",
            "-c:a",
            "aac",
            "-movflags",
            "+faststart",
            str(clip_path),
        ]
        subprocess.run(
            ffmpeg_cmd,
            check=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            text=True,
        )
        clip_paths.append(clip_path)

    with concat_list.open("w", encoding="utf-8") as handle:
        for clip_path in clip_paths:
            handle.write(f"file '{clip_path.as_posix()}'\n")

    ffmpeg_cmd = [
        ffmpeg_exe,
        "-y",
        "-f",
        "concat",
        "-safe",
        "0",
        "-i",
        str(concat_list),
        "-map",
        "0:v:0",
        "-map",
        "0:a:0?",
        "-c:v",
        "libx264",
        "-preset",
        "fast",
        "-crf",
        "23",
        "-c:a",
        "aac",
        "-movflags",
        "+faststart",
        str(output_video),
    ]
    subprocess.run(
        ffmpeg_cmd,
        check=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        text=True,
    )


def burn_subtitles(input_video: Path, output_video: Path, srt_path: Path, ffmpeg_path: str | None = None) -> None:
    ffmpeg_exe = ensure_ffmpeg(ffmpeg_path)
    subprocess.run(
        [
            ffmpeg_exe,
            "-y",
            "-i",
            str(input_video),
            "-vf",
            f"subtitles={escape_ffmpeg_filter_path(srt_path)}",
            str(output_video),
        ],
        check=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        text=True,
    )


def build_default_output_paths(input_video: Path, output_video: str | None = None, srt_path: str | None = None) -> Tuple[Path, Path]:
    input_video = input_video.expanduser().resolve()
    output_path = Path(output_video).expanduser().resolve() if output_video else input_video.with_suffix(".subtitled.mp4")
    subtitle_path = Path(srt_path).expanduser().resolve() if srt_path else input_video.with_suffix(".srt")
    return output_path, subtitle_path


def process_video(input_video: Path, output_video: Path, srt_path: Path, temp_dir: Path, model_name: str = "base", language: str = "ja", ffmpeg_path: str | None = None) -> None:
    audio_path = temp_dir / "audio.wav"
    speech_video = temp_dir / "speech_only.mp4"
    extract_audio(input_video, audio_path, ffmpeg_path=ffmpeg_path)
    raw_segments = transcribe_with_whisper(audio_path, model_name=model_name, language=language, ffmpeg_path=ffmpeg_path)
    filtered = filtered_segments(raw_segments)
    merged_segments = merge_segments(filtered)
    build_speech_video(input_video, speech_video, merged_segments, temp_dir, ffmpeg_path=ffmpeg_path)
    output_video.write_bytes(Path(speech_video).read_bytes())


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Create a speech-only video by detecting speech segments with Whisper and clipping them together.")
    parser.add_argument("input", help="Input MP4 file")
    parser.add_argument("-o", "--output", help="Output MP4 file", default=None)
    parser.add_argument("--temp-dir", help="Temporary directory for intermediate files", default=None)
    parser.add_argument("--model", default="base", help="Whisper model name (tiny/base/small/medium/large)")
    parser.add_argument("--language", default="ja", help="Speech language for transcription")
    parser.add_argument("--ffmpeg-path", default=None, help="Path to the ffmpeg executable if it is not on PATH")
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    input_video = Path(args.input).expanduser().resolve()
    if not input_video.exists():
        raise FileNotFoundError(f"Input file not found: {input_video}")

    output_video, srt_path = build_default_output_paths(input_video, output_video=args.output, srt_path=None)
    temp_dir = Path(args.temp_dir or input_video.parent / "_subtitle_temp").expanduser().resolve()
    temp_dir.mkdir(parents=True, exist_ok=True)

    process_video(input_video, output_video, srt_path, temp_dir, model_name=args.model, language=args.language, ffmpeg_path=args.ffmpeg_path)
    print(f"Created: {output_video}")


if __name__ == "__main__":
    main()
