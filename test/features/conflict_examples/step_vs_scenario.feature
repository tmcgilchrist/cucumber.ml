# This demonstrates conflict where WORD could be step or new scenario
# Without lexical keyword recognition, parser cannot distinguish

Feature: Step vs Scenario Conflict

  Scenario: Minimal scenario
    Given the basic setup
    Scenario: This looks like a new scenario but parser is confused

  Scenario: Another test
    When something happens
    Then verify result
    Background: This keyword in wrong place causes issues

# Expected: Parse error - "Scenario:" and "Background:" in wrong positions
# Actual: Parser treats these keywords as potential step text
# Without keyword tokens, "Scenario" is just another WORD
# Errors at lines 7 and 12
