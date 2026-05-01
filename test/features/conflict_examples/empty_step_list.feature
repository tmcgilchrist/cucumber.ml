# This demonstrates Conflict Category B: Step List Termination
# Parser cannot tell if step_list is empty or if Examples keyword starts a step

Feature: Empty Step List Test

  Scenario: No steps before examples
    Examples:
      | column |
      | value  |

  Scenario: Has steps
    Given a step exists
    Examples:
      | column |
      | data   |

# Expected: First scenario has no steps, Examples provides data
# Actual: Parser conflict - is step_list empty or does "Examples" start a step?
# Error at line 6, column 5
