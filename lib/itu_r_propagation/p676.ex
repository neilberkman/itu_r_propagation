defmodule ItuRPropagation.P676 do
  @moduledoc """
  ITU-R P.676: Attenuation by atmospheric gases.

  Implements the simplified model for gaseous attenuation due to oxygen and
  water vapor absorption in the frequency range 1-350 GHz.

  At frequencies below ~10 GHz (e.g., L-band at 1.6 GHz), gaseous attenuation
  is small but non-negligible for precise link budgets. This module provides
  both the specific attenuation coefficients and the total slant-path
  attenuation through the atmosphere.

  ## Reference

  ITU-R P.676-13: Attenuation by atmospheric gases and related effects.
  https://www.itu.int/rec/R-REC-P.676/en
  """

  @doc """
  Compute specific attenuation due to dry air (oxygen) in dB/km.

  Uses the simplified approximate model from Annex 2 of ITU-R P.676.
  Valid for frequencies from 1 to 350 GHz.

  ## Parameters

    * `frequency_ghz` - Frequency in GHz (1-350)

  ## Returns

  Specific dry-air attenuation in dB/km.

  ## Examples

      iex> gamma_o = ItuRPropagation.P676.specific_dry_air(1.66)
      iex> gamma_o > 0.0 and gamma_o < 0.01
      true

  """
  @spec specific_dry_air(float()) :: float()
  def specific_dry_air(frequency_ghz) when is_number(frequency_ghz) do
    f = frequency_ghz

    cond do
      f <= 54.0 ->
        # Simplified model for frequencies up to 54 GHz
        # Dominant contribution from the 60 GHz oxygen complex
        7.2 * f * f / (f * f + 0.34) * 1.0e-3 +
          0.62 * :math.exp(-((f - 118.75) * (f - 118.75)) / 2500.0) * 1.0e-3

      f <= 66.0 ->
        # Near the 60 GHz oxygen absorption band
        # Approximate peak region
        oxygen_peak_attenuation(f)

      f <= 120.0 ->
        # Between 60 GHz band and 118.75 GHz line
        oxygen_high_freq(f)

      true ->
        # Above 120 GHz - simplified approximation
        oxygen_above_120(f)
    end
  end

  @doc """
  Compute specific attenuation due to water vapor in dB/km.

  Uses the simplified approximate model. The primary water vapor absorption
  lines relevant to this model are at 22.235 GHz, 183.31 GHz, and 325.15 GHz.

  ## Parameters

    * `frequency_ghz` - Frequency in GHz (1-350)
    * `water_vapor_density` - Water vapor density in g/m^3 (default: 7.5)

  ## Returns

  Specific water vapor attenuation in dB/km.

  ## Examples

      iex> gamma_w = ItuRPropagation.P676.specific_water_vapor(1.66)
      iex> gamma_w >= 0.0 and gamma_w < 0.001
      true

  """
  @spec specific_water_vapor(float(), float()) :: float()
  def specific_water_vapor(frequency_ghz, water_vapor_density \\ 7.5)
      when is_number(frequency_ghz) and is_number(water_vapor_density) do
    f = frequency_ghz
    rho = water_vapor_density

    if f <= 350.0 do
      # Simplified water vapor model based on ITU-R P.676 Annex 2
      # Line contributions use a Van Vleck-Weisskopf-like shape

      # 22.235 GHz line
      # Half-width ~2.85 GHz at ground level
      delta_f_22 = 2.85
      f0_22 = 22.235

      s_22 =
        0.0540 * rho *
          (f / f0_22) *
          (delta_f_22 / ((f - f0_22) * (f - f0_22) + delta_f_22 * delta_f_22) +
             delta_f_22 / ((f + f0_22) * (f + f0_22) + delta_f_22 * delta_f_22))

      # 183.31 GHz line
      # Half-width ~3.0 GHz
      delta_f_183 = 3.0
      f0_183 = 183.31

      s_183 =
        0.225 * rho *
          (f / f0_183) *
          (delta_f_183 / ((f - f0_183) * (f - f0_183) + delta_f_183 * delta_f_183) +
             delta_f_183 / ((f + f0_183) * (f + f0_183) + delta_f_183 * delta_f_183))

      # 325.153 GHz line
      delta_f_325 = 4.0
      f0_325 = 325.153

      s_325 =
        0.11 * rho *
          (f / f0_325) *
          (delta_f_325 / ((f - f0_325) * (f - f0_325) + delta_f_325 * delta_f_325) +
             delta_f_325 / ((f + f0_325) * (f + f0_325) + delta_f_325 * delta_f_325))

      # Continuum absorption (from the simplified model)
      continuum = (0.05 + 0.0021 * rho) * :math.pow(f, 1.5) * 1.0e-4

      max(s_22 + s_183 + s_325 + continuum, 0.0)
    else
      0.0
    end
  end

  @doc """
  Compute total gaseous attenuation along a slant path through the atmosphere.

  Integrates the specific attenuation over the equivalent path length through
  the atmosphere, accounting for the elevation angle and the finite extent of
  the atmosphere.

  ## Parameters

    * `frequency_ghz` - Frequency in GHz
    * `elevation_deg` - Elevation angle in degrees (must be > 0)
    * `water_vapor_density` - Water vapor density in g/m^3 (default: 7.5)

  ## Returns

  Total gaseous attenuation along the slant path in dB.

  ## Examples

      iex> a_gas = ItuRPropagation.P676.slant_path_attenuation(1.66, 30.0)
      iex> a_gas > 0.0 and a_gas < 1.0
      true

  """
  @spec slant_path_attenuation(float(), float(), float()) :: float()
  def slant_path_attenuation(frequency_ghz, elevation_deg, water_vapor_density \\ 7.5)
      when is_number(frequency_ghz) and is_number(elevation_deg) and
             is_number(water_vapor_density) do
    gamma_o = specific_dry_air(frequency_ghz)
    gamma_w = specific_water_vapor(frequency_ghz, water_vapor_density)

    # Equivalent heights for dry air and water vapor
    # From ITU-R P.676 Table 2 (approximate values)
    h_o = equivalent_height_dry_air(frequency_ghz)
    h_w = equivalent_height_water_vapor(frequency_ghz)

    el_rad = elevation_deg * :math.pi() / 180.0

    cond do
      elevation_deg >= 10.0 ->
        # Simple cosecant law for high elevation angles
        (gamma_o * h_o + gamma_w * h_w) / :math.sin(el_rad)

      elevation_deg > 0.0 ->
        # For low elevation angles, use the more accurate formula
        # that accounts for Earth curvature
        re = 6371.0
        # Effective path lengths with Earth curvature correction

        path_with_curvature(gamma_o, h_o, gamma_w, h_w, el_rad, re)

      true ->
        # Horizontal or negative elevation - not physical for satellite links
        0.0
    end
  end

  # Equivalent height for dry air absorption
  # Approximate model from ITU-R P.676 Annex 2
  @spec equivalent_height_dry_air(float()) :: float()
  defp equivalent_height_dry_air(f) do
    cond do
      f <= 57.0 ->
        # Below 57 GHz
        6.1 / (1.0 + 0.17 * :math.pow(f / 10.0, -1.1)) + 0.227

      f <= 63.0 ->
        # In the 60 GHz band
        # Reduced equivalent height due to strong absorption
        max(1.5, 6.1 / (1.0 + 0.17 * :math.pow(f / 10.0, -1.1)))

      f <= 350.0 ->
        # Above 63 GHz
        6.1 / (1.0 + 0.17 * :math.pow(f / 10.0, -1.1)) + 0.227

      true ->
        6.0
    end
  end

  # Equivalent height for water vapor absorption
  @spec equivalent_height_water_vapor(float()) :: float()
  defp equivalent_height_water_vapor(f) do
    if f <= 350.0 do
      # Water vapor scale height, approximately 1.6-2.1 km
      hw_base = 1.66

      # Enhancement near 22.235 GHz water vapor line
      g_22 = 1.0 + 3.0 * :math.exp(-:math.pow((f - 22.235) / 3.0, 2))

      hw_base * g_22
    else
      1.7
    end
  end

  # Low elevation angle path calculation with Earth curvature
  @spec path_with_curvature(float(), float(), float(), float(), float(), float()) :: float()
  defp path_with_curvature(gamma_o, h_o, gamma_w, h_w, el_rad, re) do
    sin_el = :math.sin(el_rad)

    # Use ITU-R P.676 formula for low elevation angles
    # A = gamma * h / (sin(el) + 2*h/Re)^0.5 approximately
    f_o =
      1.0 /
        :math.sqrt(
          sin_el * sin_el +
            2.0 * h_o / re
        )

    f_w =
      1.0 /
        :math.sqrt(
          sin_el * sin_el +
            2.0 * h_w / re
        )

    gamma_o * h_o * f_o + gamma_w * h_w * f_w
  end

  # Oxygen attenuation near 60 GHz peak
  @spec oxygen_peak_attenuation(float()) :: float()
  defp oxygen_peak_attenuation(f) do
    # Simplified model for the 60 GHz oxygen complex
    # Peak attenuation ~15 dB/km at 60 GHz
    15.0 * :math.exp(-:math.pow((f - 60.0) / 3.0, 2))
  end

  # Oxygen attenuation between 66-120 GHz
  @spec oxygen_high_freq(float()) :: float()
  defp oxygen_high_freq(f) do
    # Contribution from 60 GHz complex tail + 118.75 GHz line
    tail_60 = 0.5 * :math.exp(-:math.pow((f - 60.0) / 10.0, 2))

    line_118 =
      1.4 * :math.exp(-:math.pow((f - 118.75) / 2.0, 2))

    base = 7.2 * f * f / (f * f + 0.34) * 1.0e-3
    base + tail_60 + line_118
  end

  # Oxygen attenuation above 120 GHz
  @spec oxygen_above_120(float()) :: float()
  defp oxygen_above_120(f) do
    # Simplified approximation above 120 GHz
    # Gradually increasing with frequency
    base = 7.2 * f * f / (f * f + 0.34) * 1.0e-3
    base + 0.001 * (f - 120.0) / 230.0
  end
end
