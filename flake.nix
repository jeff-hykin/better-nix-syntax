{
    description = "My Project";
    inputs = {
        nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
        # nixpkgs.url = "github:NixOS/nixpkgs/6f884c2#nodejs-slim";
        # nixpkgsWithPython38.url = "https://github.com/NixOS/nixpkgs/archive/9108a20782535741433c304f6a4376cb8b364b89.tar.gz";
        nixpkgsWithNodejs16.url = "https://github.com/NixOS/nixpkgs/archive/a71323f68d4377d12c04a5410e214495ec598d4c.tar.gz";
        nixpkgsWithRuby.url = "https://github.com/NixOS/nixpkgs/archive/ebf88190cce9a092f9c7abe195548057a0273e51.tar.gz";
        xome.url = "github:jeff-hykin/xome";
    };
    outputs = { self, nixpkgs, nixpkgsWithNodejs16, nixpkgsWithRuby, xome, ... }:
        xome.superSimpleMakeHome { inherit nixpkgs; pure = true; } ({system, ...}:
            let
                setup = {
                    system = system;

                    # This is where you allow insecure/unfree packages
                    config = {
                        allowUnfree = true;
                        allowInsecure = true;
                        permittedInsecurePackages = [
                            "python-2.7.18.6"
                            "openssl-1.0.2u"
                        ];
                    };
                };
                pkgs = import nixpkgs setup;
                # pkgsWithPython38 = import nixpkgsWithPython38 setup;
                pkgsWithNodejs16 = import nixpkgsWithNodejs16 setup;
                pkgsWithRuby = import nixpkgsWithRuby setup;
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
                        pkgs.bash
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
                        pkgsWithNodejs16.nodejs # v16.15.0
                        # npm --version           8.5.5
                        # pkgsWithPython38.python38 # 3.8.13.venv
                        # pkgsWithPython38.python38Packages.setuptools
                        # pkgsWithPython38.python38Packages.pip
                        # pkgsWithPython38.python38Packages.virtualenv
                        # pkgsWithPython38.python38Packages.wheel
                        pkgsWithPython38.python2
                        pkgs.cmake
                        pkgs.pkg-config
                        pkgs.libffi
                        pkgsWithRuby.ruby.devEnv # ruby 2.7.6p219 (2022-04-12 revision c9c2245c0a) [arm64-darwin21]
                        pkgsWithRuby.bundix
                        pkgsWithRuby.sqlite
                        pkgsWithRuby.libpcap
                        pkgsWithRuby.postgresql
                        pkgs.libxml2
                        pkgs.libxslt
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
                                
                                #
                                # Ruby setup
                                #
                                export GEM_HOME="$HOME/gems.ignore/"
                                # if not setup yet, then setup ruby
                                if ! [ -d "$VAR" ]
                                then
                                    mkdir "$GEM_HOME" &>/dev/null
                                    bundix -l
                                    bundler install
                                fi
                                
                                #
                                # Npm setup
                                #
                                if ! [ -d "./node_modules" ]; then
                                    npm install
                                fi
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
