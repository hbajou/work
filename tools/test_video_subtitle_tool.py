import os
import sys
import tempfile
from pathlib import Path

sys.path.append(str(Path(__file__).resolve().parent))

from video_subtitle_tool import build_crop_filter, build_default_output_paths, build_reencode_command, escape_ffmpeg_filter_path, merge_segments, prepare_ffmpeg_environment, resolve_ffmpeg_path, segments_to_srt


def test_segments_to_srt_formats_expected_content():
    segments = [
        {"start": 0.0, "end": 1.23, "text": "Hello world"},
        {"start": 1.23, "end": 2.5, "text": "Second line"},
    ]

    expected = (
        "1\n"
        "00:00:00,000 --> 00:00:01,230\n"
        "Hello world\n\n"
        "2\n"
        "00:00:01,230 --> 00:00:02,500\n"
        "Second line\n"
    )

    assert segments_to_srt(segments) == expected


def test_build_default_output_paths_uses_input_names_when_not_specified():
    input_video = Path("C:/videos/sample.mp4")

    output_video, subtitle_path = build_default_output_paths(input_video)

    assert output_video == Path("C:/videos/sample.subtitled.mp4")
    assert subtitle_path == Path("C:/videos/sample.srt")


def test_resolve_ffmpeg_path_returns_existing_explicit_path():
    with tempfile.TemporaryDirectory() as temp_dir:
        ffmpeg_path = Path(temp_dir) / "ffmpeg.exe"
        ffmpeg_path.write_text("fake", encoding="utf-8")

        assert resolve_ffmpeg_path(str(ffmpeg_path)) == str(ffmpeg_path.resolve())


def test_prepare_ffmpeg_environment_adds_ffmpeg_directory_to_path(monkeypatch):
    with tempfile.TemporaryDirectory() as temp_dir:
        ffmpeg_path = Path(temp_dir) / "ffmpeg.exe"
        ffmpeg_path.write_text("fake", encoding="utf-8")

        monkeypatch.delenv("FFMPEG_BINARY", raising=False)
        monkeypatch.delenv("PATH", raising=False)

        prepared_path = prepare_ffmpeg_environment(str(ffmpeg_path))

        assert prepared_path == str(ffmpeg_path.resolve())
        assert os.environ["FFMPEG_BINARY"] == prepared_path
        assert str(ffmpeg_path.parent) in os.environ["PATH"].split(os.pathsep)


def test_merge_segments_merges_short_gaps():
    segments = [
        {"start": 0.0, "end": 1.0, "text": "Hello"},
        {"start": 1.2, "end": 2.2, "text": "world"},
    ]

    assert merge_segments(segments) == [{"start": 0.0, "end": 2.2, "text": "Hello world"}]


def test_build_crop_filter_returns_expected_filter():
    assert build_crop_filter(180, 1920, 1080) == "crop=iw:ih-180:0:0,scale=1920:1080:force_original_aspect_ratio=increase,crop=1920:1080"


def test_escape_ffmpeg_filter_path_escapes_windows_drive_letters():
    path = Path(r"C:\Users\example\output.srt")

    assert escape_ffmpeg_filter_path(path) == "'C\\:/Users/example/output.srt'"


def test_build_reencode_command_drops_subtitle_streams_and_preserves_video_audio_mapping():
    command = build_reencode_command(Path("input.mp4"), Path("output.mp4"), "ffmpeg")
    joined = " ".join(command)

    assert "ffmpeg" in command[0]
    assert "-map 0:v:0" in joined
    assert "-map 0:a:0?" in joined
    assert "subtitles" not in joined
