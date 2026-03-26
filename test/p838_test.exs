defmodule ItuRPropagation.P838Test do
  use ExUnit.Case, async: true

  alias ItuRPropagation.P838

  describe "coefficients/3" do
    test "horizontal coefficients at 14.25 GHz match ITU validation data" do
      # From ITU-Rpy test data: f=14.25, el=31.077, tau=0 (horizontal)
      # Expected: k=0.03975, alpha=1.1242
      {k, alpha} = P838.coefficients(14.25, :horizontal)
      assert_in_delta k, 0.03949, 0.002
      assert_in_delta alpha, 1.129, 0.02
    end

    test "horizontal coefficients at 29 GHz match ITU validation data" do
      # From ITU-Rpy test data: f=29, tau=0 (horizontal)
      # Expected: k~0.221, alpha~0.953
      {k, alpha} = P838.coefficients(29.0, :horizontal)
      assert_in_delta k, 0.221, 0.005
      assert_in_delta alpha, 0.953, 0.02
    end

    test "L-band (1.66 GHz) k is very small" do
      {k_h, alpha_h} = P838.coefficients(1.66, :horizontal)
      {k_v, alpha_v} = P838.coefficients(1.66, :vertical)

      # At 1.66 GHz, k should be in the 0.0001 range or smaller
      assert k_h < 0.001
      assert k_h > 0.0
      assert k_v < 0.001
      assert k_v > 0.0

      # Alpha should be around 0.9-1.2 at low frequencies
      assert alpha_h > 0.5
      assert alpha_h < 1.5
      assert alpha_v > 0.5
      assert alpha_v < 1.5
    end

    test "circular polarization coefficients are average of H and V" do
      {k_h, _alpha_h} = P838.coefficients(12.0, :horizontal)
      {k_v, _alpha_v} = P838.coefficients(12.0, :vertical)
      {k_c, _alpha_c} = P838.coefficients(12.0, :circular)

      # For circular (tau=45), cos(2*45)=0, so k_c = (k_h + k_v) / 2
      expected_k = (k_h + k_v) / 2.0
      assert_in_delta k_c, expected_k, 1.0e-10
    end

    test "k increases with frequency" do
      {k_1, _} = P838.coefficients(1.0, :horizontal)
      {k_10, _} = P838.coefficients(10.0, :horizontal)
      {k_30, _} = P838.coefficients(30.0, :horizontal)
      {k_100, _} = P838.coefficients(100.0, :horizontal)

      assert k_10 > k_1
      assert k_30 > k_10
      assert k_100 > k_30
    end

    test "alpha decreases toward 1 at higher frequencies" do
      {_, alpha_5} = P838.coefficients(5.0, :horizontal)
      {_, alpha_50} = P838.coefficients(50.0, :horizontal)
      {_, alpha_200} = P838.coefficients(200.0, :horizontal)

      # At higher frequencies, alpha approaches ~0.7
      assert alpha_5 > alpha_50
      assert alpha_50 > alpha_200
    end
  end

  describe "specific_attenuation/4" do
    test "L-band rain attenuation is minimal" do
      gamma = P838.specific_attenuation(1.66, 10.0, :circular)
      # At 1.66 GHz with 10 mm/h rain, attenuation should be negligible
      assert gamma < 0.01
      assert gamma > 0.0
    end

    test "Ku-band (12 GHz) with moderate rain" do
      gamma = P838.specific_attenuation(12.0, 25.0, :horizontal)
      # Expect roughly 1-3 dB/km at 12 GHz, 25 mm/h
      assert gamma > 0.5
      assert gamma < 5.0
    end

    test "Ka-band (30 GHz) with heavy rain" do
      gamma = P838.specific_attenuation(30.0, 50.0, :horizontal)
      # Heavy rain at Ka-band: expect significant attenuation
      assert gamma > 5.0
      assert gamma < 30.0
    end

    test "zero rain rate gives zero attenuation" do
      assert P838.specific_attenuation(12.0, 0.0, :horizontal) == 0.0
    end

    test "negative rain rate gives zero attenuation" do
      assert P838.specific_attenuation(12.0, -5.0, :horizontal) == 0.0
    end

    test "attenuation increases with rain rate" do
      gamma_5 = P838.specific_attenuation(12.0, 5.0, :horizontal)
      gamma_25 = P838.specific_attenuation(12.0, 25.0, :horizontal)
      gamma_100 = P838.specific_attenuation(12.0, 100.0, :horizontal)

      assert gamma_25 > gamma_5
      assert gamma_100 > gamma_25
    end

    test "attenuation increases with frequency" do
      gamma_4 = P838.specific_attenuation(4.0, 25.0, :circular)
      gamma_12 = P838.specific_attenuation(12.0, 25.0, :circular)
      gamma_30 = P838.specific_attenuation(30.0, 25.0, :circular)

      assert gamma_12 > gamma_4
      assert gamma_30 > gamma_12
    end

    test "ITU-Rpy validation: 14.25 GHz, horizontal, various rain rates" do
      # From the ITU-Rpy test CSV:
      # f=14.25, R=26.48, tau=0, gamma_r=1.5813
      gamma = P838.specific_attenuation(14.25, 26.48, :horizontal, 31.077)
      assert_in_delta gamma, 1.581, 0.15

      # f=14.25, R=50.64, tau=0, gamma_r=3.3214
      gamma2 = P838.specific_attenuation(14.25, 50.64, :horizontal, 22.278)
      assert_in_delta gamma2, 3.321, 0.3
    end

    test "ITU-Rpy validation: 29 GHz, horizontal" do
      # f=29, R=26.48, tau=0, gamma_r=5.0218
      gamma = P838.specific_attenuation(29.0, 26.48, :horizontal, 31.077)
      assert_in_delta gamma, 5.022, 0.5
    end
  end
end
