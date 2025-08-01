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
        :normal_context,
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
            ).then("\n"),
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
                tag_as: "string.unquoted.path punctuation.section.regexp punctuation.section.path.lookup storage.type.modifier",
                match: /<\w+>/,
                includes: [
                    Pattern.new(
                        match: /<|>/,
                        tag_as: "punctuation.section.regexp.path.angle-brackets",
                    ),
                    Pattern.new(
                        match: /\//,
                        tag_as: "punctuation.definition.path storage.type.modifier",
                    ),
                    Pattern.new(
                        match: variableBounds[/\.\.|\./],
                        tag_as: "punctuation.definition.relative storage.type.modifier",
                    ),
                ],
            )
            
            grammar[:path_literal_content] = Pattern.new(
                tag_as: "string.unquoted.path punctuation.section.regexp punctuation.section.path storage.type.modifier",
                match: /[\w+\-\.\/]+\/[\w+\-\.\/]+/,
                includes: [
                    Pattern.new(
                        match: /\//,
                        tag_as: "punctuation.definition.path storage.type.modifier",
                    ),
                    Pattern.new(
                        match: variableBounds[/\.\.|\./],
                        tag_as: "punctuation.definition.relative storage.type.modifier",
                    ),
                ],
            )
            
            grammar[:relative_path_literal] = Pattern.new(
                tag_as: "constant.other.path.relative",
                match: Pattern.new(
                    Pattern.new(
                        match:/\.\//,
                        tag_as: "punctuation.definition.path.relative storage.type.modifier",
                    ).then(grammar[:path_literal_content])
                ),
            )
            
            grammar[:absolute_path_literal] = Pattern.new(
                tag_as: "constant.other.path.absolute",
                match: Pattern.new(
                    Pattern.new(
                        match:/\//,
                        tag_as: "punctuation.definition.path.absolute storage.type.modifier",
                    ).then(grammar[:path_literal_content])
                ),
            )
            
            grammar[:system_path_literal] = Pattern.new(
                tag_as: "constant.other.path.system",
                match: Pattern.new(
                    Pattern.new(
                        match: /</,
                        tag_as: "punctuation.definition.path.system storage.type.modifier",
                    ).then(
                        grammar[:path_literal_content]
                    ).then(
                        match: />/,
                        tag_as: "punctuation.definition.path.system storage.type.modifier",
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
        builtin = Pattern.new(
            tag_as: "support.module variable.language.special.builtins",
            match: Pattern.new(variableBounds[/builtins/]),
        )
        grammar[:variable] = Pattern.new(
            builtin.or(
                tag_as: "variable.other.external",
                match: Pattern.new(external_variable),
            ).or(
                tag_as: "variable.other.dirty",
                match: Pattern.new(dirty_variable),
            ).or(
                tag_as: "variable.other.object",
                match: Pattern.new(variable),
            )
        )
        
        function_call_lookahead = std_space.lookAheadToAvoid(/then\b|in\b|else\b|- |-$/).then(lookAheadFor(/\{|"|'|\d|\w|-[^>]|\.\/|\.\.\/|\/\w|\(|\[|if\b|let\b|with\b|rec\b/).or(lookAheadFor(grammar[:url])))
        grammar[:standalone_function_call] = Pattern.new(
            oneOf([
                lookBehindToAvoid(/\)|"|\d|\s/).then(std_space).then(
                    tag_as: "entity.name.function.call support.type.builtin.top-level support.type.builtin.property.$match",
                    match: @tokens.that(:areBuiltinAttributes,:areFunctions,:canAppearTopLevel),
                ),
                
                lookBehindToAvoid(/\)|"|\d|\s/).then(std_space).then(
                    tag_as: "entity.name.function.call.external",
                    match: external_variable
                ),
                
                lookBehindToAvoid(/\)|"|\d|\s/).then(std_space).then(
                    tag_as: "entity.name.function.call.dirty",
                    match: dirty_variable,
                ),
                
                lookBehindToAvoid(/\)|"|\d|\s/).then(std_space).then(
                    tag_as: "entity.name.function.call",
                    match: variable,
                ),
            ]).then(function_call_lookahead)
        )
        grammar[:standalone_function_call_guess] = oneOf([
            lookBehindToAvoid(/\(/).then(
                tag_as: "entity.name.function.call support.type.builtin.top-level support.type.builtin.property.$match",
                match: @tokens.that(:areBuiltinAttributes,:areFunctions,:canAppearTopLevel),
            ).then(function_call_lookahead),
                
            lookBehindFor(/\(/).then(
                tag_as: "entity.name.function.call.external",
                match: external_variable,
            ).then(function_call_lookahead.or(std_space.then(@end_of_line))),
            
            lookBehindFor(/\(/).then( 
                tag_as: "entity.name.function.call.dirty",
                match: dirty_variable,
            ).then(function_call_lookahead.or(std_space.then(@end_of_line))),
            
            lookBehindFor(/\(/).then(
                tag_as: "entity.name.function.call",
                match: variable,
            ).then(function_call_lookahead.or(std_space.then(@end_of_line))),
            
        ])
        
        grammar[:dot_access] = dot_access = Pattern.new(
            tag_as: "punctuation.separator.dot-access",
            match: ".",
        )
        inline_dot_access = std_space.then(dot_access).then(std_space)
        
        attributeGenerator = ->(tag) do
            return oneOf([
                # standalone
                lookBehindToAvoid(/\./).then(
                    tag_as: "variable.other.#{tag}",
                    should_fully_match: [ "zipListsWith'" ],
                    should_not_partial_match: ["in", "let", "if"],
                    match: variable,
                ).lookAheadToAvoid(/\./),
                
                # first
                lookBehindToAvoid(/\./).then(
                    tag_as: "variable.other.object.access",
                    match: variable,
                ),
                # last
                Pattern.new(
                    tag_as: if tag == "object" then "variable.other.property.last" else "variable.other.#{tag}.last" end,
                    match: variable.lookAheadToAvoid(/\./), # .or(interpolated_attribut),
                ),
                # middle
                Pattern.new(
                    tag_as: "variable.other.object.property",
                    match: variable, #.or(interpolated_attribute),
                ),
                grammar[:double_quote_inline],
                grammar[:single_quote_inline],
            ])
        end
        
        grammar[:attribute_assignment] = attribute_assignment = attributeGenerator["constant"]
        # NOTE: does not handle interpolation
        attribute_assignment_chain = attribute_assignment.zeroOrMoreOf(
            inline_dot_access.then(
                attribute_assignment
            )
        )
        
        attribute = attributeGenerator["object"]
        # this should only be internally used
        attribute_chain = Pattern.new(
            attribute.zeroOrMoreOf(
                inline_dot_access.then(
                    attribute
                )
            ).then(std_space)
        )
        builtin_attribute_tagger = lookBehindToAvoid(/[^ \t]builtins\./).lookBehindFor(/builtins\./).then(
            tag_as: "variable.language.special.method.$match support.type.builtin.property.$match",
            match: @tokens.that(:areBuiltinAttributes, !:areFunctions).lookAheadToAvoid(/[a-zA-Z0-9_\-']/),
        )
        builtin_method_tagger = lookBehindToAvoid(/[^ \t]builtins\./).lookBehindFor(/builtins\./).then(
            tag_as: "variable.language.special.property.$match entity.name.function.call.builtin support.type.builtin.method.$match",
            match: @tokens.that(:areBuiltinAttributes, :areFunctions).lookAheadToAvoid(/[a-zA-Z0-9_\-']/),
        )
        # this is used for lists where spaces separate elements (e.g. no method calls)
        grammar[:variable_maybe_attrs_no_method] = Pattern.new(
            match: attribute_chain,
            includes: [
                lookBehindToAvoid(".").then(builtin), # "builtins" at the start
                builtin_attribute_tagger, # the attribute of builtins
                builtin_method_tagger, # even though its a method, it can be treated as an attribute (higher order function-type-stuff)
                attribute, # first/middle/last tagging
                :dot_access,
            ]
        )
        
        method_pattern_tagger = builtin_method_tagger.or(
            oneOf([
                Pattern.new(
                    tag_as: "entity.name.function.method",
                    match: variable,
                ),
                grammar[:double_quote_inline],
                grammar[:single_quote_inline],
            ]).then(function_call_lookahead)
        )
        # this is needed because maybe-function-call needs to be below var-with-attrs but above standalone-var
        grammar[:standalone_variable] = lookBehindToAvoid(".").then(grammar[:variable]).lookAheadToAvoid(".")
        # this can be used everywhere except lists and attribute assignment
        grammar[:variable_attrs_maybe_method] = Pattern.new(
            tag_as: "meta.variable_attrs_maybe_method",
            # needs to definitely have attrs because maybe-function-call needs to be below var-with-attrs but above standalone-var
            match: grammar[:variable].then(inline_dot_access).then(attribute_chain),
            # includes: [
            #     lookBehindToAvoid(".").then(builtin), # "builtins" at the start
            #     builtin_attribute_tagger, # the attribute of builtins
            #     method_pattern_tagger, # even though its a method, it can be treated as an attribute (higher order function-type-stuff)
            #     attribute, # first/middle/last tagging
            #     :dot_access,
            # ]
        )
        grammar[:variable_with_method_probably] = Pattern.new(
            lookBehindFor("(").then(
                grammar[:variable_attrs_maybe_method]
            ).then(inline_dot_access).then(
                Pattern.new(
                    tag_as: "entity.name.function.method",
                    match: variable,
                ).then(
                    function_call_lookahead.or(std_space.then(@end_of_line))
                )
            ),
        )
        
        grammar[:variable_or_function] = oneOf([
            grammar[:variable_with_method_probably],
            grammar[:variable_attrs_maybe_method],
            grammar[:standalone_function_call],
            grammar[:standalone_function_call_guess],
            grammar[:standalone_variable],
            attribute, # something that would be a standalone variable but has interpolation as the "next" or "prev"
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
        
        # TODO: interpolation ${} currently doesn't work for with() statements
        namespace_with_attributes = Pattern.new(
            Pattern.new(
                tag_as: "entity.name.namespace.object.access",
                match: variable,
            ).then(inline_dot_access).then(
                match: zeroOrMoreOf(
                    middle_repeat_namespace = Pattern.new(
                        namespace_attribute.then(inline_dot_access),
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
        # this one is, unfortunately, special
        grammar[:or_operator] = Pattern.new(
            tag_as: "keyword.operator.or",
            match: /\bor\b/,
        )
    
    # 
    # keyworded values
    # 
        grammar[:value_prefix] = value_prefix = Pattern.new(
            Pattern.new(
                tag_as: "keyword.operator.with",
                match: variableBounds[/with/],
            ).then(std_space).then(
                tag_as: "meta.with",
                match: namespace,
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
                    :list_context,
                ]
            ),
        ]
    # 
    # basic function
    # 
        grammar[:parameter] = Pattern.new(
            tag_as: "variable.parameter.function",
            match: variable,
        )
        grammar[:probably_parameter] = grammar[:parameter].lookAheadFor(/ *+:/)
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
                        :attribute_assignment,
                        :dot_access,
                    ],
                ).then(std_space).then(
                    assignment_operator
                )
            )
        end
        
        normal_attr_assignment = assignmentOf[
            attribute_assignment_chain
        ]
        
        assignment_start = Pattern.new(
            tag_as: "meta.assignment-start",
            match: Pattern.new(
                Pattern.new(
                    lookBehindToAvoid(/[^ \t]/).lookAheadFor(/inherit\b/)
                ).or(
                    normal_attr_assignment,
                )
            ),
            includes: [
                normal_attr_assignment,
                :attribute_assignment,
                :dot_access,
                assignment_operator,
            ],
        )
        
        
        # NOTE: this one doesn't actually need to tag stuff or fully-match things
        #       it ONLY needs to detect the start
        assignment_start_lookahead = Pattern.new(
            Pattern.new(assignment_start).or(
                /\$\{/, # start of a dynamic attribute
            ).or(
                # normal attribute, then start of a dynamic attribute
                attribute_assignment_chain.then(inline_dot_access).then(/\$\{/) 
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
                        includes: [
                            namespace,
                            :normal_context,
                        ],
                    ),
                    attribute_assignment,
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
                #         :normal_context,
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
                    :normal_context,
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
                            :normal_context,
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
                            :normal_context,
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
                        start_pattern: lookAheadFor(assignment_start_lookahead),
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
                        tag_as: "meta.punctuation.section.function meta.punctuation.section.parameters",
                        start_pattern: Pattern.new(
                            grammar[:parameter].or(eplipsis).then(std_space).lookAheadFor(/$|\?|,|\}/),
                        ),
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
                                    :normal_context,
                                ]
                            ),
                            eplipsis,
                            comma,
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
                        :comments,
                        :normal_context,
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
                        :comments,
                        :normal_context,
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
                        :comments,
                        :normal_context
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
                :comments,
                :normal_context,
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
                                attribute.then(inline_dot_access),
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
                :comments,
                :normal_context,
            ]
        )
        
        grammar[:literal] = oneOf([
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
            grammar[:literal],
            grammar[:probably_parameter],
            grammar[:variable_or_function],
        ])
        
        grammar[:normal_context] = [
            :comments,
            :value_prefix,
            :double_quote,
            :single_quote,
            :list,
            :brackets,
            :parentheses,
            :if_then_else,
            :let_in_statement,
            :assert,
            :path_literal_angle_brackets,
            :relative_path_literal,
            :absolute_path_literal,
            :operators,
            :basic_function,
            :inline_value,
            :interpolation,
            attribute,  # these would be redundant except that interpolation causes variable_or_function not to match 
            :dot_access, # these would be redundant except that interpolation causes variable_or_function not to match 
        ]
        grammar[:list_context] = [
            :comments,
            # :value_prefix,                # not allowed in :list_context (needs parentheses)
            :double_quote,
            :single_quote,
            :list,
            :brackets, # NOTE: this matched func-or-attrset but in :list_context only attrset is valid (e.g. could be improved in future)
            :parentheses,
            # :if_then_else,                # not allowed in :list_context (needs parentheses)
            # :let_in_statement,            # not allowed in :list_context (needs parentheses)
            # :assert,                      # not allowed in :list_context (needs parentheses)
            :path_literal_angle_brackets,
            :relative_path_literal,
            :absolute_path_literal,
            # :operators,                   # not allowed in :list_context (needs parentheses)
            :or_operator, # for some reason... this one is allowed in list contexts
            # :basic_function,              # not allowed in :list_context (needs parentheses)
            # :inline_value,                # not allowed in :list_context because of the value_prefix
            :literal,                        # partial substitute for :inline_value
            :variable_maybe_attrs_no_method, # partial substitute for :inline_value
            :interpolation,
            attribute,  # these would be redundant except that interpolation causes variable_or_function not to match 
            :dot_access, # these would be redundant except that interpolation causes variable_or_function not to match 
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