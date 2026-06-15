defmodule Data.MixProject do
  use Mix.Project

  @version "0.6.0"
  @source_url "https://github.com/well-ironed/data"

  def project do
    [
      app: :data,
      deps: deps(),
      description: "Extensions to Elixir data structures",
      docs: docs(),
      elixir: "~> 1.7",
      package: package(),
      start_permanent: Mix.env() == :prod,
      version: @version
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false},
      {:error, "~> 0.3"},
      {:ex_doc, "~> 0.38.2", only: :dev, runtime: false},
      {:fe, "~> 0.1.5"}
    ]
  end

  defp docs do
    [
      main: "readme",
      extras: ["README.md"],
      source_ref: @version,
      source_url: @source_url
    ]
  end

  defp package do
    [
      licenses: ["MIT"],
      links: %{"GitHub" => @source_url}
    ]
  end
end
