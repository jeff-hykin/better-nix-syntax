- DONE: fix `or` (both make it special and make the pre-thing know its not a function call)
- fix the following not highlighting builtins.map as a function call:
```nix
(builtins.map
)
```