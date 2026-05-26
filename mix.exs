defmodule FSST.MixProject do
  use Mix.Project

  @source_url "https://github.com/elixir-vibe/fsst"
  @version "0.1.2"

  def project do
    [
      app: :fsst,
      version: @version,
      elixir: "~> 1.19",
      start_permanent: Mix.env() == :prod,
      name: "FSST",
      description:
        "Fast Static Symbol Tables compression for Elixir with an optional Rustler backend",
      package: package(),
      docs: docs(),
      deps: deps(),
      aliases: aliases(),
      source_url: @source_url,
      homepage_url: @source_url
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  def cli do
    [
      preferred_envs: [ci: :test]
    ]
  end

  defp deps do
    [
      {:benchee, "~> 1.5", only: :dev, runtime: false},
      {:ex_doc, "~> 0.34", only: :dev, runtime: false},
      {:ex_slop, "~> 0.4", only: [:dev, :test], runtime: false},
      {:reach, "~> 2.0", only: [:dev, :test], runtime: false},
      {:rustler, "~> 0.38", optional: true, runtime: false},
      {:rustler_precompiled, "~> 0.8"},
      {:ex_dna, "~> 1.0", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.0", only: [:dev, :test], runtime: false},
      {:credo, "~> 1.0", only: [:dev, :test], runtime: false},
      {:vibe_kit, "~> 0.1", only: [:dev, :test], runtime: false},
      {:igniter, "~> 0.6", only: [:dev, :test], runtime: false}
    ]
  end

  defp package do
    [
      licenses: ["MIT"],
      files:
        ~w(lib native/fsst_nif/src native/fsst_nif/Cargo.toml native/fsst_nif/Cargo.lock .formatter.exs mix.exs README.md LICENSE checksum-*.exs),
      links: %{
        "GitHub" => @source_url,
        "fsst-rs" => "https://docs.rs/fsst-rs/latest/fsst/",
        "Paper" => "https://www.vldb.org/pvldb/vol13/p2649-boncz.pdf"
      }
    ]
  end

  defp docs do
    [
      main: "FSST",
      extras: ["README.md", "LICENSE"],
      source_ref: "v#{@version}",
      source_url: @source_url
    ]
  end

  defp aliases() do
    [
      ci: [
        "compile --warnings-as-errors",
        "format --check-formatted",
        "test",
        "credo --strict",
        "dialyzer",
        "ex_dna --max-clones 0",
        "reach.check --arch --smells"
      ]
    ]
  end
end
