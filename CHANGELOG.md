# Changelog

All notable changes to this project will be documented in this file.

## [1.0.2] - 2026-11-24

### Changed
- Picks up game-common 1.18.0: a status line cut off with "…" opens in full
  when tapped, so a long hint can be read.

## [1.0.1] - 2026-11-18

### Changed
- Picks up game-common 1.17.0 (a board redraw fix used by chess, binairo and
  tatami; no change in this game).

## [1.0.0] - 2026-11-10

### Added
- First release: a cooperative game for two players with a reader each.
  Both readers show a grid of symbols built from the same game code; the
  grids differ in a few cells, and the players find them by describing
  their grids aloud. Each reader checks the taps of its own player.
- Easy 5×5 (4 differences, filled shapes only), Medium 6×6 (6), Hard 7×7
  (8 look-alike differences); mistakes counted, Show the differences,
  auto-save.
