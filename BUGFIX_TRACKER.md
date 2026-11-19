# QuietCue — Bugfix Tracker

Lightweight log of regressions and fixes. Updated by `/bugfix` when a bug is diagnosed and shipped.

**Workflow:** `/bugfix` analyzes root cause, finds the introducing commit, implements the fix, appends a row here, and commits both together.

---

## Fixed

| # | Bug | Reported | Introduced | Introducing commit | Fixed | Fix commit | Notes |
|---|-----|----------|------------|-------------------|-------|------------|-------|
| 1 | Volume ducks without microphone when starting media | 2026-11-19 | 2026-11-14 | `ec94afa` Add English UI, volume ducking… | 2026-11-19 | (this commit) | `MediaRemoteUIService` false input on play; filter Now Playing playback; safer duck/preview handoff. |

---

## Changelog

| Date | Change |
|------|--------|
| 2026-11-19 | Created bugfix tracker. |
| 2026-11-19 | Fixed bug #1: Volume ducks without microphone when starting media. |