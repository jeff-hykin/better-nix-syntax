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
        :comment,
        :value_base_case,
        # :attribute_set,
        # :method,
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
                        should_fully_match: [ "fakljflkdjfad", "fakljflkdjfad$", "fakljflkdjfad\\${testing}" ],
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
                                    match: Pattern.new(/''/).lookAheadToAvoid(/\$|\'|\\./), # I'm not exactly sure what this lookahead is for
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
                    start_pattern: Pattern.new(
                        tag_as: "string.quoted.double punctuation.definition.string.double",
                        match: /"/,
                    ),
                    end_pattern: Pattern.new(
                        tag_as: "string.quoted.double punctuation.definition.string.double",
                        match: /"/,
                    ),
                    includes: [
                        :escape_character_double_quote,
                        :interpolation,
                    ]
                )
                grammar[:single_quote] = PatternRange.new(
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
        grammar[:standalone_variable] = Pattern.new(
            tag_as: "variable.other",
            match: variable,
        )
        
        grammar[:variable_with_attributes] = Pattern.new(
            Pattern.new(
                tag_as: "variable.other.object.access",
                match: variable,
            ).maybe(@spaces).then(
                tag_as: "punctuation.separator.dot-access",
                match: ".",
            ).maybe(@spaces).then(
                match: zeroOrMoreOf(
                    middle_property = Pattern.new(
                        Pattern.new(
                            tag_as: "variable.other.object.property",
                            match: variable,
                        ).maybe(@spaces).then(
                            tag_as: "punctuation.separator.dot-access",
                            match: ".",
                        ),
                    ),
                ),
                includes: [ middle_property ],
            ).then(
                tag_as: "variable.other.property",
                match: variable,
            ),
        )
        
        grammar[:variable] = grammar[:variable_with_attributes].or(grammar[:standalone_variable])
    
    # 
    # function or attribute_set
    # 
        # FIXME
    
    # 
    # containers
    # 
        grammar[:empty_list] = Pattern.new(
            maybe(@spaces).then(
                match: "[",
                tag_as: "punctuation.definition.list",
            ).maybe(@spaces).then(
                match: "]",
                tag_as: "punctuation.definition.list",
            ),
        )
        
        grammar[:empty_set] = Pattern.new(
            maybe(@spaces).then(
                match: "{",
                tag_as: "punctuation.definition.dict",
            ).maybe(@spaces).then(
                match: "}",
                tag_as: "punctuation.definition.dict",
            ),
        )
    
        grammar[:list] = [
            PatternRange.new(
                tag_as: "meta.list",
                start_pattern: Pattern.new(
                    match: "[",
                    tag_as: "punctuation.definition.list",
                ),
                end_pattern: Pattern.new(
                    match: "]",
                    tag_as: "punctuation.definition.list",
                ),
                includes: [
                    
                ]
            ),
        ]
        
        # FIXME: add rec
        # FIXME: 
        grammar[:attribute_set] = [
            # Multi-line
            PatternRange.new(
                tag_as: "meta.dict",
                start_pattern: Pattern.new(
                    oneOf([
                        # word before hand
                        lookBehindFor(/\w|;/).maybe(@spaces).then(
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
                ]
            ),
        ]
    
    # 
    # operators
    # 
        # FIXME
    
    # 
    # functions
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
            tag_as: "punctuation.other.eplipsis",
            match: "...",
        )
        parameter_entry = oneOf([
            parameter.maybe(@spaces).then(comma),
            parameter.maybe(@spaces).then(optional),
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
                        lookBehindFor(/\w|;/).maybe(@spaces).then(
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
    
    # 
    # statements
    # 
        # if then else
        # let in
        # with
        # assert
        # include
    
    # 
    # other
    # 
        grammar[:comment] = oneOf([
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
        # FIXME: block comment
            # {
            #     "begin": "\/\\*([^*]|\\*[^\\\/])*",
            #     "end": "\\*\\\/",
            #     "patterns": [
            #         {
            #             "include": "#comment-remark"
            #         }
            #     ],
            #     "name": "comment.block.nix"
            # }
        
        # TODO: add shell support
    
    grammar[:value_base_case] = oneOf([
        grammar[:url],
        grammar[:normal_path_literal],
        grammar[:path_literal_content],
        grammar[:system_path_literal],
        grammar[:null],
        grammar[:boolean],
        grammar[:decimal],
        grammar[:integer],
        grammar[:double_quote_inline],
        grammar[:single_quote_inline],
        grammar[:empty_list],
        grammar[:empty_set],
        grammar[:variable],
    ])
    
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