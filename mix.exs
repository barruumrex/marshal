defmodule Marshal.Mixfile do
  use Mix.Project

  @version "0.9.0"
  @source "https://github.com/barruumrex/marshal"

  def project do
    [
      app: :marshal,
      version: @version,
      elixir: "~> 1.3.0",
      deps: deps(),
      description: description(),
      package: package(),
      source_url: @source,
      docs: [source_ref: "v#{@version}", main: "Marshal"],
    ]
  end

  # Configuration for the OTP application
  #
  # Type "mix help compile.app" for more information
  def application do
    [applications: [:logger]]
  end

  # Dependencies can be Hex packages:
  #
  #   {:mydep, "~> 0.3.0"}
  #
  # Or git/path repositories:
  #
  #   {:mydep, git: "https://github.com/elixir-lang/mydep.git", tag: "0.1.0"}
  #
  # Type "mix help deps" for more examples and options
  defp deps do
    [
      {:benchee, "~> 0.2", only: :dev},
      {:credo, "~> 0.4.3", only: :dev},

      {:ex_doc, "~> 0.12.0", only: :dev},
      {:inch_ex, "~> 0.5.3", only: :dev},
    ]
  end

  defp description do
    """
    Parser for Ruby Marshal format version 4.8
    """
  end

  defp package do
    [
      name: :marshal,
      files: ["lib", "mix.exs", "README.md", "LICENSE.md"],
      maintainers: ["Dylan Spencer"],
      licenses: ["MIT"],
      links: %{github: @source}
    ]
  end
end
