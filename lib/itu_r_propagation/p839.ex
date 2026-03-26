defmodule ItuRPropagation.P839 do
  @moduledoc """
  ITU-R P.839: Rain height model for prediction methods.

  Provides the mean annual rain height above mean sea level as a function
  of latitude and longitude. The rain height is used by ITU-R P.618 to
  compute the slant-path length through rain.

  This implementation uses a 5-degree gridded lookup table derived from
  ITU-R P.839-4 data with bilinear interpolation. This matches the accuracy
  of the Python `itur` library.

  ## Reference

  ITU-R P.839-4: Rain height model for prediction methods.
  https://www.itu.int/rec/R-REC-P.839/en
  """

  # Grid data file generated from ITU-R P.839-4 via Python itur library
  @external_resource Path.expand("../data/rain_height_grid.csv", __DIR__)

  @rain_height_grid Path.expand("../data/rain_height_grid.csv", __DIR__)
                    |> File.read!()
                    |> String.split("\n", trim: true)
                    |> Map.new(fn line ->
                      [lat, lon, hr] = String.split(line, ",")
                      {{String.to_integer(lat), String.to_integer(lon)}, String.to_float(hr)}
                    end)

  @grid_step 1
  @lat_min -70
  @lat_max 70
  @lon_min -180
  @lon_max 175

  @doc """
  Compute the mean annual rain height above mean sea level.

  Uses bilinear interpolation on a 5-degree grid derived from ITU-R P.839-4.

  ## Parameters

    * `latitude_deg` - Latitude in degrees (-90 to 90)
    * `longitude_deg` - Longitude in degrees (-180 to 180)

  ## Returns

  Mean annual rain height in km above mean sea level.

  ## Examples

      iex> h_r = ItuRPropagation.P839.rain_height(34.0, -118.0)
      iex> abs(h_r - 2.907) < 0.3
      true

      iex> h_r = ItuRPropagation.P839.rain_height(0.0, 0.0)
      iex> abs(h_r - 4.926) < 0.1
      true

  """
  @spec rain_height(float(), float()) :: float()
  def rain_height(latitude_deg, longitude_deg \\ 0.0)
      when is_number(latitude_deg) and is_number(longitude_deg) do
    # Clamp to grid bounds
    lat = max(@lat_min * 1.0, min(@lat_max * 1.0, latitude_deg * 1.0))
    lon = normalize_lon(longitude_deg)

    # Find grid cell
    lat_lo = floor_to_grid(lat, @grid_step, @lat_min)
    lat_hi = min(lat_lo + @grid_step, @lat_max)
    lon_lo = floor_to_grid(lon, @grid_step, @lon_min)
    lon_hi = lon_lo + @grid_step
    lon_hi = if lon_hi > @lon_max, do: @lon_min, else: lon_hi

    # Bilinear interpolation
    q11 = Map.get(@rain_height_grid, {lat_lo, lon_lo}, 0.0)
    q21 = Map.get(@rain_height_grid, {lat_hi, lon_lo}, 0.0)
    q12 = Map.get(@rain_height_grid, {lat_lo, lon_hi}, 0.0)
    q22 = Map.get(@rain_height_grid, {lat_hi, lon_hi}, 0.0)

    if lat_hi == lat_lo do
      # Same lat row — linear in lon
      if lon_hi == lon_lo, do: q11, else: lerp(lon, lon_lo, lon_hi, q11, q12)
    else
      t_lat = (lat - lat_lo) / (lat_hi - lat_lo)

      if lon_hi == lon_lo do
        lerp_val(t_lat, q11, q21)
      else
        t_lon = (lon - lon_lo) / (lon_hi - lon_lo)
        r1 = lerp_val(t_lon, q11, q12)
        r2 = lerp_val(t_lon, q21, q22)
        lerp_val(t_lat, r1, r2)
      end
    end
  end

  defp normalize_lon(lon) do
    lon = :math.fmod(lon + 180.0, 360.0)
    if lon < 0, do: lon + 360.0 - 180.0, else: lon - 180.0
  end

  defp floor_to_grid(val, step, grid_min) do
    trunc(Float.floor((val - grid_min) / step)) * step + grid_min
  end

  defp lerp(x, x0, x1, y0, y1) do
    t = (x - x0) / (x1 - x0)
    lerp_val(t, y0, y1)
  end

  defp lerp_val(t, a, b), do: a + t * (b - a)
end
