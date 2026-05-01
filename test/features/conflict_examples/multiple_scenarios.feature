# This demonstrates Conflict Category A: Empty vs Non-Empty List Ambiguity
# Parser must decide if scenario_list is complete or continuing

Feature: Multiple Scenarios Test

  Scenario: First scenario
    Given step one
    When step two
    Then step three

  Scenario: Second scenario
    Given another step
    When another action
    Then another result

# Expected: Two distinct scenarios parsed successfully
# Actual: After first scenario, parser confused by newlines before second
# Conflict: Is tag_list empty (reduce) or starting new scenario?
# Error when parsing second "Scenario:" keyword
