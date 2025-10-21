(* Ctypes.Foreign bindings for gherkin C library
 *
 * This module uses Ctypes to create type-safe dynamic bindings to the
 * gherkin-c C library.
 *)

open Ctypes
open Foreign

(* Platform-specific wchar_t type *)
let wchar_t =
  match Sys.word_size with      (* TODO Review why we do this? *)
  | 32 -> int32_t  (* 32-bit systems typically use 32-bit wchar *)
  | _ -> int32_t   (* Most modern systems use 32-bit wchar, even on 64-bit *)

let wstring = ptr wchar_t

(* item_delete_function - function pointer for deletion *)
let item_delete_fn = Foreign.funptr (ptr void @-> returning void)

type gherkin_ast_type =
  | Gherkin_GherkinDocument
  | Gherkin_Feature
  | Gherkin_Rule
  | Gherkin_Background
  | Gherkin_Scenario
  | Gherkin_Examples
  | Gherkin_Step
  | Gherkin_DataTable
  | Gherkin_DocString
  | Gherkin_TableRow
  | Gherkin_TableCell
  | Gherkin_Tag
  | Gherkin_Comment
  | Gherkin_Unknown

let gherkin_ast_type_of_int = function
  | 0 -> Gherkin_GherkinDocument
  | 1 -> Gherkin_Feature
  | 2 -> Gherkin_Rule
  | 3 -> Gherkin_Background
  | 4 -> Gherkin_Scenario
  | 5 -> Gherkin_Examples
  | 6 -> Gherkin_Step
  | 7 -> Gherkin_DataTable
  | 8 -> Gherkin_DocString
  | 9 -> Gherkin_TableRow
  | 10 -> Gherkin_TableCell
  | 11 -> Gherkin_Tag
  | 12 -> Gherkin_Comment
  | _ -> Gherkin_Unknown

let gherkin_ast_type_to_int = function
  | Gherkin_GherkinDocument -> 0
  | Gherkin_Feature -> 1
  | Gherkin_Rule -> 2
  | Gherkin_Background -> 3
  | Gherkin_Scenario -> 4
  | Gherkin_Examples -> 5
  | Gherkin_Step -> 6
  | Gherkin_DataTable -> 7
  | Gherkin_DocString -> 8
  | Gherkin_TableRow -> 9
  | Gherkin_TableCell -> 10
  | Gherkin_Tag -> 11
  | Gherkin_Comment -> 12
  | Gherkin_Unknown -> -1

let gherkin_ast_type =
  view ~read:gherkin_ast_type_of_int ~write:gherkin_ast_type_to_int int

(* Location structure *)
type location
let location : location structure typ = structure "Location"
let location_line = field location "line" ulong
let location_column = field location "column" ulong
let () = seal location

(* Tag structure *)
type tag
let tag : tag structure typ = structure "Tag"
let tag_delete = field tag "tag_delete" item_delete_fn
let tag_type = field tag "type" gherkin_ast_type
let tag_location = field tag "location" location
let tag_id = field tag "id" wstring
let tag_name = field tag "name" wstring
let () = seal tag

(* Tags collection *)
type tags
let tags : tags structure typ = structure "Tags"
let tags_count = field tags "tag_count" int
let tags_array = field tags "tags" (ptr tag)  (* Tag* not Tag** *)
let () = seal tags

(* Step structure (forward declaration) *)
type step
let step : step structure typ = structure "Step"

type steps
let steps : steps structure typ = structure "Steps"

(* StepArgument (abstract for now - can be DataTable or DocString) *)
type step_argument
let step_argument : step_argument structure typ = structure "StepArgument"
let step_argument_type = field step_argument "type" gherkin_ast_type
let () = seal step_argument

(* Step fields *)
let step_delete = field step "step_delete" item_delete_fn
let step_type = field step "type" gherkin_ast_type
let step_location = field step "location" location
let step_id = field step "id" wstring
let step_keyword = field step "keyword" wstring
let step_keyword_type = field step "keyword_type" int  (* KeywordType enum *)
let step_text = field step "text" wstring
let step_argument_field = field step "argument" (ptr step_argument)
let () = seal step

(* Steps collection *)
let steps_count = field steps "step_count" int
let steps_array = field steps "steps" (ptr step)  (* Step* not Step** *)
let () = seal steps

(* TableCell structure *)
type table_cell
let table_cell : table_cell structure typ = structure "TableCell"
let table_cell_delete = field table_cell "cell_delete" item_delete_fn
let table_cell_type = field table_cell "type" gherkin_ast_type
let table_cell_location = field table_cell "location" location
let table_cell_value = field table_cell "value" wstring
let () = seal table_cell

type table_cells
let table_cells : table_cells structure typ = structure "TableCells"
let table_cells_count = field table_cells "cell_count" int
let table_cells_array = field table_cells "table_cells" (ptr table_cell)
let () = seal table_cells

(* TableRow structure *)
type table_row
let table_row : table_row structure typ = structure "TableRow"
let table_row_delete = field table_row "row_delete" item_delete_fn
let table_row_type = field table_row "type" gherkin_ast_type
let table_row_location = field table_row "location" location
let table_row_id = field table_row "id" wstring
let table_row_cells = field table_row "table_cells" (ptr table_cells)
let () = seal table_row

type table_rows
let table_rows : table_rows structure typ = structure "TableRows"
let table_rows_count = field table_rows "row_count" int
let table_rows_array = field table_rows "table_rows" (ptr table_row)
let () = seal table_rows

(* DataTable structure *)
type data_table
let data_table : data_table structure typ = structure "DataTable"
let data_table_delete = field data_table "table_delete" item_delete_fn
let data_table_type = field data_table "type" gherkin_ast_type
let data_table_location = field data_table "location" location
let data_table_rows = field data_table "rows" (ptr table_rows)
let () = seal data_table

(* DocString structure *)
type doc_string
let doc_string : doc_string structure typ = structure "DocString"
let doc_string_delete = field doc_string "doc_string_delete" item_delete_fn
let doc_string_type = field doc_string "type" gherkin_ast_type
let doc_string_location = field doc_string "location" location
let doc_string_delimiter = field doc_string "delimiter" wstring
let doc_string_media_type = field doc_string "media_type" wstring
let doc_string_content = field doc_string "content" wstring
let () = seal doc_string

(* Background structure *)
type background
let background : background structure typ = structure "Background"
let background_delete = field background "background_delete" item_delete_fn
let background_type = field background "type" gherkin_ast_type
let background_location = field background "location" location
let background_id = field background "id" wstring
let background_keyword = field background "keyword" wstring
let background_name = field background "name" wstring
let background_description = field background "description" wstring
let background_steps = field background "steps" (ptr steps)
let () = seal background

(* Examples structure (for Scenario Outlines) *)
type examples
let examples : examples structure typ = structure "Examples"
(* Simplified - full implementation would have more fields *)
let () = seal examples

(* Scenario structure *)
type scenario
let scenario : scenario structure typ = structure "Scenario"
let scenario_delete = field scenario "scenario_delete" item_delete_fn
let scenario_type = field scenario "type" gherkin_ast_type
let scenario_location = field scenario "location" location
let scenario_id = field scenario "id" wstring
let scenario_keyword = field scenario "keyword" wstring
let scenario_name = field scenario "name" wstring
let scenario_description = field scenario "description" wstring
let scenario_tags = field scenario "tags" (ptr tags)
let scenario_steps = field scenario "steps" (ptr steps)
let scenario_examples = field scenario "examples" (ptr examples)
let () = seal scenario

(* ChildDefinition - base type for Background/Scenario/Rule *)
type child_definition
let child_definition : child_definition structure typ = structure "ChildDefinition"
let child_definition_delete = field child_definition "item_delete" item_delete_fn
let child_definition_type = field child_definition "type" gherkin_ast_type
let () = seal child_definition

type child_definitions
let child_definitions : child_definitions structure typ = structure "ChildDefinitions"
let child_definitions_count = field child_definitions "child_definition_count" int
let child_definitions_array = field child_definitions "child_definitions" (ptr (ptr child_definition))
let () = seal child_definitions

(* Feature structure *)
type feature
let feature : feature structure typ = structure "Feature"
let feature_delete = field feature "feature_delete" item_delete_fn
let feature_type = field feature "type" gherkin_ast_type
let feature_location = field feature "location" location
let feature_language = field feature "language" wstring
let feature_keyword = field feature "keyword" wstring
let feature_name = field feature "name" wstring
let feature_description = field feature "description" wstring
let feature_tags = field feature "tags" (ptr tags)
let feature_children = field feature "child_definitions" (ptr child_definitions)
let () = seal feature

(* GherkinDocument structure *)
type gherkin_document
let gherkin_document : gherkin_document structure typ = structure "GherkinDocument"
let gherkin_document_delete = field gherkin_document "gherkin_document_delete" item_delete_fn
let gherkin_document_type = field gherkin_document "type" gherkin_ast_type
let gherkin_document_uri = field gherkin_document "uri" wstring
let gherkin_document_feature = field gherkin_document "feature" (ptr feature)
let gherkin_document_comments = field gherkin_document "comments" (ptr void) (* Simplified *)
let () = seal gherkin_document

(* Error structure *)
type error
let error : error structure typ = structure "Error"
let error_text = field error "error_text" wstring
let error_location = field error "location" location
let () = seal error

(* Opaque types for C objects *)
type parser_t
let parser_t : parser_t structure typ = structure "Parser"

type builder_t
let builder_t : builder_t structure typ = structure "Builder"

type token_matcher_t
let token_matcher_t : token_matcher_t structure typ = structure "TokenMatcher"

type token_scanner_t
let token_scanner_t : token_scanner_t structure typ = structure "TokenScanner"

type id_generator_t
let id_generator_t : id_generator_t structure typ = structure "IdGenerator"

(* Function bindings *)

(* Parser functions *)
let parser_new =
  foreign "Parser_new" (ptr builder_t @-> returning (ptr parser_t))

let parser_delete =
  foreign "Parser_delete" (ptr parser_t @-> returning void)

let parser_parse =
  foreign "Parser_parse"
    (ptr parser_t @-> ptr token_matcher_t @-> ptr token_scanner_t @-> returning int)

let parser_has_more_errors =
  foreign "Parser_has_more_errors" (ptr parser_t @-> returning bool)

let parser_next_error =
  foreign "Parser_next_error" (ptr parser_t @-> returning (ptr error))

(* AstBuilder functions *)
let astbuilder_new =
  foreign "AstBuilder_new" (ptr id_generator_t @-> returning (ptr builder_t))

let astbuilder_delete =
  foreign "AstBuilder_delete" (ptr builder_t @-> returning void)

let astbuilder_get_result =
  foreign "AstBuilder_get_result"
    (ptr builder_t @-> string @-> returning (ptr gherkin_document))

(* TokenMatcher functions *)
let tokenmatcher_new =
  foreign "TokenMatcher_new" (wstring @-> returning (ptr token_matcher_t))

let tokenmatcher_delete =
  foreign "TokenMatcher_delete" (ptr token_matcher_t @-> returning void)

(* TokenScanner functions *)
let string_token_scanner_new =
  foreign "StringTokenScanner_new" (wstring @-> returning (ptr token_scanner_t))

let token_scanner_delete =
  foreign "TokenScanner_delete" (ptr token_scanner_t @-> returning void)

(* IdGenerator functions *)
let incrementing_id_generator_new =
  foreign "IncrementingIdGenerator_new" (void @-> returning (ptr id_generator_t))

let incrementing_id_generator_delete =
  foreign "IncrementingIdGenerator_delete" (ptr id_generator_t @-> returning void)

(* Error functions *)
let error_delete =
  foreign "Error_delete" (ptr error @-> returning void)
