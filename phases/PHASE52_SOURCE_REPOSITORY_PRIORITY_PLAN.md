# Phase 52 — Source Repository Audit & VOD Priority Lanes

**Date:** 2026-11-09  
**Base:** `RAVEN23-LIVE-TV-SETUP-FIX1` (successful 4.3.1+11 working baseline)  
**Target package version:** `4.4.0+12`

## Objective

Audit the six bundled source indexes and their relevant provider scripts, then introduce three independent VOD search-priority lanes:

- Movies: English or explicitly multilingual (`en`, `eng`, `English`, `Multi`) only.
- Series: English or explicitly multilingual only.
- Anime: English/multilingual plus Japanese and Chinese declarations.

The policy must not promote Live TV adapters into VOD, must respect each source's declared media capabilities, and must not treat a repository index declaration as proof of live availability or actual audio language.

## Search order

For a movie, series episode, or anime episode:

1. Try the user's ordered priority list for that media category.
2. Only if that tier returns no direct playable stream, try all remaining installed and eligible direct providers for the same category as backups.
3. Only if direct providers still return no stream, try embedded/WebView fallback providers.

A provider that declares more than one content type may appear in more than one lane. Each lane is evaluated independently. Removing a provider from a priority list demotes it to backup; it does not uninstall or delete it. An empty priority list means all eligible direct providers are backups; it does not revert to the legacy order.

## User controls

The Source Repositories screen contains a `REPOSITORIES` section with Movies, Series, and Anime tabs. The user can:

- review the ordered priority list and upstream status label;
- move a provider up or down;
- remove it from priority (keep installed as backup);
- add an eligible installed or catalogued provider, installing it as needed;
- configure up to 15 providers in each category.

Automatic activation and later manual additions are separately bounded to no more than 15 unique active providers per repository index. The per-category list limit is also 15. The series lane is intentionally allowed to contain fewer than 10 when the audited repositories do not declare enough eligible series providers; the list must not be padded with movie-only, wrong-language, adult, torrent-only, or unsupported sources.

## Evidence and caveats

The current six indexes contain 142 discovery records before global duplicate analysis. The Phase52 ranking uses current index metadata plus targeted source-script inspection. Upstream status `1` is only the repository's declared status, `3` means Beta, and a missing status is shown as `Unrated`. These values are not uptime measurements. A source is not labelled Playback Verified until it is tested against a real title and playback succeeds on a device.

`Multi` is treated as a provider-declared multilingual capability. It does not guarantee that every returned stream has English audio; the player's actual track metadata remains authoritative. Sources whose current script disagrees with the index language are excluded. Magnet/torrent-only providers are excluded because RAVEN23 currently maps HTTP(S) media URLs and has no torrent playback engine.

## Initial curated lane sizes

- Movies: 15.
- Series: 9 (all currently eligible candidates found in the reviewed indexes; do not invent a tenth provider).
- Anime: 15.

Within the backup tier, explicitly declared upstream lifecycle status is used as a conservative sort hint (Listed OK, Slow, Beta, then Unrated), followed by the existing engine priority/observed-health order. The user may change each list after installation. An upstream index refresh does not overwrite a previously initialized user's manual ordering.
