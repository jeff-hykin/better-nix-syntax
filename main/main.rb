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
        :variable_with_attributes,
        :variable,
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
# basic patterns
# 
    # "with" 
    value_ahead = Pattern.new(/\s*+/).lookAheadToAvoid(/\b(?:import|assert|let|in|include|if|else|then|with|or)/).lookAheadFor(/\w|\d|\{|\(|\[|"|'/)
    
    grammar[:null] = Pattern.new(
        tag_as: "constant.language.null",
        match: variableBounds[/null/],
    )
    
    grammar[:boolean] = Pattern.new(
        tag_as: "constant.language.boolean",
        match: variableBounds[/true|false/],
    )
    
    grammar[:variable] = Pattern.new(
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
    
    grammar[:variable_entry] = grammar[:variable_with_attributes].or(grammar[:variable])
    
    grammar[:integer] = Pattern.new(
        match: variableBounds[/[0-9]+/],
        tag_as: "constant.numeric.integer",
    )
    
    grammar[:decimal] = Pattern.new(
        match: variableBounds[/[0-9]+\.[0-9]+/],
        tag_as: "constant.numeric.decimal",
    )
    
    grammar[:path_literal_content] = Pattern.new(
        tag_as: "string.unquoted.path punctuation.section.regexp punctuation.section.path",
        match: /[\w+\-\.\/]+\/[\w+\-\.\/]+/,
        includes: [
            Pattern.new(
                match: /\//,
                tag_as: "punctuation.separator.path",
            ),
            Pattern.new(
                match: variableBounds[/\.\.|\./],
                tag_as: "punctuation.separator.relative",
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
    
    grammar[:value_base_case] = oneOf([
        grammar[:null],
        grammar[:boolean],
        grammar[:integer],
        grammar[:decimal],
        grammar[:variable_entry],
        grammar[:path_literal_content],
        grammar[:normal_path_literal],
        grammar[:system_path_literal],
        grammar[:url],
        grammar[:empty_list],
        grammar[:empty_set],
    ])

# 
# compound patterns
# 
    
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