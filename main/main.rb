require 'ruby_grammar_builder'
require 'walk_up'
require_relative walk_up_until("paths.rb")
require_relative './tokens.rb'

# FIXME:
    # interpolation in paths
    # system path literal isnt working
# todo
    # better function call detection when multiple vars split up by spaces
    # custom hanlding of stdenv, lib, mkDerivation, and shellHook

# 
# 
# create grammar!
# 
# 
# grammar = Grammar.fromTmLanguage("./original.tmLanguage.json")
grammar = Grammar.new(
    name: "nix",
    scope_name: "source.nix",
    fileTypes: [
        "nix",
        # for example here are come C++ file extensions:
        #     "cpp",
        #     "cxx",
        #     "c++",
    ],
    version: "",
)

# 
#
# Setup Grammar
#
# 
    grammar[:$initial_context] = [
        :values,
    ]

# 
# Helpers
# 
    # @space
    # @spaces
    # @digit
    # @digits
    # @standard_character
    # @word
    # @word_boundary
    # @white_space_start_boundary
    # @white_space_end_boundary
    # @start_of_document
    # @end_of_document
    # @start_of_line
    # @end_of_line
    part_of_a_variable = /[a-zA-Z_][a-zA-Z0-9_\-']*/
    # this is really useful for keywords. eg: variableBounds[/new/] wont match "newThing" or "thingnew"
    variableBounds = ->(regex_pattern) do
        lookBehindToAvoid(/[a-zA-Z0-9_']/).then(regex_pattern).lookAheadToAvoid(/[a-zA-Z0-9_\-']/)
    end
    variable = variableBounds[part_of_a_variable].then(@tokens.lookBehindToAvoidWordsThat(:areKeywords))
    external_variable = variableBounds[/_-#{part_of_a_variable}/].then(@tokens.lookBehindToAvoidWordsThat(:areKeywords))
    dirty_variable = variableBounds[/_'#{part_of_a_variable}/].then(@tokens.lookBehindToAvoidWordsThat(:areKeywords))
    
# 
# patterns
# 
    # 
    # comments
    # 
        grammar[:line_comment] = oneOf([
            Pattern.new(
                match: Pattern.new(/\s*+/).then(
                    match: /#/,
                    tag_as: "punctuation.definition.comment"
                ).then(
                    match: /.*/,
                    tag_as: "comment.line",
                ),
            ),
        ])
        
        # 
        # /*comment*/
        # 
        # same as block_comment, but uses Pattern so it can be used inside other patterns
        grammar[:inline_comment] = Pattern.new(
            should_fully_match: [ "/* thing */", "/* thing *******/", "/* */", "/**/", "/***/" ],
            match: Pattern.new(
                Pattern.new(
                    match: "/*",
                    tag_as: "comment.block punctuation.definition.comment.begin",
                ).then(
                    # this pattern is complicated because its optimized to never backtrack
                    match: Pattern.new(
                        tag_as: "comment.block",
                        match: zeroOrMoreOf(
                            dont_back_track?: true,
                            match: Pattern.new(
                                Pattern.new(
                                    /[^\*]++/
                                ).or(
                                    Pattern.new(/\*+/).lookAheadToAvoid(/\//)
                                )
                            ),
                        ).then(
                            match: "*/",
                            tag_as: "comment.block punctuation.definition.comment.end",
                        )
                    )
                )
            )    
        )
        
        # 
        # /*comment*/
        # 
        # same as inline but uses PatternRange to cover multiple lines
        grammar[:block_comment] = PatternRange.new(
            tag_as: "comment.block",
            start_pattern: Pattern.new(
                Pattern.new(/\s*+/).then(
                    match: /\/\*/,
                    tag_as: "punctuation.definition.comment.begin"
                )
            ),
            end_pattern: Pattern.new(
                match: /\*\//,
                tag_as: "punctuation.definition.comment.end"
            )
        )
        
        grammar[:comments] = [
            :line_comment,
            :block_comment,
        ]
    
    # 
    # space helper
    # 
        # efficiently match zero or more spaces that may contain inline comments
        std_space = Pattern.new(
            # NOTE: this pattern can match 0-spaces so long as its still a word boundary
            # this is the intention, for example `int/*comment*/a = 10` would be valid
            # this space pattern will match inline /**/ comments that do not contain newlines
            match: oneOf([
                oneOrMoreOf(
                    Pattern.new(/\s*/).then( 
                        grammar[:inline_comment]
                    ).then(/\s*/)
                ),
                Pattern.new(/\s++/),
                lookBehindFor(/\W/),
                lookAheadFor(/\W/),
                /^/,
                /\n?$/,
                @start_of_document,
                @end_of_document,
            ]),
            includes: [
                :inline_comment,
            ],
        )
    
    # 
    # 
    # primitives
    # 
    # 
        grammar[:null] = Pattern.new(
            tag_as: "constant.language.null",
            match: variableBounds[/null/],
        )
        
        grammar[:boolean] = Pattern.new(
            tag_as: "constant.language.boolean.$match",
            match: variableBounds[/true|false/],
        )
        
        grammar[:integer] = Pattern.new(
            match: variableBounds[/[0-9]+/],
            tag_as: "constant.numeric.integer",
        )
        
        grammar[:decimal] = Pattern.new(
            match: variableBounds[/[0-9]+\.[0-9]+/],
            tag_as: "constant.numeric.decimal",
        )
        
        grammar[:number] = grammar[:integer].or(grammar[:decimal])
        
        # 
        # file path and URLs
        # 
            grammar[:path_literal_angle_brackets] = Pattern.new(
                tag_as: "string.unquoted.path punctuation.section.regexp punctuation.section.path.lookup",
                match: /<\w+>/,
                includes: [
                    Pattern.new(
                        match: /<|>/,
                        tag_as: "punctuation.section.regexp.path.angle-brackets",
                    ),
                    Pattern.new(
                        match: /\//,
                        tag_as: "punctuation.definition.path",
                    ),
                    Pattern.new(
                        match: variableBounds[/\.\.|\./],
                        tag_as: "punctuation.definition.relative",
                    ),
                ],
            )
            
            grammar[:path_literal_content] = Pattern.new(
                tag_as: "string.unquoted.path punctuation.section.regexp punctuation.section.path",
                match: /[\w+\-\.\/]+\/[\w+\-\.\/]+/,
                includes: [
                    Pattern.new(
                        match: /\//,
                        tag_as: "punctuation.definition.path",
                    ),
                    Pattern.new(
                        match: variableBounds[/\.\.|\./],
                        tag_as: "punctuation.definition.relative",
                    ),
                ],
            )
            
            grammar[:relative_path_literal] = Pattern.new(
                tag_as: "constant.other.path.relative",
                match: Pattern.new(
                    Pattern.new(
                        match:/\.\//,
                        tag_as: "punctuation.definition.path.relative",
                    ).then(grammar[:path_literal_content])
                ),
            )
            
            grammar[:absolute_path_literal] = Pattern.new(
                tag_as: "constant.other.path.absolute",
                match: Pattern.new(
                    Pattern.new(
                        match:/\//,
                        tag_as: "punctuation.definition.path.absolute",
                    ).then(grammar[:path_literal_content])
                ),
            )
            
            grammar[:system_path_literal] = Pattern.new(
                tag_as: "constant.other.path.system",
                match: Pattern.new(
                    Pattern.new(
                        match: /</,
                        tag_as: "punctuation.definition.path.system",
                    ).then(
                        grammar[:path_literal_content]
                    ).then(
                        match: />/,
                        tag_as: "punctuation.definition.path.system",
                    )
                ),
            )
            
            grammar[:url] = Pattern.new(
                tag_as: "constant.other.url",
                match: Pattern.new(
                    Pattern.new(
                        match: /[a-zA-Z][a-zA-Z0-9_+\-\.]*:/,
                        tag_as: "punctuation.definition.url.protocol",
                    ).then(
                        match: /[a-zA-Z0-9%$*!@&*_=+:'\/?~\-\.:]+/,
                        tag_as: "punctuation.definition.url.address",
                    )
                ),
            )
        
        # 
        # 
        # Strings
        # 
        # 
            # 
            # inline strings
            # 
                grammar[:double_quote_inline] = Pattern.new(
                    Pattern.new(
                        tag_as: "string.quoted.double punctuation.definition.string.double",
                        match: /"/,
                    ).then(
                        tag_as: "string.quoted.double",
                        should_fully_match: [ "fakljflkdjfad", "fakljflkdjfad$", "fakljflkdjfad\\${testing}", ],
                        match: zeroOrMoreOf(
                            match: Pattern.new(/\\./).or(lookAheadToAvoid(/\$\{/).then(/[^"]/)),
                            atomic: true,
                        ),
                        includes: [
                            grammar[:escape_character_double_quote] = Pattern.new(
                                tag_as: "constant.character.escape",
                                match: /\\./,
                            ),
                        ]
                    ).then(
                        tag_as: "string.quoted.double punctuation.definition.string.double",
                        match: /"/,
                    )
                )
                
                grammar[:single_quote_inline] = oneOf([
                    Pattern.new(
                        tag_as: "string.quoted.single",
                        match: Pattern.new(
                            Pattern.new(
                                tag_as: "punctuation.definition.string.single",
                                match: /''/,
                            ).then(
                                tag_as: "string.quoted.single",
                                match: zeroOrMoreOf(
                                    match: oneOf([
                                        grammar[:escape_character_single_quote] = Pattern.new(
                                            tag_as: "constant.character.escape",
                                            match: /\'\'(?:\$|\')/,
                                        ),
                                        lookAheadToAvoid(/\$\{/).then(/[^']/),
                                    ]),
                                    atomic: true,
                                ),
                                includes: [
                                    :escape_character_single_quote,
                                ]
                            ).then(
                                Pattern.new(
                                    tag_as: "punctuation.definition.string.single",
                                    match: Pattern.new(/''/).lookAheadToAvoid(/\$|\'|\\./), # I'm not exactly sure what this lookAheadFor is for
                                )
                            )
                        ),
                    ),
                ])
            # 
            # multiline strings
            # 
                grammar[:interpolation] = PatternRange.new(
                    start_pattern: Pattern.new(
                        match: /\$\{/,
                        tag_as: "punctuation.section.embedded"
                    ),
                    end_pattern: Pattern.new(
                        tag_as: "punctuation.section.embedded",
                        match: /\}/,
                    ),
                    includes: [
                        :$initial_context
                    ]
                )
                
                generateStringBlock = ->(additional_tag:"", includes:[]) do
                    [
                        PatternRange.new(
                            tag_as: "string.quoted.double #{additional_tag}",
                            start_pattern: Pattern.new(
                                tag_as: "punctuation.definition.string.double",
                                match: /"/,
                            ),
                            end_pattern: Pattern.new(
                                tag_as: "punctuation.definition.string.double",
                                match: /"/,
                            ),
                            includes: [
                                :escape_character_double_quote,
                                :interpolation,
                                *includes,
                            ],
                        ),
                        PatternRange.new(
                            tag_as: "string.quoted.other #{additional_tag}",
                            start_pattern: Pattern.new(
                                tag_as: "string.quoted.single punctuation.definition.string.single",
                                match: /''/,
                            ),
                            apply_end_pattern_last: true,
                            end_pattern: Pattern.new(
                                tag_as: "string.quoted.single punctuation.definition.string.single",
                                match: /''/,
                            ),
                            includes: [
                                :escape_character_single_quote,
                                :interpolation,
                                *includes,
                            ]
                        )
                    ]
                end
                
                default_string_blocks = generateStringBlock[]
                grammar[:double_quote] = default_string_blocks[0]
                grammar[:single_quote] = default_string_blocks[1]
        
    # 
    # variables
    # 
        function_call_lookahead = std_space.lookAheadToAvoid(/then\b|in\b|else\b|- |-$/).then(lookAheadFor(/\{|"|'|\d|\w|-[^>]|\.\/|\.\.\/|\/\w|\(|\[|if\b|let\b|with\b|rec\b/).or(lookAheadFor(grammar[:url])))
        lookBehindToAvoidNames = ->(names) do
            oneOf([
                # good case: no partial match
                lookBehindToAvoid(/#{names.join("|")}/),
                # unconfirmed case: partial match, but not nessairly full reject
                lookBehindFor(/#{names.join("|")}/).then(
                    lookBehindFor(/#{names.map{ |each| "[^a-zA-Z0-9\\-_]#{each}" }.join('|')}/).lookAheadToAvoid(/[^a-zA-Z0-9\-_]|$/).or(
                        lookBehindFor(/#{names.map{ |each| "^#{each}" }.join('|')}/).lookAheadToAvoid(/[^a-zA-Z0-9\-_]|$/),
                    ),
                ),
            ])
        end
        avoid_invalid_names = lookBehindToAvoidNames[ ["with", "if", "then", "else", "let", "in", "assert", ] ]
        
        grammar[:standalone_variable] = Pattern.new(
            Pattern.new(
                tag_as: "support.module variable.language.special.builtins",
                match: lookBehindToAvoid(".").then(/builtins/).lookAheadToAvoid("."),
            ).or(
                tag_as: "variable.other.external",
                match: lookBehindToAvoid(".").then(external_variable).lookAheadToAvoid("."),
            ).or(
                tag_as: "variable.other.dirty",
                match: lookBehindToAvoid(".").then(dirty_variable).lookAheadToAvoid("."),
            ).or(
                tag_as: "variable.other",
                match: lookBehindToAvoid(".").then(variable).lookAheadToAvoid("."),
            )
        )
        
        grammar[:or_operator] = Pattern.new(
            tag_as: "keyword.operator.or",
            match: /\bor\b/,
        )
        
        grammar[:standalone_function_call] = Pattern.new(
            oneOf([
                lookBehindToAvoid(/\)|"|\d|\s/).then(std_space).then(
                    tag_as: "entity.name.function.call support.type.builtin.top-level support.type.builtin.property.$match",
                    match: @tokens.that(:areBuiltinAttributes,:areFunctions,:canAppearTopLevel),
                ).then(function_call_lookahead),
                
                lookBehindToAvoid(/\)|"|\d|\s/).then(std_space).then(
                    tag_as: "entity.name.function.call.external",
                    match: external_variable.then(avoid_invalid_names)
                ).then(function_call_lookahead),
                
                lookBehindToAvoid(/\)|"|\d|\s/).then(std_space).then(
                    tag_as: "entity.name.function.call.dirty",
                    match: dirty_variable.then(avoid_invalid_names),
                ).then(function_call_lookahead),
                
                lookBehindToAvoid(/\)|"|\d|\s/).then(std_space).then(
                    tag_as: "entity.name.function.call",
                    match: variable.then(avoid_invalid_names),
                ).then(function_call_lookahead),
            ])
        )
        
        grammar[:standalone_function_call_guess] = oneOf([
            lookBehindToAvoid(/\(/).then(
                tag_as: "entity.name.function.call support.type.builtin.top-level support.type.builtin.property.$match",
                match: @tokens.that(:areBuiltinAttributes,:areFunctions,:canAppearTopLevel),
            ).then(function_call_lookahead),
                
            lookBehindFor(/\(/).then(
                tag_as: "entity.name.function.call.external",
                match: external_variable.then(avoid_invalid_names),
            ).then(function_call_lookahead.or(std_space.then(/$/))),
            
            lookBehindFor(/\(/).then( 
                tag_as: "entity.name.function.call.dirty",
                match: dirty_variable.then(avoid_invalid_names),
            ).then(function_call_lookahead.or(std_space.then(/$/))),
            
            lookBehindFor(/\(/).then(
                tag_as: "entity.name.function.call",
                match: variable.then(avoid_invalid_names),
            ).then(function_call_lookahead.or(std_space.then(/$/))),
            
        ])
        
        grammar[:parameter] = Pattern.new(
            tag_as: "variable.parameter.function",
            match: variable,
        )
        
        grammar[:probably_parameter] = grammar[:parameter].lookAheadFor(/ *+:/)
        
        dot_access = Pattern.new(
            tag_as: "punctuation.separator.dot-access",
            match: ".",
        )
        
        interpolated_attribute = Pattern.new(
            # try to support thing.${stuff}
            Pattern.new(
                match: /\$\{/,
                tag_as: "punctuation.section.embedded",
            ).then(
                match: /.+?/,
                includes: [
                    :values,
                ],
            ).then(
                match: /\}/,
                tag_as: "punctuation.section.embedded",
            )
        )
        attribute = oneOf([
            # standalone
            lookBehindToAvoid(/\./).then(
                tag_as: "variable.other.object",
                should_fully_match: [ "zipListsWith'" ],
                match: variable,
            ).lookAheadToAvoid(/\./),
            # first
            lookBehindToAvoid(/\./).then(
                tag_as: "variable.other.object.access",
                match: variable,
            ),
            # last
            Pattern.new(
                tag_as: "variable.other.property",
                match: interpolated_attribute.or(variable.lookAheadToAvoid(/\./)),
            ),
            # middle
            Pattern.new(
                tag_as: "variable.other.object.property",
                match: interpolated_attribute.or(variable),
            ),
            grammar[:double_quote_inline],
            grammar[:single_quote_inline],
        ])
        
        object_access = Pattern.new(
            Pattern.new(
                Pattern.new(
                    tag_as: "variable.other.object.access variable.language.special.builtins",
                    match: variableBounds[/builtins/],
                ).or(
                    tag_as: "variable.other.object.access",
                    match: variable,
                )
            ).then(std_space).then(
                dot_access
            ).then(std_space).then(
                match: zeroOrMoreOf(
                    middle_repeat = Pattern.new(
                        attribute.then(std_space).then(dot_access).then(std_space),
                    ),
                ),
                includes: [ middle_repeat ],
            )
        )
        
        builtin_method = lookBehindFor(/builtins\./).then(
            tag_as: "variable.language.special.property.$match support.type.builtin.property.$match",
            match: @tokens.that(:areBuiltinAttributes, :areFunctions).lookAheadToAvoid(/[a-zA-Z0-9_\-']/),
        )
        builtin_value = lookBehindFor(/builtins\./).then(
            tag_as: "variable.language.special.method.$match support.type.builtin.method.$match",
            match: @tokens.that(:areBuiltinAttributes, !:areFunctions).lookAheadToAvoid(/[a-zA-Z0-9_\-']/),
        )
        method_pattern = Pattern.new(
            Pattern.new(
                match: oneOf([
                    builtin_method,
                    builtin_value,
                    Pattern.new(
                        tag_as: "entity.name.function.method",
                        match: variable,
                    ),
                    grammar[:double_quote_inline],
                    grammar[:single_quote_inline],
                ]),
            ).then(function_call_lookahead)
        )
        
        grammar[:variable_with_attributes] = Pattern.new(
            object_access.oneOf([
                builtin_method,
                builtin_value,
                Pattern.new(
                    tag_as: "variable.other.property",
                    match: attribute,
                ),
            ]),
        )
        
        grammar[:variable_with_method] = Pattern.new(
            object_access.then(method_pattern),
        )
        
        grammar[:variable_with_method_guess] = Pattern.new(
            lookBehindFor("(").then(
                object_access
            ).then(method_pattern),
        )
        
        grammar[:variable_or_function] = oneOf([
            grammar[:probably_parameter],
            grammar[:variable_with_method],
            grammar[:variable_with_method_guess],
            grammar[:variable_with_attributes],
            grammar[:standalone_function_call],
            grammar[:standalone_function_call_guess],
            grammar[:standalone_variable],
        ])
        grammar[:variable] = oneOf([
            grammar[:variable_with_attributes],
            grammar[:standalone_variable],
        ])
        
        # 
        # namespace (which is really just a variable, but is nice to highlight different)
        # 
        standalone_namespace = Pattern.new(
            tag_as: "entity.name.namespace",
            match: variable,
        )
        
        namespace_attribute = oneOf([
            Pattern.new(
                tag_as: "entity.name.namespace.object.property",
                match: variable,
            ),
            grammar[:double_quote_inline],
            grammar[:single_quote_inline],
        ])
        
        namespace_with_attributes = Pattern.new(
            Pattern.new(
                tag_as: "entity.name.namespace.object.access",
                match: variable,
            ).then(std_space).then(
                dot_access
            ).then(std_space).then(
                match: zeroOrMoreOf(
                    middle_repeat_namespace = Pattern.new(
                        namespace_attribute.then(std_space).then(dot_access).then(std_space),
                    ),
                ),
                includes: [ middle_repeat_namespace ],
            ).then(
                tag_as: "entity.name.namespace.property",
                match: namespace_attribute,
            ),
        )
        
        namespace = standalone_namespace.or(namespace_with_attributes)
    
    # 
    # operators
    # 
        grammar[:operators] = Pattern.new(
            tag_as: "keyword.operator.$match",
            match: @tokens.that(:areOperators),
        )
    
    # 
    # keyworded values
    # 
        value_prefix = Pattern.new(
            Pattern.new(
                tag_as: "keyword.operator.with",
                match: variableBounds[/with/],
            ).then(std_space).then(
                namespace
            ).then(
                std_space
            ).then(
                match: /;/,
                tag_as: "punctuation.separator.with",
            ).then(std_space)
        )
    
    # 
    # list
    # 
        grammar[:empty_list] = Pattern.new(
            maybe(std_space).then(
                match: "[",
                tag_as: "punctuation.definition.list",
            ).maybe(std_space).then(
                match: "]",
                tag_as: "punctuation.definition.list",
            ),
        )
        
        grammar[:list] = [
            PatternRange.new(
                tag_as: "meta.list",
                start_pattern: maybe(value_prefix).then(
                    match: "[",
                    tag_as: "punctuation.definition.list",
                ),
                end_pattern: Pattern.new(
                    match: "]",
                    tag_as: "punctuation.definition.list",
                ),
                includes: [
                    :values_inside_list,
                ]
            ),
        ]
    # 
    # basic function
    # 
        grammar[:basic_function] = Pattern.new(
            Pattern.new(
                match: variable,
                tag_as: "variable.parameter.function.standalone",
            ).then(
                std_space
            ).then(
                match: ":",
                tag_as: "punctuation.definition.function.colon"
            )
        )
    # 
    # attribute_set or function
    # 
        
        grammar[:empty_set] = Pattern.new(
            maybe(std_space).then(
                match: "{",
                tag_as: "punctuation.definition.dict",
            ).maybe(std_space).then(
                match: "}",
                tag_as: "punctuation.definition.dict",
            ),
        )
        
        attribute_key = Pattern.new(
            tag_as: "meta.attribute-key",
            match: attribute.zeroOrMoreOf(
                std_space.then(
                    dot_access
                ).then(std_space).then(
                    attribute
                )
            ),
            includes: [
                attribute,
                dot_access,
            ],
        )
        assignment_operator = Pattern.new(
            match: /\=/,
            tag_as: "keyword.operator.assignment",
        )
        assignmentOf = ->(attribute_pattern) do
            Pattern.new(
                Pattern.new(
                    tag_as: "meta.attribute-key",
                    match: attribute_pattern,
                    includes: [
                        attribute,
                        dot_access,
                    ],
                ).then(std_space).then(
                    assignment_operator
                )
            )
        end
        
        # generic attribute
        assignment_start = Pattern.new(
            lookAheadFor(/inherit\b/).or(
                assignmentOf[
                    attribute.zeroOrMoreOf(
                        std_space.then(
                            dot_access
                        ).then(std_space).then(
                            attribute
                        )
                    )
                ]
            )
        )
        
        grammar[:assignment_statements] = [
            # 
            # inherit statement
            # 
            PatternRange.new(
                tag_as: "meta.inherit",
                start_pattern: Pattern.new(
                    match: variableBounds[/inherit/],
                    tag_as: "keyword.other.inherit",
                ),
                end_pattern: Pattern.new(
                    match: /;/,
                    tag_as: "punctuation.terminator.statement"
                ),
                includes: [
                    PatternRange.new(
                        tag_as: "meta.source",
                        start_pattern: Pattern.new(
                            match: "(",
                            tag_as: "punctuation.separator.source",
                        ),
                        end_pattern: Pattern.new(
                            match: ")",
                            tag_as: "punctuation.separator.source"
                        ),
                    ),
                    :standalone_variable,
                ]
            ),
            
            # 
            # shellHook
            # 
                # its broken atm
                # PatternRange.new(
                #     tag_as: "meta.shell-hook",
                #     start_pattern: assignmentOf[variableBounds[/shellHook/]],
                #     end_pattern: Pattern.new(
                #         match: /;/,
                #         tag_as: "punctuation.terminator.statement"
                #     ),
                #     includes: [
                #         generateStringBlock[ additional_tag:"source.shell", includes:[ "source.shell" ] ],
                #         :values,
                #     ]
                # ),
            
            # 
            # normal attribute assignment
            # 
            PatternRange.new(
                tag_as: "meta.statement",
                start_pattern: assignment_start,
                end_pattern: Pattern.new(
                    match: /;/,
                    tag_as: "punctuation.terminator.statement"
                ),
                includes: [
                    assignment_start,
                    :values,
                ]
            ),
            
            # 
            # dynamic attribute assignment
            # 
            PatternRange.new(
                tag_as: "meta.statement.dynamic-attr",
                start_pattern: Pattern.new(
                    match: lookAheadFor(/\$/),
                ),
                end_pattern: Pattern.new(
                    match: /;/,
                    tag_as: "punctuation.terminator.statement"
                ),
                includes: [
                    :interpolation,
                    PatternRange.new(
                        start_pattern: assignment_operator,
                        end_pattern: lookAheadFor(/;/),
                        includes: [
                            :bracket_ending_with_semicolon_context,
                            :values,
                        ],
                    ),
                ]
            ),
            
            # 
            # dynamic attribute assignment
            # 
            PatternRange.new(
                tag_as: "meta.statement.dynamic-attr",
                start_pattern: Pattern.new(
                    match: lookAheadFor(/"|'/),
                ),
                end_pattern: Pattern.new(
                    match: /;/,
                    tag_as: "punctuation.terminator.statement"
                ),
                includes: [
                    :double_quote,
                    :single_quote,
                    PatternRange.new(
                        start_pattern: assignment_operator,
                        end_pattern: lookAheadFor(/;/),
                        includes: [
                            :bracket_ending_with_semicolon_context,
                            :values,
                        ],
                    ),
                ]
            ),
        ]
        
        optional = Pattern.new(
            match: "?",
            tag_as: "punctuation.separator.default",
        )
        comma = Pattern.new(
            match: ",",
            tag_as: "punctuation.separator.comma",
        )
        eplipsis = Pattern.new(
            tag_as: "punctuation.vararg-ellipses",
            match: "...",
        )
        
        grammar[:newline_eater] = Pattern.new(
            match: /\s++/,
        )
        
        bracketContext = ->(lookahead_end) do
            function_parameters = PatternRange.new(
                tag_as: "meta.punctuation.section.parameters",
                start_pattern: Pattern.new(/\G/).lookBehindToAvoid(/:|^/),
                end_pattern: Pattern.new(
                    Pattern.new(
                        match: "}",
                        tag_as: "punctuation.section.bracket",
                    ).then(std_space).maybe(
                        Pattern.new(
                            tag_as: "punctuation.definition.arguments",
                            match: /@/,
                        ).then(std_space).then(
                            tag_as: "variable.language.arguments",
                            match: variable,
                        ).then(std_space)
                    ).then(match: ":", tag_as: "punctuation.definition.function.colon")
                ),
                includes: [
                    :comments,
                    :eplipsis,
                    grammar[:parameter],
                    PatternRange.new(
                        tag_as: "meta.default",
                        start_pattern: optional,
                        end_pattern: lookAheadFor(/,|}/),
                        includes: [
                            :values,
                        ]
                    ),
                    eplipsis,
                    comma,
                ],
            )
            PatternRange.new(
                tag_as: "meta.punctuation.section.bracket",
                start_pattern: Pattern.new(
                    maybe(value_prefix).maybe(
                        std_space.then(
                            match: variableBounds[/rec/],
                            tag_as: "storage.modifier",
                        ).then(std_space)
                    ).then(
                        match: "{",
                        tag_as: "punctuation.section.bracket",
                    ).lookBehindToAvoid(/\$\{/),
                ),
                end_pattern: lookAheadFor(lookahead_end).or(lookBehindFor(/\}|:/)),
                includes: [
                    :comments,
                    # 
                    # attribute set
                    # 
                    PatternRange.new(
                        tag_as: "meta.attribute-set",
                        start_pattern: lookAheadFor(assignment_start),
                        end_pattern: Pattern.new(
                            match: "}",
                            tag_as: "punctuation.section.bracket",
                        ),
                        includes: [
                            :comments,
                            :assignment_statements,
                        ],
                    ),
                    # 
                    # function definition
                    # 
                    PatternRange.new(
                        tag_as: "meta.punctuation.section.function",
                        start_pattern: Pattern.new(
                            grammar[:parameter].then(std_space).lookAheadFor(/$|\?|,|\}/),
                        ),
                        apply_end_pattern_last: true,
                        end_pattern: lookAheadFor(lookahead_end),
                        includes: [
                            function_parameters,
                            :values,
                        ],
                    ),
                    # just a normal ending bracket to an empty attribute set
                    std_space.then(
                        match: "}",
                        tag_as: "punctuation.section.bracket",
                    ),
                ]
            )
        end
        
        grammar[:bracket_ending_with_semicolon_context] = bracketContext[/;/]
        grammar[:brackets] = bracketContext[/;|,|\)|else\W|then\W|in\W|else$|then$|in$/]
    
    value_end = lookAheadFor(/\}|;|,|\)|else\W|then\W|in\W|else$|then$|in$/) # technically this is imperfect, but must be done cause of multi-line values
    # 
    # keyworded statements
    # 
        # let in
        grammar[:let_in_statement] =  PatternRange.new(
            tag_as: "meta.punctuation.section.let",
            start_pattern: Pattern.new(
                match: variableBounds[/let/],
                tag_as: "keyword.control.let",
            ),
            apply_end_pattern_last: true,
            end_pattern: lookAheadFor(/./).or(/$/), # match anything (once inner patterns are done)
            includes: [
                # first part
                PatternRange.new(
                    tag_as: "meta.let.in.part1",
                    # anchor to the begining of the match
                    start_pattern: /\G/,
                    # then grab the "in"
                    end_pattern: Pattern.new(
                        match: variableBounds[/in/],
                        tag_as: "keyword.control.in",
                    ),
                    includes: [
                        :comments,
                        :assignment_statements,
                    ],
                ),
                # second part
                PatternRange.new(
                    tag_as: "meta.let.in.part2",
                    start_pattern: lookBehindFor(/\Win\W|\Win\$|^in\W|^in\$/),
                    end_pattern: value_end,
                    includes: [
                        :values,
                    ],
                ),
            ]
        )
        
        grammar[:if_then_else] =  PatternRange.new(
            tag_as: "meta.punctuation.section.conditional",
            start_pattern: Pattern.new(
                maybe(value_prefix).then(
                    match: variableBounds[/if/],
                    tag_as: "keyword.control.if",
                ),
            ),
            end_pattern: lookBehindFor(/^else\W|^else$|\Welse\W|\Welse$/),
            includes: [
                PatternRange.new(
                    tag_as: "meta.punctuation.section.condition",
                    start_pattern: /\G/,
                    end_pattern: lookAheadFor(/\Wthen\W|\Wthen$|^then\W|^then$\W/),
                    includes: [
                        :values,
                    ],
                ),
                PatternRange.new(
                    start_pattern: Pattern.new(
                        match: variableBounds[/then/],
                        tag_as: "keyword.control.then",
                    ),
                    end_pattern: Pattern.new(
                        match: variableBounds[/else/],
                        tag_as: "keyword.control.else",
                    ),
                    includes: [
                        :values
                    ],
                ),
            ],
        )
        
        grammar[:assert] =  PatternRange.new(
            tag_as: "meta.punctuation.section.conditional",
            start_pattern: Pattern.new(
                maybe(value_prefix).then(
                    match: variableBounds[/assert/],
                    tag_as: "keyword.operator.assert",
                ),
            ),
            end_pattern: Pattern.new(
                match: /;/,
                tag_as: "punctuation.separator.assert",
            ),
            includes: [
                :values,
            ],
        )
    
    # 
    # values
    # 
        grammar[:parentheses] =  PatternRange.new(
            start_pattern: Pattern.new(
                tag_as: "punctuation.section.parentheses",
                match: /\(/,
            ),
            end_pattern: Pattern.new(
                Pattern.new(
                    tag_as: "punctuation.section.parentheses",
                    match: /\)/,
                ).maybe(
                    dot_access.then(std_space).then(
                        match: zeroOrMoreOf(
                            middle_repeat = Pattern.new(
                                attribute.then(std_space).then(dot_access).then(std_space),
                            ),
                        ),
                        includes: [ middle_repeat ],
                    ).then(
                        tag_as: "variable.other.property",
                        match: attribute,
                    )
                ),
            ),
            includes: [
                :values,
            ]
        )
        
        grammar[:value_common_base] = oneOf([
            grammar[:double_quote_inline],
            grammar[:single_quote_inline],
            grammar[:url],
            grammar[:relative_path_literal],
            grammar[:absolute_path_literal],
            grammar[:path_literal_angle_brackets],
            grammar[:path_literal_content],
            grammar[:system_path_literal],
            grammar[:null],
            grammar[:boolean],
            grammar[:decimal],
            grammar[:integer],
            grammar[:empty_list],
            grammar[:empty_set],
        ])
        grammar[:inline_value] = maybe(value_prefix).oneOf([
            grammar[:value_common_base],
            grammar[:variable_or_function],
        ])
        grammar[:list_value_base] = maybe(value_prefix).oneOf([
            grammar[:value_common_base],
            grammar[:variable],
        ])
        
        
        grammar[:most_values] = [
            :comments, # comments are valid whereever values are
            :double_quote,
            :single_quote,
            :list,
            :brackets,
            :parentheses,
            :if_then_else,
            :let_in_statement,
            :assert,
            :or_operator,
            :path_literal_angle_brackets,
            :relative_path_literal,
            :absolute_path_literal,
            :operators,
            :basic_function,
        ]
        grammar[:values] = [
            value_prefix,
            :most_values,
            :inline_value,
        ]
        grammar[:values_inside_list] = [
            :most_values,
            :list_value_base,
        ]
#
# Save
#
name = "nix"
grammar.save_to(
    syntax_name: name,
    syntax_dir: "./autogenerated",
    tag_dir: "./autogenerated",
)