{
  description = "My Project";
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.05";
    home-manager.url = "github:nix-community/home-manager/release-25.05";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
  };
  outputs = { self, nixpkgs,home-manager, xome, ... }:
    xome.superSimpleMakeHome { inherit nixpkgs; pure = true; } ({system, ...}:
      {
        setup.someShell = pkgs.mkShell {
          name = "demo-shell";
        
          # Bash highlighting?
          shellHook = ''
            echo "🔧 Entering the demo development shell"
            # Define some environment variables
            export PROJECT_ENV=development
            export PATH="$PWD/scripts:$PATH"
            my-helper() {
              echo "🧪 Running helper with args: $@"
            }
        
            # if name_of_command exists
            if ! [ -n "$(command -v "name_of_command")" ]
            then
                echo 
            fi
          '';
          
          buildInputs = [
            pkgs.git
            pkgs.nodejs
          ];
        };
        home = {
          # home-manager example
          home.homeDirectory = "/tmp/virtual_homes/xome_simple";
          home.stateVersion = "25.05";
          home.packages = [
            # vital stuff
            pkgs.nix
            pkgs.coreutils-full
            
            # optional stuff
            pkgs.bash pkgs.gnugrep pkgs.findutils pkgs.wget
            pkgs.curl pkgs.unixtools.locale
            pkgs.unixtools.more pkgs.unixtools.ps
            pkgs.unixtools.getopt pkgs.unixtools.ifconfig
            pkgs.unixtools.hostname pkgs.unixtools.ping
            pkgs.unixtools.hexdump pkgs.unixtools.killall
            pkgs.unixtools.mount pkgs.unixtools.sysctl
            pkgs.unixtools.top pkgs.unixtools.umount pkgs.git
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
        };
    });
}