defmodule ItuRPropagation.P840 do
  @moduledoc """
  ITU-R P.840: Attenuation due to clouds and fog.

  This module implements the method for predicting attenuation due to clouds
  and fog on Earth-space paths.

  The model calculates the specific attenuation coefficient K_l (dB/km per g/m^3)
  based on the complex permittivity of water, which depends on frequency and
  temperature.

  ## Reference

  ITU-R P.840-7: Attenuation due to clouds and fog.
  https://www.itu.int/rec/R-REC-P.840/en
  """

  @doc """
  Compute the specific attenuation coefficient for clouds and fog.

  Calculates K_l (dB/km per g/m^3) as defined in ITU-R P.840-7.

  ## Parameters

    * `frequency_ghz` - Frequency in GHz (up to 1000 GHz)
    * `temperature_c` - Temperature in degrees Celsius (default: 0.0)

  ## Returns

  Specific attenuation coefficient K_l in (dB/km)/(g/m^3).
  """
  @spec specific_attenuation_coeff(float(), float()) :: float()
  def specific_attenuation_coeff(frequency_ghz, temperature_c \\ 0.0) do
    f = frequency_ghz
    # Temperature in Kelvin
    t = temperature_c + 273.15
    theta = 300.0 / t

    # Permittivity of water using the double-Debye model (P.840-7, Eq. 6-10)
    epsilon_0 = 77.66 + 103.3 * (theta - 1.0)
    epsilon_1 = 0.0671 * epsilon_0
    epsilon_2 = 3.52

    # Relaxation frequencies (GHz)
    f_p = 20.20 - 146.4 * (theta - 1.0) + 316.0 * (theta - 1.0) * (theta - 1.0)
    f_s = 39.8 * f_p

    # Real and imaginary parts of permittivity
    eps_p =
      (epsilon_0 - epsilon_1) / (1.0 + :math.pow(f / f_p, 2)) +
        (epsilon_1 - epsilon_2) / (1.0 + :math.pow(f / f_s, 2)) + epsilon_2

    eps_pp =
      f / f_p * (epsilon_0 - epsilon_1) / (1.0 + :math.pow(f / f_p, 2)) +
        f / f_s * (epsilon_1 - epsilon_2) / (1.0 + :math.pow(f / f_s, 2))

    # Complex permittivity factor (P.840-7, Eq. 4)
    eta = (2.0 + eps_p) / eps_pp

    # K_l coefficient (P.840-7, Eq. 3)
    0.819 * f / (eps_pp * (1.0 + eta * eta))
  end

  @doc """
  Compute cloud attenuation along a slant path.

  ## Parameters

    * `frequency_ghz` - Frequency in GHz
    * `elevation_deg` - Elevation angle in degrees (> 0)
    * `liquid_water_content_kg_m2` - Integrated liquid water content in kg/m^2 (L)
    * `temperature_c` - Cloud temperature in degrees Celsius (default: 0.0)

  ## Returns

  Cloud attenuation in dB.
  """
  @spec cloud_attenuation(float(), float(), float(), float()) :: float()
  def cloud_attenuation(
        frequency_ghz,
        elevation_deg,
        liquid_water_content_kg_m2,
        temperature_c \\ 0.0
      ) do
    if elevation_deg <= 0.0 or liquid_water_content_kg_m2 <= 0.0 do
      0.0
    else
      kl = specific_attenuation_coeff(frequency_ghz, temperature_c)
      el_rad = elevation_deg * :math.pi() / 180.0

      # Attenuation A = L * Kl / sin(theta)

      # L is in kg/m^2, which is equivalent to mm of liquid water.
      # Kl is in (dB/km)/(g/m^3).
      # 1 kg/m^2 = 1000 g / (10^6 cm^2) = 0.001 g/cm^2 ? No.
      # 1 kg/m^2 = 1 mm thickness = 0.1 g/cm^2? No.
      # 1 kg/m^2 = 1000 g / m^2.
      # 1 g/m^3 * 1 km = 1 g/m^3 * 1000 m = 1000 g / m^2 = 1 kg/m^2.
      # So Kl (dB/km per g/m^3) * L (kg/m^2) gives dB directly.

      kl * liquid_water_content_kg_m2 / :math.sin(el_rad)
    end
  end
end
