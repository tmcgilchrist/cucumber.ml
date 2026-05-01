# This demonstrates Conflict Category D: Table Cell Parsing
# Empty cells between pipes create reduce/reduce conflicts

Feature: Table Empty Cells Test

  Scenario: Table with empty cells
    Given a data table:
      | column1 |  | column3 |
      | value1  |  | value3  |
      | a       | b |  c     |

# Expected: Table with some empty cells preserved
# Actual: Reduce/reduce conflict at empty cell positions
# Parser cannot decide between:
#   1. table_cell -> empty (this cell is empty)
#   2. table_cells -> empty (no more cells)
# Error at line 7, when parsing pipes with empty content between them
