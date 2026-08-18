<p align="center">
  <img src="docs/app-icon.png" width="160" height="160" alt="showPirate app icon">
</p>

<h1 align="center">showPirate</h1>

<p align="center"><em>Navigate your favorite shows.</em></p>

Native macOS TV tracker built with SwiftUI, SwiftData, and the [TMDB](https://www.themoviedb.org) API. Keep a library of series, mark episodes watched, and see what airs next.

![Library](docs/screenshots/library-light.png)

## Features

- **Dashboard** — continue watching, upcoming episodes, recently aired
- **Library** — grid or list view with filters and sorting
- **Search** — find shows on TMDB and add them to your catalog
- **Calendar** — month view with episodes per day
- **Statistics** — watch time, progress, and favorite genres
- **Settings** — appearance, TMDB API key, catalog refresh, folder sync

## Requirements

- Mac with Apple Silicon or Intel
- macOS 14 Sonoma or later

## Download

Download the latest release from [GitHub Releases](https://github.com/starwash/showPirate/releases).

The zip is a universal app (Apple Silicon and Intel). It is not notarized, so after unzipping: right-click `showPirate.app` and choose **Open** the first time.

## First launch

The app asks for a TMDB **API Key (v3)** before the library opens. The key is checked with TMDB, stored only on that Mac, and is not bundled with the download.

1. Get a free key at [themoviedb.org/settings/api](https://www.themoviedb.org/settings/api)
2. Paste it on the setup screen and click **Continue**
3. Go to **Search** and add shows, or connect a sync folder if you already have a catalog on another Mac

You can change the key later in **Settings**.

## Sync between Macs

CloudKit is not used. In **Settings → Sync folder**, pick a shared folder (Dropbox, iCloud Drive, or Syncthing). Both Macs use the same folder. The app writes `showPirate-library.json` there.

Local edits save within about a second. Incoming changes are checked every few seconds. Use **Sync Now** if iCloud has not delivered the file yet. If both Macs edit at once, the last save wins.

The TMDB API key is not synced. Enter it once on each Mac.

## Build from source

Requirements: Xcode 16

```bash
git clone https://github.com/starwash/showPirate.git
cd showPirate
open ShowPirate.xcodeproj
```

Select the **showPirate** scheme and press Run.

## Architecture

SwiftUI + MVVM. Views render; view models and `LibraryStore` mutate data; `TMDBService` talks to the network with async/await. Persistence is SwiftData (`Show`, `Season`, `Episode`, `Genre`). Folder sync is a JSON catalog file, not iCloud CloudKit.

Sidebar: Dashboard, Library, Search, Calendar, Statistics, Settings.

## Attribution

This product uses the TMDB API but is not endorsed or certified by TMDB. Poster and still images are provided by TMDB.
