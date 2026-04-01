defmodule ItuRPropagation.P618 do
  @moduledoc """
  ITU-R P.618: Propagation data and prediction methods required for the
  design of Earth-space telecommunication systems.

  Implements the step-by-step procedure for computing rain attenuation along
  an Earth-space slant path. This is the primary model used for satellite
  link budget rain margin calculations.

  The procedure uses:

    * ITU-R P.839 for rain height
    * ITU-R P.838 for specific rain attenuation coefficients
    * Horizontal and vertical reduction factors to account for the
      non-uniform spatial distribution of rain

  ## Reference

  ITU-R P.618-13: Propagation data and prediction methods required for the
  design of Earth-space telecommunication systems.
  https://www.itu.int/rec/R-REC-P.618/en
  """

  alias ItuRPropagation.P838
  alias ItuRPropagation.P839

  @doc """
  Compute rain attenuation along an Earth-space slant path.

  Implements the step-by-step method from ITU-R P.618-13, Section 2.2.1.1.
  This computes the rain attenuation exceeded for 0.01% of an average year,
  then scales to the requested time percentage.

  ## Parameters

    * `frequency_ghz` - Frequency in GHz
    * `elevation_deg` - Elevation angle in degrees (> 0)
    * `latitude_deg` - Earth station latitude in degrees
    * `rain_rate_mmh` - Rain rate exceeded for 0.01% of an average year (mm/h).
      If computing for a different time percentage, provide the 0.01% value
      and use the `:time_percentage` option.
    * `opts` - Options keyword list:
      - `:station_altitude_km` - Station altitude above MSL in km (default: 0.0)
      - `:polarization` - `:horizontal`, `:vertical`, or `:circular` (default: `:circular`)
      - `:time_percentage` - Time percentage for which attenuation is exceeded
        (default: 0.01, valid range: 0.001 to 5.0)
      - `:longitude_deg` - Longitude in degrees, passed to P.839 (default: 0.0)

  ## Returns

  Rain attenuation in dB exceeded for the given time percentage.

  ## Examples

      iex> a_rain = ItuRPropagation.P618.rain_attenuation(12.0, 30.0, 40.0, 25.0)
      iex> a_rain > 1.0
      true

      iex> a_rain = ItuRPropagation.P618.rain_attenuation(1.66, 30.0, 40.0, 10.0)
      iex> a_rain < 0.5
      true

  """
  @spec rain_attenuation(float(), float(), float(), float(), keyword()) :: float()
  def rain_attenuation(frequency_ghz, elevation_deg, latitude_deg, rain_rate_mmh, opts \\ []) do
    hs = Keyword.get(opts, :station_altitude_km, 0.0)
    polarization = Keyword.get(opts, :polarization, :circular)
    p = Keyword.get(opts, :time_percentage, 0.01)
    lon = Keyword.get(opts, :longitude_deg, 0.0)

    # Guard: no rain, no attenuation
    if rain_rate_mmh <= 0.0 do
      0.0
    else
      compute_rain_attenuation(
        frequency_ghz,
        elevation_deg,
        latitude_deg,
        rain_rate_mmh,
        hs,
        polarization,
        p,
        lon
      )
    end
  end

  @spec compute_rain_attenuation(
          float(),
          float(),
          float(),
          float(),
          float(),
          P838.polarization(),
          float(),
          float()
        ) :: float()
  defp compute_rain_attenuation(f, el, lat, r001, hs, polarization, p, lon) do
    re = 8500.0

    # Step 1: Rain height from P.839
    hr = P839.rain_height(lat, lon)

    # If rain height is below or equal to station altitude, no rain attenuation
    if hr <= hs do
      0.0
    else
      # Step 2: Slant path length (km)
      el_rad = el * :math.pi() / 180.0

      ls =
        if el >= 5.0 do
          # Eq. 1: Simple geometry for el >= 5 degrees
          (hr - hs) / :math.sin(el_rad)
        else
          # Eq. 2: Earth curvature correction for low elevation
          sin_el = :math.sin(el_rad)

          2.0 * (hr - hs) /
            (:math.sqrt(sin_el * sin_el + 2.0 * (hr - hs) / re) + sin_el)
        end

      # Step 3: Horizontal projection
      lg = abs(ls * :math.cos(el_rad))

      # Step 5: Specific attenuation from P.838
      gamma_r = P838.specific_attenuation(f, r001, polarization, el)

      # Step 6: Horizontal reduction factor r_0.01
      r001_factor =
        if lg * gamma_r > 0.0 do
          1.0 /
            (1.0 + 0.78 * :math.sqrt(lg * gamma_r / f) -
               0.38 * (1.0 - :math.exp(-2.0 * lg)))
        else
          1.0
        end

      # Step 7: Vertical adjustment factor v_0.01
      eta_rad = :math.atan2(hr - hs, lg * r001_factor)
      eta = eta_rad * 180.0 / :math.pi()

      lr =
        if eta > el do
          lg * r001_factor / :math.cos(el_rad)
        else
          (hr - hs) / :math.sin(el_rad)
        end

      xi =
        if abs(lat) < 36.0 do
          36.0 - abs(lat)
        else
          0.0
        end

      el_term = max(el, 1.0)

      v001_denom =
        1.0 +
          :math.sqrt(:math.sin(el_rad)) *
            (31.0 * (1.0 - :math.exp(-el_term / (1.0 + xi))) *
               :math.sqrt(lr * gamma_r) / (f * f) - 0.45)

      v001 = 1.0 / max(v001_denom, 0.01)

      # Step 8: Effective path length
      le = lr * v001

      # Step 9: Predicted attenuation for 0.01% of the time
      a001 = gamma_r * le

      # Step 10: Scale to requested time percentage
      if abs(p - 0.01) < 1.0e-10 do
        max(a001, 0.0)
      else
        scale_attenuation(a001, p, lat, el)
      end
    end
  end

  @doc """
  Compute tropospheric scintillation attenuation.

  Implements the step-by-step method from ITU-R P.618-13, Section 2.4.
  Calculates the scintillation fade depth exceeded for a given time percentage.

  ## Parameters

    * `frequency_ghz` - Frequency in GHz (up to 20 GHz for the model validity,
      but often used higher)
    * `elevation_deg` - Elevation angle in degrees (> 5.0)
    * `p` - Time percentage (0.01 to 50)
    * `opts` - Options:
      - `:antenna_diameter_m` - Antenna diameter in meters (default: 1.2)
      - `:antenna_efficiency` - Antenna efficiency (default: 0.5)
      - `:temperature_c` - Average surface temperature in degrees Celsius (default: 15.0)
      - `:relative_humidity` - Average relative humidity in % (default: 75.0)
      - `:n_wet` - Wet term of surface refractivity (if known)

  ## Returns

  Scintillation fade depth in dB.
  """
  @spec scintillation_attenuation(float(), float(), float(), keyword()) :: float()
  def scintillation_attenuation(frequency_ghz, elevation_deg, p, opts \\ []) do
    if elevation_deg < 5.0 do
      # Model validity is for elevation >= 5 degrees
      # For very low elevation, return 0 or a very simplified value
      0.0
    else
      f = frequency_ghz
      theta = elevation_deg
      theta_rad = theta * :math.pi() / 180.0
      d = Keyword.get(opts, :antenna_diameter_m, 1.2)
      eta = Keyword.get(opts, :antenna_efficiency, 0.5)

      # Step 1-2: Wet term of surface refractivity N_wet
      n_wet =
        case Keyword.get(opts, :n_wet) do
          nil ->
            t_c = Keyword.get(opts, :temperature_c, 15.0)
            h = Keyword.get(opts, :relative_humidity, 75.0)
            calculate_n_wet(t_c, h)

          val ->
            val
        end

      # Step 3: Standard deviation of signal amplitude sigma_ref
      sigma_ref = 3.6e-3 + 1.0e-4 * n_wet

      # Step 4: Effective antenna diameter d_eff
      d_eff = :math.sqrt(eta) * d

      # Step 5: Antenna gain factor g(x)
      # L = slant path length to height h = 1000m
      h = 1000.0
      # Earth radius in meters
      re = 6371.0 * 1000.0
      sin_theta = :math.sin(theta_rad)
      l = 2.0 * h / (:math.sqrt(sin_theta * sin_theta + 2.0 * h / re) + sin_theta)

      # x = 1.22 * d_eff^2 * f / L  where f is in GHz, d_eff and L in meters
      x = 1.22 * d_eff * d_eff * f / l

      gx =
        if x < 7.0 do
          term1 =
            3.86 * :math.pow(x * x + 1.0, 11.0 / 12.0) *
              :math.sin(11.0 / 6.0 * :math.atan(1.0 / x))

          term2 = 7.08 * :math.pow(x, 5.0 / 6.0)
          :math.sqrt(max(term1 - term2, 0.0))
        else
          0.0
        end

      # Step 6: Standard deviation of signal amplitude sigma
      sigma = sigma_ref * :math.pow(f, 7.0 / 12.0) / :math.pow(:math.sin(theta_rad), 1.2) * gx

      # Step 7: Time percentage factor a(p)
      ap =
        -0.061 * :math.pow(:math.log10(p), 3) + 0.072 * :math.pow(:math.log10(p), 2) -
          1.71 * :math.log10(p) + 3.0

      # Step 8: Scintillation fade depth A_s(p)
      ap * sigma
    end
  end

  # Calculate N_wet from temperature and relative humidity
  # Based on ITU-R P.453
  defp calculate_n_wet(t_c, h) do
    t_k = t_c + 273.15
    # Saturation water vapor pressure e_s (hPa)
    # Magnus formula
    es = 6.1121 * :math.exp(17.67 * t_c / (t_c + 243.5))
    # Water vapor pressure e (hPa)
    e = h * es / 100.0
    # N_wet = 3.732 * 10^5 * e / T^2
    3.732e5 * e / (t_k * t_k)
  end

  # Scale the 0.01% attenuation to other time percentages
  # Using the method from P.618-13, Step 10
  @spec scale_attenuation(float(), float(), float(), float()) :: float()
  defp scale_attenuation(a001, p, lat, el) do
    el_rad = el * :math.pi() / 180.0

    beta =
      cond do
        p >= 1.0 ->
          0.0

        abs(lat) >= 36.0 ->
          0.0

        abs(lat) < 36.0 and el > 25.0 ->
          -0.005 * (abs(lat) - 36.0)

        true ->
          -0.005 * (abs(lat) - 36.0) + 1.8 - 4.25 * :math.sin(el_rad)
      end

    # Ensure A001 > 0 for logarithm
    a001_safe = max(a001, 1.0e-10)

    exponent =
      -(0.655 + 0.033 * :math.log(p) - 0.045 * :math.log(a001_safe) -
          beta * (1.0 - p) * :math.sin(el_rad))

    a = a001 * :math.pow(p / 0.01, exponent)
    max(a, 0.0)
  end
end
