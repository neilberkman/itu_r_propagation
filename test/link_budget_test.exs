defmodule ItuRPropagation.LinkBudgetTest do
  use ExUnit.Case, async: true

  alias ItuRPropagation.LinkBudget

  describe "total_atmospheric_attenuation/1" do
    test "returns all expected components" do
      result =
        LinkBudget.total_atmospheric_attenuation(
          frequency_ghz: 12.0,
          elevation_deg: 30.0,
          latitude_deg: 40.0,
          longitude_deg: -100.0,
          rain_rate_mmh: 25.0
        )

      assert Map.has_key?(result, :total_db)
      assert Map.has_key?(result, :gaseous_db)
      assert Map.has_key?(result, :rain_db)
      assert Map.has_key?(result, :cloud_db)
      assert Map.has_key?(result, :scintillation_db)
    end

    test "total equals sum of components" do
      result =
        LinkBudget.total_atmospheric_attenuation(
          frequency_ghz: 12.0,
          elevation_deg: 30.0,
          latitude_deg: 40.0,
          longitude_deg: -100.0,
          rain_rate_mmh: 25.0
        )

      expected = result.gaseous_db + result.rain_db + result.cloud_db + result.scintillation_db
      assert_in_delta result.total_db, expected, 1.0e-10
    end

    test "all components are non-negative" do
      result =
        LinkBudget.total_atmospheric_attenuation(
          frequency_ghz: 12.0,
          elevation_deg: 30.0,
          latitude_deg: 40.0,
          longitude_deg: -100.0,
          rain_rate_mmh: 25.0
        )

      assert result.gaseous_db >= 0.0
      assert result.rain_db >= 0.0
      assert result.cloud_db >= 0.0
      assert result.scintillation_db >= 0.0
      assert result.total_db >= 0.0
    end

    test "L-band total attenuation is small" do
      result =
        LinkBudget.total_atmospheric_attenuation(
          frequency_ghz: 1.66,
          elevation_deg: 30.0,
          latitude_deg: 40.0,
          longitude_deg: -100.0,
          rain_rate_mmh: 10.0
        )

      # L-band: total should be < 1 dB in most conditions
      assert result.total_db < 2.0
      assert result.total_db > 0.0

      # Rain should be the smallest component at L-band relative to higher bands
      assert result.rain_db < 0.5
    end

    test "Ku-band rain dominates the budget" do
      result =
        LinkBudget.total_atmospheric_attenuation(
          frequency_ghz: 12.0,
          elevation_deg: 30.0,
          latitude_deg: 40.0,
          longitude_deg: -100.0,
          rain_rate_mmh: 25.0
        )

      # At 12 GHz with 25 mm/h rain, rain should be the dominant term
      assert result.rain_db > result.gaseous_db
      assert result.rain_db > result.cloud_db
    end

    test "Ka-band (20 GHz) with heavy rain" do
      result =
        LinkBudget.total_atmospheric_attenuation(
          frequency_ghz: 20.0,
          elevation_deg: 30.0,
          latitude_deg: 40.0,
          longitude_deg: -100.0,
          rain_rate_mmh: 50.0
        )

      # Heavy rain at Ka-band: expect large total attenuation
      assert result.total_db > 10.0
      assert result.rain_db > 10.0
    end

    test "clear sky (no rain) still has gaseous and other components" do
      result =
        LinkBudget.total_atmospheric_attenuation(
          frequency_ghz: 12.0,
          elevation_deg: 30.0,
          latitude_deg: 40.0,
          longitude_deg: -100.0,
          rain_rate_mmh: 0.0
        )

      assert result.rain_db == 0.0
      assert result.gaseous_db > 0.0
      assert result.total_db > 0.0
    end

    test "station altitude reduces attenuation" do
      result_sea =
        LinkBudget.total_atmospheric_attenuation(
          frequency_ghz: 12.0,
          elevation_deg: 30.0,
          latitude_deg: 40.0,
          longitude_deg: -100.0,
          rain_rate_mmh: 25.0,
          station_altitude_km: 0.0
        )

      result_high =
        LinkBudget.total_atmospheric_attenuation(
          frequency_ghz: 12.0,
          elevation_deg: 30.0,
          latitude_deg: 40.0,
          longitude_deg: -100.0,
          rain_rate_mmh: 25.0,
          station_altitude_km: 2.0
        )

      assert result_high.rain_db < result_sea.rain_db
    end

    test "raises on missing required options" do
      assert_raise KeyError, fn ->
        LinkBudget.total_atmospheric_attenuation(
          elevation_deg: 30.0,
          latitude_deg: 40.0,
          longitude_deg: -100.0,
          rain_rate_mmh: 25.0
        )
      end
    end
  end

  describe "cloud_attenuation/3" do
    test "increases with frequency" do
      a_5 = LinkBudget.cloud_attenuation(5.0, 30.0, 0.3)
      a_20 = LinkBudget.cloud_attenuation(20.0, 30.0, 0.3)
      assert a_20 > a_5
    end

    test "increases with cloud liquid water content" do
      a_low = LinkBudget.cloud_attenuation(12.0, 30.0, 0.1)
      a_high = LinkBudget.cloud_attenuation(12.0, 30.0, 1.0)
      assert a_high > a_low
    end

    test "is zero for non-positive elevation" do
      assert LinkBudget.cloud_attenuation(12.0, 0.0, 0.3) == 0.0
    end

    test "L-band cloud attenuation is negligible" do
      a_cloud = LinkBudget.cloud_attenuation(1.66, 30.0, 0.3)
      assert a_cloud < 0.01
    end
  end

  describe "scintillation_attenuation/2" do
    test "increases with frequency" do
      s_5 = LinkBudget.scintillation_attenuation(5.0, 30.0)
      s_20 = LinkBudget.scintillation_attenuation(20.0, 30.0)
      assert s_20 > s_5
    end

    test "increases at lower elevation" do
      s_60 = LinkBudget.scintillation_attenuation(12.0, 60.0)
      s_30 = LinkBudget.scintillation_attenuation(12.0, 30.0)
      s_10 = LinkBudget.scintillation_attenuation(12.0, 10.0)

      assert s_30 > s_60
      assert s_10 > s_30
    end

    test "is zero for non-positive elevation" do
      assert LinkBudget.scintillation_attenuation(12.0, 0.0) == 0.0
    end
  end

  describe "ItuRPropagation.total_atmospheric_attenuation/1 (main API)" do
    test "delegates to LinkBudget" do
      result =
        ItuRPropagation.total_atmospheric_attenuation(
          frequency_ghz: 12.0,
          elevation_deg: 30.0,
          latitude_deg: 40.0,
          longitude_deg: -100.0,
          rain_rate_mmh: 25.0
        )

      assert is_map(result)
      assert result.total_db > 0.0
    end
  end
end
