(** AST types for Gherkin feature files *)

type position = { line : int; col : int }
type span = { start_pos : position; end_pos : position }
type step_type = Given | When | Then

type table = {
  rows : string list list;
  span : span option;
  position : position option;
}

type docstring = { content : string; span : span option }
type step_argument = DocString of docstring | Table of table

type step = {
  keyword : string;
  step_type : step_type;
  text : string;
  argument : step_argument option;
  span : span option;
  position : position option;
}

type examples = {
  keyword : string;
  name : string option;
  description : string option;
  tags : string list;
  table : table option;
  span : span option;
  position : position option;
}

type scenario = {
  keyword : string;
  name : string;
  description : string option;
  tags : string list;
  steps : step list;
  examples : examples list;
  span : span option;
  position : position option;
}

type background = {
  keyword : string;
  name : string;
  description : string option;
  steps : step list;
  span : span option;
  position : position option;
}

type rule = {
  keyword : string;
  name : string;
  description : string option;
  tags : string list;
  background : background option;
  scenarios : scenario list;
  span : span option;
  position : position option;
}

type feature = {
  keyword : string;
  language : string;
  name : string;
  description : string option;
  tags : string list;
  background : background option;
  scenarios : scenario list;
  rules : rule list;
  span : span option;
  position : position option;
}

let make_position line col = { line; col }
let make_span start_pos end_pos = { start_pos; end_pos }
let empty_table = { rows = []; span = None; position = None }

let empty_feature =
  {
    keyword = "Feature";
    language = "en";
    name = "";
    description = None;
    tags = [];
    background = None;
    scenarios = [];
    rules = [];
    span = None;
    position = None;
  }
