# Admin Command Messages

## impersonate
**missing_arg**: Usage: @impersonate <agent name>
**not_found**: Cannot find agent: {agent_name}
**not_ai_agent**: {agent_name} is not an AI agent (no thinker component)

## show_profile
**missing_arg**: Usage: @show-profile <agent name>
**not_found**: Cannot find agent: {agent_name}
**not_ai_agent**: {agent_name} is not an AI agent (no thinker component)

## edit_profile
**missing_arg**: Usage: @edit-profile <agent name> -> <new profile>
**no_arrow**: Usage: @edit-profile <agent name> -> <new profile> (arrow required)
**empty_profile**: Profile cannot be empty
**not_found**: Cannot find agent: {agent_name}
**not_ai_agent**: {agent_name} is not an AI agent (no thinker component)
**success**: Updated profile for {agent_name}\n\nNew profile:\n{new_profile}

## edit_interval
**missing_arg**: Usage: @edit-interval <agent name> <seconds>
**invalid_number**: Interval must be a number (seconds)
**too_short**: Interval must be at least 1.0 seconds
**not_found**: Cannot find agent: {agent_name}
**not_ai_agent**: {agent_name} is not an AI agent (no thinker component)
**success**: Updated think interval for {agent_name} to {interval} seconds
