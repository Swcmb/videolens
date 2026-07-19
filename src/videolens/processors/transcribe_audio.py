from __future__ import annotations

import os
import warnings
from concurrent.futures import ThreadPoolExecutor, as_completed
from pathlib import Path

from openai import OpenAI

from videolens.config import Models
from videolens.processors.extract_audio import AudioChunk
from videolens.types import AnalysisMode, Transcript, TranscriptSegment


class TranscriptionError(RuntimeError):
    pass


def transcribe(
    audio_chunks: list[AudioChunk],
    client: OpenAI,
    models: Models,
    mode: AnalysisMode,
    max_workers: int = 4,
) -> Transcript:
    """Transcribe pre-chunked audio with rough per-chunk timestamps.

    Tries the OpenAI audio API first. If the provider doesn't support it
    (e.g. Sensenova, Agnes AI), falls back to local faster-whisper.
    Set VIDEOLENS_WHISPER_MODEL env var to choose a model size
    (tiny, base, small; default: tiny).
    """
    if not audio_chunks:
        return Transcript(segments=[])

    model_id = (
        models.transcribe_diarize if mode == AnalysisMode.MEETING else models.transcribe_default
    )

    results: dict[int, TranscriptSegment] = {}

    def task(idx: int, chunk: AudioChunk) -> tuple[int, TranscriptSegment]:
        text, speaker = _transcribe_one(chunk.path, client, model_id)
        return idx, TranscriptSegment(
            start=chunk.start,
            end=chunk.end,
            text=text.strip(),
            speaker=speaker,
        )

    with ThreadPoolExecutor(max_workers=max_workers) as pool:
        futures = [pool.submit(task, i, c) for i, c in enumerate(audio_chunks)]
        for fut in as_completed(futures):
            idx, segment = fut.result()
            results[idx] = segment

    ordered = [results[i] for i in sorted(results)]
    return Transcript(segments=[s for s in ordered if s.text])


# ── local whisper fallback ──────────────────────────────────────

_WHISPER_MODEL = None


def _get_whisper():
    global _WHISPER_MODEL
    if _WHISPER_MODEL is not None:
        return _WHISPER_MODEL
    from faster_whisper import WhisperModel

    model_size = os.environ.get("VIDEOLENS_WHISPER_MODEL", "tiny")
    compute_type = os.environ.get("VIDEOLENS_WHISPER_COMPUTE", "int8")
    download_root = os.environ.get(
        "VIDEOLENS_WHISPER_DIR",
        "/home/admin/.cache/whisper",
    )
    # Use full path if model is already cached locally
    model_path = os.path.join(download_root, model_size)
    if os.path.isdir(model_path) and os.path.exists(os.path.join(model_path, "model.bin")):
        model_size_or_path = model_path
    else:
        model_size_or_path = model_size
    warnings.warn(
        f"Loading local whisper model '{model_size_or_path}' (compute={compute_type}). "
        f"This may take a moment on first run."
    )
    _WHISPER_MODEL = WhisperModel(
        model_size_or_path, device="cpu", compute_type=compute_type,
        download_root=download_root,
    )
    return _WHISPER_MODEL


def _transcribe_local(path: Path) -> tuple[str, str | None]:
    """Transcribe with local faster-whisper. Returns (text, speaker)."""
    model = _get_whisper()
    segments, info = model.transcribe(str(path))
    text_parts = []
    for seg in segments:
        text_parts.append(seg.text)
    return " ".join(text_parts).strip(), None


# ── main dispatch ────────────────────────────────────────────────


def _transcribe_one(path: Path, client: OpenAI, model_id: str) -> tuple[str, str | None]:
    # Try OpenAI API first
    try:
        with path.open("rb") as f:
            response = client.audio.transcriptions.create(
                model=model_id,
                file=f,
                response_format="json",
            )
        text = getattr(response, "text", "") or ""
        speaker = getattr(response, "speaker", None)
        return text, speaker
    except Exception as exc:
        err_str = str(exc).lower()
        # If provider doesn't support audio API (404, not_found, forbidden),
        # fall back to local whisper
        is_provider_issue = any(
            kw in err_str
            for kw in ["not_found", "404", "forbidden", "not supported", "not found", "route"]
        )
        if is_provider_issue:
            warnings.warn(
                f"Provider doesn't support audio transcription API ({model_id}). "
                f"Falling back to local whisper..."
            )
            return _transcribe_local(path)
        raise TranscriptionError(f"Transcription failed ({model_id}): {exc}") from exc
