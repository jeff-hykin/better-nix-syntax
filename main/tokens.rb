require "walk_up"
require_relative walk_up_until("paths.rb")
require_relative PathFor[:textmate_tools]

# 
# Create tokens
#
tokens = [
    # keywords
    { representation: "if"      , areKeywords: true },
    { representation: "then"    , areKeywords: true },
    { representation: "else"    , areKeywords: true },
    { representation: "assert"  , areKeywords: true },
    { representation: "with"    , areKeywords: true },
    { representation: "let"     , areKeywords: true },
    { representation: "in"      , areKeywords: true },
    { representation: "rec"     , areKeywords: true },
    
    # operators
    { representation: "-"       , areOperators: true, priority: 3,  name: "neg"      , associtivity: :none , },
    { representation: "?"       , areOperators: true, priority: 4,  name: "has_attr" , associtivity: :none , },
    { representation: "++"      , areOperators: true, priority: 5,  name: "concat"   , associtivity: :right, },
    { representation: "*"       , areOperators: true, priority: 6,  name: "mul"      , associtivity: :left , },
    { representation: "/"       , areOperators: true, priority: 6,  name: "div"      , associtivity: :left , },
    { representation: "+"       , areOperators: true, priority: 7,  name: "add"      , associtivity: :left , },
    { representation: "-"       , areOperators: true, priority: 7,  name: "sub"      , associtivity: :left , },
    { representation: "!"       , areOperators: true, priority: 8,  name: "not"      , associtivity: :left , },
    { representation: "//"      , areOperators: true, priority: 9,  name: "update"   , associtivity: :right, },
    { representation: "<"       , areOperators: true, priority: 10, name: "lt"       , associtivity: :left , },
    { representation: "<="      , areOperators: true, priority: 10, name: "lte"      , associtivity: :left , },
    { representation: ">"       , areOperators: true, priority: 10, name: "gt"       , associtivity: :left , },
    { representation: ">="      , areOperators: true, priority: 10, name: "gte"      , associtivity: :left , },
    { representation: "=="      , areOperators: true, priority: 11, name: "eq"       , associtivity: :none , },
    { representation: "!="      , areOperators: true, priority: 11, name: "neq"      , associtivity: :none , },
    { representation: "&&"      , areOperators: true, priority: 12, name: "and"      , associtivity: :left , },
    { representation: "||"      , areOperators: true, priority: 13, name: "or"       , associtivity: :left , },
    { representation: "->"      , areOperators: true, priority: 14, name: "impl"     , associtivity: :none , },
    
    # builtin values
    { representation: "langVersion",                    areBuiltinAttributes: true, areFunctions: false, impure: true },
    { representation: "false",                          areBuiltinAttributes: true, areFunctions: false, canAppearTopLevel: true, },
    { representation: "true",                           areBuiltinAttributes: true, areFunctions: false, canAppearTopLevel: true, },
    { representation: "nixPath",                        areBuiltinAttributes: true, areFunctions: false, impure: true },
    { representation: "nixVersion",                     areBuiltinAttributes: true, areFunctions: false, impure: true },
    { representation: "null",                           areBuiltinAttributes: true, areFunctions: false, canAppearTopLevel: true, },
    { representation: "storeDir",                       areBuiltinAttributes: true, areFunctions: false, impure: true },
    { representation: "currentTime",                    areBuiltinAttributes: true, areFunctions: false, impure: true },
    { representation: "currentSystem",                  areBuiltinAttributes: true, areFunctions: false, impure: true },
    # builtin functions
    { representation: "abort",                          areBuiltinAttributes: true, areFunctions: true, canAppearTopLevel: true, },
    { representation: "add",                            areBuiltinAttributes: true, areFunctions: true, },
    { representation: "addErrorContext",                areBuiltinAttributes: true, areFunctions: true, },
    { representation: "all",                            areBuiltinAttributes: true, areFunctions: true, },
    { representation: "any",                            areBuiltinAttributes: true, areFunctions: true, },
    { representation: "appendContext",                  areBuiltinAttributes: true, areFunctions: true, },
    { representation: "attrNames",                      areBuiltinAttributes: true, areFunctions: true, },
    { representation: "attrValues",                     areBuiltinAttributes: true, areFunctions: true, },
    { representation: "baseNameOf",                     areBuiltinAttributes: true, areFunctions: true, canAppearTopLevel: true, },
    { representation: "bitAnd",                         areBuiltinAttributes: true, areFunctions: true, },
    { representation: "bitOr",                          areBuiltinAttributes: true, areFunctions: true, },
    { representation: "bitXor",                         areBuiltinAttributes: true, areFunctions: true, },
    { representation: "break",                          areBuiltinAttributes: true, areFunctions: true, },
    { representation: "catAttrs",                       areBuiltinAttributes: true, areFunctions: true, },
    { representation: "ceil",                           areBuiltinAttributes: true, areFunctions: true, },
    { representation: "compareVersions",                areBuiltinAttributes: true, areFunctions: true, },
    { representation: "concatLists",                    areBuiltinAttributes: true, areFunctions: true, },
    { representation: "concatMap",                      areBuiltinAttributes: true, areFunctions: true, },
    { representation: "concatStringsSep",               areBuiltinAttributes: true, areFunctions: true, },
    { representation: "deepSeq",                        areBuiltinAttributes: true, areFunctions: true, },
    { representation: "derivation",                     areBuiltinAttributes: true, areFunctions: true, canAppearTopLevel: true, },
    { representation: "derivationStrict",               areBuiltinAttributes: true, areFunctions: true, canAppearTopLevel: true, },
    { representation: "dirOf",                          areBuiltinAttributes: true, areFunctions: true, canAppearTopLevel: true, },
    { representation: "div",                            areBuiltinAttributes: true, areFunctions: true, },
    { representation: "elem",                           areBuiltinAttributes: true, areFunctions: true, },
    { representation: "elemAt",                         areBuiltinAttributes: true, areFunctions: true, },
    { representation: "fetchGit",                       areBuiltinAttributes: true, areFunctions: true, canAppearTopLevel: true, },
    { representation: "fetchMercurial",                 areBuiltinAttributes: true, areFunctions: true, canAppearTopLevel: true, },
    { representation: "fetchTarball",                   areBuiltinAttributes: true, areFunctions: true, canAppearTopLevel: true, },
    { representation: "fetchTree",                      areBuiltinAttributes: true, areFunctions: true, },
    { representation: "fetchurl",                       areBuiltinAttributes: true, areFunctions: true, },
    { representation: "filter",                         areBuiltinAttributes: true, areFunctions: true, },
    { representation: "filterSource",                   areBuiltinAttributes: true, areFunctions: true, },
    { representation: "findFile",                       areBuiltinAttributes: true, areFunctions: true, dirty: true, },
    { representation: "floor",                          areBuiltinAttributes: true, areFunctions: true, },
    { representation: "foldl'",                         areBuiltinAttributes: true, areFunctions: true, },
    { representation: "fromJSON",                       areBuiltinAttributes: true, areFunctions: true, },
    { representation: "fromTOML",                       areBuiltinAttributes: true, areFunctions: true, canAppearTopLevel: true, },
    { representation: "functionArgs",                   areBuiltinAttributes: true, areFunctions: true, },
    { representation: "genericClosure",                 areBuiltinAttributes: true, areFunctions: true, },
    { representation: "genList",                        areBuiltinAttributes: true, areFunctions: true, },
    { representation: "getAttr",                        areBuiltinAttributes: true, areFunctions: true, },
    { representation: "getContext",                     areBuiltinAttributes: true, areFunctions: true, },
    { representation: "getEnv",                         areBuiltinAttributes: true, areFunctions: true, dirty: true, },
    { representation: "groupBy",                        areBuiltinAttributes: true, areFunctions: true, },
    { representation: "hasAttr",                        areBuiltinAttributes: true, areFunctions: true, },
    { representation: "hasContext",                     areBuiltinAttributes: true, areFunctions: true, },
    { representation: "hashFile",                       areBuiltinAttributes: true, areFunctions: true, },
    { representation: "hashString",                     areBuiltinAttributes: true, areFunctions: true, },
    { representation: "head",                           areBuiltinAttributes: true, areFunctions: true, },
    { representation: "import",                         areBuiltinAttributes: true, areFunctions: true, canAppearTopLevel: true, },
    { representation: "intersectAttrs",                 areBuiltinAttributes: true, areFunctions: true, },
    { representation: "isAttrs",                        areBuiltinAttributes: true, areFunctions: true, },
    { representation: "isBool",                         areBuiltinAttributes: true, areFunctions: true, },
    { representation: "isFloat",                        areBuiltinAttributes: true, areFunctions: true, },
    { representation: "isFunction",                     areBuiltinAttributes: true, areFunctions: true, },
    { representation: "isInt",                          areBuiltinAttributes: true, areFunctions: true, },
    { representation: "isList",                         areBuiltinAttributes: true, areFunctions: true, },
    { representation: "isNull",                         areBuiltinAttributes: true, areFunctions: true, canAppearTopLevel: true, },
    { representation: "isPath",                         areBuiltinAttributes: true, areFunctions: true, },
    { representation: "isString",                       areBuiltinAttributes: true, areFunctions: true, },
    { representation: "length",                         areBuiltinAttributes: true, areFunctions: true, },
    { representation: "lessThan",                       areBuiltinAttributes: true, areFunctions: true, },
    { representation: "listToAttrs",                    areBuiltinAttributes: true, areFunctions: true, },
    { representation: "map",                            areBuiltinAttributes: true, areFunctions: true, canAppearTopLevel: true, },
    { representation: "mapAttrs",                       areBuiltinAttributes: true, areFunctions: true, },
    { representation: "match",                          areBuiltinAttributes: true, areFunctions: true, },
    { representation: "mul",                            areBuiltinAttributes: true, areFunctions: true, },
    { representation: "parseDrvName",                   areBuiltinAttributes: true, areFunctions: true, },
    { representation: "partition",                      areBuiltinAttributes: true, areFunctions: true, },
    { representation: "path",                           areBuiltinAttributes: true, areFunctions: true, },
    { representation: "pathExists",                     areBuiltinAttributes: true, areFunctions: true, dirty: true, },
    { representation: "placeholder",                    areBuiltinAttributes: true, areFunctions: true, canAppearTopLevel: true, },
    { representation: "readDir",                        areBuiltinAttributes: true, areFunctions: true, dirty: true, },
    { representation: "readFile",                       areBuiltinAttributes: true, areFunctions: true, dirty: true, },
    { representation: "removeAttrs",                    areBuiltinAttributes: true, areFunctions: true, canAppearTopLevel: true, },
    { representation: "replaceStrings",                 areBuiltinAttributes: true, areFunctions: true, },
    { representation: "scopedImport",                   areBuiltinAttributes: true, areFunctions: true, canAppearTopLevel: true, },
    { representation: "seq",                            areBuiltinAttributes: true, areFunctions: true, },
    { representation: "sort",                           areBuiltinAttributes: true, areFunctions: true, },
    { representation: "split",                          areBuiltinAttributes: true, areFunctions: true, },
    { representation: "splitVersion",                   areBuiltinAttributes: true, areFunctions: true, },
    { representation: "storePath",                      areBuiltinAttributes: true, areFunctions: true, },
    { representation: "stringLength",                   areBuiltinAttributes: true, areFunctions: true, },
    { representation: "sub",                            areBuiltinAttributes: true, areFunctions: true, },
    { representation: "substring",                      areBuiltinAttributes: true, areFunctions: true, },
    { representation: "tail",                           areBuiltinAttributes: true, areFunctions: true, },
    { representation: "throw",                          areBuiltinAttributes: true, areFunctions: true, canAppearTopLevel: true, },
    { representation: "toFile",                         areBuiltinAttributes: true, areFunctions: true, },
    { representation: "toJSON",                         areBuiltinAttributes: true, areFunctions: true, },
    { representation: "toPath",                         areBuiltinAttributes: true, areFunctions: true, },
    { representation: "toString",                       areBuiltinAttributes: true, areFunctions: true, canAppearTopLevel: true, },
    { representation: "toXML",                          areBuiltinAttributes: true, areFunctions: true, },
    { representation: "trace",                          areBuiltinAttributes: true, areFunctions: true, impure: true },
    { representation: "traceVerbose",                   areBuiltinAttributes: true, areFunctions: true, impure: true  },
    { representation: "tryEval",                        areBuiltinAttributes: true, areFunctions: true, },
    { representation: "typeOf",                         areBuiltinAttributes: true, areFunctions: true, },
    { representation: "unsafeDiscardOutputDependency",  areBuiltinAttributes: true, areFunctions: true, },
    { representation: "unsafeDiscardStringContext",     areBuiltinAttributes: true, areFunctions: true, },
    { representation: "unsafeGetAttrPos",               areBuiltinAttributes: true, areFunctions: true, },
    { representation: "zipAttrsWith",                   areBuiltinAttributes: true, areFunctions: true, canAppearTopLevel: true, },
]

# automatically add some adjectives (functional adjectives)
@tokens = TokenHelper.new tokens, for_each_token: ->(each) do 
    # isSymbol, isWordish
    if each[:representation] =~ /[a-zA-Z0-9_]/
        each[:isWordish] = true
    else
        each[:isSymbol] = true
    end
    # isWord
    if each[:representation] =~ /\A[a-zA-Z_][a-zA-Z0-9_]*\z/
        each[:isWord] = true
    end
    
    if each[:isTypeSpecifier] or each[:isStorageSpecifier]
        each[:isPossibleStorageSpecifier] = true
    end
end