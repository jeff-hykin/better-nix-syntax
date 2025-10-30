- DONE: fix k being marked as a method in "(attrDerivations v [ k ])" 
- DONE: fix `import nixpkgs {inherit system;};` "inherit" needs space in front of it
- DONE: fix `devShells.${system}.default = pkgs.mkShell {`
- DONE: fix pkgs being "variable.other.object.access" in "(pkgs.fetchurl { inherit url sha256; })" 
- DONE: fix `with (thing);`
- DONE: fix `or` (both make it special and make the pre-thing know its not a function call)
- DONE: fix the url
- DONE: fix the following not highlighting builtins.map as a function call:
```nix
(builtins.map
)
```