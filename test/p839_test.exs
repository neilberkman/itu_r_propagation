defmodule ItuRPropagation.P839Test do
  use ExUnit.Case, async: true

  alias ItuRPropagation.P839

  doctest ItuRPropagation.P839

  describe "rain_height/2" do
    test "equatorial rain height is about 5 km" do
      h_r = P839.rain_height(0.0, 0.0)
      assert_in_delta h_r, 4.926, 0.1
    end

    test "mid-latitude rain height decreases with latitude" do
      h_eq = P839.rain_height(0.0, 0.0)
      h_mid = P839.rain_height(45.0, 0.0)
      assert h_eq > h_mid
    end

    test "high-latitude rain height is low" do
      h_r = P839.rain_height(65.0, 0.0)
      assert h_r < 1.5
    end

    test "rain height is always positive" do
      for lat <- -70..70//10, lon <- [-120, 0, 60] do
        h_r = P839.rain_height(lat * 1.0, lon * 1.0)
        assert h_r >= 0.0, "rain height negative at lat=#{lat} lon=#{lon}"
      end
    end

    test "longitude matters for rain height" do
      h_la = P839.rain_height(34.0, -118.0)
      h_eu = P839.rain_height(34.0, 0.0)
      assert abs(h_la - h_eu) > 0.1
    end

    test "matches Python itur reference values within 10%" do
      references = [
        {0.0, 0.0, 4.926},
        {34.0, -118.0, 2.907},
        {50.0, 0.0, 2.294},
        {60.0, 0.0, 1.236}
      ]

      for {lat, lon, expected} <- references do
        h_r = P839.rain_height(lat, lon)
        rel_error = abs(h_r - expected) / expected

        assert rel_error < 0.10,
               "rain_height(#{lat}, #{lon}) = #{Float.round(h_r, 3)}, expected ~#{expected} (#{Float.round(rel_error * 100, 1)}% off)"
      end
    end
  end
end
