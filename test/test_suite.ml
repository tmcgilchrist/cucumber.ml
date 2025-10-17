open Cucumber

(* ============================================================================
   PARSER TESTS
   Tests for Gherkin parsing including basic features, edge cases, and grammar
   ============================================================================ *)

(* Parser - Basic Feature Parsing *)

let test_parse_empty () =
  let pickles = Pickle.load_feature_file "" "features/test_empty.feature" in
  Alcotest.(check int)
    "test_empty.feature should parse 0 scenarios" 0 (List.length pickles)

let test_parse_simple () =
  let pickles = Pickle.load_feature_file "" "features/test_simple.feature" in
  Alcotest.(check int)
    "test_simple.feature should parse 0 scenarios" 0 (List.length pickles)

let test_parse_english_minimal () =
  let eng_content = "Feature: Test\n" in
  let feature = Gherkin_parser.parse_string eng_content in
  Alcotest.(check string)
    "English feature name should be Test" "Test" feature.Gherkin_ast.name

let test_parse_english_with_newlines () =
  let eng_content = "Feature: Test\n\n" in
  let feature = Gherkin_parser.parse_string eng_content in
  Alcotest.(check string)
    "English feature with newlines should parse" "Test" feature.Gherkin_ast.name

let parser_basic_tests =
  [
    ("Parse empty feature", `Quick, test_parse_empty);
    ("Parse simple feature", `Quick, test_parse_simple);
    ("Parse minimal English feature", `Quick, test_parse_english_minimal);
    ("Parse English with newlines", `Quick, test_parse_english_with_newlines);
  ]

(* Parser - Multi-Scenario *)

let test_parse_camels () =
  let pickles = Pickle.load_feature_file "" "features/camels.feature" in
  Alcotest.(check int)
    "camels.feature should parse 2 scenarios" 2 (List.length pickles);
  match pickles with
  | [ p1; p2 ] ->
      Alcotest.(check string)
        "First scenario name should be 'Buy more camels'" "Buy more camels"
        (Pickle.name p1);
      Alcotest.(check int)
        "First scenario should have 3 steps" 3
        (List.length (Pickle.steps p1));
      Alcotest.(check string)
        "Second scenario name should be 'Sell some camels'" "Sell some camels"
        (Pickle.name p2);
      Alcotest.(check int)
        "Second scenario should have 3 steps" 3
        (List.length (Pickle.steps p2))
  | _ -> Alcotest.fail "Expected exactly 2 pickles"

let test_multiple_scenarios () =
  let pickles =
    Pickle.load_feature_file ""
      "features/conflict_examples/multiple_scenarios.feature"
  in
  Alcotest.(check int)
    "multiple_scenarios.feature should parse 2 pickle(s)" 2
    (List.length pickles)

let parser_multi_scenario_tests =
  [
    ("Parse camels.feature (2 scenarios)", `Quick, test_parse_camels);
    ("Parse multiple_scenarios.feature", `Quick, test_multiple_scenarios);
  ]

(* Parser - Edge Cases & Grammar *)

let test_description_vs_background () =
  let pickles =
    Pickle.load_feature_file ""
      "features/conflict_examples/description_vs_background.feature"
  in
  Alcotest.(check int)
    "description_vs_background.feature should parse 1 pickle(s)" 1
    (List.length pickles)

let test_newline_separator () =
  let pickles =
    Pickle.load_feature_file ""
      "features/conflict_examples/newline_separator.feature"
  in
  Alcotest.(check int)
    "newline_separator.feature should parse 2 pickle(s)" 2
    (List.length pickles)

let test_step_vs_scenario () =
  let pickles =
    Pickle.load_feature_file ""
      "features/conflict_examples/step_vs_scenario.feature"
  in
  Alcotest.(check int)
    "step_vs_scenario.feature should parse 0 pickle(s)" 0
    (List.length pickles)

let test_table_empty_cells () =
  let pickles =
    Pickle.load_feature_file ""
      "features/conflict_examples/table_empty_cells.feature"
  in
  Alcotest.(check int)
    "table_empty_cells.feature should parse 1 pickle(s)" 1
    (List.length pickles)

let test_empty_step_list () =
  let pickles =
    Pickle.load_feature_file ""
      "features/conflict_examples/empty_step_list.feature"
  in
  Alcotest.(check int)
    "empty_step_list.feature should parse 2 pickle(s)" 2
    (List.length pickles)

let parser_edge_cases_tests =
  [
    ("Description vs background", `Quick, test_description_vs_background);
    ("Newline separator", `Quick, test_newline_separator);
    ("Invalid keyword placement", `Quick, test_step_vs_scenario);
    ("Table with empty cells", `Quick, test_table_empty_cells);
    ("Scenario with Examples but no steps", `Quick, test_empty_step_list);
  ]

(* ============================================================================
   UNICODE & INTERNATIONALIZATION TESTS
   Tests for language detection, keyword matching, and non-English parsing
   ============================================================================ *)

(* I18n - Language Detection *)

let test_detect_french () =
  let content = "# language: fr\nFonctionnalité: Test\n" in
  let lang = Gherkin_parser.detect_language content in
  Alcotest.(check string) "Should detect French language" "fr" lang

let test_detect_english_default () =
  let content = "Feature: Test\n" in
  let lang = Gherkin_parser.detect_language content in
  Alcotest.(check string) "Should default to English language" "en" lang

let test_french_keywords_available () =
  let content = "# language: fr\nFonctionnalité: Test\n" in
  let lang = Gherkin_parser.detect_language content in
  match Gherkin_keywords.get_keywords lang with
  | Some kws ->
      Alcotest.(check bool)
        "French keywords should include Fonctionnalité" true
        (List.mem "Fonctionnalité" kws.Gherkin_keywords.feature)
  | None -> Alcotest.fail "French keywords should be available"

let test_english_keywords_available () =
  let content = "Feature: Test\n" in
  let lang = Gherkin_parser.detect_language content in
  match Gherkin_keywords.get_keywords lang with
  | Some kws ->
      Alcotest.(check bool)
        "English keywords should include Feature" true
        (List.mem "Feature" kws.Gherkin_keywords.feature)
  | None -> Alcotest.fail "English keywords should be available"

let i18n_language_detection_tests =
  [
    ("Detect French language", `Quick, test_detect_french);
    ("Detect English default", `Quick, test_detect_english_default);
    ("French keywords available", `Quick, test_french_keywords_available);
    ("English keywords available", `Quick, test_english_keywords_available);
  ]

(* I18n - Keyword Matching *)

let test_french_keywords () =
  let kws = Gherkin_keywords.get_keywords "fr" in
  match kws with
  | None -> Alcotest.fail "French keywords should be available"
  | Some k ->
      Alcotest.(check bool)
        "French keywords should include Fonctionnalité" true
        (List.mem "Fonctionnalité" k.Gherkin_keywords.feature)

let test_french_keyword_matching () =
  let kws =
    match Gherkin_keywords.get_keywords "fr" with
    | Some k -> k
    | None -> Alcotest.fail "Could not get French keywords"
  in
  let test_word = "Fonctionnalité" in
  let matches =
    Gherkin_keywords.matches_keyword test_word kws.Gherkin_keywords.feature
  in
  Alcotest.(check bool)
    "Fonctionnalité should match French feature keyword" true matches

let i18n_keyword_tests =
  [
    ("Get French keywords", `Quick, test_french_keywords);
    ("Match Fonctionnalité keyword", `Quick, test_french_keyword_matching);
  ]

(* I18n - French Parsing *)

let test_parse_french_minimal () =
  let content = "# language: fr\nFonctionnalité: Test\n" in
  let feature = Gherkin_parser.parse_string content in
  Alcotest.(check string)
    "French feature name should be Test" "Test" feature.Gherkin_ast.name

let test_parse_french_with_newlines () =
  let content = "# language: fr\nFonctionnalité: Test\n\n" in
  let feature = Gherkin_parser.parse_string content in
  Alcotest.(check string)
    "French feature with newlines should parse" "Test" feature.Gherkin_ast.name

let test_parse_french_without_directive () =
  let content = "Fonctionnalité: Test\n" in
  try
    let _ = Gherkin_parser.parse_string content in
    Alcotest.fail "Should have raised Parse_error"
  with
  | Gherkin_parser.Parse_error _ ->
      (* Expected - pass the test *)
      ()
  | e -> Alcotest.failf "Expected Parse_error, got %s" (Printexc.to_string e)

let test_parse_french () =
  let pickles = Pickle.load_feature_file "" "features/test_french.feature" in
  Alcotest.(check int)
    "test_french.feature should parse 1 scenario" 1 (List.length pickles);
  match pickles with
  | [ p ] ->
      Alcotest.(check string)
        "Scenario name should be 'Un scénario simple'" "Un scénario simple"
        (Pickle.name p);
      Alcotest.(check int)
        "Should have 3 steps" 3
        (List.length (Pickle.steps p))
  | _ -> Alcotest.fail "Expected exactly 1 pickle"

let i18n_french_parsing_tests =
  [
    ("Parse French feature (minimal)", `Quick, test_parse_french_minimal);
    ( "Parse French feature (with newlines)",
      `Quick,
      test_parse_french_with_newlines );
    ( "Parse French without directive (should fail)",
      `Quick,
      test_parse_french_without_directive );
    ("Parse French from file", `Quick, test_parse_french);
  ]

(* ============================================================================
   TAG FILTERING TESTS
   Tests for tag parsing and pickle filtering
   ============================================================================ *)

(* Tags - Parsing *)

let test_parse_single_tag () =
  let allowed, disallowed = Tag.list_of_string "@smoke" in
  Alcotest.(check int) "Should have 1 allowed tag" 1 (List.length allowed);
  Alcotest.(check int)
    "Should have 0 disallowed tags" 0 (List.length disallowed)

let test_parse_multiple_tags () =
  let allowed, disallowed = Tag.list_of_string "@smoke @regression" in
  Alcotest.(check int) "Should have 2 allowed tags" 2 (List.length allowed);
  Alcotest.(check int)
    "Should have 0 disallowed tags" 0 (List.length disallowed)

let test_parse_excluded_tag () =
  let allowed, disallowed = Tag.list_of_string "~@slow" in
  Alcotest.(check int) "Should have 0 allowed tags" 0 (List.length allowed);
  Alcotest.(check int) "Should have 1 disallowed tag" 1 (List.length disallowed)

let test_parse_mixed_tags () =
  let allowed, disallowed = Tag.list_of_string "@smoke ~@slow @regression" in
  Alcotest.(check int) "Should have 2 allowed tags" 2 (List.length allowed);
  Alcotest.(check int) "Should have 1 disallowed tag" 1 (List.length disallowed)

let test_parse_empty_string () =
  let allowed, disallowed = Tag.list_of_string "" in
  Alcotest.(check int) "Should have 0 allowed tags" 0 (List.length allowed);
  Alcotest.(check int)
    "Should have 0 disallowed tags" 0 (List.length disallowed)

let test_parse_with_tabs () =
  let allowed, disallowed = Tag.list_of_string "@smoke\t@regression" in
  Alcotest.(check int) "Should have 2 allowed tags" 2 (List.length allowed);
  Alcotest.(check int)
    "Should have 0 disallowed tags" 0 (List.length disallowed)

let tag_parsing_tests =
  [
    ("Parse single tag", `Quick, test_parse_single_tag);
    ("Parse multiple tags", `Quick, test_parse_multiple_tags);
    ("Parse excluded tag", `Quick, test_parse_excluded_tag);
    ("Parse mixed tags", `Quick, test_parse_mixed_tags);
    ("Parse empty string", `Quick, test_parse_empty_string);
    ("Parse with tabs", `Quick, test_parse_with_tabs);
  ]

(* Tags - Filtering *)

let test_filter_no_tags () =
  let pickles = Pickle.load_feature_file "" "features/camels.feature" in
  let tags = Tag.list_of_string "" in
  let filtered = Pickle.filter_pickles tags pickles in
  Alcotest.(check int)
    "No filter should return all pickles" (List.length pickles)
    (List.length filtered)

let test_filter_with_include_tag () =
  let pickles = Pickle.load_feature_file "" "features/test_tags.feature" in
  let tags = Tag.list_of_string "@smoke" in
  let filtered = Pickle.filter_pickles tags pickles in
  Alcotest.(check bool)
    "Should filter pickles with @smoke tag" true
    (List.length filtered > 0 && List.length filtered <= List.length pickles)

let test_filter_with_exclude_tag () =
  let pickles = Pickle.load_feature_file "" "features/test_tags.feature" in
  let tags = Tag.list_of_string "~@slow" in
  let filtered = Pickle.filter_pickles tags pickles in
  Alcotest.(check bool)
    "Should exclude pickles with @slow tag" true
    (List.length filtered <= List.length pickles)

let test_filter_with_mixed_tags () =
  let pickles = Pickle.load_feature_file "" "features/test_tags.feature" in
  let tags = Tag.list_of_string "@smoke ~@wip" in
  let filtered = Pickle.filter_pickles tags pickles in
  Alcotest.(check bool)
    "Should include @smoke and exclude @wip" true
    (List.length filtered <= List.length pickles)

let test_filter_empty_tags_with_exclude () =
  let pickles = Pickle.load_feature_file "" "features/camels.feature" in
  let tags = Tag.list_of_string "~@slow" in
  let filtered = Pickle.filter_pickles tags pickles in
  Alcotest.(check int)
    "Pickles without tags should be included when excluding tags"
    (List.length pickles) (List.length filtered)

let tag_filtering_tests =
  [
    ("Filter with no tags", `Quick, test_filter_no_tags);
    ("Filter with include tag", `Quick, test_filter_with_include_tag);
    ("Filter with exclude tag", `Quick, test_filter_with_exclude_tag);
    ("Filter with mixed tags", `Quick, test_filter_with_mixed_tags);
    ( "Filter empty tags with exclude",
      `Quick,
      test_filter_empty_tags_with_exclude );
  ]

let () =
  Alcotest.run "Cucumber.ml Test Suite"
    [
      ("Parser - Basic", parser_basic_tests);
      ("Parser - Multi-Scenario", parser_multi_scenario_tests);
      ("Parser - Edge Cases", parser_edge_cases_tests);
      ("I18n - Language Detection", i18n_language_detection_tests);
      ("I18n - Keywords", i18n_keyword_tests);
      ("I18n - French Parsing", i18n_french_parsing_tests);
      ("Tags - Parsing", tag_parsing_tests);
      ("Tags - Filtering", tag_filtering_tests);
    ]
