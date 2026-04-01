# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.6.0] - 2026-04-01

### Added
- **ITU-R P.840-7**: Implementation of the Double-Debye model for cloud and fog attenuation.
- **ITU-R P.618-13**: Full implementation of the tropospheric scintillation prediction method (Section 2.4).
- **Parity Tests**: Comprehensive cross-validation tests against the Python `itur` reference library.

### Changed
- **ITU-R P.676-13**: Significantly improved Annex 2 simplified model with Van Vleck-Weisskopf line shapes for key absorption lines (22 GHz, 183 GHz, 325 GHz).
- **ITU-R P.618**: Updated `rain_attenuation` call signature to use keyword options for `station_altitude_km`.
- **Link Budget**: Integrated cloud and scintillation components into the total atmospheric attenuation model.

### Fixed
- Addressed trailing whitespace and formatting issues across the codebase.
- Fixed unreachable pattern matches in parity tests.
- Resolved compilation warnings.
