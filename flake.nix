# {
#     description = "My Project";
#     inputs = {
#         nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.05";
#         # nixpkgs.url = "github:NixOS/nixpkgs/6f884c2#nodejs-slim";
#         # nixpkgsWithPython38.url = "https://github.com/NixOS/nixpkgs/archive/9108a20782535741433c304f6a4376cb8b364b89.tar.gz";
#         nixpkgsWithNodejs16.url = "https://github.com/NixOS/nixpkgs/archive/a71323f68d4377d12c04a5410e214495ec598d4c.tar.gz";
#         nixpkgsWithRuby.url = "https://github.com/NixOS/nixpkgs/archive/ebf88190cce9a092f9c7abe195548057a0273e51.tar.gz";
#         xome.url = "github:jeff-hykin/xome";
#     };
#     outputs = { self, nixpkgs, nixpkgsWithNodejs16, nixpkgsWithRuby, xome, ... }:
#         xome.superSimpleMakeHome { inherit nixpkgs; pure = true; } ({system, ...}:
#             let
#                 setup = {
#                     system = system;

#                     # This is where you allow insecure/unfree packages
#                     config = {
#                         allowUnfree = true;
#                         allowInsecure = true;
#                         permittedInsecurePackages = [
#                             "python-2.7.18.8"
#                             "python-2.7.18.6"
#                             "openssl-1.0.2u"
#                         ];
#                     };
#                 };
#                 pkgs = import nixpkgs setup;
#                 # pkgsWithPython38 = import nixpkgsWithPython38 setup;
#                 pkgsWithNodejs16 = import nixpkgsWithNodejs16 setup;
#                 pkgsWithRuby = import nixpkgsWithRuby setup;
#             in
#                 {
#                     # for home-manager examples, see: https://deepwiki.com/nix-community/home-manager/5-configuration-examples
#                     # all home-manager options: https://nix-community.github.io/home-manager/options.xhtml
#                     home.homeDirectory = "/tmp/virtual_homes/xome_simple";
#                     home.stateVersion = "25.05";
#                     home.packages = [
#                         # vital stuff
#                         pkgs.nix
#                         pkgs.coreutils-full
                        
#                         # optional stuff
#                         pkgs.bash
#                         pkgs.gnugrep
#                         pkgs.findutils
#                         pkgs.wget
#                         pkgs.curl
#                         pkgs.unixtools.locale
#                         pkgs.unixtools.more
#                         pkgs.unixtools.ps
#                         pkgs.unixtools.getopt
#                         pkgs.unixtools.ifconfig
#                         pkgs.unixtools.hostname
#                         pkgs.unixtools.ping
#                         pkgs.unixtools.hexdump
#                         pkgs.unixtools.killall
#                         pkgs.unixtools.mount
#                         pkgs.unixtools.sysctl
#                         pkgs.unixtools.top
#                         pkgs.unixtools.umount
#                         pkgs.git
                        
#                         # project specific
#                         pkgsWithNodejs16.nodejs # v16.15.0
#                         # npm --version           8.5.5
#                         # pkgsWithPython38.python38 # 3.8.13.venv
#                         # pkgsWithPython38.python38Packages.setuptools
#                         # pkgsWithPython38.python38Packages.pip
#                         # pkgsWithPython38.python38Packages.virtualenv
#                         # pkgsWithPython38.python38Packages.wheel
#                         pkgs.python2
#                         pkgs.cmake
#                         pkgs.pkg-config
#                         pkgs.libffi
#                         pkgsWithRuby.ruby.devEnv # ruby 2.7.6p219 (2022-04-12 revision c9c2245c0a) [arm64-darwin21]
#                         pkgsWithRuby.bundix
#                         pkgsWithRuby.sqlite
#                         pkgsWithRuby.libpcap
#                         pkgsWithRuby.postgresql
#                         pkgs.libxml2
#                         pkgs.libxslt
#                         pkgs.gnumake
#                         pkgs.ncurses5
#                         pkgs.openssh
#                     ];
                    
#                     programs = {
#                         home-manager = {
#                             enable = true;
#                         };
#                         zsh = {
#                             enable = true;
#                             enableCompletion = true;
#                             autosuggestion.enable = true;
#                             syntaxHighlighting.enable = true;
#                             shellAliases.ll = "ls -la";
#                             history.size = 100000;
#                             # this is kinda like .zshrc
#                             initContent = ''
#                                 # this enables some impure stuff like sudo, comment it out to get FULL purity
#                                 export PATH="$PATH:/usr/bin/"
                                
#                                 #
#                                 # Ruby setup
#                                 #
#                                 export GEM_HOME="$HOME/gems.ignore/"
#                                 # if not setup yet, then setup ruby
#                                 if ! [ -d "$VAR" ]
#                                 then
#                                     mkdir "$GEM_HOME" &>/dev/null
#                                     bundix -l
#                                     bundler install
#                                 fi
                                
#                                 #
#                                 # Npm setup
#                                 #
#                                 if ! [ -d "./node_modules" ]; then
#                                     npm install
#                                 fi
#                             '';
#                         };
#                         starship = {
#                             enable = true;
#                             enableZshIntegration = true;
#                         };
#                     };
#                 }
#         );
# }


{
    description = "My Project";
    inputs = {
        libSource.url = "github:divnix/nixpkgs.lib";
        flake-utils.url = "github:numtide/flake-utils";
        nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.05";
        # nixpkgsWithPython38.url = "https://github.com/NixOS/nixpkgs/archive/9108a20782535741433c304f6a4376cb8b364b89.tar.gz";
        nixpkgsWithNodejs16.url = "https://github.com/NixOS/nixpkgs/archive/a71323f68d4377d12c04a5410e214495ec598d4c.tar.gz";
        nixpkgsWithRuby.url = "https://github.com/NixOS/nixpkgs/archive/ebf88190cce9a092f9c7abe195548057a0273e51.tar.gz";
        home-manager.url = "github:nix-community/home-manager";
        home-manager.inputs.nixpkgs.follows = "nixpkgs";
        # xome.url = "github:jeff-hykin/xome";
        
    };
    outputs = { self, libSource, nixpkgs, flake-utils, home-manager, nixpkgsWithNodejs16, nixpkgsWithRuby, ... }:
        let
            lib = builtins.trace nixpkgs.lib.trivial.version nixpkgs.lib;
            defaultEnvPassthrough = [ "NIX_SSL_CERT_FILE" "TERM" ];
            makeHomeFor = ({ overrideShell ? null, home, pure ? true, envPassthrough ? defaultEnvPassthrough, ... }@args:
                let
                    pkgs = home.pkgs;
                    shellPackageNameProbably = (
                        if (home.config.programs.zsh.enable) then
                            "zsh"
                        else if (home.config.programs.bash.enable) then
                            "bash"
                        else if (builtins.isFunction overrideShell) then
                            true
                        else
                            builtins.throw ''Sorry I don't support the shell you selected in home manager (I only support zsh and bash) However you can override this by giving xome.makeHomeFor an argument: overrideShell = system: [ "''${yourShellExecutablePath}" "--no-globalrcs" ]; ''
                    );
                    shellCommandList = (
                        if (shellPackageNameProbably == "zsh") then
                            [ "${pkgs.zsh}/bin/zsh" "--no-globalrcs" ]
                        else if (shellPackageNameProbably == "bash") then
                            [ "${pkgs.bash}/bin/bash" "--noprofile" ]
                        else if (builtins.isFunction overrideShell) then
                            (overrideShell pkgs)
                        else
                            builtins.throw ''Note: this should be unreachable, but as a fallback: Sorry I don't support the shell you selected in home manager (I only support zsh and bash at the moment). However you can override this by giving xome.makeHomeFor an argument: overrideShell = pkgs: [ "''${yourShellExecutablePath}" "--no-globalrcs" ]; ''
                    );
                    shellCommandString = "${lib.concatStringsSep " " (builtins.map lib.escapeShellArg shellCommandList)}";
                    homePath = home.config.home.homeDirectory;
                    envPassthroughFiltered = builtins.filter (envVar: envVar != "PATH" && envVar != "HOME" && envVar != "SHELL") envPassthrough;
                    envPassthroughString = lib.concatStringsSep " " (builtins.map (envVar: lib.escapeShellArg envVar + ''="$'' + envVar + ''"'') envPassthroughFiltered);
                    
                    mainCommand = (
                        if (pure) then
                            ''env -i XOME_ACTIVE=1 PATH=${lib.escapeShellArg homePath}/bin:${lib.escapeShellArg homePath}/.nix-profile/bin HOME=${lib.escapeShellArg homePath} SHELL=${lib.escapeShellArg (builtins.elemAt shellCommandList 0)} ${envPassthroughString} ${shellCommandString}''
                        else
                            ''XOME_ACTIVE=1 PATH=${lib.escapeShellArg homePath}/bin:${lib.escapeShellArg homePath}/.nix-profile/bin:"$PATH" HOME=${lib.escapeShellArg homePath} SHELL=${lib.escapeShellArg (builtins.elemAt shellCommandList 0)} ${shellCommandString}''
                    );
                in 
                    {
                        default = pkgs.mkShell {
                            packages = home.config.home.packages;
                            shellHook = ''
                                export REAL_HOME="$HOME"
                                export HOME=${lib.escapeShellArg homePath}
                                mkdir -p "$HOME/.local/state/nix/profiles"
                                # note: the grep is to remove common startup noise
                                USER="default" HOME=${lib.escapeShellArg homePath} ${home.activationPackage.out}/activate 2>&1 | ${pkgs.gnugrep}/bin/grep -v -E "Starting Home Manager activation|warning: unknown experimental feature 'repl-flake'|Activating checkFilesChanged|Activating checkLinkTargets|Activating writeBoundary|No change so reusing latest profile generation|Activating installPackages|warning: unknown experimental feature 'repl-flake'|replacing old 'home-manager-path'|installing 'home-manager-path'|Activating linkGeneration|Cleaning up orphan links from .*|Creating home file links in .*|Activating onFilesChange|Activating setupLaunchAgents"
                                ${mainCommand}
                                exit $?
                            '';
                        };
                    }
            );
            simpleMakeHomeFor = ({ pkgs, overrideShell ? null, pure ? true, envPassthrough ? defaultEnvPassthrough, homeModule,  ... }:
                makeHomeFor {
                    envPassthrough = envPassthrough;
                    overrideShell = overrideShell;
                    pure = pure;
                    home = (
                        let
                            setupModule = homeModule // {
                                home = homeModule.home // {
                                    username = "default";
                                };
                            };
                            config = {
                                # so user doesn't need to inherit pkgs every time
                                inherit pkgs;
                                modules = [
                                    setupModule
                                ];
                            };
                        in 
                            (home-manager.lib.homeManagerConfiguration 
                                config
                            )
                    );
                }
            );
            xome = {
                makeHomeFor = makeHomeFor;
                simpleMakeHomeFor = simpleMakeHomeFor;
                superSimpleMakeHome = {nixpkgs, overrideShell ? null, pure ? true, envPassthrough ? defaultEnvPassthrough}: homeConfigFunc: (flake-utils.lib.eachSystem
                    flake-utils.lib.allSystems
                    (system:
                        {
                            devShells = simpleMakeHomeFor {
                                pkgs = nixpkgs.legacyPackages.${system}; 
                                envPassthrough = envPassthrough; 
                                overrideShell = overrideShell;
                                pure = pure;
                                homeModule = (homeConfigFunc
                                    {
                                        inherit system;
                                        pkgs = nixpkgs.legacyPackages.${system};
                                    }
                                );
                            };
                        }
                    )
                );
            };
        in
            flake-utils.lib.eachSystem flake-utils.lib.allSystems (system:
                let
                    setup = {
                        system = system;

                        # This is where you allow insecure/unfree packages
                        config = {
                            allowUnfree = true;
                            allowInsecure = true;
                            permittedInsecurePackages = [
                                "python-2.7.18.8"
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
                        packages = { /* your normal flake stuff*/ };
                        devShells = xome.makeHomeFor {
                            pure = true;
                            envPassthrough = [ "NIX_SSL_CERT_FILE" "TERM" ];
                            # ^this is the default list. Could add HISTSIZE, EDITOR, etc without loosing much purity
                            home = (home-manager.lib.homeManagerConfiguration
                                {
                                    inherit pkgs;
                                    modules = [
                                        {
                                            home.username = "default"; # it NEEDS to be "default", it cant actually be 
                                            home.homeDirectory = "/tmp/virtual_homes/xome_simple";
                                            home.stateVersion = "25.05";
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
                                                pkgs.htop
                                                pkgs.ripgrep
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
                                    ];
                                }
                            );
                        };
                    }
            );
}