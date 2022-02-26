defmodule Data.MixProject do
  use Mix.Project

  def project do
    [
      app: :data,
      deps: deps(),
      description: "Extensions to Elixir data structures",
      docs: docs(),
      elixir: "~> 1.7",
      package: package(),
      start_permanent: Mix.env() == :prod,
      version: "0.4.7"
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      {:dialyxir, "~> 0.5.1", only: [:dev, :test], runtime: false},
      {:error, "~> 0.3.1"},
      {:ex_doc, "~> 0.21.2", only: :dev, runtime: false},
      # TODO: use newest fe in this an in error
      {:fe, github: "well-ironed/fe", branch: :master, override: true}
    ]
  end

  defp docs do
    [
      main: "readme",
      extras: ["README.md"]
    ]
  end

  defp package do
    [
      licenses: ["MIT"],
      links: %{"GitHub" => "https://github.com/well-ironed/data"}
    ]
  end
end
