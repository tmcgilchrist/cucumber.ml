(* C-based Gherkin parser using Ctypes.Foreign
 *
 * This module implements the PARSER interface using gherkin C library via
 * Ctypes bindings.
 *)

open Ctypes
open Gherkin_c_bindings
open Gherkin_c_converter
open Cucumber__Gherkin_ast

(* Parse error exception *)
exception Parse_error of string * position option

(* Helper: Convert OCaml string to wchar_t* *)
let string_to_wchar (s : string) : int32 ptr =
  let len = String.length s in
  let arr = CArray.make wchar_t (len + 1) in
  String.iteri (fun i c ->
    CArray.set arr i (Int32.of_int (Char.code c))
  ) s;
  CArray.set arr len Int32.zero;
  CArray.start arr

(* Detect language from content *)
let detect_language content =
  (* Simple regex-based detection *)
  let lang_regex = Str.regexp "^[ \t]*# language:[ \t]*\\([a-zA-Z][a-zA-Z]\\)" in
  try
    ignore (Str.search_forward lang_regex content 0);
    Str.matched_group 1 content
  with Not_found -> "en"

(* Parse string content *)
let parse_string content =
  (* Convert content to wchar_t* *)
  let wcontent = string_to_wchar content in

  (* Create ID generator *)
  let id_gen = incrementing_id_generator_new () in

  (* Create AST builder *)
  let builder = astbuilder_new id_gen in

  (* Create parser *)
  let parser = parser_new builder in

  (* Create token matcher (NULL for default) *)
  let matcher = tokenmatcher_new (from_voidp wchar_t null) in

  (* Create string token scanner *)
  let scanner = string_token_scanner_new wcontent in

  (* Parse *)
  let result = parser_parse parser matcher scanner in

  (* Check for errors *)
  if result <> 0 || parser_has_more_errors parser then begin
    let error_msg =
      if parser_has_more_errors parser then
        let error_ptr = parser_next_error parser in
        if not (is_null error_ptr) then
          let err = !@ error_ptr in
          let msg = wchar_to_string (getf err error_text) in
          error_delete error_ptr;
          msg
        else
          "Parse error"
      else
        "Parse failed"
    in

    (* Cleanup *)
    token_scanner_delete scanner;
    tokenmatcher_delete matcher;
    parser_delete parser;
    astbuilder_delete builder;
    incrementing_id_generator_delete id_gen;

    raise (Parse_error (error_msg, None))
  end;

  (* Get the GherkinDocument *)
  let doc_ptr = astbuilder_get_result builder "" in

  if is_null doc_ptr then begin
    (* Cleanup *)
    token_scanner_delete scanner;
    tokenmatcher_delete matcher;
    parser_delete parser;
    astbuilder_delete builder;
    incrementing_id_generator_delete id_gen;

    raise (Parse_error ("Failed to parse document", None))
  end;

  (* Extract feature and convert to OCaml AST *)
  let doc = !@ doc_ptr in
  let feature_ptr = getf doc gherkin_document_feature in

  let feature =
    try
      convert_feature feature_ptr
    with e ->
      (* Cleanup on conversion error *)
      token_scanner_delete scanner;
      tokenmatcher_delete matcher;
      parser_delete parser;
      astbuilder_delete builder;
      incrementing_id_generator_delete id_gen;
      raise e
  in

  (* Cleanup *)
  token_scanner_delete scanner;
  tokenmatcher_delete matcher;
  parser_delete parser;
  astbuilder_delete builder;
  incrementing_id_generator_delete id_gen;

  feature

(* Parse file *)
let parse_file filename =
  (* Read file content *)
  let ic = open_in filename in
  let content =
    try
      really_input_string ic (in_channel_length ic)
    with e ->
      close_in ic;
      raise e
  in
  close_in ic;

  (* Parse the content *)
  try
    parse_string content
  with Parse_error (msg, _) ->
    (* Add filename to error *)
    raise (Parse_error (Printf.sprintf "%s: %s" filename msg, None))
