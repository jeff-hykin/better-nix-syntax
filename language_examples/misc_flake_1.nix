{
    description = "A CLI tool(s) for finding old versions of nix packages!";

    inputs = {
        nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
        flakeUtils.url = "github:numtide/flake-utils";
    };

    outputs = { self, nixpkgs, flakeUtils, thing ? true }:
        flakeUtils.lib.eachDefaultSystem (system:
            let
                pkgs = nixpkgs.legacyPackages.${system};
                nvs = (pkgs.callPackage
                    (builtins.import ./default.nix)
                    {
                        _core = builtins;
                        _pkgs = pkgs;
                        _src = self;
                        system = system;
                        deno = pkgs.deno;
                        bash = pkgs.bash;
                    }
                );
            in
                {
                    packages = {
                        nvs = nvs;
                        default = nvs;
                    };
                }
        );
}
