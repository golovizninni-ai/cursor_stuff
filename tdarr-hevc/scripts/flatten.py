#!/usr/bin/env python3
"""Hardlink a downloads folder into ../output with a human-readable log.

Only creates hardlinks (os.link). Never copies. Stops on the first hardlink
failure. Ambiguous sidecar matches are logged and skipped.
"""

from __future__ import annotations

import argparse
import os
import re
import sys
from dataclasses import dataclass
from datetime import datetime, timezone
from pathlib import Path

VIDEO_EXTENSIONS = {".mkv", ".mp4", ".m4v", ".avi", ".ts"}
SUB_EXTENSIONS = {".ass", ".srt", ".sub", ".sup"}
AUDIO_EXTENSIONS = {".mka", ".ac3", ".dts", ".flac", ".aac", ".opus"}
SIDECAR_EXTENSIONS = SUB_EXTENSIONS | AUDIO_EXTENSIONS | {".idx"}

RESOLUTION_NUMBERS = {720, 1080, 2160, 4320}

GENERIC_DIR_NAMES = {
    "subs",
    "sub",
    "subtitles",
    "subtitle",
    "audio",
    "sound",
    "sounds",
    "озвучка",
    "dubs",
    "tracks",
}

EPISODE_PATTERNS: list[re.Pattern[str]] = [
    re.compile(r"(?i)\bs(\d{1,2})e(\d{1,2})\b"),
    re.compile(r"(?i)\b(\d{1,2})x(\d{1,2})\b"),
    re.compile(r"(?i)(?:^|[^0-9])e(\d{1,3})(?:[^0-9]|$)"),
]


@dataclass(frozen=True)
class EpisodeKey:
    season: int | None
    episode: int

    @classmethod
    def from_name(cls, name: str) -> EpisodeKey | None:
        for index, pattern in enumerate(EPISODE_PATTERNS):
            match = pattern.search(name)
            if not match:
                continue
            if index == 0:
                return cls(int(match.group(1)), int(match.group(2)))
            if index == 1:
                return cls(int(match.group(1)), int(match.group(2)))
            episode = int(match.group(1))
            if episode in RESOLUTION_NUMBERS:
                continue
            return cls(None, episode)
        return None


@dataclass
class VideoEntry:
    src: Path
    stem: str
    basename: str
    episode: EpisodeKey | None


@dataclass
class SidecarEntry:
    src: Path
    kind: str
    extension: str
    stem: str
    episode: EpisodeKey | None
    language: str
    studio: str | None
    paired_sub: Path | None = None


class HumanLogger:
    def __init__(self, log_path: Path, src_root: Path) -> None:
        self.log_path = log_path
        self.src_root = src_root.resolve()
        self._file = log_path.open("a", encoding="utf-8")
        self._write_header()

    def _write_header(self) -> None:
        stamp = datetime.now(timezone.utc).strftime("%Y-%m-%d %H:%M:%S UTC")
        self._emit(f"# flatten.py started {stamp}")
        self._emit(f"# src: {self.src_root}")
        self._emit("")

    def _emit(self, line: str) -> None:
        print(line)
        self._file.write(line + "\n")
        self._file.flush()

    def rel_src(self, path: Path) -> str:
        try:
            return str(path.resolve().relative_to(self.src_root))
        except ValueError:
            return str(path)

    def ok_video(self, dst_name: str, src: Path) -> None:
        self._emit(f"OK   video  {dst_name}")
        self._emit(f"       <- {self.rel_src(src)}")

    def ok_sidecar(
        self,
        kind: str,
        dst_name: str,
        src: Path,
        language: str,
        studio: str | None,
    ) -> None:
        tags = [language]
        if studio:
            tags.append(studio)
        tag_str = ", ".join(tags)
        self._emit(f"OK   {kind:<5}  {dst_name}  [{tag_str}]")
        self._emit(f"       <- {self.rel_src(src)}")

    def skip_ambiguous(self, sidecar_name: str, matches: list[str]) -> None:
        joined = ", ".join(matches)
        self._emit(f"SKIP ambiguous  {sidecar_name}  -> {joined}")

    def skip_existing(self, dst_name: str) -> None:
        self._emit(f"SKIP exists     {dst_name}")

    def error(self, message: str) -> None:
        self._emit(f"ERROR           {message}")

    def close(self) -> None:
        self._file.close()


def normalize_stem(value: str) -> str:
    return value.casefold()


def stems_match(video_stem: str, sidecar_stem: str) -> bool:
    video = normalize_stem(video_stem)
    sidecar = normalize_stem(sidecar_stem)
    if video == sidecar:
        return True
    if sidecar.startswith(video + ".") or sidecar.startswith(video + "_"):
        return True
    if video.startswith(sidecar + ".") or video.startswith(sidecar + "_"):
        return True
    return False


def detect_language(name: str) -> str:
    upper = name.upper()
    if "[ENG]" in upper or ".ENG." in upper or re.search(r"(?i)\beng\b", name):
        return "eng"
    return "rus"


def detect_studio(path: Path) -> str | None:
    parts = path.parts
    for index, part in enumerate(parts[:-1]):
        if part.casefold() not in GENERIC_DIR_NAMES:
            continue
        if index + 1 >= len(parts) - 1:
            continue
        studio = parts[index + 1]
        cleaned = re.sub(r"[^\w.-]+", "", studio)
        if cleaned and cleaned.casefold() not in GENERIC_DIR_NAMES:
            return cleaned
    return None


def sidecar_kind(extension: str) -> str:
    if extension in SUB_EXTENSIONS or extension == ".idx":
        return "sub"
    if extension in AUDIO_EXTENSIONS:
        return "audio"
    return "file"


def collect_videos(src_root: Path) -> list[VideoEntry]:
    videos: list[VideoEntry] = []
    for path in sorted(src_root.rglob("*")):
        if not path.is_file():
            continue
        if path.suffix.casefold() not in VIDEO_EXTENSIONS:
            continue
        videos.append(
            VideoEntry(
                src=path,
                stem=path.stem,
                basename=path.name,
                episode=EpisodeKey.from_name(path.stem),
            )
        )
    return videos


def collect_sidecars(src_root: Path, video_paths: set[Path]) -> list[SidecarEntry]:
    sidecars: list[SidecarEntry] = []
    seen_pairs: set[Path] = set()

    for path in sorted(src_root.rglob("*")):
        if not path.is_file():
            continue
        if path in video_paths:
            continue

        extension = path.suffix.casefold()
        if extension not in SIDECAR_EXTENSIONS:
            continue

        paired_sub: Path | None = None
        if extension == ".idx":
            sub_path = path.with_suffix(".sub")
            if not sub_path.is_file():
                continue
            paired_sub = sub_path
            seen_pairs.add(sub_path)
        elif extension == ".sub" and path in seen_pairs:
            continue

        sidecars.append(
            SidecarEntry(
                src=path,
                kind=sidecar_kind(extension),
                extension=extension,
                stem=path.stem,
                episode=EpisodeKey.from_name(path.stem),
                language=detect_language(path.name),
                studio=detect_studio(path),
                paired_sub=paired_sub,
            )
        )

    return sidecars


def match_videos(sidecar: SidecarEntry, videos: list[VideoEntry]) -> list[VideoEntry]:
    exact = [video for video in videos if stems_match(video.stem, sidecar.stem)]
    if exact:
        return exact

    if sidecar.episode is None:
        return []

    matched: list[VideoEntry] = []
    for video in videos:
        if video.episode != sidecar.episode:
            continue
        if video.episode.season is not None and sidecar.episode.season is not None:
            if video.episode.season != sidecar.episode.season:
                continue
        matched.append(video)
    return matched


def build_sidecar_name(video: VideoEntry, sidecar: SidecarEntry) -> str:
    studio_part = f".{sidecar.studio}" if sidecar.studio else ""
    return f"{video.stem}.{sidecar.language}{studio_part}{sidecar.extension}"


def hardlink(src: Path, dst: Path) -> None:
    dst.parent.mkdir(parents=True, exist_ok=True)
    if dst.exists():
        if dst.samefile(src):
            return
        raise FileExistsError(f"destination exists with a different inode: {dst}")
    os.link(src, dst)


def process_videos(
    videos: list[VideoEntry],
    dst_root: Path,
    logger: HumanLogger,
) -> dict[Path, Path]:
    video_dst_map: dict[Path, Path] = {}
    for video in videos:
        dst = dst_root / video.basename
        if dst.exists() and not dst.samefile(video.src):
            logger.skip_existing(video.basename)
            raise SystemExit(1)
        hardlink(video.src, dst)
        logger.ok_video(video.basename, video.src)
        video_dst_map[video.src] = dst
    return video_dst_map


def process_sidecars(
    sidecars: list[SidecarEntry],
    videos: list[VideoEntry],
    dst_root: Path,
    logger: HumanLogger,
) -> None:
    for sidecar in sidecars:
        matches = match_videos(sidecar, videos)
        if not matches:
            continue
        if len(matches) > 1:
            logger.skip_ambiguous(
                sidecar.src.name,
                [video.basename for video in matches],
            )
            continue

        video = matches[0]
        dst_name = build_sidecar_name(video, sidecar)
        dst = dst_root / dst_name
        if dst.exists() and not dst.samefile(sidecar.src):
            logger.skip_existing(dst_name)
            raise SystemExit(1)

        hardlink(sidecar.src, dst)
        logger.ok_sidecar(
            sidecar.kind,
            dst_name,
            sidecar.src,
            sidecar.language,
            sidecar.studio,
        )

        if sidecar.paired_sub is not None:
            sub_sidecar = SidecarEntry(
                src=sidecar.paired_sub,
                kind="sub",
                extension=".sub",
                stem=sidecar.paired_sub.stem,
                episode=sidecar.episode,
                language=sidecar.language,
                studio=sidecar.studio,
            )
            sub_dst_name = build_sidecar_name(video, sub_sidecar)
            sub_dst = dst_root / sub_dst_name
            if sub_dst.exists() and not sub_dst.samefile(sidecar.paired_sub):
                logger.skip_existing(sub_dst_name)
                raise SystemExit(1)
            hardlink(sidecar.paired_sub, sub_dst)
            logger.ok_sidecar(
                "sub",
                sub_dst_name,
                sidecar.paired_sub,
                sidecar.language,
                sidecar.studio,
            )


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Hardlink one downloads folder into ../output with a readable log.",
    )
    parser.add_argument("--src", required=True, type=Path, help="Source downloads folder")
    parser.add_argument("--dst", required=True, type=Path, help="Destination output folder")
    parser.add_argument("--log", required=True, type=Path, help="Log file path")
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    src_root = args.src.resolve()
    dst_root = args.dst.resolve()

    if not src_root.is_dir():
        print(f"Source folder does not exist: {src_root}", file=sys.stderr)
        return 1

    args.log.parent.mkdir(parents=True, exist_ok=True)
    logger = HumanLogger(args.log, src_root)

    try:
        videos = collect_videos(src_root)
        if not videos:
            logger.error(f"no video files found under {src_root}")
            return 1

        video_paths = {video.src for video in videos}
        sidecars = collect_sidecars(src_root, video_paths)

        process_videos(videos, dst_root, logger)
        process_sidecars(sidecars, videos, dst_root, logger)
    except OSError as exc:
        logger.error(str(exc))
        return 1
    finally:
        logger.close()

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
