# Self-Awareness Command Messages

## my_profile
**no_thinker**: You don't have a personality profile (no thinker component).
**footer**: Use @set-profile to update your personality.\nUse @my-description to view/edit your physical description.

## my_description
**footer**: Use @set-description to update how you appear to others.

## set_profile
**no_thinker**: You don't have a personality profile to modify (no thinker component).
**missing_arg**: Usage: @set-profile -> <new profile>
**no_arrow**: Usage: @set-profile -> <new profile> (arrow required)
**empty_profile**: Profile cannot be empty
**success**: You have updated your personality profile.\n\nOld profile:\n{old_profile}\n\nNew profile:\n{new_profile}\n\nThis change will affect your future decisions and behavior.

## set_description
**missing_arg**: Usage: @set-description -> <new description>
**no_arrow**: Usage: @set-description -> <new description> (arrow required)
**empty_description**: Description cannot be empty
**success**: You have updated your description.\n\nOld description:\n{old_description}\n\nNew description:\n{new_description}\n\nThis is how others will see you when they examine you.
