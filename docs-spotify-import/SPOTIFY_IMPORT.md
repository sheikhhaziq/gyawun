# Importing a Spotify Playlist into Gyawun Music (Android)

Gyawun streams from YouTube Music and has no direct Spotify connection, so
there's no built-in "Connect Spotify" button. This guide walks through a
one-time workaround: export your Spotify playlist, match it against YouTube
Music, and bulk-import the result into your **Favourites** using Gyawun's
existing Backup & Restore feature.

This uses a small helper script at [`tool/spotify_import`](../tool/spotify_import),
run once on a computer. It does **not** require modifying the app or your
phone in any special way — you're just generating a JSON file the app
already knows how to read.

**Estimated time:** 10-20 minutes for a large playlist (500+ songs), mostly
unattended.

---

## Overview

1. Export your Spotify playlist to a file (on any computer, via a website)
2. Run the import script (on the same computer) — it searches YouTube Music
   for each track and builds a `Backup & Restore` JSON file
3. Move that JSON file to your Android phone
4. Restore it inside Gyawun Music

---

## Step 1 — Export your Spotify playlist

The easiest way, no Spotify developer account needed:

1. On a computer, go to **[exportify.net](https://exportify.net)** 
or **[Tune My Music](https://www.tunemymusic.com/)**
or **[Sound Biz](https://soundiiz.com/)**
2. Log in with your Spotify account (Exportify only reads your playlists —
   it doesn't modify anything)
3. Find the playlist you want to import, click to export it
4. You'll get a `.csv` file (e.g. `Liked Songs.csv`) — save it somewhere
   you'll remember

*(Alternative: if you already have a plain list of songs, save it as a
`.txt` file with one song per line, formatted as `Artist - Title`. The
script supports both formats.)*

---

## Step 2 — Set up Python (one-time)

You need Python on the same computer:

- **Windows:** install from [python.org/downloads](https://python.org/downloads).
  Check **"Add Python to PATH"** during setup.
- **Mac:** usually preinstalled — check with `python3 --version` in Terminal.
- **Linux:** almost certainly already installed.

---

## Step 3 — Get the script and install its one dependency

If you've cloned the Gyawun repo, the script is at `tool/spotify_import/`.
Otherwise, download `import_spotify_to_gyawun.py` and `requirements.txt`
from that folder in the repo.

Open a terminal in that folder and run:

```bash
pip install -r requirements.txt
```

---

## Step 4 — Run the import

```bash
python import_spotify_to_gyawun.py "Liked Songs.csv" gyawun_favourites_backup.json
```

Replace `"Liked Songs.csv"` with your exported file (use the `.txt` file
instead if that's what you have). The second argument is just the name
you want the output file to have.

You'll see one line printed per track as it's matched:

```
[1/620] OK  PALMITO - La Cuarta Estrella  ->  PALMITO - La Cuarta Estrella
[2/620] OK  Mariah Carey - Fantasy  ->  Mariah Carey - Fantasy
[3/620] MISS  Some Obscure Local Release
```

When it finishes, you'll have `gyawun_favourites_backup.json` in that
folder. Tracks it couldn't confidently match are listed in a companion
`gyawun_favourites_backup.json.notfound.txt` file — worth a quick manual
check afterward, since matching is by search, not exact ID.

> Large playlists take a while — the script deliberately paces its
> requests to avoid hammering YouTube Music's search.

---

## Step 5 — Move the JSON file to your Android phone

Any of these work:

- Email it to yourself and open the attachment on your phone
- Upload to Google Drive / Dropbox, then open the Drive/Dropbox app on your phone
- Plug the phone into the computer via USB and copy the file over
- Use `adb push gyawun_favourites_backup.json /sdcard/Download/` if you
  have `adb` set up

Either way, make sure it ends up somewhere your phone's file picker can
browse to (Downloads folder is simplest).

---

## Step 6 — Restore it in Gyawun Music

1. Open Gyawun Music on your phone
2. Go to **Settings → Backup and Restore**
3. Tap **Restore**
4. Browse to and select `gyawun_favourites_backup.json`
5. Matched tracks will appear in your **Favourites**

---

## Optional — Download everything for offline listening

Once restored, you can queue every song for offline download in one action:

1. Open your **Favourites** page
2. Tap the **⋮ (more)** icon near the top
3. Tap **Download**

This queues the whole list, not one song at a time. Do this on Wi-Fi if
your playlist is large — it adds up in storage and data.

---

## Troubleshooting

| Problem | Likely cause |
|---|---|
| Lots of `MISS` results | Track names with unusual formatting, regional/local releases not on YouTube Music, or a network hiccup — try re-running just the `.notfound.txt` entries |
| Wrong song matched | Search-based matching isn't perfect for common titles/remixes — check `.notfound.txt`-adjacent mismatches manually and re-add via in-app search if needed |
| Restore does nothing / errors | Confirm the JSON file wasn't modified/corrupted in transit (re-copy it), and that you're picking the `.json` file, not the `.csv`/`.txt` source |
