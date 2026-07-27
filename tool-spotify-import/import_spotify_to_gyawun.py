#!/usr/bin/env python3
"""
Import a Spotify playlist into Gyawun Music by generating a
Backup & Restore JSON file the app can import directly into Favourites.

WHY THIS EXISTS
----------------
Gyawun has no direct Spotify integration (it's a YouTube Music client),
so there's no 1-click "connect Spotify" flow. This script bridges the gap:
it takes a list of your Spotify tracks, finds each one on YouTube Music,
and produces a JSON file matching Gyawun's Backup & Restore format:

    {
      "name": "Gyawun",
      "type": "backup",
      "version": 1,
      "data": { "favourites": { "<videoId>": { ...song fields... }, ... } }
    }

Settings > Backup and Restore > Restore in the app then merges that
straight into your Favourites - no manual searching/tapping per song.

SUPPORTED INPUT FORMATS
------------------------
1. Exportify CSV (https://exportify.net) - export any Spotify playlist
   without needing a developer account. Recommended for most users.
   Expected columns include "Track Name" and "Artist Name(s)"
   (Exportify's default export header names).

2. Plain text, one track per line, formatted as:
       Artist - Track Title
   Useful if you already have a list from elsewhere.

Format is auto-detected from the file extension (.csv vs .txt).

SETUP
-----
    pip install ytmusicapi

USAGE
-----
    python import_spotify_to_gyawun.py playlist.csv gyawun_favourites_backup.json
    python import_spotify_to_gyawun.py playlist.txt gyawun_favourites_backup.json

Then on your phone:
    1. Get the output .json file onto the device (email, cloud drive, USB...)
    2. Open Gyawun Music -> Settings -> Backup and Restore -> Restore
    3. Select the JSON file.

A companion "<output>.notfound.txt" lists any tracks that couldn't be
confidently matched, so they can be checked by hand.
"""

import csv
import json
import re
import sys
import time
from pathlib import Path

from ytmusicapi import YTMusic


def clean_query(text: str) -> str:
    """Strip parenthetical noise like (feat. X) / (with X) that can
    confuse search matching, while keeping the core artist/title."""
    cleaned = re.sub(r"\s*\((?:with|feat\.?|ft\.?)[^)]*\)", "", text, flags=re.I)
    return cleaned.strip()


def load_tracks(input_path: Path):
    """Returns a list of (artist, title, raw_label) tuples from either
    an Exportify CSV export or a plain 'Artist - Title' text file."""
    if input_path.suffix.lower() == ".csv":
        return _load_csv(input_path)
    return _load_txt(input_path)


def _load_csv(input_path: Path):
    tracks = []
    with input_path.open(newline="", encoding="utf-8-sig") as f:
        reader = csv.DictReader(f)
        # Exportify's default headers; fall back gracefully if renamed/lowercased.
        field_map = {k.strip().lower(): k for k in (reader.fieldnames or [])}
        title_key = field_map.get("track name") or field_map.get("name")
        artist_key = field_map.get("artist name(s)") or field_map.get("artist")
        if not title_key or not artist_key:
            raise ValueError(
                "Couldn't find 'Track Name' / 'Artist Name(s)' columns in the CSV. "
                "Make sure this is an Exportify export, or use the .txt format instead."
            )
        for row in reader:
            title = (row.get(title_key) or "").strip()
            artist = (row.get(artist_key) or "").split(",")[0].strip()  # first listed artist
            if title:
                tracks.append((artist or None, title, f"{artist} - {title}".strip(" -")))
    return tracks


def _load_txt(input_path: Path):
    tracks = []
    for line in input_path.read_text(encoding="utf-8").splitlines():
        line = line.strip()
        if not line:
            continue
        parts = line.split(" - ", 1)
        if len(parts) == 2:
            tracks.append((parts[0].strip(), parts[1].strip(), line))
        else:
            tracks.append((None, line, line))
    return tracks


def build_song_entry(result: dict, created_at: int) -> dict:
    return {
        "videoId": result.get("videoId"),
        "title": result.get("title"),
        "artists": result.get("artists") or [],
        "album": result.get("album"),
        "thumbnails": result.get("thumbnails") or [],
        "explicit": bool(result.get("isExplicit", False)),
        "duration": result.get("duration"),
        "duration_seconds": result.get("duration_seconds"),
        "createdAt": created_at,
    }


def search_best_match(yt: YTMusic, artist, title, raw_label):
    """Try a few query strategies, return the best 'songs' result."""
    queries = []
    if artist:
        queries.append(f"{artist} {title}")
    queries.append(clean_query(raw_label))
    queries.append(raw_label)

    seen = set()
    for q in queries:
        if not q or q in seen:
            continue
        seen.add(q)
        try:
            results = yt.search(q, filter="songs", limit=5)
        except Exception:
            results = []
        if results:
            return results[0]
    return None


def main():
    if len(sys.argv) < 2:
        print("Usage: python import_spotify_to_gyawun.py <playlist.csv|playlist.txt> [output.json]")
        sys.exit(1)

    input_path = Path(sys.argv[1])
    output_path = Path(sys.argv[2]) if len(sys.argv) > 2 else Path("gyawun_favourites_backup.json")
    notfound_path = output_path.with_suffix(output_path.suffix + ".notfound.txt")

    tracks = load_tracks(input_path)
    print(f"Loaded {len(tracks)} tracks from {input_path}")

    yt = YTMusic()  # no auth needed for search

    favourites = {}
    not_found = []
    base_time = int(time.time() * 1000)

    for i, (artist, title, raw_label) in enumerate(tracks, start=1):
        match = search_best_match(yt, artist, title, raw_label)

        if match and match.get("videoId"):
            vid = match["videoId"]
            if vid in favourites:
                print(f"[{i}/{len(tracks)}] (dup) {raw_label}")
            else:
                favourites[vid] = build_song_entry(match, base_time + i)
                matched_title = match.get("title")
                matched_artist = ", ".join(a["name"] for a in (match.get("artists") or []))
                print(f"[{i}/{len(tracks)}] OK  {raw_label}  ->  {matched_artist} - {matched_title}")
        else:
            not_found.append(raw_label)
            print(f"[{i}/{len(tracks)}] MISS {raw_label}")

        time.sleep(0.25)  # be polite to the (unauthenticated) API

    backup = {
        "name": "Gyawun",
        "type": "backup",
        "version": 1,
        "data": {"favourites": favourites},
    }
    output_path.write_text(json.dumps(backup), encoding="utf-8")

    if not_found:
        notfound_path.write_text("\n".join(not_found), encoding="utf-8")

    print()
    print(f"Matched {len(favourites)}/{len(tracks)} tracks.")
    print(f"Backup file written to: {output_path}")
    if not_found:
        print(f"{len(not_found)} unmatched tracks written to: {notfound_path}")


if __name__ == "__main__":
    main()
