(** Ctypes bindings for gherkin C library *)

open Ctypes

(** {1 Basic Types} *)

val wchar_t : int32 typ
(** Platform-specific wchar_t type *)

val wstring : int32 ptr typ
(** Wide character string pointer *)

val item_delete_fn : (unit ptr -> unit) typ
(** Function pointer for item deletion *)

(** {1 Enums} *)

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

val gherkin_ast_type : gherkin_ast_type typ

(** {1 Structure Types} *)

type location
val location : location structure typ
val location_line : (Unsigned.ulong, location structure) field
val location_column : (Unsigned.ulong, location structure) field

type tag
val tag : tag structure typ
val tag_location : (location structure, tag structure) field
val tag_name : (int32 ptr, tag structure) field

type tags
val tags : tags structure typ
val tags_count : (int, tags structure) field
val tags_array : (tag structure ptr, tags structure) field

type step
val step : step structure typ
val step_location : (location structure, step structure) field
val step_keyword : (int32 ptr, step structure) field
val step_text : (int32 ptr, step structure) field

type step_argument
val step_argument : step_argument structure typ
val step_argument_type : (gherkin_ast_type, step_argument structure) field
val step_argument_field : (step_argument structure ptr, step structure) field

type steps
val steps : steps structure typ
val steps_count : (int, steps structure) field
val steps_array : (step structure ptr, steps structure) field

type table_cell
val table_cell : table_cell structure typ
val table_cell_location : (location structure, table_cell structure) field
val table_cell_value : (int32 ptr, table_cell structure) field

type table_cells
val table_cells : table_cells structure typ
val table_cells_count : (int, table_cells structure) field
val table_cells_array : (table_cell structure ptr, table_cells structure) field

type table_row
val table_row : table_row structure typ
val table_row_location : (location structure, table_row structure) field
val table_row_cells : (table_cells structure ptr, table_row structure) field

type table_rows
val table_rows : table_rows structure typ
val table_rows_count : (int, table_rows structure) field
val table_rows_array : (table_row structure ptr, table_rows structure) field

type data_table
val data_table : data_table structure typ
val data_table_location : (location structure, data_table structure) field
val data_table_rows : (table_rows structure ptr, data_table structure) field

type doc_string
val doc_string : doc_string structure typ
val doc_string_location : (location structure, doc_string structure) field
val doc_string_media_type : (int32 ptr, doc_string structure) field
val doc_string_content : (int32 ptr, doc_string structure) field

type background
val background : background structure typ
val background_location : (location structure, background structure) field
val background_keyword : (int32 ptr, background structure) field
val background_name : (int32 ptr, background structure) field
val background_description : (int32 ptr, background structure) field
val background_steps : (steps structure ptr, background structure) field

type scenario
val scenario : scenario structure typ
val scenario_location : (location structure, scenario structure) field
val scenario_keyword : (int32 ptr, scenario structure) field
val scenario_name : (int32 ptr, scenario structure) field
val scenario_description : (int32 ptr, scenario structure) field
val scenario_tags : (tags structure ptr, scenario structure) field
val scenario_steps : (steps structure ptr, scenario structure) field

type child_definition
val child_definition : child_definition structure typ
val child_definition_type : (gherkin_ast_type, child_definition structure) field

type child_definitions
val child_definitions : child_definitions structure typ
val child_definitions_count : (int, child_definitions structure) field
val child_definitions_array : (child_definition structure ptr ptr, child_definitions structure) field

type feature
val feature : feature structure typ
val feature_location : (location structure, feature structure) field
val feature_language : (int32 ptr, feature structure) field
val feature_keyword : (int32 ptr, feature structure) field
val feature_name : (int32 ptr, feature structure) field
val feature_description : (int32 ptr, feature structure) field
val feature_tags : (tags structure ptr, feature structure) field
val feature_children : (child_definitions structure ptr, feature structure) field

type gherkin_document
val gherkin_document : gherkin_document structure typ
val gherkin_document_feature : (feature structure ptr, gherkin_document structure) field

type error
val error : error structure typ
val error_text : (int32 ptr, error structure) field
val error_location : (location structure, error structure) field

(** {1 Opaque C Types} *)

type parser_t
val parser_t : parser_t structure typ

type builder_t
val builder_t : builder_t structure typ

type token_matcher_t
val token_matcher_t : token_matcher_t structure typ

type token_scanner_t
val token_scanner_t : token_scanner_t structure typ

type id_generator_t
val id_generator_t : id_generator_t structure typ

(** {1 C Functions} *)

val parser_new : builder_t structure ptr -> parser_t structure ptr
val parser_delete : parser_t structure ptr -> unit
val parser_parse : parser_t structure ptr -> token_matcher_t structure ptr -> token_scanner_t structure ptr -> int
val parser_has_more_errors : parser_t structure ptr -> bool
val parser_next_error : parser_t structure ptr -> error structure ptr

val astbuilder_new : id_generator_t structure ptr -> builder_t structure ptr
val astbuilder_delete : builder_t structure ptr -> unit
val astbuilder_get_result : builder_t structure ptr -> string -> gherkin_document structure ptr

val tokenmatcher_new : int32 ptr -> token_matcher_t structure ptr
val tokenmatcher_delete : token_matcher_t structure ptr -> unit

val string_token_scanner_new : int32 ptr -> token_scanner_t structure ptr
val token_scanner_delete : token_scanner_t structure ptr -> unit

val incrementing_id_generator_new : unit -> id_generator_t structure ptr
val incrementing_id_generator_delete : id_generator_t structure ptr -> unit

val error_delete : error structure ptr -> unit
