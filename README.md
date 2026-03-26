# ITU-R Propagation

[![Build & Test](https://github.com/neilberkman/itu_r_propagation/actions/workflows/ci.yml/badge.svg)](https://github.com/neilberkman/itu_r_propagation/actions/workflows/ci.yml)
[![Hex.pm](https://img.shields.io/hexpm/v/itu_r_propagation.svg)](https://hex.pm/packages/itu_r_propagation)

Pure Elixir implementation of ITU-R atmospheric propagation models for satellite link budget calculations.

## What are ITU-R recommendations?

The [International Telecommunication Union - Radiocommunication Sector (ITU-R)](https://www.itu.int/en/ITU-R/) publishes recommendations that serve as international standards for radio communication systems. The P-series recommendations cover radiowave propagation and are essential for designing reliable satellite communication links.

This library implements the following recommendations:

| Recommendation | Title | Implementation |
|---|---|---|
| [P.676](https://www.itu.int/rec/R-REC-P.676/en) | Attenuation by atmospheric gases | Simplified Annex 2 model (1-350 GHz) |
| [P.838](https://www.itu.int/rec/R-REC-P.838/en) | Specific attenuation model for rain | Full regression coefficients from P.838-3 (1-1000 GHz) |
| [P.618](https://www.itu.int/rec/R-REC-P.618/en) | Earth-space propagation | Full step-by-step procedure from P.618-13 |
| [P.839](https://www.itu.int/rec/R-REC-P.839/en) | Rain height model | 1-degree gridded data from P.839-4 with bilinear interpolation |

## Installation

Add `itu_r_propagation` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:itu_r_propagation, "~> 0.1.0"}
  ]
end
```

## Usage

### Total atmospheric attenuation

For link budget calculations, use the combined model:

```elixir
result = ItuRPropagation.total_atmospheric_attenuation(
  frequency_ghz: 12.0,
  elevation_deg: 30.0,
  latitude_deg: 40.0,
  longitude_deg: -100.0,
  rain_rate_mmh: 25.0
)

# result = %{
#   total_db: ...,
#   gaseous_db: ...,
#   rain_db: ...,
#   cloud_db: ...,
#   scintillation_db: ...
# }
```

### Individual models

```elixir
# P.838: Specific rain attenuation (dB/km)
gamma = ItuRPropagation.P838.specific_attenuation(12.0, 25.0, :circular, 30.0)

# P.839: Rain height (km)
h_r = ItuRPropagation.P839.rain_height(40.0, -100.0)

# P.618: Slant-path rain attenuation (dB)
a_rain = ItuRPropagation.P618.rain_attenuation(12.0, 30.0, 40.0, 25.0,
  longitude_deg: -100.0, polarization: :circular)

# P.676: Gaseous attenuation (dB)
a_gas = ItuRPropagation.P676.slant_path_attenuation(12.0, 30.0)
```

### Polarization

Supports horizontal, vertical, and circular polarization per ITU-R P.838-3. The combined coefficient formula correctly accounts for elevation angle:

```elixir
gamma_h = ItuRPropagation.P838.specific_attenuation(12.0, 25.0, :horizontal, 30.0)
gamma_v = ItuRPropagation.P838.specific_attenuation(12.0, 25.0, :vertical, 30.0)
gamma_c = ItuRPropagation.P838.specific_attenuation(12.0, 25.0, :circular, 30.0)
```

## Validation

P.838 and P.618 are validated against the [Python itur library](https://github.com/inigodelportillo/ITU-Rpy) (v0.4.0). P.838 coefficients match to 6 significant figures. P.618 rain attenuation matches the ITU-R P.618-13 step-by-step procedure to within 0.01%.

Run the Python parity tests (requires `itur` installed):

```
mix test --include python_parity
```

## Frequency ranges

| Band | Frequency | Rain effect | Primary concern |
|------|-----------|-------------|-----------------|
| L-band | 1-2 GHz | Negligible (< 0.01 dB) | Gaseous absorption, scintillation |
| S-band | 2-4 GHz | Very small | Gaseous absorption |
| C-band | 4-8 GHz | Small | Rain begins to matter |
| Ku-band | 12-18 GHz | Significant (1-10 dB) | Rain attenuation |
| Ka-band | 26-40 GHz | Dominant (5-30 dB) | Rain attenuation |

## Limitations

- **P.676**: Simplified Annex 2 model, not the line-by-line Annex 1 summation. Accuracy is reduced near strong absorption lines (22 GHz water vapor, 60 GHz oxygen).
- **Cloud/scintillation**: Simplified empirical models. For detailed modeling, refer to ITU-R P.840 (clouds) and P.618 Section 2.4 (scintillation).
- **P.839 grid**: 1-degree resolution. The full ITU-R P.839-4 dataset has finer resolution in some regions.

## License

MIT License. See [LICENSE](LICENSE) for details.
