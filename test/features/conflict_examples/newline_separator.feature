# This demonstrates Conflict Category E: NEWLINE Separator Ambiguity
# Multiple newlines create shift/reduce conflicts

Feature: Newline Separator Test

  Scenario: Extra blank lines


    Given a step with blank lines before it


    When another step with blanks


    Then result


  Scenario: No extra blanks
    Given immediate step

# Expected: Steps parse correctly regardless of blank line padding
# Actual: Shift/reduce conflict on each extra NEWLINE
# Parser must decide: shift (add to NEWLINE+) or reduce (start new element)?
# This creates ambiguity at lines 8, 11, 14, and 17
