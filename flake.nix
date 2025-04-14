{
  description = "eshet.py";

  inputs = {
    nixpkgs.url = "nixpkgs/nixos-24.11";

    utils.url = "github:numtide/flake-utils";

    peggie_src.url = "github:mossblaser/peggie";
    peggie_src.flake = false;
  };

  outputs = { self, nixpkgs, utils, peggie_src }:
    utils.lib.eachSystem utils.lib.defaultSystems (system:
      let
        pkgs = nixpkgs.legacyPackages."${system}";
        python = pkgs.python3;
      in
      rec {
        packages.peggie = python.pkgs.buildPythonPackage rec {
          name = "peggie";
          format = "pyproject";
          src = peggie_src;

          nativeBuildInputs = with python.pkgs; [ setuptools ];

          prePatch = ''
            substituteInPlace run_mypy.sh --replace '#!/bin/bash' '#!${pkgs.stdenv.shell}'
          '';
          nativeCheckInputs = with python.pkgs; [ pytestCheckHook mypy ];

          # XXX: mypy currently fails
          disabledTests = [ "test_with_mypy" ];
        };

        # needs an older version of marko (the latest version is significantly
        # different), which doesn't build properly as the pyproject.toml
        # doesn't have some required fields, so we use the wheel
        packages.marko = python.pkgs.buildPythonPackage rec {
          pname = "marko";
          format = "wheel";
          version = "0.9.1";
          src = pkgs.fetchurl {
            url = "https://files.pythonhosted.org/packages/py2.py3/m/marko/marko-${version}-py2.py3-none-any.whl";
            hash = "sha256-9ss7BUOqcq99Uj7U7aMUegYmCKGY++ITG27ORg+6UhU=";
          };
        };

        packages.recipe_grid = python.pkgs.buildPythonPackage rec {
          name = "recipe_grid";
          format = "pyproject";
          src = ./.;
          nativeBuildInputs = with python.pkgs; [ poetry-core ];
          propagatedBuildInputs = with python.pkgs; [
            lxml
            packages.marko
            jinja2
            packages.peggie
          ];
          nativeCheckInputs = with python.pkgs; [ pytestCheckHook mypy ];

          pythonRelaxDeps = [ "lxml" ];

          prePatch = ''
            substituteInPlace run_mypy.sh --replace '#!/bin/bash' '#!${pkgs.stdenv.shell}'
          '';

          # XXX: mypy currently fails
          disabledTests = [ "test_with_mypy" ];

          meta.mainProgram = "recipe-grid";
        };

        defaultPackage = packages.recipe_grid;

        apps.recipe-grid = {
          type = "app";
          program = "${packages.recipe_grid}/bin/recipe-grid";
        };

        apps.recipe-grid-lint = {
          type = "app";
          program = "${packages.recipe_grid}/bin/recipe-grid-lint";
        };

        apps.recipe-grid-site = {
          type = "app";
          program = "${packages.recipe_grid}/bin/recipe-grid-site";
        };
      }
    );
}
