# frozen_string_literal: true
require 'ruby_grammar_builder'
require 'walk_up'
require_relative walk_up_until("paths.rb")
require_relative './tokens.rb'

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
        lookBehindToAvoid(@standard_character).then(regex_pattern).lookAheadToAvoid(@standard_character)
    end
    variable = variableBounds[part_of_a_variable]
    
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
            grammar[:path_literal_content] = Pattern.new(
                tag_as: "string.unquoted.path punctuation.section.regexp punctuation.section.path",
                match: /[\w+\-\.\/]+\/[\w+\-\.\/]+/,
                includes: [
                    Pattern.new(
                        match: /\//,
                        tag_as: "punctuation.other.path",
                    ),
                    Pattern.new(
                        match: variableBounds[/\.\.|\./],
                        tag_as: "punctuation.other.relative",
                    ),
                ],
            )
            
            grammar[:normal_path_literal] = Pattern.new(
                tag_as: "constant.path.normal",
                match: Pattern.new(
                    Pattern.new(
                        match:/\.\//,
                        tag_as: "punctuation.other.path.normal",
                    ).then(grammar[:path_literal_content])
                ),
            )
            
            grammar[:system_path_literal] = Pattern.new(
                tag_as: "constant.path.system",
                match: Pattern.new(
                    Pattern.new(
                        match: /</,
                        tag_as: "punctuation.other.path.system",
                    ).then(
                        grammar[:path_literal_content]
                    ).then(
                        match: />/,
                        tag_as: "punctuation.other.path.system",
                    )
                ),
            )
            
            grammar[:url] = Pattern.new(
                tag_as: "constant.url",
                match: Pattern.new(
                    Pattern.new(
                        match: /[a-zA-Z][a-zA-Z0-9_+\-\.]*:/,
                        tag_as: "punctuation.other.url.protocol",
                    ).then(
                        match: /[a-zA-Z0-9%$*!@&*_=+:'\/?~\-\.:]+/,
                        tag_as: "punctuation.other.url.address",
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
                grammar[:double_quote] = PatternRange.new(
                    tag_as: "string.quoted.double",
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
                    ]
                )
                grammar[:single_quote] = PatternRange.new(
                    tag_as: "string.quoted.other",
                    start_pattern: Pattern.new(
                        tag_as: "string.quoted.single punctuation.definition.string.single",
                        match: /''/,
                    ),
                    end_pattern: Pattern.new(
                        tag_as: "string.quoted.single punctuation.definition.string.single",
                        match: /''/,
                    ),
                    includes: [
                        :escape_character_single_quote,
                        :interpolation,
                    ]
                )
        
    # 
    # variables
    # 
        function_call_lookahead = std_space.then(lookAheadFor(/\{|"|'|\d|\w|-|\+|\.\/|\/|\(|\[/).or(lookAheadFor(grammar[:url])))
        
        grammar[:standalone_variable] = Pattern.new(
            tag_as: "variable.other",
            match: variable,
        )
        
        grammar[:standalone_function_call] = Pattern.new(
            tag_as: "entity.name.function",
            match: variable,
        ).then(function_call_lookahead)
        
        grammar[:standalone_function_call_guess] = lookBehindFor(/\(/).then(
            tag_as: "entity.name.function",
            match: variable,
        ).then(function_call_lookahead.or(std_space.then(/$/)))
        
        dot_access = Pattern.new(
            tag_as: "punctuation.separator.dot-access",
            match: ".",
        )
        
        attribute = oneOf([
            Pattern.new(
                tag_as: "variable.other.object.property",
                match: variable,
            ),
            grammar[:double_quote_inline],
            grammar[:single_quote_inline],
        ])
        
        grammar[:variable_with_attributes] = Pattern.new(
            Pattern.new(
                tag_as: "variable.other.object.access",
                match: variable,
            ).then(std_space).then(
                dot_access
            ).then(std_space).then(
                match: zeroOrMoreOf(
                    middle_repeat = Pattern.new(
                        attribute.then(std_space).then(dot_access).then(std_space),
                    ),
                ),
                includes: [ middle_repeat ],
            ).then(
                tag_as: "variable.other.property",
                match: attribute,
            ),
        )
        
        grammar[:variable_with_method] = Pattern.new(
            Pattern.new(
                tag_as: "variable.other.object.access",
                match: variable,
            ).then(std_space).then(
                dot_access
            ).then(std_space).then(
                match: zeroOrMoreOf(
                    middle_repeat = Pattern.new(
                        attribute.then(std_space).then(dot_access).then(std_space),
                    ),
                ),
                includes: [ middle_repeat ],
            ).then(
                tag_as: "entity.name.function.method",
                match: attribute,
            ),
        )
        
        grammar[:variable] = oneOf([
            grammar[:variable_with_method],
            grammar[:variable_with_attributes],
            grammar[:standalone_function_call],
            grammar[:standalone_function_call_guess],
            grammar[:standalone_variable],
        ])
    
    # 
    # keyworded values
    # 
        value_prefix = Pattern.new(
            Pattern.new(
                tag_as: "keyword.operator.with",
                match: variableBounds[/with/],
            ).then(std_space).then(
                tag_as: "entity.name.namespace",
                match: grammar[:variable],
            ).then(
                std_space
            ).then(
                match: /;/,
                tag_as: "punctuation.separator.with",
            ).then(std_space)
        )
        # FIXME: "with", "include"
    
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
                    :values,
                ]
            ),
        ]
    
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
        
        # FIXME: "assert" keyword
        # ex: assert assertMsg ("foo" == "bar") "foo is not bar, silly"; ""
        assignment_start = attribute_key.then(std_space).then(
            match: /=/,
            tag_as: "keyword.operator.assignment",
        )
        
        grammar[:assignment_statement] = PatternRange.new(
            tag_as: "meta.statement",
            start_pattern: assignment_start,
            end_pattern: Pattern.new(
                match: /;/,
                tag_as: "punctuation.terminator.statement"
            ),
            includes: [
                :values,
            ]
        )
        
        parameter = Pattern.new(
            tag_as: "variable.parameter.function",
            match: variable,
        )
                
        grammar[:brackets] =  PatternRange.new(
            tag_as: "meta.punctuation.section.bracket",
            start_pattern: Pattern.new(
                maybe(value_prefix).maybe(
                    std_space.then(
                        # FIXME: also make it so that variables cannot be keywords like this
                        match: variableBounds[/rec/],
                        tag_as: "storage.modifier",
                    ).then(std_space)
                ).then(
                    match: "{",
                    tag_as: "punctuation.section.bracket",
                ),
            ),
            end_pattern: lookBehindFor(/\}|\}:/),
            includes: [
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
                        :assignment_statement,
                    ],
                ),
                # 
                # function definition
                # 
                PatternRange.new(
                    tag_as: "punctuation.section.parameters",
                    start_pattern: parameter.then(std_space).lookAheadFor(/$|\?|,/),
                    end_pattern: Pattern.new(
                        Pattern.new(
                            match: "}",
                            tag_as: "punctuation.section.bracket",
                        ).then(match: ":", tag_as: "punctuation.section.function")
                        # FIXME: add the {}@aldkfjadj: case
                    ),
                    includes: [
                        :comments,
                        Pattern.new(
                            tag_as: "variable.parameter.function",
                            match: variable,
                        ),
                        Pattern.new(
                            tag_as: "punctuation.separator.delimiter.comma",
                            match: ",",
                        ),
                    ],
                )
                    # FIXME
            ]
        )
        # FIXME: inline function definition
    
    # 
    # keyworded statements
    # 
        # let in
        
        grammar[:if_then_else] =  PatternRange.new(
            tag_as: "meta.punctuation.section.conditional",
            start_pattern: Pattern.new(
                maybe(value_prefix).then(
                    match: variableBounds[/if/],
                    tag_as: "keyword.control.if",
                ),
            ),
            end_pattern: lookAheadFor(/\}|;/), # technically this is imperfect, but must be done cause of multi-line values
            includes: [
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
                :values
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
        # FIXME: parentheses 
        
        grammar[:value_base_case] = maybe(value_prefix).oneOf([
            grammar[:double_quote_inline],
            grammar[:single_quote_inline],
            grammar[:url],
            grammar[:normal_path_literal],
            grammar[:path_literal_content],
            grammar[:system_path_literal],
            grammar[:null],
            grammar[:boolean],
            grammar[:decimal],
            grammar[:integer],
            grammar[:empty_list],
            grammar[:empty_set],
            grammar[:variable],
        ])
        
        grammar[:values] = [
            :comments, # comments are valid whereever values are
            :double_quote,
            :single_quote,
            :list,
            :brackets,
            :parentheses,
            :if_then_else,
            :value_base_case,
            # FIXME: functions
            # FIXME: keyworded statements
        ]
    
    # 
    # other
    # 
        # FIXME
        parameter = Pattern.new(
            tag_as: "variable.parameter.function",
            match: variable,
        )
        comma = Pattern.new(
            match: /,/,
            tag_as: "punctuation.separator"
        )
        optional = Pattern.new(
            match: "?",
            tag_as: "punctuation.separator.default",
        )
        eplipsis = Pattern.new(
            tag_as: "punctuation.vararg-ellipses",
            match: "...",
        )
        parameter_entry = oneOf([
            parameter.maybe(std_space).then(comma),
            parameter.maybe(std_space).then(optional),
            parameter,
            eplipsis,
            comma,
        ])
        grammar[:methods] = [
            Pattern.new(
                match: zeroOrMoreOf(parameter_entry),
                includes: [ parameter_entry ],
            ),
            # Multi-line
            PatternRange.new(
                tag_as: "meta.function",
                start_pattern: Pattern.new(
                    oneOf([
                        # word before hand
                        lookBehindFor(/\w|;/).then(std_space).then(
                            tag_as: "punctuation.definition.dict",
                            match: "{",
                        ),
                        # newline after
                        Pattern.new(
                            tag_as: "punctuation.definition.dict",
                            match: "{",
                        ).lookAheadFor(/ *$/),
                    ])
                ),
                end_pattern: Pattern.new(
                    match: "}",
                    tag_as: "punctuation.definition.dict",
                ),
                includes: [
                    :$initial_context,
                    :attribute_set,
                ]
            ),
        ]
    
    
        # TODO: add shell support
    
    
    # grammar[:line_continuation_character] = Pattern.new(
    #     match: /\\\n/,
    #     tag_as: "constant.character.escape.line-continuation",
    # )
    
    # grammar[:attribute] = PatternRange.new(
    #     start_pattern: Pattern.new(
    #             match: /\[\[/,
    #             tag_as: "punctuation.section.attribute.begin"
    #         ),
    #     end_pattern: Pattern.new(
    #             match: /\]\]/,
    #             tag_as: "punctuation.section.attribute.end",
    #         ),
    #     tag_as: "support.other.attribute",
    #     # tag_content_as: "support.other.attribute", # <- alternative that doesnt double-tag the start/end
    #     includes: [
    #         :attributes_context,
    #     ]
    # )

# 
# imports
# 
    # grammar.import(PathFor[:pattern]["comments"])
    # grammar.import(PathFor[:pattern]["string"])
    # grammar.import(PathFor[:pattern]["numeric_literal"])

#
# Save
#
name = "nix"
grammar.save_to(
    syntax_name: name,
    syntax_dir: "./autogenerated",
    tag_dir: "./autogenerated",
)