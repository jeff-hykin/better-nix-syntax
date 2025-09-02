{
    description = "Vix: virtual home environments powered nix";
    inputs = {
        libSource.url = "github:divnix/nixpkgs.lib";
        flake-utils.url = "github:numtide/flake-utils";
        nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
        home-manager.url = "github:nix-community/home-manager";
        home-manager.inputs.nixpkgs.follows = "nixpkgs";
        xome.url = "github:jeff-hykin/xome";
        # home-manager.inputs.nixpkgs.follows = "nixpkgs";
    };
    outputs = { self, libSource, flake-utils, home-manager, xome, ... }:
        let
            # 
            # generic helpers
            # 
                lib = libSource.lib;
                core = builtins; # this weird trick is so that builtins can be overridden by the user
                getDeep = (path: attrs:
                    builtins.foldl'
                    (acc: key:
                        if acc ? ${key} then acc.${key} else throw "path ${toString path} not found in ${toString attrs}"
                    )
                    attrs
                    path
                );
                isUrl = (str:
                    builtins.any (prefix: builtins.hasPrefix prefix str) [
                        "http://"
                        "https://"
                        "ftp://"
                        "file://"
                    ]
                );
                mkSystemAttrList = supportedSystems: whateverFunc: (builtins.listToAttrs 
                    (builtins.map
                        (eachSystem: {
                            name = eachSystem;
                            value = whateverFunc eachSystem;
                        })
                        supportedSystems
                    )
                );
                # embedded here cause I couldn't get around this problem:
                #       while evaluating attribute 'shellHook' of derivation 'nix-shell'
                #          at /nix/store/agbbjxvdcp9dydmrn2hf3s652k547rbc-source/pkgs/build-support/mkshell/default.nix:53:5:
                #          52|
                #          53|     shellHook = lib.concatStringsSep "\n" (
                #              |     ^
                #          54|       lib.catAttrs "shellHook" (lib.reverseList inputsFrom ++ [ attrs ])
                #      error: attribute 'lib' missing
                makeMkShell = (stdenv:
                    # A special kind of derivation that is only meant to be consumed by the
                    # nix-shell.
                    {
                        name ? "nix-shell",
                        # a list of packages to add to the shell environment
                        packages ? [ ],
                        # propagate all the inputs from the given derivations
                        inputsFrom ? [ ],
                        buildInputs ? [ ],
                        nativeBuildInputs ? [ ],
                        propagatedBuildInputs ? [ ],
                        propagatedNativeBuildInputs ? [ ],
                        ...
                    }@attrs:
                        let
                            mergeInputs =
                                name:
                                (attrs.${name} or [ ])
                                ++
                                    # 1. get all `{build,nativeBuild,...}Inputs` from the elements of `inputsFrom`
                                    # 2. since that is a list of lists, `flatten` that into a regular list
                                    # 3. filter out of the result everything that's in `inputsFrom` itself
                                    # this leaves actual dependencies of the derivations in `inputsFrom`, but never the derivations themselves
                                    (lib.subtractLists inputsFrom (lib.flatten (lib.catAttrs name inputsFrom)));

                            rest = builtins.removeAttrs attrs [
                                "name"
                                "packages"
                                "inputsFrom"
                                "buildInputs"
                                "nativeBuildInputs"
                                "propagatedBuildInputs"
                                "propagatedNativeBuildInputs"
                                "shellHook"
                            ];
                        in

                        stdenv.mkDerivation (
                            {
                                inherit name;

                                buildInputs = mergeInputs "buildInputs";
                                nativeBuildInputs = packages ++ (mergeInputs "nativeBuildInputs");
                                propagatedBuildInputs = mergeInputs "propagatedBuildInputs";
                                propagatedNativeBuildInputs = mergeInputs "propagatedNativeBuildInputs";

                                shellHook = lib.concatStringsSep "\n" (
                                    lib.catAttrs "shellHook" (lib.reverseList inputsFrom ++ [ attrs ])
                                );

                                phases = [ "buildPhase" ];

                                buildPhase = ''
                                    { echo "------------------------------------------------------------";
                                        echo " WARNING: the existence of this path is not guaranteed.";
                                        echo " It is an internal implementation detail for pkgs.mkShell.";
                                        echo "------------------------------------------------------------";
                                        echo;
                                        # Record all build inputs as runtime dependencies
                                        export;
                                    } >> "$out"
                                '';

                                preferLocalBuild = true;
                            }
                            // rest
                        )
                );
                
                #
                # vix 1.0
                #
                
                # prefixing a trace is harder than you think because of additional traces that happen when evaluating the value (thus making prints appear out of order)
                # this tries to fix that
                noValue = { a= b: b; };
                print = (input1: returnValue: 
                    let
                        input1IsAttrs = builtins.isAttrs input1;  
                        prefix = if input1IsAttrs then input1.prefix or null else input1;
                        postfix = if input1IsAttrs then input1.postfix or null else null;
                        val = if input1IsAttrs then input1.val or noValue else noValue;
                        
                        printValue = if val == noValue then returnValue else val;
                        ending = (builtins.trace
                            printValue
                            (if postfix == null then
                                returnValue
                            else
                                (builtins.trace
                                    postfix
                                    returnValue
                                )
                            )
                        );
                    in
                        if prefix == null then
                            ending
                        else
                            (builtins.trace
                                (if (builtins.tryEval printValue).success then
                                    prefix+":"
                                else
                                    returnValue # if it fails its going to throw anyways and not get here
                                )
                                ending
                            )
                );
                hasDeepAttribute = (
                    let
                        hasDeepAttributeInner = (attrSet: path:
                            (builtins.foldl'
                                (acc: key:
                                    if acc != null && builtins.isAttrs acc && builtins.hasAttr key acc then
                                        acc.${key}
                                    else
                                        null
                                )
                                attrSet
                                (if (path != null && builtins.isList path) then path else [])
                            )
                        );
                    in
                        # Final result is: was the value resolved to something non-null?
                        attrSet: path: hasDeepAttributeInner attrSet path != null
                );
                getDeepAttribute = (attrSet: path:
                    (builtins.foldl'
                        (acc: key:
                            if acc != null && builtins.isAttrs acc && builtins.hasAttr key acc then
                                acc.${key}
                            else
                                null
                        )
                        attrSet
                        path
                    )
                );
                mergeActions = (actions:
                    let
                        # this is a kind of "magic attrSet" e.g. an attrSet that only equal to itself (because of the function attribute)
                        # we are going to use this to check if the value in a key-value pair is the result of a mergeTool (and therefore needs to be evaluated)
                        mergeToolResultIdentifier = { f=x: x; };
                        mergeToolDeleteIdentifier = { f=x: x; };
                        
                        # checker
                        isMergeToolResult = attrSet: builtins.isAttrs attrSet && (builtins.hasAttr "mergeToolResultIdentifier" attrSet) && attrSet.mergeToolResultIdentifier == mergeToolResultIdentifier;
                        
                        # make sure all the mergeToolResults are evaluated
                        recursiveEvaluateMergeToolResults = (maybeAttrSet: path:
                            if !(builtins.isAttrs (maybeAttrSet)) then
                                maybeAttrSet
                            # TODO: consider exploring/evaling lists too (revisit once merging-of-lists is supported)
                            else
                                let
                                    shallowEvaled = (
                                        if (isMergeToolResult maybeAttrSet) then
                                            maybeAttrSet.eval path
                                        else
                                            maybeAttrSet
                                    );
                                in
                                    if !(builtins.isAttrs shallowEvaled) then
                                        shallowEvaled
                                    else 
                                        (builtins.foldl'
                                            (accumulator: keyGettingMerged:
                                                accumulator // {
                                                    ${keyGettingMerged} = (recursiveEvaluateMergeToolResults
                                                        shallowEvaled.${keyGettingMerged}
                                                        (path ++ [ keyGettingMerged ])
                                                    ); 
                                                }
                                            )
                                            shallowEvaled
                                            (builtins.attrNames shallowEvaled)
                                        )
                        );
                        
                        # this should be called before putting something on the accumulator or giving a value to the user
                        recursiveRemoveDeleteKeys = (maybeAttrSet:
                            if maybeAttrSet == mergeToolDeleteIdentifier then
                                # NOTE: this shouldn't happen / be allowed it would mean mergeTools.delete was used incorrectly (top level)
                                #       consider making this an error
                                null
                            else if !builtins.isAttrs maybeAttrSet then
                                maybeAttrSet
                            # TODO: consider exploring/evaling lists too (revisit once merging-of-lists is supported)
                            else
                                let
                                    keysToDelete = (builtins.filter
                                        (key: maybeAttrSet.${key} == mergeToolDeleteIdentifier)
                                        (builtins.attrNames maybeAttrSet)
                                    );
                                    withoutDeleteKeys = builtins.removeAttrs maybeAttrSet keysToDelete;
                                    deepEval = (builtins.foldl'
                                        (accumulator: keyGettingMerged:
                                            accumulator // {
                                                ${keyGettingMerged} = (recursiveRemoveDeleteKeys
                                                    withoutDeleteKeys.${keyGettingMerged}
                                                ); 
                                            }
                                        )
                                        withoutDeleteKeys
                                        (builtins.attrNames withoutDeleteKeys)
                                    );
                                in
                                    deepEval
                        );
                        
                        # a helper for making mergeTools
                        # prev is the previous whole attrSet (e.g. the accumulator)
                        # mergeToolFunction needs to accept an argument of { valueExisted, attrPathOldValue } and return the new value for that attribute
                        # attrSetPath will be given by the recursiveMerge evaluator (at the very end)
                        makeMergeToolResult = (accumulator: mergeToolFunction:
                            {
                                inherit mergeToolResultIdentifier; # this is how we can identify this attrSet is special and not just a user-provided value
                                eval = (attrSetPath:
                                    mergeToolFunction {
                                        valueExisted = hasDeepAttribute accumulator attrSetPath;
                                        prevValue = getDeepAttribute accumulator attrSetPath;
                                    }
                                );
                            }
                        );
                        
                        # TODO: warn on merge when there is an overwrite 
                        recursiveMerge = ({oldValue, newValue, path ? []}:
                            let
                                newValueResult = (
                                    if (isMergeToolResult newValue) then
                                        newValue.eval path
                                    else
                                        newValue
                                );
                            in
                                (recursiveEvaluateMergeToolResults 
                                    (
                                        # note this check NEEDS to be on newValue NOT newValueResult
                                        # a merge tool value always wins (it will handle merging)
                                        # if (print {prefix="path0";val=path;} ((print {prefix="oldValue0";val=oldValue;}) ((print {prefix="newValue0";val=newValue;}) (isMergeToolResult newValue)))) then
                                        if (isMergeToolResult newValue) then
                                            (recursiveRemoveDeleteKeys newValueResult)
                                        # TODO: this is where list-merging should be added in the future
                                        # if either is non-attrSet, new value wins
                                        else if (!(builtins.isAttrs oldValue) || !(builtins.isAttrs newValueResult)) then
                                            (recursiveRemoveDeleteKeys newValueResult)
                                        # if both are normal attrSets, then merge
                                        # (it should* be impossible for oldValue to be a mergeToolResult)
                                        else
                                            let
                                                allKeys = (builtins.attrNames newValueResult);
                                                keysToDelete = (builtins.filter
                                                    (key: newValueResult.${key} == mergeToolDeleteIdentifier)
                                                    allKeys
                                                );
                                                keysToCheck = (builtins.filter
                                                    (key: newValueResult.${key} != mergeToolDeleteIdentifier)
                                                    allKeys
                                                );
                                                oldValueAfterDeletingKeys = (builtins.removeAttrs oldValue keysToDelete);
                                            in 
                                                (builtins.foldl'
                                                    (accumulator: keyGettingMerged:
                                                        let
                                                            innerOldValueExists = builtins.hasAttr keyGettingMerged accumulator;
                                                            innerOldValue = accumulator.${keyGettingMerged};
                                                            innerNewValue = newValueResult.${keyGettingMerged};
                                                            oldValue = (if innerOldValueExists then accumulator.${keyGettingMerged} else null);
                                                        in
                                                            accumulator // {
                                                                ${keyGettingMerged} = (recursiveMerge {
                                                                    oldValue = oldValue;
                                                                    newValue = innerNewValue;
                                                                    path = (path ++ [ keyGettingMerged ]);
                                                                });
                                                            }
                                                    )
                                                    oldValueAfterDeletingKeys
                                                    keysToCheck
                                                )
                                    )
                                    path
                                )
                        );
                    in
                        intialValue: (builtins.foldl'
                            (accumulator: action:
                                let
                                    # then, somehow, get a list of these magic attrSets into a recursive evaluator (e.g. like recursiveMerge) that detects those magic attrSets and gives them the attrPath
                                    mergeTools = {
                                        # mergeTools.override
                                        override = (newValue: makeMergeToolResult accumulator ({ valueExisted, prevValue }:
                                            # always give new value, (e.g. skip merge)
                                            newValue
                                        ));
                                        # mergeTools.noChange
                                        noChange = (makeMergeToolResult accumulator ({ valueExisted, prevValue }:
                                            # always give prevValue. This is used in if statements. Ex: (if system == "x86_64-linux" then 10 else mergeTools.noChange)
                                            prevValue
                                        ));
                                        # mergeTools.softMerge
                                        softMerge = (newValue: makeMergeToolResult accumulator ({ valueExisted, prevValue }:
                                            if valueExisted then
                                                prevValue
                                            else
                                                newValue
                                        ));
                                        # this technically isn't a mergeToolResult, its its own special value and needs special handling
                                        delete = mergeToolDeleteIdentifier;
                                        # TODO: mergeTools.appendToFront        # for list merging
                                        # TODO: mergeTools.appendToBack         # for list merging
                                        # TODO: mergeTools.splice start length  # for list merging (splice will handle removal and injection) have it support negative start
                                    };
                                    next = action accumulator mergeTools;
                                in
                                    (recursiveMerge { oldValue=accumulator; newValue=next; path=[]; })
                            )
                            intialValue # Initial value of `accumulator`
                            actions
                        )
                );
            # 
            # vix specifics
            # 
                # input names
                    # system
                    # targetType
                    # targetName
                    # targetId
                    
                    # config.projectName
                    # config.supportedSystems
                    # configVix.[...options]
                    # warehouses.default
                    # warehouses.<name>
                    # configPackage.<name>
                    
                    # configShell.homeConfig.[...options]
                    # configShell.[...options]
                    # env.<EnvVarName>
                    # outputShell.<name>
                    # outputPackage.<name>
                    # outputApp.<name>
                superStructToFlake = (superStruct:
                    let
                        # NOTE: this is an important value
                        trivialInput = {
                            system = "none";
                            targetType = null;
                            targetName = null;
                            targetId = null;
                            
                            warehouses = {};
                            configPackage = {};
                            configShell = {};
                            
                            # default shell
                            outputShell.default = organizedInputs@{devShellInputs}: (xome.makeHomeFor {
                                pure = true;
                                envPassthrough = [ "NIX_SSL_CERT_FILE" "TERM" "XOME_REAL_HOME" "XOME_REAL_PATH" ];
                                # ^this is the default list. Could add HISTSIZE, EDITOR, etc without loosing much purity
                                home = (home-manager.lib.homeManagerConfiguration
                                    {
                                        pkgs = organizedInputs.nixpkgs; 
                                        modules = [
                                            {
                                                home.username = "default"; # it NEEDS to be "default", it cant actually be 
                                                home.homeDirectory = "/tmp/virtual_homes/xome_simple";
                                                home.stateVersion = "25.11";
                                                home.packages = [
                                                    # vital stuff
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
                            });
                        };
                        initalOutput = superStruct trivialInput;
                        supportedSystems = initalOutput.config.supportedSystems or flake-utils.lib.allSystems;
                        systemSpecificOutput = flake-utils.lib.eachSystem supportedSystems (system:
                            let 
                                systemSuperStruct = superStruct { inherit system; };
                                # output shell and output package names
                                outputShellNames   = (builtins.attrNames (systemSuperStruct.outputShell   or {}));
                                outputPackageNames = (builtins.attrNames (systemSuperStruct.outputPackage or {}));
                                outputAppNames     = (builtins.attrNames (systemSuperStruct.outputApp     or {}));
                                
                                shellOutputTargets = (builtins.map
                                    (eachName: { targetType = "shell"; targetName = eachName; targetId = "shell:${eachName}"; })
                                    outputShells
                                );
                                packageOutputTargets = (builtins.map
                                    (each: { targetType = "package"; targetName = eachName; targetId = "package:${eachName}"; })
                                    outputPackageNames
                                );
                                appOutputTargets = (builtins.map
                                    (each: { targetType = "app"; targetName = eachName; targetId = "app:${eachName}"; })
                                    outputAppNames
                                );
                                outputTargets = shellOutputTargets ++ packageOutputTargets ++ appOutputTargets;
                                # we are going to build the input for those
                                outputValues = (builtins.map
                                    (eachOutput: eachOutput // {
                                        value = (
                                            let 
                                                rawSuperStruct = (superStruct (eachOutput // { inherit system; }));
                                                packageConfigs = (builtins.map
                                                    (each:
                                                        {
                                                            # default values of configPackage are defined here
                                                            derivation             = each.derivation             or null;
                                                            # TODO: add warning on missing derivation
                                                            isEmpty                = ((each.derivation or null) == null) || (builtins.length (builtins.attrNames eachPackageConfig) == 0);
                                                            isBuildInput           = eachPackageConfig.asBuildInput           or true;
                                                            isNativeBuildInput     = eachPackageConfig.asNativeBuildInput     or false;
                                                            isPropagatedBuildInput = eachPackageConfig.asPropagatedBuildInput or false;
                                                            isDevShellInput        = eachPackageConfig.asDevShellInput        or true;
                                                            isAppInput             = eachPackageConfig.asAppInput             or true;
                                                        }
                                                    )
                                                    (builtins.attrValues rawSuperStruct.configPackage)
                                                );
                                                buildInputs = (builtins.filter
                                                    (configPackage: 
                                                        !configPackage.isEmpty && configPackage.isBuildInput
                                                    )
                                                    packageConfigs
                                                );
                                                propagatedBuildInputs = (builtins.filter
                                                    (configPackage: 
                                                        !configPackage.isEmpty && configPackage.isPropagatedBuildInput
                                                    )
                                                    packageConfigs
                                                );
                                                nativeBuildInputs = (builtins.filter
                                                    (configPackage: 
                                                        !configPackage.isEmpty && configPackage.isNativeBuildInput
                                                    )
                                                    packageConfigs
                                                );
                                                devShellInputs = (builtins.filter
                                                    (configPackage: 
                                                        !configPackage.isEmpty && configPackage.isDevShellInput
                                                    )
                                                    packageConfigs
                                                );
                                                appInputs = (builtins.filter
                                                    (configPackage: 
                                                        !configPackage.isEmpty && configPackage.isAppInput
                                                    )
                                                    packageConfigs
                                                );
                                                organizedInputs = rawSuperStruct // {
                                                    buildInputs           = (builtins.map (each: each.derivation) buildInputs           );
                                                    propagatedBuildInputs = (builtins.map (each: each.derivation) propagatedBuildInputs );
                                                    nativeBuildInputs     = (builtins.map (each: each.derivation) nativeBuildInputs     );
                                                    devShellInputs        = (builtins.map (each: each.derivation) devShellInputs        );
                                                    appInputs             = (builtins.map (each: each.derivation) appInputs             );
                                                };
                                                mkShellOrMkDerivationOutput = (
                                                    if eachOutput.targetType == "shell" then
                                                        (systemSuperStruct.outputShell.${eachOutput.targetName} organizedInputs)
                                                    else
                                                        (systemSuperStruct.outputPackage.${eachOutput.targetName} organizedInputs)
                                                );
                                            in
                                                mkShellOrMkDerivationOutput
                                        );
                                    })
                                    outputTargets
                                );
                            in
                                # this gets fed to the flake-utils.lib.eachSystem
                                {
                                    devShells = (builtins.listToAttrs
                                        (builtins.map
                                            (each: each.value)
                                            (builtins.filter
                                                (each: each.targetType == "shell")
                                                outputValues
                                            )
                                        )
                                    );
                                    packages = (builtins.listToAttrs
                                        (builtins.map
                                            (each: each.value)
                                            (builtins.filter
                                                (each: each.targetType == "package")
                                                outputValues
                                            )
                                        )
                                    );
                                    apps = (builtins.listToAttrs
                                        (builtins.map
                                            (each: each.value)
                                            (builtins.filter
                                                (each: each.targetType == "app")
                                                outputValues
                                            )
                                        )
                                    );
                                }
                        );
                    in
                        systemSpecificOutput
                );
                setup = ({ nixpkgs, projectName, warehouses, localPackages, builtins ? core, ... }:
                    {
                        inherit nixpkgs projectName warehouses localPackages;
                        builtins = assert builtins.isString projectName; builtins;
                        load = (system:
                            let
                                defaultWarehouse = nixpkgs.legacyPackages.${system};
                                unEvaledPackages = localPackages;
                                warehouseToPkgs = eachWarehouse: (
                                    (builtins.import
                                        # import source
                                        (
                                            if (builtins.hasAttr eachWarehouse "tarFileUrl") then
                                                defaultWarehouse.fetchTarball (
                                                    if (builtins.hasAttr eachWarehouse "sha256") then
                                                        { url = eachWarehouse.tarFileUrl; sha256 = eachWarehouse.sha256; }
                                                    else
                                                        { url = eachWarehouse.tarFileUrl; }
                                                )
                                            # TODO: add support for fetchFromGit, and other methods
                                            else if (builtins.isString eachWarehouse) then
                                                if (isUrl eachWarehouse) then
                                                    defaultWarehouse.fetchTarball { url = eachWarehouse; }
                                                else
                                                    # assume nixpkgs hash
                                                    defaultWarehouse.fetchTarball { url = "https://github.com/NixOS/nixpkgs/archive/${eachWarehouse}.tar.gz"; }  
                                            else if (builtins.hasAttr eachWarehouse "gitHubInfo") then
                                                defaultWarehouse.fetchFromGitHub (eachWarehouse.gitHubInfo)
                                                # {
                                                #     owner = eachWarehouse.owner;
                                                #     repo = eachWarehouse.repo;
                                                #     rev = eachWarehouse.rev;
                                                #     sha256 = eachWarehouse.sha256;
                                                # }
                                            else
                                                builtins.throw "unsupported warehouse. Needs a tarFileUrl, or gitHubInfo (owner, repo, rev, and a sha256)"
                                        )
                                        # config
                                        {
                                            system = system;
                                            # overlays = [ ];
                                            # 
                                        } // (eachWarehouse.config or {})
                                    )
                                );
                                # TODO: probably use a set instead of a list
                                warehousesByName = (builtins.listToAttrs
                                    (builtins.map
                                        (eachWarehouse:
                                            {
                                                name = eachWarehouse.name;
                                                value = (warehouseToPkgs eachWarehouse);
                                            }
                                        )
                                        warehouses
                                    )
                                ) // { default = defaultWarehouse; };
                                
                                packagesForThisSystem = (builtins.filter
                                    (eachPackage:
                                        let
                                            defaultOnlyIf = { system, ... }: true;
                                            onlyIf = eachPackage.onlyIf or defaultOnlyIf;
                                        in
                                            (onlyIf {inherit system;})
                                    )
                                    unEvaledPackages
                                );
                                evalPackage = (eachPackage:
                                    # TODO: add limiter here to wrap/filter bins and ENV vars
                                    # maybe also add a shellHook to enable stuff like zsh plugins
                                    if (builtins.isString eachPackage.from) then
                                        let
                                            warehouse = (builtins.getAttr eachPackage.from warehousesByName);
                                        in
                                            (getDeep eachPackage.package warehouse )
                                    else if (builtins.isAttrs eachPackage.from) then
                                        # TODO: probably have vix auto-hoist and give them misc names instead of allowing inline hooks
                                        (getDeep eachPackage.package (warehouseToPkgs eachPackage.from))
                                    else
                                        builtins.throw "unsupported package. Needs a string or attrset"
                                );
                                
                                buildInputs = (builtins.map
                                    evalPackage
                                    (builtins.filter
                                        (each: 
                                            # asBuildInput is kinda redundant, but it's allowed for the edgecase of something that needs to be both a buildInput and a nativeBuildInput
                                            each.asBuildInput or (
                                                !(
                                                    (each.asNativeBuildInput or false)
                                                    && (each.asPropagatedBuildInput or false)
                                                )
                                            )
                                        )
                                        packagesForThisSystem
                                    )
                                );
                                
                                nativeBuildInputs = (builtins.map
                                    evalPackage
                                    (builtins.filter
                                        (each: each.asNativeBuildInput or false)
                                        packagesForThisSystem
                                    )
                                );
                                
                                propagatedBuildInputs = (builtins.map
                                    evalPackage
                                    (builtins.filter
                                        (each: each.asPropagatedBuildInput or false)
                                        packagesForThisSystem
                                    )
                                );
                                
                                packagesByName = (builtins.listToAttrs
                                    (builtins.map
                                        (eachPackage:
                                            {
                                                name = eachPackage.name;
                                                value = evalPackage eachPackage;
                                            }
                                        )
                                        packagesForThisSystem
                                    )
                                );
                            in
                                {
                                    inherit warehousesByName;
                                    packageList = packagesForThisSystem;
                                    pkgs = packagesByName;
                                    inherit buildInputs nativeBuildInputs propagatedBuildInputs;
                                    defaultWarehouse = defaultWarehouse;
                                }
                        );
                    }
                );
                
                mkShells = {
                    vixBuilder,
                    supportedSystems,
                    homeManagerConfigFunc ? {system, vixBuilt ? (vixBuilder.load system), ... }: 
                        {
                            inherit (vixBuilt) pkgs;
                            modules = [
                                {
                                    home.username = "default";
                                    home.homeDirectory = "/tmp/vix_homes/${vixBuilder.projectName}";
                                    home.stateVersion = "25.11"; # vixBuilder.nixpkgs.rev;

                                    programs = {
                                        home-manager = {
                                            enable = true;
                                        };
                                        zsh = {
                                            enable = true;
                                            package = vixBuilt.pkgs.zsh;
                                            enableCompletion = true;
                                            autosuggestion.enable = true;
                                            syntaxHighlighting.enable = true;
                                            shellAliases = {
                                                ll = "ls -la";
                                            };
                                            history = {
                                                size = 100000;  # large history size
                                                save = 100000;
                                                share = true;
                                                ignoreDups = true;
                                                extended = true;
                                            };
                                            initContent = ''
                                                setopt HIST_IGNORE_ALL_DUPS
                                                setopt HIST_REDUCE_BLANKS
                                                setopt HIST_VERIFY
                                                setopt SHARE_HISTORY
                                                setopt INC_APPEND_HISTORY
                                                setopt INTERACTIVE_COMMENTS

                                                # Handy options
                                                setopt AUTO_CD
                                                setopt CORRECT
                                                setopt NO_BEEP

                                                # Set LS_COLORS using dircolors
                                                if command -v dircolors &> /dev/null; then
                                                    eval "$(dircolors -b)"
                                                fi

                                                # Enable Powerlevel10k if selected
                                                [[ -f ${vixBuilt.pkgs.zsh}/share/zsh/site-functions/p10k.zsh ]] && source ${vixBuilt.pkgs.zsh}/share/zsh/site-functions/p10k.zsh
                                            '';
                                        };
                                        starship = {
                                            enable = true;
                                            enableZshIntegration = true;
                                            settings = {
                                                add_newline = false;
                                                # prompt_order = [
                                                #     "username"
                                                #     "hostname"
                                                #     "directory"
                                                #     "git_branch"
                                                #     "git_status"
                                                #     "cmd_duration"
                                                #     "line_break"
                                                #     "jobs"
                                                #     "character"
                                                # ];
                                                character = {
                                                    success_symbol = "[∫](bold green)";
                                                    error_symbol = "[✗](bold red)";
                                                };
                                            };
                                        };
                                    };
                                    
                                    # vix is primairly for home-setup stuff
                                    home.packages = [ vixBuilt.defaultWarehouse.coreutils ] ++ builtins.attrValues vixBuilt.pkgs;
                                }
                            ];
                        },
                    overrideShell ? null,
                    builtins ? core,
                }:
                    (mkSystemAttrList 
                        supportedSystems
                        (system:
                            let
                                vixBuilt = (vixBuilder.load system);
                                homeBaseConfig = (homeManagerConfigFunc { inherit system vixBuilt; });
                                # make sure lib ends up in pkgs (even though thats not great, I'd have to fork home-manager to fix it)
                                homeConfig = homeBaseConfig // { 
                                    pkgs = { 
                                        lib = lib;
                                        inherit (vixBuilt.defaultWarehouse) path config overlays stdenv;
                                    } // homeBaseConfig.pkgs; 
                                };
                                home = (home-manager.lib.homeManagerConfiguration 
                                    homeConfig
                                );
                                shellPackageNameProbably = (
                                    if (home.config.programs.zsh.enable) then
                                        "zsh"
                                    else if (home.config.programs.bash.enable) then
                                        "bash"
                                    else if (builtins.isFunction overrideShell) then
                                        true
                                    else
                                        builtins.throw ''Sorry I don't support the shell you selected in home manager (I only support zsh and bash) However you can override this by giving vix an argument: overrideShell = system: [ "''${yourShellExecutablePath}" "--no-globalrcs" ]; ''
                                );
                                shellCommandList = (
                                    if (shellPackageNameProbably == "zsh") then
                                        [ "${home.pkgs.zsh}/bin/zsh" "--no-globalrcs" ]
                                    else if (shellPackageNameProbably == "bash") then
                                        [ "${home.pkgs.bash}/bin/bash" "--noprofile" ]
                                    else if (builtins.isFunction overrideShell) then
                                        (overrideShell system)
                                    else
                                        builtins.throw ''Note: this should be unreachable, but as a fallback: Sorry I don't support the shell you selected in home manager (I only support zsh and bash at the moment). However you can override this by giving vix an argument: overrideShell = system: [ "''${yourShellExecutablePath}" "--no-globalrcs" ]; ''
                                );
                                shellCommandString = "${lib.concatStringsSep " " (builtins.map lib.escapeShellArg shellCommandList)}";
                                homePath = home.config.home.homeDirectory;
                            in 
                                {
                                    default = (makeMkShell vixBuilt.defaultWarehouse.stdenv) {
                                        inherit (vixBuilt) buildInputs nativeBuildInputs propagatedBuildInputs;
                                        # FIXME: ENV vars
                                        # FIXME: PATH modifications/limiter
                                        shellHook = ''
                                            export REAL_HOME="$HOME"
                                            export HOME=${lib.escapeShellArg homePath}
                                            mkdir -p "$HOME/.local/state/nix/profiles"
                                            # note: the grep is to remove common startup noise
                                            USER="default" HOME=${lib.escapeShellArg homePath} ${home.activationPackage.out}/activate 2>&1 | ${vixBuilt.defaultWarehouse.gnugrep}/bin/grep -v -E "Starting Home Manager activation|warning: unknown experimental feature 'repl-flake'|Activating checkFilesChanged|Activating checkLinkTargets|Activating writeBoundary|No change so reusing latest profile generation|Activating installPackages|warning: unknown experimental feature 'repl-flake'|replacing old 'home-manager-path'|installing 'home-manager-path'|Activating linkGeneration|Cleaning up orphan links from .*|Creating home file links in .*|Activating onFilesChange|Activating setupLaunchAgents"
                                            env -i VIX_ACTIVE=1 PATH=${lib.escapeShellArg homePath}/bin:${lib.escapeShellArg homePath}/.nix-profile/bin HOME=${lib.escapeShellArg homePath} USER="$USER" SHELL=${lib.escapeShellArg (builtins.elemAt shellCommandList 0)} TERM="$TERM" ${shellCommandString}
                                            exit $?
                                        '';
                                    };
                                }
                        )
                    ) // {
                        _vix = vixBuilder; # for introspection
                    }
                ;
        in
            {
                inherit setup mkShells print mergeActions getDeepAttribute hasDeepAttribute;
            }
    ;
}