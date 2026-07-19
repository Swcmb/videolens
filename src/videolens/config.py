from __future__ import annotations

import os
from dataclasses import dataclass, field
from pathlib import Path


def _env_or_default(key: str, default: str) -> str:
    return os.environ.get(key, default)


def _env_or_none(key: str) -> str | None:
    return os.environ.get(key) or None


@dataclass(frozen=True)
class Models:
    transcribe_default: str = field(
        default_factory=lambda: _env_or_default(
            "VIDEOLENS_MODEL_TRANSCRIBE", "gpt-4o-mini-transcribe"
        )
    )
    transcribe_diarize: str = field(
        default_factory=lambda: _env_or_default(
            "VIDEOLENS_MODEL_TRANSCRIBE_DIARIZE", "gpt-4o-transcribe-diarize"
        )
    )
    frame_describe: str = field(
        default_factory=lambda: _env_or_default(
            "VIDEOLENS_MODEL_VISION", "gpt-5.4-mini"
        )
    )
    synthesize: str = field(
        default_factory=lambda: _env_or_default(
            "VIDEOLENS_MODEL_SYNTHESIZE", "gpt-5.5"
        )
    )


@dataclass(frozen=True)
class Defaults:
    max_frames: int = 40
    frame_interval_seconds: float = 5.0
    scene_change_threshold: float = 0.3


@dataclass
class Config:
    models: Models
    defaults: Defaults
    cache_root: Path
    openai_api_key: str | None
    openai_base_url: str | None

    @classmethod
    def load(cls) -> Config:
        cache_root = Path(
            os.environ.get("VIDEOLENS_CACHE_DIR", Path.cwd() / ".videolens" / "cache")
        )
        return cls(
            models=Models(),
            defaults=Defaults(),
            cache_root=cache_root,
            openai_api_key=_env_or_none("OPENAI_API_KEY"),
            openai_base_url=_env_or_none("OPENAI_BASE_URL"),
        )