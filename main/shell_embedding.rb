require 'ruby_grammar_builder'
grammar = @grammar # this file is imported from main.rb

# 
# 
# 
# inline embed the entire shell grammar (yep its a mess)
# 
# 
# 
    # 
    # 
    # create grammar!
    # 
    # 
        shell_grammar = Grammar.fromTmLanguage("./main/shell_modified.tmLanguage.json")

    #
    #
    # Contexts
    #
    #
        # this naming thing is just a backwards compatibility thing. If all tests pass without it, it should be removed
        grammar[:SHELL_initial_context] = [
                :SHELL_command_statement,
                # :SHELL_comment,
                # :SHELL_pipeline,
                # :SHELL_normal_statement_seperator,
                # :SHELL_logical_expression_double,
                # :SHELL_logical_expression_single,
                # :SHELL_assignment_statement,
                # :SHELL_case_statement,
                # :SHELL_for_statement,
                # :SHELL_loop,
                # :SHELL_function_definition,
                # :SHELL_line_continuation,
                # :SHELL_arithmetic_double,
                # :SHELL_misc_ranges,
                # :SHELL_variable,
                # :SHELL_interpolation,
                # :SHELL_heredoc,
                # :SHELL_herestring,
                # :SHELL_redirection,
                # :SHELL_pathname,
                # :SHELL_floating_keyword,
                # :SHELL_alias_statement,
                # # :SHELL_custom_commands,
                # :SHELL_normal_statement,
                # :SHELL_range_expansion,
                # :SHELL_string,
                # :SHELL_support,
            ]
        grammar[:SHELL_boolean] = Pattern.new(
                match: /\b(?:true|false)\b/,
                tag_as: "constant.language.$match.shell"
            )
        grammar[:SHELL_normal_context] = [
                :SHELL_comment,
                :SHELL_pipeline,
                :SHELL_normal_statement_seperator,
                :SHELL_misc_ranges,
                :SHELL_boolean,
                :SHELL_redirect_number,
                :SHELL_range_expansion,
                :SHELL_numeric_literal,
                :SHELL_string,
                :SHELL_variable,
                :SHELL_interpolation,
                :SHELL_heredoc,
                :SHELL_herestring,
                :SHELL_redirection,
                :SHELL_pathname,
                :SHELL_floating_keyword,
                :SHELL_support,
                :SHELL_parenthese,
            ]
        grammar[:SHELL_option_context] = [
                :SHELL_misc_ranges,
                :SHELL_range_expansion,
                :SHELL_string,
                :SHELL_variable,
                :SHELL_interpolation,
                :SHELL_heredoc,
                :SHELL_herestring,
                :SHELL_redirection,
                :SHELL_pathname,
                :SHELL_floating_keyword,
                :SHELL_support,
            ]
        grammar[:SHELL_logical_expression_context] = [
                :SHELL_regex_comparison,
                # :SHELL_arithmetic_dollar,
                :SHELL_arithmetic_no_dollar,
                :'logical-expression',
                :SHELL_logical_expression_single,
                :SHELL_logical_expression_double,
                :SHELL_comment,
                :SHELL_boolean,
                :SHELL_redirect_number,
                :SHELL_numeric_literal,
                :SHELL_pipeline,
                :SHELL_normal_statement_seperator,
                :SHELL_range_expansion,
                :SHELL_string,
                :SHELL_variable,
                :SHELL_interpolation,
                :SHELL_heredoc,
                :SHELL_herestring,
                :SHELL_pathname,
                :SHELL_floating_keyword,
                :SHELL_support,
            ]
    #
    #
    # Patterns
    #
    #
        empty_line = /^[ \t]*+$/
        line_continuation = /\\\n?$/
        grammar[:SHELL_line_continuation] = Pattern.new(
            match: Pattern.new(/\\/).lookAheadFor(/\n/),
            tag_as: "constant.character.escape.line-continuation.shell"
        )
        
        part_of_a_variable = /[a-zA-Z_0-9-]+/ # yes.. ints can be regular variables/function-names in shells
        # this is really useful for keywords. eg: variableBounds[/new/] wont match "newThing" or "thingnew"
        variableBounds = ->(regex_pattern) do
            lookBehindToAvoid(@standard_character).then(regex_pattern).lookAheadToAvoid(@standard_character)
        end
        variable_name = variableBounds[part_of_a_variable]
        
        std_space = Pattern.new(/[ \t]*+/)
        
        # this numeric_literal was stolen from C++, has been cleaned up some, but could have a few dangling oddities
        grammar[:SHELL_numeric_literal] = lookBehindFor(/=| |\t|^|\{|\(|\[/).then(
            Pattern.new(
                match: /0[xX][0-9A-Fa-f]+/,
                tag_as: "constant.numeric.shell constant.numeric.hex.shell"
            ).or(
                match: /0\d+/,
                tag_as: "constant.numeric.shell constant.numeric.octal.shell"
            ).or(
                match: /\d{1,2}#[0-9a-zA-Z@_]+/,
                tag_as: "constant.numeric.shell constant.numeric.other.shell"
            ).or(
                match: /-?\d+(?:\.\d+)/,
                tag_as: "constant.numeric.shell constant.numeric.decimal.shell"
            ).or(
                match: /-?\d+(?:\.\d+)+/,
                tag_as: "constant.numeric.shell constant.numeric.version.shell"
            ).or(
                match: /-?\d+/,
                tag_as: "constant.numeric.shell constant.numeric.integer.shell"
            )
        ).lookAheadFor(/ |\t|$|\}|\)|;/)
        grammar[:SHELL_redirect_number] = lookBehindFor(/[ \t]/).then(
            oneOf([
                Pattern.new(
                    tag_as: "keyword.operator.redirect.stdout.shell",
                    match: /1/,
                ),
                Pattern.new(
                    tag_as: "keyword.operator.redirect.stderr.shell",
                    match: /2/,
                ),
                Pattern.new(
                    tag_as: "keyword.operator.redirect.$match.shell",
                    match: /\d+/,
                ),
            ]).lookAheadFor(/>/)
        )
        
        # 
        # comments
        #
        grammar[:SHELL_comment] = Pattern.new(
            Pattern.new(
                Pattern.new(/^/).or(/[ \t]++/)
            ).then(
                Pattern.new(
                    tag_as: "comment.line.number-sign.shell meta.shebang.shell",
                    match: Pattern.new(
                        Pattern.new(
                            match: /#!/,
                            tag_as: "punctuation.definition.comment.shebang.shell"
                        ).then(/.*/)
                    ),
                ).or(
                    tag_as: "comment.line.number-sign.shell",
                    match: Pattern.new(
                        Pattern.new(
                            match: /#/,
                            tag_as: "punctuation.definition.comment.shell"
                        ).then(/.*/)
                    ),
                )
            )
        )
        
        # 
        # punctuation / operators
        # 
        # replaces the old list pattern
        grammar[:SHELL_normal_statement_seperator] = Pattern.new(
                match: /;/,
                tag_as: "punctuation.terminator.statement.semicolon.shell"
            ).or(
                match: /&&/,
                tag_as: "punctuation.separator.statement.and.shell"
            ).or(
                match: /\|\|/,
                tag_as: "punctuation.separator.statement.or.shell"
            ).or(
                match: /&/,
                tag_as: "punctuation.separator.statement.background.shell"
            )
        statement_end = /[|&;]/
        
        # function thing() {}
        # thing() {}
        function_name_pattern = /[^ \t\n\r\(\)="']+/ 
        # ^ what is actually allowed by POSIX is not the same as what shells actually allow
        # so this pattern tries to be as flexible as possible
        grammar[:SHELL_function_definition] = PatternRange.new(
            tag_as: "meta.function.shell",
            start_pattern: std_space.then(
                Pattern.new(
                    # this is the case with the function keyword
                    Pattern.new(
                        match: /\bfunction\b/,
                        tag_as: "storage.type.function.shell"
                    ).then(std_space).then(
                        match: function_name_pattern,
                        tag_as: "entity.name.function.shell",
                    ).maybe(
                        Pattern.new(
                            match: /\(/,
                            tag_as: "punctuation.definition.arguments.shell",
                        ).then(std_space).then(
                            match: /\)/,
                            tag_as: "punctuation.definition.arguments.shell",
                        )
                    )
                ).or(
                    # no function keyword
                    Pattern.new(
                        match: function_name_pattern,
                        tag_as: "entity.name.function.shell",
                    ).then(
                        std_space
                    ).then(
                        match: /\(/,
                        tag_as: "punctuation.definition.arguments.shell",
                    ).then(std_space).then(
                        match: /\)/,
                        tag_as: "punctuation.definition.arguments.shell",
                    )
                )
            ),
            apply_end_pattern_last: true,
            end_pattern: lookBehindFor(/\}|\)/),
            includes: [
                # exists soley to eat one char after the "func_name()" so that the lookBehind doesnt immediately match
                Pattern.new(/\G(?:\t| |\n)/),
                PatternRange.new(
                    tag_as: "meta.function.body.shell",
                    start_pattern: Pattern.new(
                        match: "{",
                        tag_as: "punctuation.definition.group.shell punctuation.section.function.definition.shell",
                    ),
                    end_pattern: Pattern.new(
                        match: "}",
                        tag_as: "punctuation.definition.group.shell punctuation.section.function.definition.shell",
                    ),
                    includes: [
                        :SHELL_initial_context,
                    ],
                ),
                PatternRange.new(
                    tag_as: "meta.function.body.shell",
                    start_pattern: Pattern.new(
                        match: "(",
                        tag_as: "punctuation.definition.group.shell punctuation.section.function.definition.shell",
                    ),
                    end_pattern: Pattern.new(
                        match: ")",
                        tag_as: "punctuation.definition.group.shell punctuation.section.function.definition.shell",
                    ),
                    includes: [
                        :SHELL_initial_context,
                    ],
                ),
                :SHELL_initial_context,
            ],
        )
        
        simple_option = Pattern.new(
            match:/(?<!\w)-\w+\b/,
            tag_as: "string.unquoted.argument.shell constant.other.option.shell",
        )
        grammar[:SHELL_modifiers] = modifier = Pattern.new(
            match: /(?<=^|;|&|[ \t])(?:#{@shell_tokens.representationsThat(:areModifiers).join("|")})(?=[ \t]|;|&|$)/,
            tag_as: "storage.modifier.$match.shell",
        )
        
        assignment_end = lookAheadFor(/ |\t|$/).or(grammar[:SHELL_normal_statement_seperator])
        assignment_start = std_space.then(
            Pattern.new(
                match: variable_name,
                tag_as: "variable.other.assignment.shell",
            ).maybe(
                Pattern.new(
                    match: "[",
                    tag_as: "punctuation.definition.array.access.shell",
                ).then(
                    match: maybe("$").then(variable_name).or("@").or("*").or(
                        match: /-?\d+/,
                        tag_as: "constant.numeric.shell constant.numeric.integer.shell",
                    ),
                    tag_as: "variable.other.assignment.shell",
                ).then(
                    match: "]",
                    tag_as: "punctuation.definition.array.access.shell",
                ),
            )
        ).then(
            Pattern.new(
                match: /\=/,
                tag_as: "keyword.operator.assignment.shell",
            ).or(
                match: /\+\=/,
                tag_as: "keyword.operator.assignment.compound.shell",
            ).or(
                match: /\-\=/,
                tag_as: "keyword.operator.assignment.compound.shell",
            )
        )
        grammar[:SHELL_alias_statement] = PatternRange.new(
            tag_as: "meta.expression.assignment.alias.shell",
            start_pattern: Pattern.new(
                std_space.then(
                    match: /alias/,
                    tag_as: "storage.type.alias.shell"
                ).then(std_space).then(
                    match: zeroOrMoreOf(
                        simple_option.then(std_space)
                    ),
                    includes: [
                        simple_option
                    ]
                ).then(assignment_start),
            ),
            end_pattern: assignment_end,
            includes: [ :SHELL_normal_context ]
        )
        
        possible_pre_command_characters   = /(?:^|;|\||&|!|\(|\{|\`)/
        basic_possible_command_start      = lookAheadToAvoid(/(?:!|&|\||\(|\)|\{|\[|<|>|#|\n|$|;|[ \t])/)
        possible_argument_start  = lookAheadToAvoid(/(?:&|\||\(|\[|#|\n|$|;)/)
        command_end              = lookAheadFor(/;|\||&|\n|\)|\`|\{|\}|[ \t]*#|\]/).lookBehindToAvoid(/\\/)
        command_continuation     = lookBehindToAvoid(/ |\t|;|\||&|\n|\{|#/)
        unquoted_string_end      = lookAheadFor(/ |\t|;|\||&|$|\n|\)|\`/)
        argument_end             = lookAheadFor(/ |\t|;|\||&|$|\n|\)|\`/)
        invalid_literals         = Regexp.quote(@shell_tokens.representationsThat(:areInvalidLiterals).join(""))
        valid_literal_characters = Regexp.new("[^ \t\n#{invalid_literals}]+")
        any_builtin_name         = @shell_tokens.representationsThat(:areBuiltInCommands).map{ |value| Regexp.quote(value) }.join("|")
        any_builtin_name         = Regexp.new("(?:#{any_builtin_name})(?!\/)")
        any_builtin_name         = variableBounds[any_builtin_name]
        any_builtin_control_flow = @shell_tokens.representationsThat(:areBuiltInCommands, :areControlFlow).map{ |value| Regexp.quote(value) }.join("|")
        any_builtin_control_flow = Regexp.new("(?:#{any_builtin_control_flow})")
        any_builtin_control_flow = variableBounds[any_builtin_control_flow]
        possible_command_start   = basic_possible_command_start.lookAheadToAvoid(
            Regexp.new(
                @shell_tokens.representationsThat(
                    :areShellReservedWords || :areControlFlow || :areModifiers
                # escape before putting into regex
                ).map{
                    |value| Regexp.quote(value) 
                # add word-delimiter
                }.map{
                    |value| "#{value} |#{value}\t|#{value}$"
                # "OR" join
                }.join("|")
            )
        )
        
        grammar[:SHELL_floating_keyword] = [
            Pattern.new(
                match: /(?<=^|;|&| |\t)(?:then|elif|else|done|end|do|if|fi)(?= |\t|;|&|$)/,
                tag_as: "keyword.control.$match.shell",
            ),
            # modifier
        ]
        
        # 
        # 
        # commands (very complicated becase sadly a command name can span multiple lines)
        # 
        #
        grammar[:SHELL_simple_unquoted] = Pattern.new(
            match: /[^ \t\n#{invalid_literals}]/,
            tag_as: "string.unquoted.shell",
        )
        generateUnquotedArugment = ->(tag_as) do
            std_space.then(
                tag_as: tag_as,
                match: Pattern.new(valid_literal_characters).lookAheadToAvoid(/>/), # ex: 1>&2
                includes: [
                    # wildcard
                    Pattern.new(
                        match: /\*/,
                        tag_as: "variable.language.special.wildcard.shell"
                    ),
                    :SHELL_variable,
                    :SHELL_numeric_literal,
                    variableBounds[grammar[:SHELL_boolean]],
                ]
            ) 
        end
        
        grammar[:SHELL_continuation_of_double_quoted_command_name] = PatternRange.new(
            tag_content_as: "meta.statement.command.name.continuation.shell string.quoted.double.shell entity.name.function.call.shell entity.name.command.shell",
            start_pattern: Pattern.new(
                Pattern.new(
                    /\G/
                ).lookBehindFor(/"/)
            ),
            end_pattern: Pattern.new(
                match: "\"",
                tag_as: "string.quoted.double.shell punctuation.definition.string.end.shell entity.name.function.call.shell entity.name.command.shell",
            ),
            includes: [
                Pattern.new(
                    match: /\\[\$\n`"\\]/,
                    tag_as: "constant.character.escape.shell",
                ),
                :SHELL_variable,
                :SHELL_interpolation,
            ],
        )
        
        grammar[:SHELL_continuation_of_single_quoted_command_name] = PatternRange.new(
            tag_content_as: "meta.statement.command.name.continuation.shell string.quoted.single.shell entity.name.function.call.shell entity.name.command.shell",
            start_pattern: Pattern.new(
                Pattern.new(
                    /\G/
                ).lookBehindFor(/'/)
            ),
            end_pattern: Pattern.new(
                match: "\'",
                tag_as: "string.quoted.single.shell punctuation.definition.string.end.shell entity.name.function.call.shell entity.name.command.shell",
            ),
        )
        
        grammar[:SHELL_basic_command_name] = Pattern.new(
            tag_as: "meta.statement.command.name.basic.shell",
            match: Pattern.new(
                Pattern.new(
                    possible_command_start
                ).then(
                    modifier.or(
                        tag_as: "entity.name.function.call.shell entity.name.command.shell",
                        match: lookAheadToAvoid(/"|'|\\\n?$/).then(/[^!'"<> \t\n\r]+?/), # start of unquoted command
                        includes: [
                            Pattern.new(
                                match: any_builtin_control_flow,
                                tag_as: "keyword.control.$match.shell",
                            ),
                            Pattern.new(
                                match: any_builtin_name.lookAheadToAvoid(/-/),
                                tag_as: "support.function.builtin.shell",
                            ),
                            :SHELL_variable,
                        ]
                    )
                ).then(
                    lookAheadFor(/ |\t/).or(command_end)
                )
            ),
        )
        grammar[:SHELL_start_of_command] = Pattern.new(
            std_space.then(
                possible_command_start.lookAheadToAvoid(line_continuation) # avoid line exscapes
            )
        )
        
        grammar[:NIX_escape_character_single_quote] = Pattern.new(
            tag_as: "constant.character.escape.nix.shell",
            match: Pattern.new(/\'\'/).lookAheadFor(/\$|\'/),
        ),
        grammar[:SHELL_argument_context] = [
            :SHELL_range_expansion,
            generateUnquotedArugment["string.unquoted.argument.shell"],
            :SHELL_normal_context,
            # :NIX_escape_character_single_quote,
        ]
        grammar[:SHELL_argument] = PatternRange.new(
            tag_as: "meta.argument.shell",
            start_pattern: Pattern.new(/[ \t]++/).then(possible_argument_start),
            end_pattern: unquoted_string_end,
            includes: [
                :SHELL_argument_context,
                :SHELL_line_continuation,
            ]
        )
        grammar[:SHELL_option] = PatternRange.new(
            tag_content_as: "string.unquoted.argument.shell constant.other.option.shell",
            start_pattern: Pattern.new(  
                Pattern.new(/[ \t]++/).then(
                    match: /-/,
                    tag_as: "string.unquoted.argument.shell constant.other.option.dash.shell"
                ).then(
                    match: basic_possible_command_start,
                    tag_as: "string.unquoted.argument.shell constant.other.option.shell",
                )
            ),
            end_pattern: lookAheadFor(/[ \t]/).or(command_end),
            includes: [
                :SHELL_option_context,
            ]
        )
        grammar[:SHELL_simple_options] = zeroOrMoreOf(
            Pattern.new(/[ \t]++/).then(
                match: /\-/,
                tag_as: "string.unquoted.argument.shell constant.other.option.dash.shell"
            ).then(
                match: /\w+/,
                tag_as: "string.unquoted.argument.shell constant.other.option.shell"
            )
        )
        
        keywords = @shell_tokens.representationsThat(:areShellReservedWords, :areNotModifiers)
        keyword_patterns = /#{keywords.map { |each| each+'\W|'+each+'\$' } .join('|')}/
        control_prefix_commands = @shell_tokens.representationsThat(:areControlFlow, :areFollowedByACommand)
        valid_after_patterns = /#{control_prefix_commands.map { |each| '^'+each+' | '+each+' |\t'+each+' ' } .join('|')}/
        grammar[:SHELL_typical_statements] = [
            :SHELL_assignment_statement,
            :SHELL_case_statement,
            :SHELL_for_statement,
            :SHELL_while_statement,
            :SHELL_function_definition,
            :SHELL_command_statement,
            :SHELL_line_continuation,
            :SHELL_arithmetic_double,
            :SHELL_normal_context,
        ]
        grammar[:SHELL_command_name_range] = PatternRange.new(
            tag_as: "meta.statement.command.name.shell",
            start_pattern: Pattern.new(/\G/,),
            end_pattern: argument_end.or(lookAheadFor(/</)),
            includes: [
                # 
                # builtin commands
                # 
                # :SHELL_modifiers, # TODO: eventually this one thing shouldnt be here
                
                Pattern.new(
                    match: any_builtin_control_flow,
                    tag_as: "entity.name.function.call.shell entity.name.command.shell keyword.control.$match.shell",
                ),
                Pattern.new(
                    match: any_builtin_name.lookAheadToAvoid(/-/),
                    tag_as: "entity.name.function.call.shell entity.name.command.shell support.function.builtin.shell",
                ),
                :SHELL_variable,
                
                # 
                # unquoted parts of a command name
                # 
                Pattern.new(
                    lookBehindToAvoid(/\w/).lookBehindFor(/\G|\}|\)/).then(
                        tag_as: "entity.name.function.call.shell entity.name.command.shell",
                        match: /[^ \n\t\r"'=;#$!&\|`\)\{<>]+/,
                    ),
                ),
                
                # 
                # any quotes within a command name
                # 
                PatternRange.new(
                    start_pattern: Pattern.new(
                        Pattern.new(
                            Pattern.new(/\G/).or(command_continuation)
                        ).then(
                            maybe(
                                match: /\$/,
                                tag_as: "meta.statement.command.name.quoted.shell punctuation.definition.string.shell entity.name.function.call.shell entity.name.command.shell",
                            ).then(
                                reference: "start_quote",
                                match: Pattern.new(
                                    Pattern.new(
                                        tag_as: "meta.statement.command.name.quoted.shell string.quoted.double.shell punctuation.definition.string.begin.shell entity.name.function.call.shell entity.name.command.shell",
                                        match: /"/
                                    ).or(
                                        tag_as: "meta.statement.command.name.quoted.shell string.quoted.single.shell punctuation.definition.string.begin.shell entity.name.function.call.shell entity.name.command.shell",
                                        match: /'/,
                                    )
                                )
                            )
                        )
                    ),
                    end_pattern: lookBehindToAvoid(/\G/).lookBehindFor(matchResultOf("start_quote")),
                    includes: [
                        :SHELL_continuation_of_single_quoted_command_name,
                        :SHELL_continuation_of_double_quoted_command_name,
                    ],
                ),
                :SHELL_line_continuation,
                :SHELL_simple_unquoted,
            ],
        )
        grammar[:SHELL_command_statement] = PatternRange.new(
            tag_as: "meta.statement.command.shell",
            start_pattern: grammar[:SHELL_start_of_command],
            end_pattern: command_end,
            includes: [
                # 
                # Command Name Range
                # 
                :SHELL_command_name_range,
                
                # 
                # everything else after the command name
                # 
                :SHELL_line_continuation,
                :SHELL_option,
                :SHELL_argument,
                # :SHELL_custom_commands,
                # :SHELL_statement_context,
                :SHELL_string,
                :SHELL_heredoc,
                :SHELL_variable,
                :SHELL_simple_unquoted,
                :NIX_escape_character_single_quote,
            ],
        )
        grammar[:SHELL_normal_assignment_statement] = PatternRange.new(
            tag_as: "meta.expression.assignment.shell",
            start_pattern: assignment_start,
            end_pattern: command_end,
            includes: [
                :SHELL_comment,
                :SHELL_string,
                :SHELL_normal_assignment_statement,
                PatternRange.new(
                    tag_as: "meta.statement.command.env.shell",
                    start_pattern: lookBehindFor(/ |\t/).lookAheadToAvoid(/ |\t|\w+=/),
                    end_pattern: command_end,
                    includes: [
                        # 
                        # Command Name Range
                        # 
                        :SHELL_command_name_range,
                        
                        # 
                        # everything else after the command name
                        # 
                        :SHELL_line_continuation,
                        :SHELL_option,
                        :SHELL_argument,
                        # :SHELL_custom_commands,
                        # :SHELL_statement_context,
                        :SHELL_string,
                    ],
                ),
                :SHELL_simple_unquoted, 
                :SHELL_normal_context,
            ]
        )
        grammar[:SHELL_array_value] = PatternRange.new(
            start_pattern: assignment_start.then(std_space).then(
                match:"(",
                tag_as: "punctuation.definition.array.shell",
            ),
            end_pattern: Pattern.new(
                match: ")",
                tag_as: "punctuation.definition.array.shell",
            ),
            includes: [
                :SHELL_comment,
                Pattern.new(
                    Pattern.new(
                        match: variable_name,
                        tag_as: "variable.other.assignment.array.shell entity.other.attribute-name.shell",
                    ).then(
                        match: /\=/,
                        tag_as: "keyword.operator.assignment.shell punctuation.definition.assignment.shell",
                    )
                ),
                Pattern.new(
                    Pattern.new(
                        tag_as: "punctuation.definition.bracket.named-array.shell",
                        match: /\[/,
                    ).then(
                        match: /.+?/,
                        tag_as: "string.unquoted.shell entity.other.attribute-name.bracket.shell",
                    ).then(
                        tag_as: "punctuation.definition.bracket.named-array.shell",
                        match: /\]/,
                    ).then(
                        tag_as: "punctuation.definition.assignment.shell",
                        match: /\=/,
                    )
                ),
                :SHELL_normal_context,
                :SHELL_simple_unquoted,
            ]
        )
        grammar[:SHELL_modified_assignment_statement] = PatternRange.new(
            tag_as: "meta.statement.shell meta.expression.assignment.modified.shell",
            start_pattern: grammar[:SHELL_modifiers],
            end_pattern: command_end,
            includes: [
                simple_option,
                :SHELL_array_value,
                Pattern.new(
                    Pattern.new(
                        match: variable_name,
                        tag_as: "variable.other.assignment.shell",
                    ).maybe(
                        Pattern.new(
                            match: "[",
                            tag_as: "punctuation.definition.array.access.shell",
                        ).then(
                            match: maybe("$").then(variable_name).or("@").or("*").or(
                                match: /-?\d+/,
                                tag_as: "constant.numeric.shell constant.numeric.integer.shell",
                            ),
                            tag_as: "variable.other.assignment.shell",
                        ).then(
                            match: "]",
                            tag_as: "punctuation.definition.array.access.shell",
                        ),
                    ).maybe(
                        Pattern.new(
                            match: /\=/,
                            tag_as: "keyword.operator.assignment.shell",
                        ).or(
                            match: /\+\=/,
                            tag_as: "keyword.operator.assignment.compound.shell",
                        ).or(
                            match: /\-\=/,
                            tag_as: "keyword.operator.assignment.compound.shell",
                        )
                    ).maybe(
                        grammar[:SHELL_numeric_literal]
                    ),
                ),
                :SHELL_normal_context,
            ],
        )
        grammar[:SHELL_assignment_statement] = [
            :SHELL_array_value,
            :SHELL_modified_assignment_statement,
            :SHELL_normal_assignment_statement,
        ]
        grammar[:SHELL_case_statement_context] = [
                Pattern.new(
                    match: /\*/,
                    tag_as: "variable.language.special.quantifier.star.shell keyword.operator.quantifier.star.shell punctuation.definition.arbitrary-repetition.shell punctuation.definition.regex.arbitrary-repetition.shell"
                ),
                Pattern.new(
                    match: /\+/,
                    tag_as: "variable.language.special.quantifier.plus.shell keyword.operator.quantifier.plus.shell punctuation.definition.arbitrary-repetition.shell punctuation.definition.regex.arbitrary-repetition.shell"
                ),
                Pattern.new(
                    match: /\?/,
                    tag_as: "variable.language.special.quantifier.question.shell keyword.operator.quantifier.question.shell punctuation.definition.arbitrary-repetition.shell punctuation.definition.regex.arbitrary-repetition.shell"
                ),
                Pattern.new(
                    match: /@/,
                    tag_as: "variable.language.special.at.shell keyword.operator.at.shell punctuation.definition.regex.at.shell",
                ),
                Pattern.new(
                    match: /\|/,
                    tag_as: "keyword.operator.orvariable.language.special.or.shell keyword.operator.alternation.ruby.shell punctuation.definition.regex.alternation.shell punctuation.separator.regex.alternation.shell"
                ),
                Pattern.new(
                    match: /\\./,
                    tag_as: "constant.character.escape.shell",
                ),
                # this should only match the open paranethese at the very begining see https://github.com/jeff-hykin/better-shell-syntax/issues/
                Pattern.new(
                    match: lookBehindFor(/\tin| in| |\t|;;/).then(/\(/),
                    tag_as: "keyword.operator.pattern.case.shell",
                ),
                PatternRange.new(
                    tag_as: "meta.parenthese.shell",
                    start_pattern: lookBehindFor(/\S/).then(
                        match: /\(/,
                        tag_as: "punctuation.definition.group.shell punctuation.definition.regex.group.shell",
                    ),
                    end_pattern: Pattern.new(
                        match: /\)/,
                        tag_as: "punctuation.definition.group.shell punctuation.definition.regex.group.shell",
                    ),
                    includes: [
                        :SHELL_case_statement_context,
                    ],
                ),
                PatternRange.new(
                    tag_as: "string.regexp.character-class.shell",
                    start_pattern: Pattern.new(
                        match: /\[/,
                        tag_as: "punctuation.definition.character-class.shell",
                    ),
                    end_pattern: Pattern.new(
                        match: /\]/,
                        tag_as: "punctuation.definition.character-class.shell",
                    ),
                    includes: [
                        Pattern.new(
                            match: /\\./,
                            tag_as: "constant.character.escape.shell",
                        ),
                    ],
                ),
                :SHELL_string,
                Pattern.new(
                    match: /[^) \t\n\[\?\*\|\@]/,
                    tag_as: "string.unquoted.pattern.shell string.regexp.unquoted.shell",
                ),
            ]
        grammar[:SHELL_while_statement] = [
            PatternRange.new(
                tag_as: "meta.while.shell",
                start_pattern: Pattern.new(
                    Pattern.new(
                        tag_as: "keyword.control.while.shell",
                        match: /\bwhile\b/,
                    )
                ),
                end_pattern: command_end,
                includes: [
                    :SHELL_line_continuation,
                    :SHELL_math_operators,
                    :SHELL_option,
                    :SHELL_simple_unquoted,
                    :SHELL_normal_context,
                    :SHELL_string,
                ],
            ),
        ]
        grammar[:SHELL_for_statement] = [
            PatternRange.new(
                tag_as: "meta.for.in.shell",
                start_pattern: Pattern.new(
                    Pattern.new(
                        tag_as: "keyword.control.for.shell",
                        match: /\bfor\b/,
                    ).then(
                        std_space.then(
                            match: variable_name,
                            tag_as: "variable.other.for.shell",
                        ).then(std_space).then(
                            match: /\bin\b/,
                            tag_as: "keyword.control.in.shell",
                        )
                    )
                ),
                end_pattern: command_end,
                includes: [
                    :SHELL_range_expansion,
                    :SHELL_string,
                    :SHELL_simple_unquoted,
                    :SHELL_normal_context,
                ],
            ),
            PatternRange.new(
                tag_as: "meta.for.shell",
                start_pattern: Pattern.new(
                    Pattern.new(
                        tag_as: "keyword.control.for.shell",
                        match: /\bfor\b/,
                    )
                ),
                end_pattern: command_end,
                includes: [
                    :SHELL_arithmetic_double,
                    :SHELL_normal_context,
                ],
            ),
        ]
        grammar[:SHELL_case_statement] = PatternRange.new(
            tag_as: "meta.case.shell",
            start_pattern: Pattern.new(
                Pattern.new(
                    tag_as: "keyword.control.case.shell",
                    match: /\bcase\b/,
                ).then(std_space).then(
                    match:/.+?/, # TODO: this could be a problem for inline case statements
                    includes: [
                        :SHELL_initial_context
                    ],
                ).then(std_space).then(
                    match: /\bin\b/,
                    tag_as: "keyword.control.in.shell",
                )
            ),
            end_pattern: Pattern.new(
                tag_as: "keyword.control.esac.shell",
                match: /\besac\b/
            ),
            includes: [
                :SHELL_comment,
                # hardcode-match default case
                std_space.then(
                    match: /\* *\)/,
                    tag_as: "keyword.operator.pattern.case.default.shell",
                ),
                # pattern part, everything before ")"
                PatternRange.new(
                    tag_as: "meta.case.entry.pattern.shell",
                    start_pattern: lookBehindToAvoid(/\)/).lookAheadToAvoid(std_space.then(/esac\b|$/)),
                    end_pattern: lookAheadFor(/\besac\b/).or(
                        match: /\)/,
                        tag_as: "keyword.operator.pattern.case.shell",
                    ),
                    includes: [
                        :SHELL_case_statement_context,
                    ],
                ),
                # after-pattern part 
                PatternRange.new(
                    tag_as: "meta.case.entry.body.shell",
                    start_pattern: lookBehindFor(/\)/),
                    end_pattern: Pattern.new(
                        Pattern.new(
                            match: /;;/,
                            tag_as: "punctuation.terminator.statement.case.shell",
                        ).or(
                            lookAheadFor(/\besac\b/)
                        )
                    ),
                    includes: [
                        :SHELL_typical_statements,
                        :SHELL_initial_context,
                    ],
                ),
            ],
        )
        grammar[:SHELL_normal_statement] = PatternRange.new(
            zeroLengthStart?: true,
            zeroLengthEnd?: true,
            tag_as: "meta.statement.shell",
            # blank lines screw this pattern up, which is what the first lookAheadToAvoid is fixing
            start_pattern: Pattern.new(
                lookAheadToAvoid(empty_line).then(
                    lookBehindFor(valid_after_patterns).or(lookBehindFor(possible_pre_command_characters))
                ).then(std_space).lookAheadToAvoid(keyword_patterns),
            ),
            end_pattern: command_end,
            includes: [
                :SHELL_typical_statements,
            ]
            
        )
        grammar[:SHELL_custom_commands] = [
        ]
        grammar[:SHELL_custom_command_names] = [
        ]
        grammar[:SHELL_logical_expression_single] = PatternRange.new(
            tag_as: "meta.scope.logical-expression.shell",
            start_pattern: Pattern.new(
                    match: /\[/,
                    tag_as: "punctuation.definition.logical-expression.shell",
                ),
            end_pattern: Pattern.new(
                    match: /\]/,
                    tag_as: "punctuation.definition.logical-expression.shell"
                ),
            includes: [
                :SHELL_logical_expression_context
            ],
        )
        grammar[:SHELL_logical_expression_double] = PatternRange.new(
            tag_as: "meta.scope.logical-expression.shell",
            start_pattern: Pattern.new(
                    match: /\[\[/,
                    tag_as: "punctuation.definition.logical-expression.shell",
                ),
            end_pattern: Pattern.new(
                    match: /\]\]/,
                    tag_as: "punctuation.definition.logical-expression.shell"
                ),
            includes: [
                :SHELL_logical_expression_context
            ],
        )
        
        generateBrackRanges = ->(meta_tag:nil, punctuation_tag:nil, start_char:nil, stop_char:nil, single:nil, dollar_sign:nil, includes:[]) do
            dollar_prefix = ""
            if dollar_sign
                dollar_prefix = "$"
                # punctuation_tag = punctuation_tag+".dollar"
            else
                # punctuation_tag = punctuation_tag+".no_dollar"
            end
            if not single
                start_pattern = Pattern.new(
                    tag_as: punctuation_tag+".double.shell",
                    match: Pattern.new(dollar_prefix+start_char).then(start_char)
                )
                
                end_pattern = Pattern.new(
                    tag_as: punctuation_tag+".double.shell",
                    match: Pattern.new(stop_char).then(/\s*/).then(stop_char),
                )
            else
                start_pattern = Pattern.new(
                    tag_as: punctuation_tag+".single.shell",
                    match: Pattern.new(dollar_prefix+start_char)
                )
                # .lookAheadToAvoid(start_char)
                
                end_pattern = Pattern.new(
                    tag_as: punctuation_tag+".single.shell",
                    match: Pattern.new(stop_char),
                )
            end
            
            base_one = PatternRange.new(
                tag_as: meta_tag,
                start_pattern: start_pattern,
                end_pattern: end_pattern,
                includes: includes,
            )
            
            [
                # Pattern.new(
                #     tag_as: meta_tag,
                #     match: Pattern.new(
                #         start_pattern.then(
                #             match: /[^#{Regexp.escape(start_char)}][^#{Regexp.escape(stop_char)}]*/,
                #             includes: includes,
                #         ).then(end_pattern)
                #     ),
                # ),
                base_one
            ]
        end
        
        grammar[:SHELL_arithmetic_no_dollar] = generateBrackRanges[
            meta_tag: "meta.arithmetic.shell",
            punctuation_tag: "punctuation.section.arithmetic.shell",
            start_char: "(",
            stop_char: ")",
            single: true,
            dollar_sign: false,
            includes: [
                # TODO: add more stuff here
                # see: http://tiswww.case.edu/php/chet/bash/bashref.html#Shell-Arithmetic
                :SHELL_math,
                :SHELL_range_expansion,
                :SHELL_string,
                # :SHELL_initial_context,
            ],
        ]
        # grammar[:SHELL_arithmetic_dollar] = generateBrackRanges[
        #     meta_tag: "meta.arithmetic.shell",
        #     punctuation_tag: "punctuation.section.arithmetic.shell",
        #     start_char: "(",
        #     stop_char: ")",
        #     single: false,
        #     dollar_sign: true,
        #     includes: [
        #         # TODO: add more stuff here
        #         # see: http://tiswww.case.edu/php/chet/bash/bashref.html#Shell-Arithmetic
        #         :SHELL_math,
        #         :SHELL_string,
        #         # :SHELL_initial_context,
        #     ]
        # ]
        grammar[:SHELL_arithmetic_double] = generateBrackRanges[
            meta_tag: "meta.arithmetic.shell",
            punctuation_tag: "punctuation.section.arithmetic.shell",
            start_char: "(",
            stop_char: ")",
            single: false,
            dollar_sign: false,
            includes: [
                # TODO: add more stuff here
                # see: http://tiswww.case.edu/php/chet/bash/bashref.html#Shell-Arithmetic
                :SHELL_math,
                :SHELL_range_expansion,
                :SHELL_string,
                # :SHELL_initial_context,
            ]
        ]
        grammar[:SHELL_parenthese] = [
            # NOTE: right now this maybe-arithmetic doesn't really work because 
            #       the command pattern will match the whole inner part and then operators
            #       like minus will be treated as unquoted arguments
            #       which would require a whole alternative command pattern to work around
            # 
            # PatternRange.new(
            #     tag_as: "meta.parenthese.group.maybe-arithmetic.shell",
            #     # this is a heuristic since arithmetic it can't be matched properly/reliably
            #     start_pattern: lookBehindFor(/\(/).then(
            #         match: "(",
            #         tag_as: "punctuation.section.parenthese.shell",
            #     ),
            #     end_pattern: Pattern.new(
            #         tag_as: "punctuation.section.parenthese.shell",
            #         match: ")",
            #     ),
            #     includes: [
            #         :SHELL_initial_context,
            #         :SHELL_math,
            #     ],
            # ),
            PatternRange.new(
                tag_as: "meta.arithmetic.shell",
                start_pattern: lookBehindFor(/\$\(/).then(
                    match: "(",
                    tag_as: "punctuation.section.arithmetic.shell",
                ),
                end_pattern: Pattern.new(
                    tag_as: "punctuation.section.arithmetic.shell",
                    match: ")",
                ),
                includes: [
                    :SHELL_math,
                    :SHELL_range_expansion,
                    :SHELL_string,
                ],
            ),
            PatternRange.new(
                tag_as: "meta.parenthese.group.shell",
                start_pattern: Pattern.new(
                    match: "(",
                    tag_as: "punctuation.section.parenthese.shell",
                ),
                end_pattern: Pattern.new(
                    tag_as: "punctuation.section.parenthese.shell",
                    match: ")",
                ),
                includes: [
                    :SHELL_initial_context,
                ],
            ),
        ]
        grammar[:SHELL_subshell_dollar] = generateBrackRanges[
            meta_tag: "meta.scope.subshell.shell",
            punctuation_tag: "punctuation.definition.subshell.shell",
            start_char: "(",
            stop_char: ")",
            single: true,
            dollar_sign: true,
            includes: [
                :SHELL_parenthese,
                :SHELL_initial_context,
            ]
        ]
        
        grammar[:SHELL_misc_ranges] = [
            :SHELL_logical_expression_single,
            :SHELL_logical_expression_double,
                # # 
                # # handle (())
                # # 
                # :SHELL_arithmetic_dollar,
            # 
            # handle ()
            # 
            :SHELL_subshell_dollar,
            # 
            # groups (?) 
            # 
            PatternRange.new(
                tag_as: "meta.scope.group.shell",
                start_pattern: lookBehindToAvoid(/[^ \t]/).then(
                        tag_as: "punctuation.definition.group.shell",
                        match: /{/
                    ).lookAheadToAvoid(/\w|\$/), # range-expansion
                end_pattern: Pattern.new(
                        tag_as: "punctuation.definition.group.shell",
                        match: /}/
                    ),
                includes: [
                    :SHELL_initial_context
                ]
            ),
        ]
        
        grammar[:SHELL_regex_comparison] = Pattern.new(
                tag_as: "keyword.operator.logical.regex.shell",
                match: /\=~/,
            )
        
        def generateVariable(regex_after_dollarsign, tag)
            Pattern.new(
                match: Pattern.new(
                    match: /\$/,
                    tag_as: "punctuation.definition.variable.shell #{tag}.shell"
                ).then(
                    match: Pattern.new(regex_after_dollarsign).lookAheadToAvoid(/\w/),
                    tag_as: tag,
                )
            )
        end
        
        grammar[:SHELL_special_expansion] = Pattern.new(
            match: /!|:[-=?]?|\*|@|##|#|%%|%|\//,
            tag_as: "keyword.operator.expansion.shell",
        )
        
        # static range-expansion
        grammar[:SHELL_range_expansion] = Pattern.new(
            Pattern.new(
                match: /\{/,
                tag_as: "punctuation.section.range.begin.shell",
            ).then(
                Pattern.new(
                    Pattern.new(
                        tag_as: "constant.numeric.integer.range.shell",
                        match: /\d+/,
                    ).or(
                        generateVariable(variable_name, "variable.other.range.expansion.shell"),
                    )
                )
            ).then(
                match: /,|\.\.\.?/,
                tag_as: "keyword.operator.range.expansion.shell",
            ).then(
                Pattern.new(
                    Pattern.new(
                        tag_as: "constant.numeric.integer.range.shell",
                        match: /\d+/,
                    ).or(
                        generateVariable(variable_name, "variable.other.range.expansion.shell"),
                    )
                )
            ).then(
                match: /\}/,
                tag_as: "punctuation.section.range.end.shell",
            )
        )
        
        grammar[:SHELL_array_access_inline] = Pattern.new(
            Pattern.new(
                match: /\[/,
                tag_as: "punctuation.section.array.shell",
            ).then(
                match: /[^\[\]]+/,
                includes: [
                    :SHELL_special_expansion,
                    :SHELL_range_expansion,
                    :SHELL_string,
                    :SHELL_variable,
                ]
            ).then(
                match: /\]/,
                tag_as: "punctuation.section.array.shell",
            )
        )
        grammar[:SHELL_variable] = [
            generateVariable(/\@/, "variable.parameter.positional.all.shell"),
            generateVariable(/[0-9]/, "variable.parameter.positional.shell"),
            generateVariable(/[-*#?$!0_]/, "variable.language.special.shell"),
            # positional but has {}'s
            PatternRange.new(
                tag_content_as: "meta.parameter-expansion.shell",
                start_pattern: Pattern.new(
                        match: Pattern.new(
                            match: /\$/,
                            tag_as: "punctuation.definition.variable.shell variable.parameter.positional.shell"
                        ).then(
                            match: /\{/,
                            tag_as: "punctuation.section.bracket.curly.variable.begin.shell punctuation.definition.variable.shell variable.parameter.positional.shell",
                        ).then(std_space).lookAheadFor(/\d/)
                    ),
                end_pattern: Pattern.new(
                        match: /\}/,
                        tag_as: "punctuation.section.bracket.curly.variable.end.shell punctuation.definition.variable.shell variable.parameter.positional.shell",
                    ),
                includes: [
                    :SHELL_special_expansion,
                    :SHELL_array_access_inline,
                    Pattern.new(
                        match: /[0-9]+/,
                        tag_as: "variable.parameter.positional.shell",
                    ),
                    Pattern.new(
                        match: variable_name,
                        tag_as: "variable.other.normal.shell",
                    ),
                    :SHELL_variable,
                    :SHELL_range_expansion,
                    :SHELL_string,
                ]
            ),
            # Normal varible {}'s
            PatternRange.new(
                tag_content_as: "meta.parameter-expansion.shell",
                start_pattern: Pattern.new(
                        match: Pattern.new(
                            match: /\$/,
                            tag_as: "punctuation.definition.variable.shell"
                        ).then(
                            match: /\{/,
                            tag_as: "punctuation.section.bracket.curly.variable.begin.shell punctuation.definition.variable.shell",
                            
                        )
                    ),
                end_pattern: Pattern.new(
                        match: /\}/,
                        tag_as: "punctuation.section.bracket.curly.variable.end.shell punctuation.definition.variable.shell",
                    ),
                includes: [
                    :SHELL_special_expansion,
                    :SHELL_array_access_inline,
                    Pattern.new(
                        match: variable_name,
                        tag_as: "variable.other.normal.shell",
                    ),
                    :SHELL_variable,
                    :SHELL_range_expansion,
                    :SHELL_string,
                ]
            ),
            # normal variables
            generateVariable(/\w+/, "variable.other.normal.shell")
        ]
        
        # 
        # 
        # strings
        # 
        # 
            basic_escape_char = Pattern.new(
                match: /\\./,
                tag_as: "constant.character.escape.shell",
            )
            grammar[:SHELL_double_quote_escape_char] = Pattern.new(
                match: /\\[\$`"\\\n]/,
                tag_as: "constant.character.escape.shell",
            )
            
            grammar[:SHELL_string] = [
                Pattern.new(
                    match: /\\./,
                    tag_as: "constant.character.escape.shell",
                    includes: [
                        :NIX_escape_character_single_quote,
                    ],
                ),
                # putting :NIX_escape_character_single_quote, should be the same as the following... but its not for some deep bad reason
                Pattern.new(
                    tag_as: "constant.character.escape.nix.shell",
                    match: Pattern.new(/\'\'/).lookAheadFor(/\$|\'/),
                ),
                PatternRange.new(
                    tag_as: "string.quoted.single.shell",
                    start_pattern: Pattern.new(
                        match: "'",
                        tag_as: "punctuation.definition.string.begin.shell",
                    ),
                    apply_end_pattern_last: true,
                    end_pattern: Pattern.new(
                        match: "'",
                        tag_as: "punctuation.definition.string.end.shell",
                    ),
                    includes: [
                        Pattern.new(
                            tag_as: "constant.character.escape.nix.shell",
                            match: Pattern.new(/\'\'/).lookAheadFor(/\$|\'/),
                        ),
                    ],
                ),
                PatternRange.new(
                    tag_as: "string.quoted.double.shell",
                    start_pattern: Pattern.new(
                        match:  /\$?"/,
                        tag_as: "punctuation.definition.string.begin.shell",
                    ),
                    end_pattern: Pattern.new(
                        match: /"/,
                        tag_as: "punctuation.definition.string.end.shell",
                    ),
                    includes: [
                        Pattern.new(
                            match: /\\[\$\n`"\\]/,
                            tag_as: "constant.character.escape.shell",
                        ),
                        :SHELL_variable,
                        :SHELL_interpolation,
                        :NIX_escape_character_single_quote,
                    ]
                ),
                PatternRange.new(
                    tag_as: "string.quoted.single.dollar.shell",
                    start_pattern: Pattern.new(
                        match: /\$'/,
                        tag_as: "punctuation.definition.string.begin.shell",
                    ),
                    end_pattern: Pattern.new(
                        match: "'",
                        tag_as: "punctuation.definition.string.end.shell",
                    ),
                    includes: [
                        :NIX_escape_character_single_quote,
                        Pattern.new(
                            match: /\\(?:a|b|e|f|n|r|t|v|\\|')/,
                            tag_as: "constant.character.escape.ansi-c.shell",
                        ),
                        Pattern.new(
                            match: /\\[0-9]{3}"/,
                            tag_as: "constant.character.escape.octal.shell",
                        ),
                        Pattern.new(
                            match: /\\x[0-9a-fA-F]{2}"/,
                            tag_as: "constant.character.escape.hex.shell",
                        ),
                        Pattern.new(
                            match: /\\c."/,
                            tag_as: "constant.character.escape.control-char.shell",
                        )
                    ]
                ),
            ]
        
            # 
            # heredocs
            # 
                grammar[:SHELL_redirect_fix] = Pattern.new(
                    Pattern.new(
                        tag_as: "keyword.operator.redirect.shell",
                        match: />>?/,
                    ).then(std_space).then(
                        tag_as: "string.unquoted.argument.shell",
                        match: valid_literal_characters,
                    )
                )
                generateHeredocRanges = ->(name_pattern, tag_content_as:nil, includes:[]) do
                    [
                        # <<-"HEREDOC"
                        PatternRange.new(
                            tag_content_as: "string.quoted.heredoc.indent.$3.shell", # NOTE: the $3 should be $reference(delimiter) but the library is having issues with that
                            start_pattern: Pattern.new(
                                Pattern.new(
                                    match: lookBehindToAvoid(/</).then(/<<-/),
                                    tag_as: "keyword.operator.heredoc.shell",
                                ).then(std_space).then(
                                    match: /"|'/,
                                    reference: "start_quote",
                                    tag_as: "punctuation.definition.string.heredoc.quote.shell",
                                ).then(std_space).then(
                                    match: /[^"']+?/, # can create problems
                                    reference: "delimiter",
                                    tag_as: "punctuation.definition.string.heredoc.delimiter.shell",
                                ).lookAheadFor(/\s|;|&|<|"|'/).then(
                                    tag_as: "punctuation.definition.string.heredoc.quote.shell",
                                    match: matchResultOf(
                                        "start_quote"
                                    ),
                                ).then(
                                    match: /.*/,
                                    includes: [
                                        :SHELL_redirect_fix,
                                        :SHELL_typical_statements,
                                    ],
                                )
                            ),
                            end_pattern: Pattern.new(
                                tag_as: "punctuation.definition.string.heredoc.$match.shell",
                                match: Pattern.new(
                                    Pattern.new(/^\t*/).matchResultOf(
                                        "delimiter"
                                    ).lookAheadFor(/\s|;|&|$/),
                                ),
                            ),
                            includes: includes,
                        ),
                        # <<"HEREDOC"
                        PatternRange.new(
                            tag_content_as: "string.quoted.heredoc.no-indent.$3.shell",
                            start_pattern: Pattern.new(
                                Pattern.new(
                                    match: lookBehindToAvoid(/</).then(/<</).lookAheadToAvoid(/</),
                                    tag_as: "keyword.operator.heredoc.shell",
                                ).then(std_space).then(
                                    match: /"|'/,
                                    reference: "start_quote",
                                    tag_as: "punctuation.definition.string.heredoc.quote.shell",
                                ).then(std_space).then(
                                    match: /[^"']+?/, # can create problems
                                    reference: "delimiter",
                                    tag_as: "punctuation.definition.string.heredoc.delimiter.shell",
                                ).lookAheadFor(/\s|;|&|<|"|'/).then(
                                    tag_as: "punctuation.definition.string.heredoc.quote.shell",
                                    match: matchResultOf(
                                        "start_quote"
                                    ),
                                ).then(
                                    match: /.*/,
                                    includes: [
                                        :SHELL_redirect_fix,
                                        :SHELL_typical_statements,
                                    ],
                                )
                            ),
                            end_pattern: Pattern.new(
                                tag_as: "punctuation.definition.string.heredoc.delimiter.shell",
                                match: Pattern.new(
                                    Pattern.new(/^/).matchResultOf(
                                        "delimiter"
                                    ).lookAheadFor(/\s|;|&|$/),
                                ),
                            ),
                            includes: includes,
                        ),
                        # <<-HEREDOC
                        PatternRange.new(
                            tag_content_as: "string.unquoted.heredoc.indent.$2.shell",
                            start_pattern: Pattern.new(
                                Pattern.new(
                                    match: lookBehindToAvoid(/</).then(/<<-/),
                                    tag_as: "keyword.operator.heredoc.shell",
                                ).then(std_space).then(
                                    match: /[^"' \t]+/, # can create problems
                                    reference: "delimiter",
                                    tag_as: "punctuation.definition.string.heredoc.delimiter.shell",
                                ).lookAheadFor(/\s|;|&|<|"|'/).then(
                                    match: /.*/,
                                    includes: [
                                        :SHELL_redirect_fix,
                                        :SHELL_typical_statements,
                                    ],
                                )
                            ),
                            end_pattern: Pattern.new(
                                tag_as: "punctuation.definition.string.heredoc.delimiter.shell",
                                match: Pattern.new(
                                    Pattern.new(/^\t*/).matchResultOf(
                                        "delimiter"
                                    ).lookAheadFor(/\s|;|&|$/),
                                )
                            ),
                            includes: [
                                :SHELL_double_quote_escape_char,
                                :SHELL_variable,
                                :SHELL_interpolation,
                                *includes,
                            ]
                        ),
                        # <<HEREDOC
                        PatternRange.new(
                            tag_content_as: "string.unquoted.heredoc.no-indent.$2.shell",
                            start_pattern: Pattern.new(
                                Pattern.new(
                                    match: lookBehindToAvoid(/</).then(/<</).lookAheadToAvoid(/</),
                                    tag_as: "keyword.operator.heredoc.shell",
                                ).then(std_space).then(
                                    match: /[^"' \t]+/, # can create problems
                                    reference: "delimiter",
                                    tag_as: "punctuation.definition.string.heredoc.delimiter.shell",
                                ).lookAheadFor(/\s|;|&|<|"|'/).then(
                                    match: /.*/,
                                    includes: [
                                        :SHELL_redirect_fix,
                                        :SHELL_typical_statements,
                                    ],
                                )
                            ),
                            end_pattern: Pattern.new(
                                tag_as: "punctuation.definition.string.heredoc.delimiter.shell",
                                match: Pattern.new(
                                    Pattern.new(/^/).matchResultOf(
                                        "delimiter"
                                    ).lookAheadFor(/\s|;|&|$/),
                                )
                            ),
                            includes: [
                                :SHELL_double_quote_escape_char,
                                :SHELL_variable,
                                :SHELL_interpolation,
                                *includes,
                            ]
                        ),
                    ]
                end
                
                grammar[:SHELL_heredoc] = generateHeredocRanges[variable_name]
        
        # 
        # regex
        # 
            grammar[:SHELL_regexp] = [
                # regex highlight is not the same as Perl, Ruby, or JavaScript so extra work needs to be done here
                Pattern.new(/.+/) # leaving this list empty causes an error so add generic pattern
            ]
