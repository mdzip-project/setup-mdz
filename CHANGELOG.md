# Changelog

## [1.0.0] - 2026-11-12

### Added
- Installs a pinned or the latest `mdz` CLI release on Linux, macOS and Windows runners (x64 and Arm64), adds it to `PATH`, and outputs its version and folder ([mdzip-project/.github#3](https://github.com/mdzip-project/.github/issues/3)).
- Checks each download against the SHA-256 digest GitHub records for the release asset.
- Reuses an installed copy in the runner's tool cache.
