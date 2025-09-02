- fix pkgs being "variable.other.object.access" in "(pkgs.fetchurl { inherit url sha256; })" 
- DONE: fix `with (thing);`
- DONE: fix `or` (both make it special and make the pre-thing know its not a function call)
- DONE: fix the url
- DONE: fix the following not highlighting builtins.map as a function call:
```nix
(builtins.map
)
```