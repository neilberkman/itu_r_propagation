defmodule ItuRPropagation.LinkBudget do
  @moduledoc """
  Combined atmospheric attenuation model for satellite link budgets.

  Aggregates all atmospheric propagation effects into a single total
  attenuation value with a component-by-component breakdown. This is the
  module that link budget calculators typically call.

  The total atmospheric attenuation is the sum of:

    * **Gaseous attenuation** (ITU-R P.676) - Oxygen and water vapor absorption,
      always present, dominant below 10 GHz
    * **Rain attenuation** (ITU-R P.618) - Dominant effect above 10 GHz for
      the specified exceedance probability
    * **Cloud attenuation** - Simplified model based on integrated liquid water
      content (from ITU-R P.840 concepts)
    * **Tropospheric scintillation** - Simplified model for amplitude
      fluctuations (from ITU-R P.618 concepts)

  Note: The cloud and scintillation models implemented here are simplified
  approximations. For detailed cloud attenuation calculations, refer to
  ITU-R P.840. For detailed scintillation calculations, refer to the full
  ITU-R P.618 procedure.
  """

  alias ItuRPropagation.P618
  alias ItuRPropagation.P676
  alias ItuRPropagation.P840

  @type attenuation_result :: %{
          total_db: float(),
          gaseous_db: float(),
          rain_db: float(),
          cloud_db: float(),
          scintillation_db: float()
        }

  @doc """
  Compute total atmospheric attenuation for a satellite link.

  Combines gaseous, rain, cloud, and scintillation attenuation into a
  single result with per-component breakdown.

  ## Options

    * `:frequency_ghz` - Frequency in GHz (required)
    * `:elevation_deg` - Elevation angle in degrees (required)
    * `:latitude_deg` - Earth station latitude in degrees (required)
    * `:longitude_deg` - Earth station longitude in degrees (required)
    * `:rain_rate_mmh` - Rain rate in mm/h (required)
    * `:station_altitude_km` - Station altitude above MSL in km (default: 0.0)
    * `:water_vapor_density` - Water vapor density in g/m^3 (default: 7.5)
    * `:polarization` - `:horizontal`, `:vertical`, or `:circular` (default: `:circular`)
    * `:cloud_liquid_water` - Integrated cloud liquid water in kg/m^2 (default: 0.3)
    * `:time_percentage` - Exceedance time percentage (default: 0.01)
    * `:antenna_diameter_m` - Antenna diameter in meters (default: 1.2, for scintillation)
    * `:antenna_efficiency` - Antenna efficiency (default: 0.5, for scintillation)
    * `:temperature_c` - Average surface temperature in degrees Celsius (default: 15.0)
    * `:relative_humidity` - Average relative humidity in % (default: 75.0)

  ## Returns

  A map with the following keys:

    * `:total_db` - Total atmospheric attenuation in dB
    * `:gaseous_db` - Gaseous attenuation (P.676) in dB
    * `:rain_db` - Rain attenuation (P.618) in dB
    * `:cloud_db` - Cloud attenuation (P.840) in dB
    * `:scintillation_db` - Scintillation (P.618) in dB

  ## Examples

      iex> result = ItuRPropagation.LinkBudget.total_atmospheric_attenuation(
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
    f = Keyword.fetch!(opts, :frequency_ghz)
    el = Keyword.fetch!(opts, :elevation_deg)
    lat = Keyword.fetch!(opts, :latitude_deg)
    lon = Keyword.fetch!(opts, :longitude_deg)
    rain_rate = Keyword.fetch!(opts, :rain_rate_mmh)
    hs = Keyword.get(opts, :station_altitude_km, 0.0)
    rho = Keyword.get(opts, :water_vapor_density, 7.5)
    pol = Keyword.get(opts, :polarization, :circular)
    cloud_lw = Keyword.get(opts, :cloud_liquid_water, 0.3)
    p = Keyword.get(opts, :time_percentage, 0.01)
    temp_c = Keyword.get(opts, :temperature_c, 15.0)
    rel_h = Keyword.get(opts, :relative_humidity, 75.0)
    ant_d = Keyword.get(opts, :antenna_diameter_m, 1.2)
    ant_eta = Keyword.get(opts, :antenna_efficiency, 0.5)

    # Gaseous attenuation from P.676
    gaseous_db = P676.slant_path_attenuation(f, el, rho, 1013.25, temp_c)

    # Rain attenuation from P.618
    rain_db =
      P618.rain_attenuation(f, el, lat, rain_rate,
        station_altitude_km: hs,
        polarization: pol,
        time_percentage: p,
        longitude_deg: lon
      )

    # Cloud attenuation from P.840
    cloud_db = P840.cloud_attenuation(f, el, cloud_lw, temp_c)

    # Scintillation from P.618
    scintillation_db =
      P618.scintillation_attenuation(f, el, p,
        antenna_diameter_m: ant_d,
        antenna_efficiency: ant_eta,
        temperature_c: temp_c,
        relative_humidity: rel_h
      )

    # Total attenuation is the sum of the components
    # Note: ITU-R P.618 Section 2.5 recommends a more complex combination
    # of rain and gaseous/cloud/scintillation for detailed budgets.
    # Here we use the simple sum as a first-order approximation.
    total_db = gaseous_db + rain_db + cloud_db + scintillation_db

    %{
      total_db: total_db,
      gaseous_db: gaseous_db,
      rain_db: rain_db,
      cloud_db: cloud_db,
      scintillation_db: scintillation_db
    }
  end

  @doc """
  Compute cloud attenuation using ITU-R P.840.
  """
  defdelegate cloud_attenuation(f, el, cloud_lw, temp_c \\ 0.0), to: P840, as: :cloud_attenuation

  @doc """
  Compute scintillation attenuation using ITU-R P.618.
  """
  defdelegate scintillation_attenuation(f, el, p, opts \\ []),
    to: P618,
    as: :scintillation_attenuation
end
