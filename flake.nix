{
    description = "My Project";
    inputs = {
        nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
        xome.url = "github:jeff-hykin/xome";
    };
    outputs = { self, nixpkgs, xome, ... }:
        xome.superSimpleMakeHome { inherit nixpkgs; pure = true; } ({pkgs, ...}:
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
                    pkgs.python38
                    pkgs.python38Packages.setuptools
                    pkgs.python38Packages.pip
                    pkgs.python38Packages.virtualenv
                    pkgs.python38Packages.wheel
                    pkgs.python2
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
