defmodule ItuRPropagation.P676Test do
  use ExUnit.Case, async: true

  alias ItuRPropagation.P676

  describe "specific_dry_air/1" do
    test "L-band (1.66 GHz) attenuation is very small" do
      gamma_o = P676.specific_dry_air(1.66)
      assert gamma_o > 0.0
      assert gamma_o < 0.01
    end

    test "attenuation increases with frequency below 54 GHz" do
      gamma_5 = P676.specific_dry_air(5.0)
      gamma_10 = P676.specific_dry_air(10.0)
      gamma_30 = P676.specific_dry_air(30.0)
      assert gamma_10 > gamma_5
      assert gamma_30 > gamma_10
    end

    test "peak attenuation near 60 GHz oxygen band" do
      gamma_60 = P676.specific_dry_air(60.0)
      gamma_30 = P676.specific_dry_air(30.0)
      gamma_90 = P676.specific_dry_air(90.0)
      assert gamma_60 > gamma_30
      assert gamma_60 > gamma_90
      # 60 GHz peak should be very high (order of 10+ dB/km)
      assert gamma_60 > 5.0
    end

    test "118.75 GHz oxygen line produces a local peak" do
      gamma_118 = P676.specific_dry_air(118.75)
      gamma_100 = P676.specific_dry_air(100.0)
      assert gamma_118 > gamma_100
    end

    test "returns positive values across frequency range" do
      for f <- [1.0, 5.0, 10.0, 22.0, 40.0, 100.0, 200.0, 350.0] do
        assert P676.specific_dry_air(f) > 0.0, "Expected positive attenuation at #{f} GHz"
      end
    end
  end

  describe "specific_water_vapor/2" do
    test "L-band (1.66 GHz) water vapor attenuation is very small" do
      gamma_w = P676.specific_water_vapor(1.66, 7.5)
      assert gamma_w >= 0.0
      assert gamma_w < 0.001
    end

    test "peak near 22.235 GHz water vapor line" do
      gamma_22 = P676.specific_water_vapor(22.235, 7.5)
      gamma_15 = P676.specific_water_vapor(15.0, 7.5)
      gamma_30 = P676.specific_water_vapor(30.0, 7.5)
      assert gamma_22 > gamma_15
      assert gamma_22 > gamma_30
    end

    test "attenuation scales with water vapor density" do
      gamma_low = P676.specific_water_vapor(22.0, 3.0)
      gamma_high = P676.specific_water_vapor(22.0, 15.0)
      assert gamma_high > gamma_low
    end

    test "zero water vapor gives small continuum only" do
      # With zero water vapor density, there should be essentially no
      # water vapor attenuation (just the tiny continuum base)
      gamma = P676.specific_water_vapor(10.0, 0.0)
      assert gamma >= 0.0
      assert gamma < 0.01
    end

    test "returns non-negative across frequency range" do
      for f <- [1.0, 10.0, 22.235, 50.0, 100.0, 183.0, 300.0, 350.0] do
        assert P676.specific_water_vapor(f, 7.5) >= 0.0,
               "Expected non-negative attenuation at #{f} GHz"
      end
    end
  end

  describe "slant_path_attenuation/3" do
    test "L-band at 30 degrees elevation" do
      a_gas = P676.slant_path_attenuation(1.66, 30.0, 7.5)
      # At L-band, total gaseous attenuation should be small but measurable
      assert a_gas > 0.0
      assert a_gas < 1.0
    end

    test "attenuation increases at lower elevation angles" do
      a_30 = P676.slant_path_attenuation(12.0, 30.0, 7.5)
      a_10 = P676.slant_path_attenuation(12.0, 10.0, 7.5)
      assert a_10 > a_30
    end

    test "zenith attenuation (90 degrees)" do
      a_zenith = P676.slant_path_attenuation(12.0, 90.0, 7.5)
      a_30 = P676.slant_path_attenuation(12.0, 30.0, 7.5)
      # Zenith should be less than 30 degrees (shorter path)
      assert a_zenith < a_30
    end

    test "Ku-band (12 GHz) gaseous attenuation is moderate" do
      a_gas = P676.slant_path_attenuation(12.0, 30.0, 7.5)
      # At 12 GHz, 30 deg elevation, expect roughly 0.1-0.5 dB
      assert a_gas > 0.05
      assert a_gas < 2.0
    end

    test "returns zero for non-positive elevation" do
      assert P676.slant_path_attenuation(12.0, 0.0, 7.5) == 0.0
      assert P676.slant_path_attenuation(12.0, -5.0, 7.5) == 0.0
    end

    test "low elevation angle uses curvature correction" do
      a_5 = P676.slant_path_attenuation(12.0, 5.0, 7.5)
      # Should be larger than high elevation but still finite
      assert a_5 > 0.0
      assert a_5 < 50.0
    end
  end
end
