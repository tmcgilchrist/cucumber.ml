%{
  open Gherkin_ast

  (* Track last step type for And/But steps *)
  let last_step_type = ref None

  (* Create position from Lexing.position *)
  let pos_of_lexing p =
    { line = p.Lexing.pos_lnum; col = p.Lexing.pos_cnum - p.Lexing.pos_bol + 1 }

  (* Create span from start and end positions *)
  let _span_of_positions start_p end_p =
    Some { start_pos = pos_of_lexing start_p; end_pos = pos_of_lexing end_p }
%}

/* Token declarations - Line-based tokens following official Gherkin parser */
%token EOF
%token <string> LANGUAGE_DIRECTIVE
%token <string list * Gherkin_ast.position> TAG_LINE
%token <string * Gherkin_ast.position> FEATURE_LINE
%token <(string * string) * Gherkin_ast.position> SCENARIO_LINE  /* (keyword, name) */
%token <string * Gherkin_ast.position> BACKGROUND_LINE
%token <string * Gherkin_ast.position> RULE_LINE
%token <string * Gherkin_ast.position> EXAMPLES_LINE
%token <(string * string * string) * Gherkin_ast.position> STEP_LINE  /* (keyword, step_marker, text) where step_marker is "Given"|"When"|"Then"|"And"|"But" */
%token <string list> TABLE_ROW
%token DOCSTRING_DELIMITER
%token DOCSTRING_ALT_DELIMITER
%token <string> DESCRIPTION_LINE
%token COMMENT_LINE
%token BLANK_LINE

%start <Gherkin_ast.feature> feature_file
%%

/* Main entry point */
feature_file:
  | blank_or_comment*
    lang = language_directive?
    blank_or_comment*
    tags = tags_opt
    f = FEATURE_LINE
    descr = description_lines
    blank_or_comment*
    bg = background?
    scenarios = scenario_list
    rules = rule_list
    blank_or_comment*
    EOF
    {
      let (name, pos) = f in
      let language = match lang with Some l -> l | None -> "en" in
      {
        keyword = "Feature";
        language = language;
        name = name;
        description = (if descr = "" then None else Some descr);
        tags = tags;
        background = bg;
        scenarios = scenarios;
        rules = rules;
        span = None;
        position = Some pos;
      }
    }

/* Helper to skip blank lines and comments */
blank_or_comment:
  | BLANK_LINE { () }
  | COMMENT_LINE { () }

/* Helper rules for line-based parsing */
language_directive:
  | LANGUAGE_DIRECTIVE { $1 }

/* Tags - optional tag lines */
tags_opt:
  | /* empty */ { [] }
  | t = TAG_LINE rest = tags_opt { let (tags, _pos) = t in tags @ rest }

description_lines:
  | /* empty */ { "" }
  | d = DESCRIPTION_LINE rest = description_lines {
      if rest = "" then d else d ^ "\n" ^ rest
    }

background:
  | b = BACKGROUND_LINE
    steps = step_list
    {
      let (name, pos) = b in
      {
        keyword = "Background";
        name = name;
        description = None;
        steps = steps;
        span = None;
        position = Some pos;
      }
    }

/* Scenario list - left-recursive to avoid conflicts */
scenario_list:
  | /* empty */ { [] }
  | scenarios = scenario_list BLANK_LINE { scenarios }
  | scenarios = scenario_list COMMENT_LINE { scenarios }
  | scenarios = scenario_list s = scenario { scenarios @ [s] }

scenario:
  | tags = tags_opt
    s = SCENARIO_LINE
    steps = step_list
    examples = examples_list
    {
      let ((keyword, name), pos) = s in
      {
        keyword = keyword;
        name = name;
        description = None;
        tags = tags;
        steps = steps;
        examples = examples;
        span = None;
        position = Some pos;
      }
    }

examples_list:
  | /* empty */ { [] }
  | examples = examples_list e = examples { examples @ [e] }

examples:
  | e = EXAMPLES_LINE
    table = table?
    {
      let (name_str, pos) = e in
      let name = if name_str = "" then None else Some name_str in
      {
        keyword = "Examples";
        name = name;
        description = None;
        tags = [];  (* Examples no longer support tags *)
        table = table;
        span = None;
        position = Some pos;
      }
    }

rule_list:
  | /* empty */ { [] }
  | rules = rule_list BLANK_LINE { rules }
  | rules = rule_list COMMENT_LINE { rules }
  | rules = rule_list r = rule { rules @ [r] }

rule:
  | tags = tags_opt
    r = RULE_LINE
    bg = background?
    scenarios = scenario_list
    {
      let (name, pos) = r in
      {
        keyword = "Rule";
        name = name;
        description = None;
        tags = tags;
        background = bg;
        scenarios = scenarios;
        span = None;
        position = Some pos;
      }
    }

step_list:
  | /* empty */ { [] }
  | steps = step_list BLANK_LINE { steps }
  | steps = step_list COMMENT_LINE { steps }
  | steps = step_list s = step { steps @ [s] }

step:
  | s = STEP_LINE arg = step_argument?
    {
      let ((keyword, step_marker, text), pos) = s in
      (* Resolve And/But to actual step type based on last step *)
      let step_type = match step_marker with
        | "Given" -> last_step_type := Some Given; Given
        | "When" -> last_step_type := Some When; When
        | "Then" -> last_step_type := Some Then; Then
        | "And" | "But" -> (match !last_step_type with Some st -> st | None -> Given)
        | _ -> Given  (* Fallback *)
      in
      {
        keyword = keyword;
        step_type = step_type;
        text = text;
        argument = arg;
        span = None;
        position = Some pos;
      }
    }

step_argument:
  | docstring = docstring { DocString docstring }
  | table = table { Table table }

docstring:
  | DOCSTRING_DELIMITER content = docstring_lines DOCSTRING_DELIMITER
    {
      {
        content = content;
        span = None;
      }
    }

docstring_lines:
  | /* empty */ { "" }
  | d = DESCRIPTION_LINE rest = docstring_lines {
      if rest = "" then d else d ^ "\n" ^ rest
    }

table:
  | rows = nonempty_list(TABLE_ROW)
    {
      {
        rows = rows;
        span = None;
        position = None;
      }
    }
