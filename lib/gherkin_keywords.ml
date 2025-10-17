(** Gherkin keyword definitions for i18n support *)

type keyword_set = {
  feature : string list;
  background : string list;
  rule : string list;
  scenario : string list;
  scenario_outline : string list;
  examples : string list;
  given : string list;
  when_ : string list;
  then_ : string list;
  and_ : string list;
  but : string list;
}

(* English keywords *)
let english =
  {
    feature = [ "Feature" ];
    background = [ "Background" ];
    rule = [ "Rule" ];
    scenario = [ "Scenario" ];
    scenario_outline = [ "Scenario Outline"; "Scenario Template" ];
    examples = [ "Examples"; "Scenarios" ];
    given = [ "Given" ];
    when_ = [ "When" ];
    then_ = [ "Then" ];
    and_ = [ "And"; "*" ];
    but = [ "But" ];
  }

(* French keywords *)
let french =
  {
    feature = [ "Fonctionnalité" ];
    background = [ "Contexte" ];
    rule = [ "Règle" ];
    scenario = [ "Scénario" ];
    scenario_outline = [ "Plan du scénario"; "Plan du Scénario" ];
    examples = [ "Exemples" ];
    given =
      [
        "Soit";
        "Etant donné";
        "Etant donnée";
        "Etant donnés";
        "Etant données";
        "Étan donné";
        "Étant donnée";
        "Étant donnés";
        "Étant données";
      ];
    when_ = [ "Quand"; "Lorsque"; "Lorsqu'" ];
    then_ = [ "Alors" ];
    and_ = [ "Et"; "*" ];
    but = [ "Mais" ];
  }

(* German keywords *)
let german =
  {
    feature = [ "Funktionalität" ];
    background = [ "Grundlage" ];
    rule = [ "Regel" ];
    scenario = [ "Szenario" ];
    scenario_outline = [ "Szenariogrundriss" ];
    examples = [ "Beispiele" ];
    given = [ "Angenommen"; "Gegeben sei"; "Gegeben seien" ];
    when_ = [ "Wenn" ];
    then_ = [ "Dann" ];
    and_ = [ "Und"; "*" ];
    but = [ "Aber" ];
  }

(* Spanish keywords *)
let spanish =
  {
    feature = [ "Característica"; "Necesidad del negocio"; "Requisito" ];
    background = [ "Antecedentes" ];
    rule = [ "Regla" ];
    scenario = [ "Escenario" ];
    scenario_outline = [ "Esquema del escenario" ];
    examples = [ "Ejemplos" ];
    given = [ "Dado"; "Dada"; "Dados"; "Dadas" ];
    when_ = [ "Cuando" ];
    then_ = [ "Entonces" ];
    and_ = [ "Y"; "E"; "*" ];
    but = [ "Pero" ];
  }

(* Portuguese keywords *)
let portuguese =
  {
    feature = [ "Funcionalidade"; "Característica" ];
    background = [ "Contexto"; "Cenário de Fundo" ];
    rule = [ "Regra" ];
    scenario = [ "Cenário" ];
    scenario_outline = [ "Esquema do Cenário"; "Delineação do Cenário" ];
    examples = [ "Exemplos"; "Cenários" ];
    given = [ "Dado"; "Dada"; "Dados"; "Dadas" ];
    when_ = [ "Quando" ];
    then_ = [ "Então" ];
    and_ = [ "E"; "*" ];
    but = [ "Mas" ];
  }

(* Italian keywords *)
let italian =
  {
    feature = [ "Funzionalità" ];
    background = [ "Contesto" ];
    rule = [ "Regola" ];
    scenario = [ "Scenario" ];
    scenario_outline = [ "Schema dello scenario" ];
    examples = [ "Esempi" ];
    given = [ "Dato"; "Data"; "Dati"; "Date" ];
    when_ = [ "Quando" ];
    then_ = [ "Allora" ];
    and_ = [ "E"; "*" ];
    but = [ "Ma" ];
  }

(* Dutch keywords *)
let dutch =
  {
    feature = [ "Functionaliteit" ];
    background = [ "Achtergrond" ];
    rule = [ "Regel" ];
    scenario = [ "Scenario" ];
    scenario_outline = [ "Abstract Scenario" ];
    examples = [ "Voorbeelden" ];
    given = [ "Gegeven"; "Stel" ];
    when_ = [ "Als"; "Wanneer" ];
    then_ = [ "Dan" ];
    and_ = [ "En"; "*" ];
    but = [ "Maar" ];
  }

(* Russian keywords *)
let russian =
  {
    feature = [ "Функция"; "Функционал"; "Свойство" ];
    background = [ "Предыстория"; "Контекст" ];
    rule = [ "Правило" ];
    scenario = [ "Сценарий" ];
    scenario_outline = [ "Структура сценария" ];
    examples = [ "Примеры" ];
    given = [ "Допустим"; "Дано"; "Пусть" ];
    when_ = [ "Если"; "Когда" ];
    then_ = [ "То"; "Тогда" ];
    and_ = [ "И"; "К тому же"; "*" ];
    but = [ "Но"; "А" ];
  }

(* Japanese keywords *)
let japanese =
  {
    feature = [ "フィーチャ"; "機能" ];
    background = [ "背景" ];
    rule = [ "ルール" ];
    scenario = [ "シナリオ" ];
    scenario_outline = [ "シナリオアウトライン"; "シナリオテンプレート"; "テンプレ"; "シナリオテンプレ" ];
    examples = [ "例"; "サンプル" ];
    given = [ "前提" ];
    when_ = [ "もし" ];
    then_ = [ "ならば" ];
    and_ = [ "かつ"; "*" ];
    but = [ "しかし"; "但し"; "ただし" ];
  }

(* Chinese (Simplified) keywords *)
let chinese_simplified =
  {
    feature = [ "功能" ];
    background = [ "背景" ];
    rule = [ "规则"; "Rule" ];
    scenario = [ "场景"; "剧本" ];
    scenario_outline = [ "场景大纲"; "剧本大纲" ];
    examples = [ "例子" ];
    given = [ "假如"; "假设"; "假定" ];
    when_ = [ "当" ];
    then_ = [ "那么" ];
    and_ = [ "而且"; "并且"; "同时"; "*" ];
    but = [ "但是" ];
  }

(* Keyword lookup table *)
let keyword_table =
  [
    ("en", english);
    ("fr", french);
    ("de", german);
    ("es", spanish);
    ("pt", portuguese);
    ("it", italian);
    ("nl", dutch);
    ("ru", russian);
    ("ja", japanese);
    ("zh-CN", chinese_simplified);
    ("zh_CN", chinese_simplified);
  ]

let get_keywords lang =
  try Some (List.assoc lang keyword_table) with Not_found -> None

let matches_keyword word keywords =
  List.exists
    (fun kw ->
      (* Exact match for UTF-8 safety *)
      word = kw
      (* Also try case-insensitive for ASCII-only keywords *)
      || String.lowercase_ascii word = String.lowercase_ascii kw
      (* Handle keywords with trailing colons *)
      || word = kw ^ ":"
      || String.lowercase_ascii word = String.lowercase_ascii kw ^ ":")
    keywords

let is_feature word lang =
  match get_keywords lang with
  | Some kws -> matches_keyword word kws.feature
  | None -> matches_keyword word english.feature

let is_scenario word lang =
  match get_keywords lang with
  | Some kws -> matches_keyword word (kws.scenario @ kws.scenario_outline)
  | None -> matches_keyword word (english.scenario @ english.scenario_outline)

let is_step word lang =
  match get_keywords lang with
  | Some kws ->
      matches_keyword word
        (kws.given @ kws.when_ @ kws.then_ @ kws.and_ @ kws.but)
  | None ->
      matches_keyword word
        (english.given @ english.when_ @ english.then_ @ english.and_
       @ english.but)

let supported_languages () = List.map fst keyword_table
