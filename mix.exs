defmodule ItuRPropagation.MixProject do
  use Mix.Project

  @version "0.5.0"
  @source_url "https://github.com/neilberkman/itu_r_propagation"

  def project do
    [
      app: :itu_r_propagation,
      version: @version,
      elixir: "~> 1.15",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      name: "ITU-R Propagation",
      description: description(),
      package: package(),
      docs: docs(),
      source_url: @source_url
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      {:ex_doc, "~> 0.34", only: :dev, runtime: false},
      {:quokka, "~> 2.12", only: [:dev, :test], runtime: false},
      {:erlang_python, "~> 2.0", only: :test}
    ]
  end

  defp description do
    """
    Pure Elixir implementation of ITU-R atmospheric propagation models for
    satellite link budget calculations. Implements P.676 (gaseous attenuation),
    P.838 (rain specific attenuation), P.618 (earth-space rain attenuation),
    and P.839 (rain height model).
    """
  end

  defp package do
    [
      licenses: ["MIT"],
      links: %{"GitHub" => @source_url}
    ]
  end

  defp docs do
    [
      main: "ItuRPropagation",
      extras: ["README.md"]
    ]
  end
end
