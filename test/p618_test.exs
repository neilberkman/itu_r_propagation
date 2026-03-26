defmodule ItuRPropagation.P618Test do
  use ExUnit.Case, async: true

  alias ItuRPropagation.P618

  describe "rain_attenuation/5" do
    test "L-band (1.66 GHz) rain attenuation is small" do
      # At L-band, rain attenuation should be < 0.5 dB even with moderate rain
      a_rain = P618.rain_attenuation(1.66, 30.0, 40.0, 10.0)
      assert a_rain >= 0.0
      assert a_rain < 0.5
    end

    test "L-band with heavy rain still small" do
      a_rain = P618.rain_attenuation(1.66, 30.0, 40.0, 50.0)
      assert a_rain >= 0.0
      assert a_rain < 1.0
    end

    test "Ku-band (12 GHz) moderate rain gives significant attenuation" do
      a_rain = P618.rain_attenuation(12.0, 30.0, 40.0, 25.0)
      # At 12 GHz, 25 mm/h, 30 deg: expect roughly 3-15 dB
      assert a_rain > 1.0
      assert a_rain < 30.0
    end

    test "Ka-band (20 GHz) heavy rain gives large attenuation" do
      a_rain = P618.rain_attenuation(20.0, 30.0, 40.0, 50.0)
      # Ka-band with heavy rain: substantial attenuation
      assert a_rain > 5.0
      assert a_rain < 100.0
    end

    test "attenuation increases with rain rate" do
      a_5 = P618.rain_attenuation(12.0, 30.0, 40.0, 5.0)
      a_25 = P618.rain_attenuation(12.0, 30.0, 40.0, 25.0)
      a_50 = P618.rain_attenuation(12.0, 30.0, 40.0, 50.0)

      assert a_25 > a_5
      assert a_50 > a_25
    end

    test "attenuation increases with frequency" do
      a_4 = P618.rain_attenuation(4.0, 30.0, 40.0, 25.0)
      a_12 = P618.rain_attenuation(12.0, 30.0, 40.0, 25.0)
      a_20 = P618.rain_attenuation(20.0, 30.0, 40.0, 25.0)

      assert a_12 > a_4
      assert a_20 > a_12
    end

    test "attenuation increases at lower elevation angles" do
      a_60 = P618.rain_attenuation(12.0, 60.0, 40.0, 25.0)
      a_30 = P618.rain_attenuation(12.0, 30.0, 40.0, 25.0)
      a_10 = P618.rain_attenuation(12.0, 10.0, 40.0, 25.0)

      assert a_30 > a_60
      assert a_10 > a_30
    end

    test "zero rain rate gives zero attenuation" do
      assert P618.rain_attenuation(12.0, 30.0, 40.0, 0.0) == 0.0
    end

    test "negative rain rate gives zero attenuation" do
      assert P618.rain_attenuation(12.0, 30.0, 40.0, -5.0) == 0.0
    end

    test "station altitude reduces path length" do
      a_sea = P618.rain_attenuation(12.0, 30.0, 40.0, 25.0, station_altitude_km: 0.0)
      a_high = P618.rain_attenuation(12.0, 30.0, 40.0, 25.0, station_altitude_km: 2.0)

      # Higher station = shorter path through rain = less attenuation
      assert a_high < a_sea
    end

    test "horizontal polarization gives slightly more attenuation than vertical" do
      a_h = P618.rain_attenuation(12.0, 30.0, 40.0, 25.0, polarization: :horizontal)
      a_v = P618.rain_attenuation(12.0, 30.0, 40.0, 25.0, polarization: :vertical)

      # Horizontal polarization generally has slightly higher rain attenuation
      assert a_h > a_v
    end

    test "time percentage scaling: higher percentage gives less attenuation" do
      a_001 = P618.rain_attenuation(12.0, 30.0, 40.0, 25.0, time_percentage: 0.01)
      a_1 = P618.rain_attenuation(12.0, 30.0, 40.0, 25.0, time_percentage: 1.0)

      # 1% availability (less stringent) should have lower attenuation than 0.01%
      assert a_1 < a_001
    end

    test "low elevation angle still works" do
      a_rain = P618.rain_attenuation(12.0, 5.0, 40.0, 25.0)
      assert a_rain > 0.0
      assert is_number(a_rain)
    end

    test "tropical latitude gives different result than mid-latitude" do
      a_tropical = P618.rain_attenuation(12.0, 30.0, 5.0, 25.0)
      a_midlat = P618.rain_attenuation(12.0, 30.0, 45.0, 25.0)

      # Tropical has higher rain height, so longer path, more attenuation
      assert a_tropical > a_midlat
    end
  end
end
