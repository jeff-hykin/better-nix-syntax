{ 
  stdenv, 
  lib, 
  makeDesktopItem, 
  unzip, 
  libsecret, 
  libXScrnSaver, 
  libxshmfence, 
  buildPackages, 
  atomEnv, 
  at-spi2-atk, 
  autoPatchelfHook, 
  systemd, 
  fontconfig, 
  libdbusmenu, 
  glib, 
  buildFHSUserEnvBubblewrap, 
  wayland, 
  tests, 
  nodePackages, 
  bash, 
  version, 
  src, 
  meta, 
  sourceRoot, 
  commandLineArgs, 
  executableName, 
  longName, 
  shortName, 
  pname, 
  updateScript, 
  dontFixup? false, 
  sourceExecutableName? executableName
}:
    let 
        fhs = { additionalPkgs ? pkgs: [] }: buildFHSUserEnvBubblewrap {
            
        };
        
    in
        unwrapped