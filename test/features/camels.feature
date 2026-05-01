Feature: Dromidary farm

@smoke
Scenario: Buy more camels
  Given I have 1 camel on my farm
  When I buy 2 more camels
  Then I have 3 camels on my farm

@wip
Scenario: Sell some camels
  Given I have 1 camel on my farm
  When I sell 1 camels
  Then I have 0 camels on my farm