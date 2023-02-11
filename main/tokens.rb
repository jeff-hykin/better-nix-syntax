require "walk_up"
require_relative walk_up_until("paths.rb")
require_relative PathFor[:textmate_tools]

# 
# Create tokens
#
tokens = [
    # operators
    { representation: "if"      , areKeywords: true },
    { representation: "then"    , areKeywords: true },
    { representation: "else"    , areKeywords: true },
    { representation: "assert"  , areKeywords: true },
    { representation: "with"    , areKeywords: true },
    { representation: "let"     , areKeywords: true },
    { representation: "in"      , areKeywords: true },
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