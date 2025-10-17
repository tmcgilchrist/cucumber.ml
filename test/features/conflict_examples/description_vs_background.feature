# This demonstrates Conflict Category C: Description vs Background Ambiguity
# The parser cannot distinguish between description text and the Background keyword

Feature: Description Conflict Test
  This is a description line that explains the feature.
  It should be treated as description, not as keywords.
  Background:
    Given some setup step

  Scenario: Test scenario
    When I do something
    Then it should work

# Expected behavior: Background should be recognized as a keyword
# Actual behavior: "Background:" is consumed as part of description
# Error occurs at line 5, column 12 (after "Background:")
