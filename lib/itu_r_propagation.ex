defmodule ItuRPropagation do
  @moduledoc """
  Pure Elixir implementation of ITU-R atmospheric propagation models for
  satellite link budget calculations.

  This library implements the following ITU-R P-series recommendations:

  - **P.676** - Gaseous attenuation (oxygen and water vapor absorption)
  - **P.838** - Specific rain attenuation (power-law coefficients)
  - **P.618** - Earth-space path rain attenuation
  - **P.839** - Rain height model

  These models are the international standard for predicting atmospheric
  propagation effects on satellite communication links.

  ## Quick Start

  For most link budget calculations, use `total_atmospheric_attenuation/2`:

      ItuRPropagation.total_atmospheric_attenuation(
        frequency_ghz: 12.0,
        elevation_deg: 30.0,
        latitude_deg: 40.0,
        longitude_deg: -100.0,
        rain_rate_mmh: 25.0
      )

  This returns the total atmospheric attenuation in dB along with a breakdown
  by component (gaseous, rain, cloud, scintillation).

  ## Individual Models

  Each ITU-R recommendation is also available as a standalone module:

  - `ItuRPropagation.P676` - Gaseous attenuation
  - `ItuRPropagation.P838` - Specific rain attenuation coefficients
  - `ItuRPropagation.P618` - Earth-space rain attenuation
  - `ItuRPropagation.P839` - Rain height model
  - `ItuRPropagation.LinkBudget` - Combined atmospheric model
  """

  alias ItuRPropagation.LinkBudget

  @type attenuation_result :: %{
          total_db: float(),
          gaseous_db: float(),
          rain_db: float(),
          cloud_db: float(),
          scintillation_db: float()
        }

  @doc """
  Compute total atmospheric attenuation for a satellite link.

  This is the primary entry point for link budget calculations. It combines
  gaseous attenuation (P.676), rain attenuation (P.618), and simplified
  cloud and scintillation models.

  ## Options

    * `:frequency_ghz` - Frequency in GHz (required)
    * `:elevation_deg` - Elevation angle in degrees (required)
    * `:latitude_deg` - Earth station latitude in degrees (required)
    * `:longitude_deg` - Earth station longitude in degrees (required)
    * `:rain_rate_mmh` - Rain rate in mm/h for the desired exceedance
      probability (required)
    * `:station_altitude_km` - Earth station altitude above mean sea level
      in km (default: 0.0)
    * `:water_vapor_density` - Water vapor density in g/m^3 (default: 7.5)
    * `:polarization` - Polarization type: `:horizontal`, `:vertical`, or
      `:circular` (default: `:circular`)
    * `:cloud_liquid_water` - Integrated cloud liquid water content in
      kg/m^2 (default: 0.3)

  ## Returns

  A map with the following keys:

    * `:total_db` - Total atmospheric attenuation in dB
    * `:gaseous_db` - Gaseous attenuation component in dB
    * `:rain_db` - Rain attenuation component in dB
    * `:cloud_db` - Cloud attenuation component in dB
    * `:scintillation_db` - Scintillation component in dB

  ## Examples

      iex> result = ItuRPropagation.total_atmospheric_attenuation(
      ...>   frequency_ghz: 12.0,
      ...>   elevation_deg: 30.0,
      ...>   latitude_deg: 40.0,
      ...>   longitude_deg: -100.0,
      ...>   rain_rate_mmh: 25.0
      ...> )
      iex> result.total_db > 0.0
      true

  """
  @spec total_atmospheric_attenuation(keyword()) :: attenuation_result()
  def total_atmospheric_attenuation(opts) do
    LinkBudget.total_atmospheric_attenuation(opts)
  end
end
