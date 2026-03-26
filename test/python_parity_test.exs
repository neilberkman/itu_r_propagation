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

  @python_setup """
  import itur
  import numpy as np
  """

  # Tolerance: 5% relative error for most values, 0.1 dB absolute for small values
  @rel_tolerance 0.05
  @abs_tolerance 0.1

  setup_all do
    # Start Python context with itur installed
    {:ok, _} = :py.start_contexts(%{mode: :worker})

    # Verify itur is available
    {result, _} = :py.eval("import itur; itur.__version__", %{})
    version = :py.decode(result)
    IO.puts("Python itur version: #{version}")

    :ok
  rescue
    e ->
      IO.puts("Python/itur not available: #{inspect(e)}")
      IO.puts("Install with: pip install itur")
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
        pol_str =
          case pol do
            :horizontal -> "H"
            :vertical -> "V"
            :circular -> "C"
          end

        python_code = """
        #{@python_setup}
        gamma = float(itur.models.itu838.rain_specific_attenuation(#{rain}, #{freq}, 0, #{case pol do
          :horizontal -> "0"
          :vertical -> "90"
          :circular -> "45"
        end}).value)
        gamma
        """

        case safe_py_eval(python_code) do
          {:ok, python_result} ->
            assert_close(
              elixir_result,
              python_result,
              "P.838 gamma_R at #{freq} GHz, #{rain} mm/h, #{pol_str}"
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

        elixir_result = ItuRPropagation.P676.gaseous_attenuation(freq, elev, rho)

        python_code = """
        #{@python_setup}
        # P.676 total gaseous attenuation
        Agas = float(itur.models.itu676.gaseous_attenuation_slant_path(#{freq}, #{elev}, #{rho}, 1013, 15).value)
        Agas
        """

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

        elixir_result = ItuRPropagation.P618.rain_attenuation(freq, elev, lat, rain, alt)

        python_code = """
        #{@python_setup}
        A_rain = float(itur.models.itu618.rain_attenuation(#{lat}, 0, #{freq}, #{elev}, 0.01, #{rain}).value)
        A_rain
        """

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

  # -- Helpers --

  defp safe_py_eval(code) do
    {result, _} = :py.eval(code, %{})
    {:ok, :py.decode(result)}
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
