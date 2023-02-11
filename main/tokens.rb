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
    
    # operators
    { representation: "-"       , areOperators: true, priority: 3,  name: "neg"      , associtivity: :none , }
    { representation: "?"       , areOperators: true, priority: 4,  name: "has_attr" , associtivity: :none , }
    { representation: "++"      , areOperators: true, priority: 5,  name: "concat"   , associtivity: :right, }
    { representation: "*"       , areOperators: true, priority: 6,  name: "mul"      , associtivity: :left , }
    { representation: "/"       , areOperators: true, priority: 6,  name: "div"      , associtivity: :left , }
    { representation: "+"       , areOperators: true, priority: 7,  name: "add"      , associtivity: :left , }
    { representation: "-"       , areOperators: true, priority: 7,  name: "sub"      , associtivity: :left , }
    { representation: "!"       , areOperators: true, priority: 8,  name: "not"      , associtivity: :left , }
    { representation: "//"      , areOperators: true, priority: 9,  name: "update"   , associtivity: :right, }
    { representation: "<"       , areOperators: true, priority: 10, name: "lt"       , associtivity: :left , }
    { representation: "<="      , areOperators: true, priority: 10, name: "lte"      , associtivity: :left , }
    { representation: ">"       , areOperators: true, priority: 10, name: "gt"       , associtivity: :left , }
    { representation: ">="      , areOperators: true, priority: 10, name: "gte"      , associtivity: :left , }
    { representation: "=="      , areOperators: true, priority: 11, name: "eq"       , associtivity: :none , }
    { representation: "!="      , areOperators: true, priority: 11, name: "neq"      , associtivity: :none , }
    { representation: "&&"      , areOperators: true, priority: 12, name: "and"      , associtivity: :left , }
    { representation: "||"      , areOperators: true, priority: 13, name: "or"       , associtivity: :left , }
    { representation: "->"      , areOperators: true, priority: 14, name: "impl"     , associtivity: :none , }
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