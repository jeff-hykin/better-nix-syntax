{
    description = "My Project";
    inputs = {
        nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.05";
        xome.url = "github:jeff-hykin/xome";
    };
    outputs = { self, nixpkgs, nixpkgsWithNodejs18, nixpkgsWithRuby, xome, ... }:
        xome.superSimpleMakeHome { inherit nixpkgs; pure = true; } ({system, ...}:
            let
                setup = {
                    system = system;

                    # This is where you allow insecure/unfree packages
                    config = {
                        allowUnfree = true;
                    };
                };
                a = hello.trace "a" 1;
                pkgs = import nixpkgs setup;
                # pkgsWithPython38 = import nixpkgsWithPython38 setup;
                pkgsWithNodejs18 = import nixpkgsWithNodejs18 setup;
                pkgsWithRuby = import nixpkgsWithRuby setup;
            in
                {}
        );
}
                {
                    # for home-manager examples, see: https://deepwiki.com/nix-community/home-manager/5-configuration-examples
                    # all home-manager options: https://nix-community.github.io/home-manager/options.xhtml
                    home.homeDirectory = "/tmp/virtual_homes/xome_simple";
                    home.stateVersion = "25.05";
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
                        pkgs.jq
                        pkgsWithNodejs18.nodejs
                        pkgs.python2
                        pkgs.cmake
                        pkgs.pkg-config
                        pkgs.libffi
                        pkgsWithRuby.ruby.devEnv # ruby 2.7.8
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