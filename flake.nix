
{
  description = "OCaml library for constraint-based Hindley-Milner type inference.";

  inputs = {
    nixpkgs.url = github:NixOS/nixpkgs/nixos-20.09;
  };

  outputs = { self, nixpkgs }:
    let
      system           = "x86_64-linux";
      pkgs             = nixpkgs.legacyPackages.${system};
      git-ignore       = pkgs.nix-gitignore.gitignoreSourcePure;

      inferno-pkg      = { stdenv, buildDunePackage, pprint }: buildDunePackage rec {
        pname = "inferno";
        version = "20201104";
        src = git-ignore [ ./.gitignore ] ./.;

        minimumOcamlVersion = "4.08";
        doCheck = true;

        buildInputs = [
          pprint
        ];

        meta = {
          homepage = "https://gitlab.inria.fr/fpottier/inferno";
          description = "OCaml library for constraint-based Hindley-Milner type inference.";
          license = stdenv.lib.licenses.mit;
          maintainers = with stdenv.lib.maintainers; [ dwarfmaster ];
        };
      };
    in rec {
      overlay = final: prev: {
        ocaml-ng = prev.ocaml-ng // rec {
          ocamlPackages_4_08 = prev.ocaml-ng.ocamlPackages_4_08.overrideScope' (self: super: {
            inferno = inferno-pkg { inherit (pkgs) stdenv; inherit (super) buildDunePackage pprint; };
          });
          ocamlPackages_4_09 = prev.ocaml-ng.ocamlPackages_4_09.overrideScope' (self: super: {
            inferno = inferno-pkg { inherit (pkgs) stdenv; inherit (super) buildDunePackage pprint; };
          });
          ocamlPackages_4_10 = prev.ocaml-ng.ocamlPackages_4_10.overrideScope' (self: super: {
            inferno = inferno-pkg { inherit (pkgs) stdenv; inherit (super) buildDunePackage pprint; };
          });
          ocamlPackages_4_11 = prev.ocaml-ng.ocamlPackages_4_11.overrideScope' (self: super: {
            inferno = inferno-pkg { inherit (pkgs) stdenv; inherit (super) buildDunePackage pprint; };
          });
          ocamlPackages_4_12 = prev.ocaml-ng.ocamlPackages_4_12.overrideScope' (self: super: {
            inferno = inferno-pkg { inherit (pkgs) stdenv; inherit (super) buildDunePackage pprint; };
          });
          ocamlPackages_latest = ocamlPackages_4_11;
          ocamlPackages = ocamlPackages_4_10;
        };
      };
      defaultPackage.${system} = (import nixpkgs { inherit system; overlays = [ overlay ]; }).ocaml-ng.ocamlPackages.inferno;
    };
}

