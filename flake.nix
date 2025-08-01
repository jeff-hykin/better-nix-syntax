{
    description = "My Project";
    inputs = {
        nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
        nixpkgsWithPython38.url = "https://github.com/NixOS/nixpkgs/archive/9108a20782535741433c304f6a4376cb8b364b89.tar.gz";
        xome.url = "github:jeff-hykin/xome";
    };
    outputs = { self, nixpkgs, nixpkgsWithPython38, xome, ... }:
        xome.superSimpleMakeHome { inherit nixpkgs; pure = true; } ({pkgs, system, ...}:
            let
                pkgsWithPython38 = import nixpkgsWithPython38 {
                    system = system;

                    # This is where you allow insecure/unfree packages
                    config = {
                        allowUnfree = true;
                        allowInsecure = true;
                    };
                };
            in
                {
                    # for home-manager examples, see: https://deepwiki.com/nix-community/home-manager/5-configuration-examples
                    # all home-manager options: https://nix-community.github.io/home-manager/options.xhtml
                    home.homeDirectory = "/tmp/virtual_homes/xome_simple";
                    home.stateVersion = "25.11";
                    home.packages = [
                        # vital stuff
                        pkgs.nix
                        pkgs.coreutils-full
                        
                        # optional stuff
                        pkgs.gnugrep
                        pkgs.findutils
                        pkgs.wget
                        pkgs.curl
                        pkgs.unixtools.locale
                        pkgs.unixtools.more
                        pkgs.unixtools.ps
                        pkgs.unixtools.getopt
                        pkgs.unixtools.ifconfig
                        pkgs.unixtools.hostname
                        pkgs.unixtools.ping
                        pkgs.unixtools.hexdump
                        pkgs.unixtools.killall
                        pkgs.unixtools.mount
                        pkgs.unixtools.sysctl
                        pkgs.unixtools.top
                        pkgs.unixtools.umount
                        pkgs.git
                        
                        # project specific
                        pkgs.nodejs 
                        pkgsWithPython38.legacyPackages.${system}.python38
                        pkgsWithPython38.legacyPackages.${system}.python38Packages.setuptools
                        pkgsWithPython38.legacyPackages.${system}.python38Packages.pip
                        pkgsWithPython38.legacyPackages.${system}.python38Packages.virtualenv
                        pkgsWithPython38.legacyPackages.${system}.python38Packages.wheel
                        pkgsWithPython38.python2
                        pkgs.cmake
                        pkgs.pkg-config
                        pkgs.libffi
                        pkgs.ruby.devEnv
                        pkgs.sqlite
                        pkgs.libpcap
                        pkgs.postgresql
                        pkgs.libxml2
                        pkgs.libxslt
                        pkgs.pkg-config
                        pkgs.bundix
                        pkgs.gnumake
                        pkgs.ncurses5
                        pkgs.openssh
                    ];
                    
                    programs = {
                        home-manager = {
                            enable = true;
                        };
                        zsh = {
                            enable = true;
                            enableCompletion = true;
                            autosuggestion.enable = true;
                            syntaxHighlighting.enable = true;
                            shellAliases.ll = "ls -la";
                            history.size = 100000;
                            # this is kinda like .zshrc
                            initContent = ''
                                # this enables some impure stuff like sudo, comment it out to get FULL purity
                                export PATH="$PATH:/usr/bin/"
                            '';
                        };
                        starship = {
                            enable = true;
                            enableZshIntegration = true;
                        };
                    };
                }
        );
}
