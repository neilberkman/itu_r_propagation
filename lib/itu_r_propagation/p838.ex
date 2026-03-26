defmodule ItuRPropagation.P838 do
  @moduledoc """
  ITU-R P.838-3: Specific attenuation model for rain.

  Implements the power-law model for computing specific rain attenuation:

      gamma_R = k * R^alpha  (dB/km)

  where R is the rain rate in mm/h, and k and alpha are frequency- and
  polarization-dependent coefficients derived from curve-fitting to
  scattering calculations.

  The coefficients are computed using regression fits published in
  ITU-R P.838-3 (03/2005), valid for frequencies from 1 to 1000 GHz.

  ## Polarization

  Coefficients are provided for horizontal and vertical linear polarization.
  For circular polarization (e.g., RHCP used in satellite links), the
  coefficients are derived as:

      k_c = (k_H + k_V + (k_H - k_V) * cos^2(el) * cos(2*tau)) / 2
      alpha_c = (k_H*alpha_H + k_V*alpha_V + ...) / (2*k_c)

  where tau = 45 degrees for circular polarization.

  ## Reference

  ITU-R P.838-3: Specific attenuation model for rain for use in prediction methods.
  https://www.itu.int/rec/R-REC-P.838-3-200503-I/en
  """

  # ============================================================================
  # P.838-3 Regression Coefficients
  #
  # These are the exact coefficients from Table 1-4 of ITU-R P.838-3.
  # The curve-fitting model is:
  #   log10(k) = sum(aj * exp(-((log10(f) - bj) / cj)^2)) + mk*log10(f) + ck
  #   alpha    = sum(aj * exp(-((log10(f) - bj) / cj)^2)) + ma*log10(f) + ca
  # ============================================================================

  # Table 1: Coefficients for k_H
  @kh_aj [-5.33980, -0.35351, -0.23789, -0.94158]
  @kh_bj [-0.10008, 1.26970, 0.86036, 0.64552]
  @kh_cj [1.13098, 0.45400, 0.15354, 0.16817]
  @kh_mk -0.18961
  @kh_ck 0.71147

  # Table 2: Coefficients for k_V
  @kv_aj [-3.80595, -3.44965, -0.39902, 0.50167]
  @kv_bj [0.56934, -0.22911, 0.73042, 1.07319]
  @kv_cj [0.81061, 0.51059, 0.11899, 0.27195]
  @kv_mk -0.16398
  @kv_ck 0.63297

  # Table 3: Coefficients for alpha_H
  @ah_aj [-0.14318, 0.29591, 0.32177, -5.37610, 16.1721]
  @ah_bj [1.82442, 0.77564, 0.63773, -0.96230, -3.29980]
  @ah_cj [-0.55187, 0.19822, 0.13164, 1.47828, 3.43990]
  @ah_ma 0.67849
  @ah_ca -1.95537

  # Table 4: Coefficients for alpha_V
  @av_aj [-0.07771, 0.56727, -0.20238, -48.2991, 48.5833]
  @av_bj [2.33840, 0.95545, 1.14520, 0.791669, 0.791459]
  @av_cj [-0.76284, 0.54039, 0.26809, 0.116226, 0.116479]
  @av_ma -0.053739
  @av_ca 0.83433

  @type polarization :: :horizontal | :vertical | :circular

  @doc """
  Compute the specific rain attenuation gamma_R in dB/km.

  Applies the power-law relationship gamma_R = k * R^alpha, where k and
  alpha are frequency- and polarization-dependent coefficients from
  ITU-R P.838-3.

  ## Parameters

    * `frequency_ghz` - Frequency in GHz (1-1000)
    * `rain_rate_mmh` - Rain rate in mm/h
    * `polarization` - Polarization: `:horizontal`, `:vertical`, or `:circular`
      (default: `:circular`)
    * `elevation_deg` - Elevation angle in degrees, used for polarization
      mixing (default: 0.0)

  ## Returns

  Specific rain attenuation in dB/km.

  ## Examples

      iex> gamma = ItuRPropagation.P838.specific_attenuation(12.0, 25.0, :horizontal)
      iex> gamma > 1.0
      true

      iex> gamma = ItuRPropagation.P838.specific_attenuation(1.66, 10.0, :circular)
      iex> gamma < 0.01
      true

  """
  @spec specific_attenuation(float(), float(), polarization(), float()) :: float()
  def specific_attenuation(
        frequency_ghz,
        rain_rate_mmh,
        polarization \\ :circular,
        elevation_deg \\ 0.0
      )

  def specific_attenuation(_frequency_ghz, rain_rate_mmh, _polarization, _elevation_deg)
      when rain_rate_mmh <= 0.0 do
    0.0
  end

  def specific_attenuation(frequency_ghz, rain_rate_mmh, polarization, elevation_deg)
      when is_number(frequency_ghz) and is_number(rain_rate_mmh) and is_number(elevation_deg) do
    {k, alpha} = coefficients(frequency_ghz, polarization, elevation_deg)
    k * :math.pow(rain_rate_mmh, alpha)
  end

  @doc """
  Compute the k and alpha coefficients for the power-law rain attenuation model.

  Returns the pair {k, alpha} such that gamma_R = k * R^alpha (dB/km).

  ## Parameters

    * `frequency_ghz` - Frequency in GHz (1-1000)
    * `polarization` - Polarization: `:horizontal`, `:vertical`, or `:circular`
      (default: `:circular`)
    * `elevation_deg` - Elevation angle in degrees (default: 0.0)

  ## Returns

  Tuple `{k, alpha}` where k is the coefficient (dimensionless) and alpha
  is the exponent (dimensionless).

  ## Examples

      iex> {k, alpha} = ItuRPropagation.P838.coefficients(14.25, :horizontal)
      iex> abs(k - 0.0393) < 0.005
      true
      iex> abs(alpha - 1.12) < 0.05
      true

  """
  @spec coefficients(float(), polarization(), float()) :: {float(), float()}
  def coefficients(frequency_ghz, polarization \\ :circular, elevation_deg \\ 0.0)

  def coefficients(frequency_ghz, polarization, elevation_deg)
      when polarization in [:horizontal, :vertical, :circular] do
    # ITU-R P.838-3 general formula (Eq. 4-5):
    #   k = [k_H + k_V + (k_H - k_V) * cos²(θ) * cos(2τ)] / 2
    #   α = [k_H*α_H + k_V*α_V + (k_H*α_H - k_V*α_V) * cos²(θ) * cos(2τ)] / (2k)
    # where θ = elevation angle, τ = polarization tilt angle:
    #   τ = 0° for horizontal, 90° for vertical, 45° for circular
    tau =
      case polarization do
        :horizontal -> 0.0
        :vertical -> 90.0
        :circular -> 45.0
      end

    k_h = compute_k(frequency_ghz, @kh_aj, @kh_bj, @kh_cj, @kh_mk, @kh_ck)
    k_v = compute_k(frequency_ghz, @kv_aj, @kv_bj, @kv_cj, @kv_mk, @kv_ck)
    alpha_h = compute_alpha(frequency_ghz, @ah_aj, @ah_bj, @ah_cj, @ah_ma, @ah_ca)
    alpha_v = compute_alpha(frequency_ghz, @av_aj, @av_bj, @av_cj, @av_ma, @av_ca)

    el_rad = elevation_deg * :math.pi() / 180.0
    tau_rad = tau * :math.pi() / 180.0

    cos2_el = :math.pow(:math.cos(el_rad), 2)
    cos_2tau = :math.cos(2.0 * tau_rad)

    k = (k_h + k_v + (k_h - k_v) * cos2_el * cos_2tau) / 2.0

    alpha =
      (k_h * alpha_h + k_v * alpha_v +
         (k_h * alpha_h - k_v * alpha_v) * cos2_el * cos_2tau) / (2.0 * k)

    {k, alpha}
  end

  # Compute k coefficient: 10^(sum(aj * exp(-((log10(f)-bj)/cj)^2)) + mk*log10(f) + ck)
  @spec compute_k(float(), [float()], [float()], [float()], float(), float()) :: float()
  defp compute_k(f, aj, bj, cj, mk, ck) do
    log10_f = :math.log10(f)

    sum =
      Enum.zip([aj, bj, cj])
      |> Enum.reduce(0.0, fn {a, b, c}, acc ->
        acc + a * :math.exp(-:math.pow((log10_f - b) / c, 2))
      end)

    :math.pow(10.0, sum + mk * log10_f + ck)
  end

  # Compute alpha coefficient: sum(aj * exp(-((log10(f)-bj)/cj)^2)) + ma*log10(f) + ca
  @spec compute_alpha(float(), [float()], [float()], [float()], float(), float()) :: float()
  defp compute_alpha(f, aj, bj, cj, ma, ca) do
    log10_f = :math.log10(f)

    sum =
      Enum.zip([aj, bj, cj])
      |> Enum.reduce(0.0, fn {a, b, c}, acc ->
        acc + a * :math.exp(-:math.pow((log10_f - b) / c, 2))
      end)

    sum + ma * log10_f + ca
  end
end
