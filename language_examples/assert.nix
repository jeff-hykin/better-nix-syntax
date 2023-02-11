/* Impure default args for `pkgs/top-level/default.nix`. See that file
   for the meaning of each argument. */


let

    homeDir = builtins.getEnv "HOME";

    # Return ‘x’ if it evaluates, or ‘def’ if it throws an exception.
    try = x: def: let res = builtins.tryEval x; in if res.success then res.value else def;

in

{ 
  localSystem? { system = args.system or builtins.currentSystem; }, 
  system? localSystem.system, 
  crossSystem? localSystem, 
  config? let
            configFile = builtins.getEnv "NIXPKGS_CONFIG";
            configFile2 = homeDir + "/.config/nixpkgs/config.nix";
            configFile3 = homeDir + "/.nixpkgs/config.nix"; 
        in
            if configFile != "" && builtins.pathExists configFile then import configFile
            else if homeDir != "" && builtins.pathExists configFile2 then import configFile2
            else if homeDir != "" && builtins.pathExists configFile3 then import configFile3
            else {},
  overlays? let
            isDir = path: builtins.pathExists (path + "/.");
            pathOverlays = try (toString <nixpkgs-overlays>) "";
            homeOverlaysFile = homeDir + "/.config/nixpkgs/overlays.nix";
            homeOverlaysDir = homeDir + "/.config/nixpkgs/overlays";
            overlays = path:

                if isDir path then

                    let content = builtins.readDir path; in 
                    map (n: import (path + ("/" + n)))
                        (builtins.filter
                            (n:
                                (builtins.match ".*\\.nix" n != null &&

                 builtins.match "\\.#.*" n == null) ||
                                builtins.pathExists (path + ("/" + n + "/default.nix")))
                            (builtins.attrNames content))
                else

                    import path;
        in
            
            
            if pathOverlays != "" && builtins.pathExists pathOverlays then overlays pathOverlays
            else if builtins.pathExists homeOverlaysFile && builtins.pathExists homeOverlaysDir then
                throw ''
                    Nixpkgs overlays can be specified with ${homeOverlaysFile} or ${homeOverlaysDir}, 
                    but not both.
                    Please remove one of them and try again.
                ''
            else if builtins.pathExists homeOverlaysFile then
                if isDir homeOverlaysFile then
                    throw (homeOverlaysFile + " should be a file")
                else overlays homeOverlaysFile
            else if builtins.pathExists homeOverlaysDir then
                if !(isDir homeOverlaysDir) then
                    throw (homeOverlaysDir + " should be a directory")
                else overlays homeOverlaysDir
            else [], 
    crossOverlays? [],
    ...
}:

    # If `localSystem` was explicitly passed, legacy `system` should
    # not be passed, and vice-versa.
    assert args ? localSystem -> !(args ? system);
    assert args ? system -> !(args ? localSystem);

    import ./. (builtins.removeAttrs args [ "system" ] // {
        inherit config overlays localSystem;
    })

