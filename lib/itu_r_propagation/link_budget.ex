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

  ## Returns

  A map with the following keys:

    * `:total_db` - Total atmospheric attenuation in dB
    * `:gaseous_db` - Gaseous attenuation (P.676) in dB
    * `:rain_db` - Rain attenuation (P.618) in dB
    * `:cloud_db` - Cloud attenuation in dB
    * `:scintillation_db` - Scintillation in dB

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
      iex> result.rain_db > result.gaseous_db
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

    # Gaseous attenuation from P.676
    gaseous_db = P676.slant_path_attenuation(f, el, rho)

    # Rain attenuation from P.618
    rain_db =
      P618.rain_attenuation(f, el, lat, rain_rate,
        station_altitude_km: hs,
        polarization: pol,
        time_percentage: p,
        longitude_deg: lon
      )

    # Simplified cloud attenuation
    cloud_db = cloud_attenuation(f, el, cloud_lw)

    # Simplified scintillation
    scintillation_db = scintillation_attenuation(f, el)

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
  Simplified cloud attenuation model.

  Based on concepts from ITU-R P.840. Cloud attenuation is proportional
  to frequency squared (Rayleigh regime) and to the integrated cloud
  liquid water content along the path.

  ## Parameters

    * `frequency_ghz` - Frequency in GHz
    * `elevation_deg` - Elevation angle in degrees
    * `cloud_liquid_water` - Integrated liquid water content in kg/m^2
      (default: 0.3, typical for moderate cloud cover)

  ## Returns

  Cloud attenuation in dB.
  """
  @spec cloud_attenuation(float(), float(), float()) :: float()
  def cloud_attenuation(frequency_ghz, elevation_deg, cloud_liquid_water \\ 0.3) do
    if elevation_deg <= 0.0 do
      0.0
    else
      # Specific cloud attenuation coefficient (dB/km per g/m^3)
      # Approximate Rayleigh absorption: K_l ~ 0.819 * f / (eps'' * (1 + eta^2))
      # Simplified: K_l proportional to f^2 at low frequencies, saturating higher
      f = frequency_ghz

      # Cloud mass absorption coefficient (dB per kg/m^2)
      # Approximate values from P.840 at 0 degrees C:
      #   K_l ~ 0.0122 at 10 GHz, scaling roughly as f^1.8
      k_l =
        if f <= 50.0 do
          0.0122 * :math.pow(f / 10.0, 1.8)
        else
          0.0122 * :math.pow(50.0 / 10.0, 1.8) * (f / 50.0)
        end

      el_rad = elevation_deg * :math.pi() / 180.0
      k_l * cloud_liquid_water / :math.sin(el_rad)
    end
  end

  @doc """
  Simplified tropospheric scintillation attenuation estimate.

  Provides a rough estimate of scintillation fade depth. At frequencies
  below about 10 GHz and elevation angles above 10 degrees, scintillation
  is generally small (< 0.5 dB).

  For detailed scintillation calculations, refer to the full ITU-R P.618
  procedure which requires temperature, humidity, and antenna diameter
  as additional inputs.

  ## Parameters

    * `frequency_ghz` - Frequency in GHz
    * `elevation_deg` - Elevation angle in degrees

  ## Returns

  Estimated scintillation fade in dB (for approximately 0.01% of the time).
  """
  @spec scintillation_attenuation(float(), float()) :: float()
  def scintillation_attenuation(frequency_ghz, elevation_deg) do
    if elevation_deg <= 0.0 do
      0.0
    else
      f = frequency_ghz
      el_rad = elevation_deg * :math.pi() / 180.0

      # Simplified scintillation model
      # sigma_ref ~ 0.02 * f^0.45 at mid-latitudes for a 1.2m antenna
      # Fade depth for p=0.01% ~ 2.7 * sigma
      # Total scales with 1/sin(el)^1.2
      sigma_ref = 0.02 * :math.pow(f, 0.45)
      fade_factor = 2.7

      fade_factor * sigma_ref / :math.pow(:math.sin(el_rad), 1.2)
    end
  end
end
