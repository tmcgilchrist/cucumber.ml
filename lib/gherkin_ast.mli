(** AST types for Gherkin feature files.

    This module defines the complete Abstract Syntax Tree for Gherkin feature
    files, closely following the Gherkin specification. *)

type position = { line : int; col : int }
(** Position in source file (line and column) *)

type span = { start_pos : position; end_pos : position }
(** Span in source file (start and end positions) *)

(** Step types after resolving And/But *)
type step_type = Given | When | Then

type table = {
  rows : string list list;
  span : span option;
  position : position option;
}
(** A data table *)

type docstring = { content : string; span : span option }
(** A docstring (multi-line string argument) *)

(** Step arguments *)
type step_argument = DocString of docstring | Table of table

type step = {
  keyword : string; (* The actual keyword used (Given, When, Then, And, But) *)
  step_type : step_type; (* The resolved type (Given, When, or Then) *)
  text : string; (* The step text *)
  argument : step_argument option;
  span : span option;
  position : position option;
}
(** A step in a scenario or background *)

type examples = {
  keyword : string; (* "Examples" or localized equivalent *)
  name : string option;
  description : string option;
  tags : string list;
  table : table option;
  span : span option;
  position : position option;
}
(** Examples table for scenario outlines *)

type scenario = {
  keyword : string; (* "Scenario" or "Scenario Outline" *)
  name : string;
  description : string option;
  tags : string list;
  steps : step list;
  examples : examples list; (* Empty for regular scenarios *)
  span : span option;
  position : position option;
}
(** A scenario or scenario outline *)

type background = {
  keyword : string; (* "Background" or localized equivalent *)
  name : string;
  description : string option;
  steps : step list;
  span : span option;
  position : position option;
}
(** A background section *)

type rule = {
  keyword : string; (* "Rule" or localized equivalent *)
  name : string;
  description : string option;
  tags : string list;
  background : background option;
  scenarios : scenario list;
  span : span option;
  position : position option;
}
(** A rule (Gherkin 6+) *)

type feature = {
  keyword : string; (* "Feature" or localized equivalent *)
  language : string; (* Language code, e.g., "en" *)
  name : string;
  description : string option;
  tags : string list;
  background : background option;
  scenarios : scenario list;
  rules : rule list;
  span : span option;
  position : position option;
}
(** A complete feature *)

val make_position : int -> int -> position
(** Create a position *)

val make_span : position -> position -> span
(** Create a span *)

val empty_table : table
(** Default empty table *)

val empty_feature : feature
(** Default empty feature for building *)
