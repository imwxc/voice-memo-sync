#!/usr/bin/env python3
"""FunASR Transcription Bridge for voice-memo-sync.

Usage:
    python3 funasr_transcribe.py --input <audio_file> --output-dir <dir> [--diarize] [--device cpu]

Requires FunASR venv: /tmp/funasr-env/bin/python3 funasr_transcribe.py ...
"""

import argparse
import json
import os
import sys
import time

os.environ.setdefault("MODELSCOPE_CACHE", os.path.expanduser("~/.cache/modelscope"))


def parse_args():
    p = argparse.ArgumentParser(description="FunASR Transcription Bridge")
    p.add_argument("--input", required=True, help="Path to audio/video file")
    p.add_argument("--output-dir", required=True, help="Directory for output files")
    p.add_argument(
        "--diarize", action="store_true", help="Enable speaker diarization (cam++)"
    )
    p.add_argument(
        "--device",
        default="cpu",
        choices=["cpu", "mps", "cuda"],
        help="Inference device",
    )
    return p.parse_args()


def load_model(diarize: bool, device: str):
    from funasr import AutoModel

    kwargs = {
        "model": "paraformer-zh",
        "vad_model": "fsmn-vad",
        "punc_model": "ct-punc",
        "device": device,
    }
    if diarize:
        kwargs["spk_model"] = "cam++"

    print(
        f"[FunASR] Loading models (diarize={diarize}, device={device})...",
        file=sys.stderr,
    )
    start = time.time()
    model = AutoModel(**kwargs)
    print(f"[FunASR] Models loaded in {time.time() - start:.1f}s", file=sys.stderr)
    return model


def format_ms(ms):
    total_sec = ms // 1000
    return f"{total_sec // 60:02d}:{total_sec % 60:02d}"


def format_timestamp_line(text, start_ms, end_ms, spk=None, diarize=False):
    ts = f"[{format_ms(start_ms)}-{format_ms(end_ms)}]"
    spk_label = f"[说话人{spk}] " if (diarize and spk is not None) else ""
    return f"{ts} {spk_label}{text}"


def process_result(result, diarize: bool):
    text = result.get("text", "")
    sentence_info = result.get("sentence_info", [])

    lines = []
    for sent in sentence_info:
        lines.append(
            format_timestamp_line(
                sent.get("text", ""),
                sent.get("start", 0),
                sent.get("end", 0),
                sent.get("spk"),
                diarize,
            )
        )

    if not lines and text:
        lines = [text]

    timestamped_text = "\n".join(lines)

    json_output = None
    if diarize:
        json_output = {
            "key": result.get("key", ""),
            "text": text,
            "timestamp": result.get("timestamp", []),
            "sentence_info": sentence_info,
        }

    return timestamped_text, json_output


def main():
    args = parse_args()

    if not os.path.isfile(args.input):
        print(f"[FunASR] Error: File not found: {args.input}", file=sys.stderr)
        sys.exit(1)

    os.makedirs(args.output_dir, exist_ok=True)
    basename = os.path.splitext(os.path.basename(args.input))[0]

    try:
        model = load_model(diarize=args.diarize, device=args.device)
    except Exception as e:
        print(f"[FunASR] Error: Failed to load model: {e}", file=sys.stderr)
        sys.exit(1)

    print(f"[FunASR] Transcribing: {os.path.basename(args.input)}", file=sys.stderr)
    start = time.time()
    try:
        results = model.generate(input=args.input, batch_size_s=300)
    except Exception as e:
        print(f"[FunASR] Error: Transcription failed: {e}", file=sys.stderr)
        sys.exit(1)
    print(f"[FunASR] Transcription done in {time.time() - start:.1f}s", file=sys.stderr)

    if not results:
        print("[FunASR] Error: No results returned", file=sys.stderr)
        sys.exit(1)

    full_text = ""
    json_output = None

    for result in results:
        timestamped_text, json_out = process_result(result, args.diarize)
        full_text += ("\n" if full_text else "") + timestamped_text
        if json_out:
            json_output = json_out

    txt_path = os.path.join(args.output_dir, f"{basename}.txt")
    with open(txt_path, "w", encoding="utf-8") as f:
        f.write(full_text + "\n")
    print(f"[FunASR] Text saved: {txt_path}", file=sys.stderr)

    if json_output:
        json_path = os.path.join(args.output_dir, f"{basename}.json")
        with open(json_path, "w", encoding="utf-8") as f:
            json.dump(json_output, f, ensure_ascii=False, indent=2)
        print(f"[FunASR] JSON saved: {json_path}", file=sys.stderr)

    print(full_text)


if __name__ == "__main__":
    main()
