import tkinter as tk
from tkinter import filedialog, messagebox
from pathlib import Path
from video_subtitle_tool import build_default_output_paths, process_video


def run_gui() -> None:
    root = tk.Tk()
    root.title("Video Subtitle Tool")
    root.geometry("520x220")

    input_path = tk.StringVar()
    output_path = tk.StringVar()
    model_name = tk.StringVar(value="base")
    language = tk.StringVar(value="ja")

    def choose_input() -> None:
        path = filedialog.askopenfilename(filetypes=[("Video files", "*.mp4 *.mkv *.mov *.avi")])
        if path:
            input_path.set(path)
            default_output, _ = build_default_output_paths(Path(path))
            output_path.set(str(default_output))

    def choose_output() -> None:
        path = filedialog.asksaveasfilename(defaultextension=".mp4", filetypes=[("MP4", "*.mp4")])
        if path:
            output_path.set(path)

    def start_processing() -> None:
        source = input_path.get().strip()
        if not source:
            messagebox.showerror("入力エラー", "動画ファイルを選択してください")
            return

        output_file = output_path.get().strip() or str(Path(source).with_suffix(".subtitled.mp4"))
        srt_file = str(Path(output_file).with_suffix(".srt"))
        temp_dir = Path(source).parent / "_subtitle_temp"
        temp_dir.mkdir(parents=True, exist_ok=True)

        try:
            process_video(
                Path(source),
                Path(output_file),
                Path(srt_file),
                temp_dir,
                model_name=model_name.get().strip() or "base",
                language=language.get().strip() or "ja",
            )
            messagebox.showinfo("完了", f"処理完了\n出力: {output_file}")
        except Exception as exc:  # pragma: no cover - UI feedback path
            messagebox.showerror("エラー", str(exc))

    tk.Label(root, text="動画ファイル").grid(row=0, column=0, sticky="w", padx=10, pady=6)
    tk.Entry(root, textvariable=input_path, width=50).grid(row=0, column=1, padx=10, pady=6)
    tk.Button(root, text="参照", command=choose_input).grid(row=0, column=2, padx=6, pady=6)

    tk.Label(root, text="出力動画").grid(row=1, column=0, sticky="w", padx=10, pady=6)
    tk.Entry(root, textvariable=output_path, width=50).grid(row=1, column=1, padx=10, pady=6)
    tk.Button(root, text="参照", command=choose_output).grid(row=1, column=2, padx=6, pady=6)

    tk.Label(root, text="Whisperモデル").grid(row=2, column=0, sticky="w", padx=10, pady=6)
    tk.Entry(root, textvariable=model_name, width=20).grid(row=2, column=1, sticky="w", padx=10, pady=6)

    tk.Label(root, text="言語").grid(row=3, column=0, sticky="w", padx=10, pady=6)
    tk.Entry(root, textvariable=language, width=20).grid(row=3, column=1, sticky="w", padx=10, pady=6)

    tk.Button(root, text="処理開始", command=start_processing, width=18).grid(row=4, column=1, sticky="w", padx=10, pady=12)

    root.mainloop()


if __name__ == "__main__":
    run_gui()
