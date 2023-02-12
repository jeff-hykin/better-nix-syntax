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
    { representation: "langVersion",                    areBuiltinAttributes: true, isFunction: false, },
    { representation: "false",                          areBuiltinAttributes: true, isFunction: false, },
    { representation: "true",                           areBuiltinAttributes: true, isFunction: false, },
    { representation: "nixPath",                        areBuiltinAttributes: true, isFunction: false, },
    { representation: "nixVersion",                     areBuiltinAttributes: true, isFunction: false, },
    { representation: "null",                           areBuiltinAttributes: true, isFunction: false, },
    { representation: "storeDir",                       areBuiltinAttributes: true, isFunction: false, },
    { representation: "currentTime",                    areBuiltinAttributes: true, isFunction: false, },
    { representation: "currentSystem",                  areBuiltinAttributes: true, isFunction: false, },
    # builtin functions
    { representation: "abort",                          areBuiltinAttributes: true, isFunction: true, },
    { representation: "add",                            areBuiltinAttributes: true, isFunction: true, },
    { representation: "addErrorContext",                areBuiltinAttributes: true, isFunction: true, },
    { representation: "all",                            areBuiltinAttributes: true, isFunction: true, },
    { representation: "any",                            areBuiltinAttributes: true, isFunction: true, },
    { representation: "appendContext",                  areBuiltinAttributes: true, isFunction: true, },
    { representation: "attrNames",                      areBuiltinAttributes: true, isFunction: true, },
    { representation: "attrValues",                     areBuiltinAttributes: true, isFunction: true, },
    { representation: "baseNameOf",                     areBuiltinAttributes: true, isFunction: true, },
    { representation: "bitAnd",                         areBuiltinAttributes: true, isFunction: true, },
    { representation: "bitOr",                          areBuiltinAttributes: true, isFunction: true, },
    { representation: "bitXor",                         areBuiltinAttributes: true, isFunction: true, },
    { representation: "break",                          areBuiltinAttributes: true, isFunction: true, },
    { representation: "catAttrs",                       areBuiltinAttributes: true, isFunction: true, },
    { representation: "ceil",                           areBuiltinAttributes: true, isFunction: true, },
    { representation: "compareVersions",                areBuiltinAttributes: true, isFunction: true, },
    { representation: "concatLists",                    areBuiltinAttributes: true, isFunction: true, },
    { representation: "concatMap",                      areBuiltinAttributes: true, isFunction: true, },
    { representation: "concatStringsSep",               areBuiltinAttributes: true, isFunction: true, },
    { representation: "deepSeq",                        areBuiltinAttributes: true, isFunction: true, },
    { representation: "derivation",                     areBuiltinAttributes: true, isFunction: true, },
    { representation: "derivationStrict",               areBuiltinAttributes: true, isFunction: true, },
    { representation: "dirOf",                          areBuiltinAttributes: true, isFunction: true, },
    { representation: "div",                            areBuiltinAttributes: true, isFunction: true, },
    { representation: "elem",                           areBuiltinAttributes: true, isFunction: true, },
    { representation: "elemAt",                         areBuiltinAttributes: true, isFunction: true, },
    { representation: "fetchGit",                       areBuiltinAttributes: true, isFunction: true, },
    { representation: "fetchMercurial",                 areBuiltinAttributes: true, isFunction: true, },
    { representation: "fetchTarball",                   areBuiltinAttributes: true, isFunction: true, },
    { representation: "fetchTree",                      areBuiltinAttributes: true, isFunction: true, },
    { representation: "fetchurl",                       areBuiltinAttributes: true, isFunction: true, },
    { representation: "filter",                         areBuiltinAttributes: true, isFunction: true, },
    { representation: "filterSource",                   areBuiltinAttributes: true, isFunction: true, },
    { representation: "findFile",                       areBuiltinAttributes: true, isFunction: true, },
    { representation: "floor",                          areBuiltinAttributes: true, isFunction: true, },
    { representation: "foldl'",                         areBuiltinAttributes: true, isFunction: true, },
    { representation: "fromJSON",                       areBuiltinAttributes: true, isFunction: true, },
    { representation: "fromTOML",                       areBuiltinAttributes: true, isFunction: true, },
    { representation: "functionArgs",                   areBuiltinAttributes: true, isFunction: true, },
    { representation: "genericClosure",                 areBuiltinAttributes: true, isFunction: true, },
    { representation: "genList",                        areBuiltinAttributes: true, isFunction: true, },
    { representation: "getAttr",                        areBuiltinAttributes: true, isFunction: true, },
    { representation: "getContext",                     areBuiltinAttributes: true, isFunction: true, },
    { representation: "getEnv",                         areBuiltinAttributes: true, isFunction: true, },
    { representation: "groupBy",                        areBuiltinAttributes: true, isFunction: true, },
    { representation: "hasAttr",                        areBuiltinAttributes: true, isFunction: true, },
    { representation: "hasContext",                     areBuiltinAttributes: true, isFunction: true, },
    { representation: "hashFile",                       areBuiltinAttributes: true, isFunction: true, },
    { representation: "hashString",                     areBuiltinAttributes: true, isFunction: true, },
    { representation: "head",                           areBuiltinAttributes: true, isFunction: true, },
    { representation: "import",                         areBuiltinAttributes: true, isFunction: true, },
    { representation: "intersectAttrs",                 areBuiltinAttributes: true, isFunction: true, },
    { representation: "isAttrs",                        areBuiltinAttributes: true, isFunction: true, },
    { representation: "isBool",                         areBuiltinAttributes: true, isFunction: true, },
    { representation: "isFloat",                        areBuiltinAttributes: true, isFunction: true, },
    { representation: "isFunction",                     areBuiltinAttributes: true, isFunction: true, },
    { representation: "isInt",                          areBuiltinAttributes: true, isFunction: true, },
    { representation: "isList",                         areBuiltinAttributes: true, isFunction: true, },
    { representation: "isNull",                         areBuiltinAttributes: true, isFunction: true, },
    { representation: "isPath",                         areBuiltinAttributes: true, isFunction: true, },
    { representation: "isString",                       areBuiltinAttributes: true, isFunction: true, },
    { representation: "length",                         areBuiltinAttributes: true, isFunction: true, },
    { representation: "lessThan",                       areBuiltinAttributes: true, isFunction: true, },
    { representation: "listToAttrs",                    areBuiltinAttributes: true, isFunction: true, },
    { representation: "map",                            areBuiltinAttributes: true, isFunction: true, },
    { representation: "mapAttrs",                       areBuiltinAttributes: true, isFunction: true, },
    { representation: "match",                          areBuiltinAttributes: true, isFunction: true, },
    { representation: "mul",                            areBuiltinAttributes: true, isFunction: true, },
    { representation: "parseDrvName",                   areBuiltinAttributes: true, isFunction: true, },
    { representation: "partition",                      areBuiltinAttributes: true, isFunction: true, },
    { representation: "path",                           areBuiltinAttributes: true, isFunction: true, },
    { representation: "pathExists",                     areBuiltinAttributes: true, isFunction: true, },
    { representation: "placeholder",                    areBuiltinAttributes: true, isFunction: true, },
    { representation: "readDir",                        areBuiltinAttributes: true, isFunction: true, },
    { representation: "readFile",                       areBuiltinAttributes: true, isFunction: true, },
    { representation: "removeAttrs",                    areBuiltinAttributes: true, isFunction: true, },
    { representation: "replaceStrings",                 areBuiltinAttributes: true, isFunction: true, },
    { representation: "scopedImport",                   areBuiltinAttributes: true, isFunction: true, },
    { representation: "seq",                            areBuiltinAttributes: true, isFunction: true, },
    { representation: "sort",                           areBuiltinAttributes: true, isFunction: true, },
    { representation: "split",                          areBuiltinAttributes: true, isFunction: true, },
    { representation: "splitVersion",                   areBuiltinAttributes: true, isFunction: true, },
    { representation: "storePath",                      areBuiltinAttributes: true, isFunction: true, },
    { representation: "stringLength",                   areBuiltinAttributes: true, isFunction: true, },
    { representation: "sub",                            areBuiltinAttributes: true, isFunction: true, },
    { representation: "substring",                      areBuiltinAttributes: true, isFunction: true, },
    { representation: "tail",                           areBuiltinAttributes: true, isFunction: true, },
    { representation: "throw",                          areBuiltinAttributes: true, isFunction: true, },
    { representation: "toFile",                         areBuiltinAttributes: true, isFunction: true, },
    { representation: "toJSON",                         areBuiltinAttributes: true, isFunction: true, },
    { representation: "toPath",                         areBuiltinAttributes: true, isFunction: true, },
    { representation: "toString",                       areBuiltinAttributes: true, isFunction: true, },
    { representation: "toXML",                          areBuiltinAttributes: true, isFunction: true, },
    { representation: "trace",                          areBuiltinAttributes: true, isFunction: true, },
    { representation: "traceVerbose",                   areBuiltinAttributes: true, isFunction: true, },
    { representation: "tryEval",                        areBuiltinAttributes: true, isFunction: true, },
    { representation: "typeOf",                         areBuiltinAttributes: true, isFunction: true, },
    { representation: "unsafeDiscardOutputDependency",  areBuiltinAttributes: true, isFunction: true, },
    { representation: "unsafeDiscardStringContext",     areBuiltinAttributes: true, isFunction: true, },
    { representation: "unsafeGetAttrPos",               areBuiltinAttributes: true, isFunction: true, },
    { representation: "zipAttrsWith",                   areBuiltinAttributes: true, isFunction: true, },
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