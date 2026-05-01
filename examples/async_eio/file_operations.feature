Feature: File operations with Eio

  Scenario: Write and read a file
    Given I have an Eio environment
    When I write "Hello, World!" to file "test.txt"
    Then reading "test.txt" should return "Hello, World!"

  Scenario: File deletion
    Given I have an Eio environment
    When I write "temporary" to file "temp.txt"
    When I delete file "temp.txt"
    Then file "temp.txt" should not exist
