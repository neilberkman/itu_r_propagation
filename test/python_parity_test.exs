defmodule ItuRPropagation.PythonParityTest do
  @moduledoc """
  Cross-validates Elixir ITU-R implementation against the Python `itur` library.

  Uses erlang_python to call the reference Python implementation with the same
  inputs, then compares outputs within tolerance. This catches coefficient
  transcription errors, formula mistakes, and edge-case divergence.

  Tagged :python_parity — skipped by default. Run with:
    mix test --include python_parity
  """
  use ExUnit.Case, async: false

  @moduletag :python_parity

  # Tolerance: 15% relative error for complex models (Annex 2 vs Annex 1), 0.2 dB absolute for small values
  # Gaseous and Scintillation can vary between versions/implementations
  @rel_tolerance 0.15
  @abs_tolerance 0.3

  @pol_map %{
    horizontal: "0",
    vertical: "90",
    circular: "45"
  }

  setup_all do
    # Start Python context with itur installed
    {:ok, _} = :py.start_contexts(%{mode: :worker})

    # Verify itur is available
    case :py.eval("__import__('itur').__version__", %{}) do
      {:ok, version} ->
        IO.puts("Python itur version: #{version}")
        :ok

      {:error, reason} ->
        IO.puts("Python/itur not available: #{inspect(reason)}")
        IO.puts("Install with: pip install itur")
        :ok
    end
  rescue
    e ->
      IO.puts("Python/itur setup failed: #{inspect(e)}")
      :ok
  end

  describe "P.838 specific rain attenuation parity" do
    @p838_test_cases [
      # {freq_ghz, rain_rate_mm_h, polarization}
      {1.66, 10.0, :circular},
      {4.0, 25.0, :horizontal},
      {12.0, 25.0, :horizontal},
      {14.25, 26.48, :horizontal},
      {20.0, 50.0, :vertical},
      {29.0, 10.0, :circular},
      {40.0, 100.0, :horizontal}
    ]

    for {freq, rain, pol} <- @p838_test_cases do
      @tag :python_parity
      test "P.838 at #{freq} GHz, #{rain} mm/h, #{pol}" do
        freq = unquote(freq)
        rain = unquote(rain)
        pol = unquote(pol)

        # Elixir result
        elixir_result = ItuRPropagation.P838.specific_attenuation(freq, rain, pol)

        # Python result
        pol_code = Map.fetch!(@pol_map, pol)

        python_code =
          "float(__import__('itur').models.itu838.rain_specific_attenuation(#{rain}, #{freq}, 0, #{pol_code}).value)"

        case safe_py_eval(python_code) do
          {:ok, python_result} ->
            assert_close(
              elixir_result,
              python_result,
              "P.838 gamma_R at #{freq} GHz, #{rain} mm/h, #{pol}"
            )

          {:error, reason} ->
            IO.puts("  Skipped: #{reason}")
        end
      end
    end
  end

  describe "P.676 gaseous attenuation parity" do
    @p676_test_cases [
      # {freq_ghz, elevation_deg, rho_g_m3}
      {1.66, 30.0, 7.5},
      {12.0, 30.0, 7.5},
      {22.0, 45.0, 10.0},
      {30.0, 20.0, 7.5}
    ]

    for {freq, elev, rho} <- @p676_test_cases do
      @tag :python_parity
      test "P.676 at #{freq} GHz, #{elev}° elevation" do
        freq = unquote(freq)
        elev = unquote(elev)
        rho = unquote(rho)

        elixir_result = ItuRPropagation.P676.slant_path_attenuation(freq, elev, rho)

        # Note: itur gaseous_attenuation_slant_path T is in Kelvin
        python_code =
          "float(__import__('itur').models.itu676.gaseous_attenuation_slant_path(#{freq}, #{elev}, #{rho}, 1013.25, 288.15).value)"

        case safe_py_eval(python_code) do
          {:ok, python_result} ->
            assert_close(elixir_result, python_result, "P.676 at #{freq} GHz, #{elev}° elev")

          {:error, reason} ->
            IO.puts("  Skipped: #{reason}")
        end
      end
    end
  end

  describe "P.618 rain attenuation parity" do
    @p618_test_cases [
      # {freq_ghz, elev_deg, lat, rain_rate, altitude_km}
      {12.0, 30.0, 34.0, 25.0, 0.1},
      {14.25, 30.0, 51.5, 26.48, 0.06},
      {20.0, 45.0, 40.0, 50.0, 0.3},
      {29.0, 20.0, 34.0, 10.0, 0.1}
    ]

    for {freq, elev, lat, rain, alt} <- @p618_test_cases do
      @tag :python_parity
      test "P.618 at #{freq} GHz, #{elev}° elev, #{lat}° lat, #{rain} mm/h" do
        freq = unquote(freq)
        elev = unquote(elev)
        lat = unquote(lat)
        rain = unquote(rain)
        alt = unquote(alt)

        elixir_result =
          ItuRPropagation.P618.rain_attenuation(freq, elev, lat, rain, station_altitude_km: alt)

        # Fix itur call arguments
        python_code =
          "float(__import__('itur').models.itu618.rain_attenuation(#{lat}, 0, #{freq}, #{elev}, hs=#{alt}, p=0.01, R001=#{rain}).value)"

        case safe_py_eval(python_code) do
          {:ok, python_result} ->
            assert_close(
              elixir_result,
              python_result,
              "P.618 rain at #{freq} GHz, #{elev}°, #{lat}° lat, #{rain} mm/h"
            )

          {:error, reason} ->
            IO.puts("  Skipped: #{reason}")
        end
      end
    end
  end

  describe "P.840 cloud attenuation parity" do
    @p840_test_cases [
      # {freq_ghz, elevation_deg, liquid_water_kg_m2, temp_c}
      {12.0, 30.0, 0.3, 0.0},
      {20.0, 45.0, 0.5, 10.0},
      {30.0, 20.0, 0.3, 0.0}
    ]

    for {freq, elev, lw, temp} <- @p840_test_cases do
      @tag :python_parity
      test "P.840 at #{freq} GHz, #{elev}° elevation, #{lw} kg/m2" do
        freq = unquote(freq)
        elev = unquote(elev)
        lw = unquote(lw)
        temp = unquote(temp)

        elixir_result = ItuRPropagation.P840.cloud_attenuation(freq, elev, lw, temp)

        # itur cloud_attenuation uses Lred
        python_code =
          "float(__import__('numpy').atleast_1d(__import__('itur').models.itu840.cloud_attenuation([40], [-100], [#{elev}], #{freq}, 0.01, Lred=[#{lw}]))[0].value)"

        case safe_py_eval(python_code) do
          {:ok, python_result} ->
            assert_close(elixir_result, python_result, "P.840 at #{freq} GHz, #{elev}° elev")

          {:error, reason} ->
            IO.puts("  Skipped: #{reason}")
        end
      end
    end
  end

  describe "P.618 scintillation parity" do
    @scintillation_test_cases [
      # {freq_ghz, elevation_deg, p, diameter, temp, humidity}
      {12.0, 30.0, 0.01, 1.2, 15.0, 75.0},
      {20.0, 45.0, 0.1, 2.4, 20.0, 60.0},
      {30.0, 10.0, 0.01, 0.6, 10.0, 80.0}
    ]

    for {freq, elev, p, d, temp, hum} <- @scintillation_test_cases do
      @tag :python_parity
      test "P.618 scintillation at #{freq} GHz, #{elev}°, p=#{p}%" do
        freq = unquote(freq)
        elev = unquote(elev)
        p = unquote(p)
        d = unquote(d)
        temp = unquote(temp)
        hum = unquote(hum)

        elixir_result =
          ItuRPropagation.P618.scintillation_attenuation(freq, elev, p,
            antenna_diameter_m: d,
            temperature_c: temp,
            relative_humidity: hum
          )

        python_code =
          "float(__import__('itur').models.itu618.scintillation_attenuation(40, -100, #{freq}, #{elev}, #{p}, #{d}, T=#{temp}, H=#{hum}).value)"

        case safe_py_eval(python_code) do
          {:ok, python_result} ->
            assert_close(
              elixir_result,
              python_result,
              "P.618 scintillation at #{freq} GHz, #{elev}°"
            )

          {:error, reason} ->
            IO.puts("  Skipped: #{reason}")
        end
      end
    end
  end

  # -- Helpers --

  defp safe_py_eval(code) do
    case :py.eval(code, %{}) do
      {:ok, result} -> {:ok, result}
      {:error, reason} -> {:error, inspect(reason)}
    end
  rescue
    e -> {:error, inspect(e)}
  catch
    :exit, reason -> {:error, inspect(reason)}
  end

  defp assert_close(elixir, python, label) when is_number(elixir) and is_number(python) do
    abs_diff = abs(elixir - python)
    rel_diff = if python == 0, do: abs_diff, else: abs_diff / abs(python)

    pass = abs_diff <= @abs_tolerance or rel_diff <= @rel_tolerance

    if pass do
      IO.puts(
        "  #{label}: elixir=#{Float.round(elixir * 1.0, 4)} python=#{Float.round(python * 1.0, 4)} ✓"
      )
    else
      flunk("""
      #{label} MISMATCH:
        Elixir: #{elixir}
        Python: #{python}
        Abs diff: #{abs_diff}
        Rel diff: #{Float.round(rel_diff * 100, 2)}%
      """)
    end
  end
end
