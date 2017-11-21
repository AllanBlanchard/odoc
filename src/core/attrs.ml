(*
 * Copyright (c) 2014 Leo White <lpw25@cl.cam.ac.uk>
 *
 * Permission to use, copy, modify, and distribute this software for any
 * purpose with or without fee is hereby granted, provided that the above
 * copyright notice and this permission notice appear in all copies.
 *
 * THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
 * WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
 * MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
 * ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
 * WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
 * ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
 * OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
 *)



exception InvalidReference of string

let read_qualifier :
  string option ->
  [< Paths.Reference.kind ] Paths.Reference.tag
  = function
  | None -> TUnknown
  | Some "module" -> TModule
  | Some "module-type" -> TModuleType
  | Some "type" -> TType
  | Some ("const" | "constructor") -> TConstructor
  | Some ("recfield" | "field") -> TField
  | Some "extension" -> TExtension
  | Some ("exn" | "exception") -> TException
  | Some ("val" | "value") -> TValue
  | Some "class" -> TClass
  | Some ("classtype" | "class-type") -> TClassType
  | Some "method" -> TMethod
  | Some "instance-variable" -> TInstanceVariable
  | Some ("section" | "label") -> TLabel
  | Some ("page") -> TPage
  | Some s -> raise (InvalidReference ("unknown qualifier `" ^ s ^ "'"))

let read_longident s =
  let open Paths.Reference in
  let split_qualifier str =
    match String.rindex str '-' with
    | exception Not_found -> (None, str)
    | idx ->
      let qualifier = String.sub str 0 idx in
      let name = String.sub str (idx + 1) (String.length str - idx - 1) in
      (Some qualifier, name)
  in
  let rec loop_datatype : string -> int -> datatype option =
    fun s pos ->
      match String.rindex_from s pos '.' with
      | exception Not_found ->
        let maybe_qualified = String.sub s 0 (pos + 1) in
        if String.length maybe_qualified = 0 then
          None
        else
          let (kind, name) = split_qualifier maybe_qualified in
          begin match read_qualifier kind with
          | TUnknown | TType as tag -> Some (Root(name, tag))
          | _ -> None
          end
      | idx ->
        let maybe_qualified = String.sub s (idx + 1) (pos - idx) in
        if String.length maybe_qualified = 0 then
          None
        else
          let (qualifier, name) = split_qualifier maybe_qualified in
          match read_qualifier qualifier with
          | TUnknown -> begin
              match loop_parent s (idx - 1) with
              | None -> None
              | Some parent -> Some (Dot(label_parent_of_parent parent, name))
            end
          | TType -> begin
              match loop_signature s (idx - 1) with
              | None -> None
              | Some parent -> Some (Type(parent, name))
            end
          | _ -> None
  and loop_signature : string -> int -> signature option = fun s pos ->
      match String.rindex_from s pos '.' with
      | exception Not_found ->
        let maybe_qualified = String.sub s 0 (pos + 1) in
        if String.length maybe_qualified = 0 then
          None
        else
          let (kind, name) = split_qualifier maybe_qualified in
          begin match read_qualifier kind with
          | TUnknown | TModule | TModuleType as tag -> Some (Root(name, tag))
          | _ -> None
          end
      | idx ->
        let maybe_qualified = String.sub s (idx + 1) (pos - idx) in
        if String.length maybe_qualified = 0 then
          None
        else
          let (qualifier, name) = split_qualifier maybe_qualified in
          match read_qualifier qualifier with
          | TUnknown -> begin
              match loop_parent s (idx - 1) with
              | None -> None
              | Some parent -> Some (Dot(label_parent_of_parent parent, name))
            end
          | TModule -> begin
              match loop_signature s (idx - 1) with
              | None -> None
              | Some parent -> Some (Module(parent, name))
            end
          | TModuleType -> begin
              match loop_signature s (idx - 1) with
              | None -> None
              | Some parent -> Some (ModuleType(parent, name))
            end
          | _ -> None
  and loop_class_signature : string -> int -> class_signature option =
    fun s pos ->
      match String.rindex_from s pos '.' with
      | exception Not_found ->
        let maybe_qualified = String.sub s 0 (pos + 1) in
        if String.length maybe_qualified = 0 then
          None
        else
          let (kind, name) = split_qualifier maybe_qualified in
          begin match read_qualifier kind with
          | TUnknown | TClass | TClassType as tag -> Some (Root(name, tag))
          | _ -> None
          end
      | idx ->
        let maybe_qualified = String.sub s (idx + 1) (pos - idx) in
        if String.length maybe_qualified = 0 then
          None
        else
          let (qualifier, name) = split_qualifier maybe_qualified in
          match read_qualifier qualifier with
          | TUnknown -> begin
              match loop_parent s (idx - 1) with
              | None -> None
              | Some parent -> Some (Dot(label_parent_of_parent parent, name))
            end
          | TClass -> begin
              match loop_signature s (idx - 1) with
              | None -> None
              | Some parent -> Some (Class(parent, name))
            end
          | TClassType -> begin
              match loop_signature s (idx - 1) with
              | None -> None
              | Some parent -> Some (ClassType(parent, name))
            end
          | _ -> None
  and loop_label_parent : string -> int -> label_parent option =
    fun s pos ->
      match String.rindex_from s pos '.' with
      | exception Not_found ->
        let maybe_qualified = String.sub s 0 (pos + 1) in
        if String.length maybe_qualified = 0 then
          None
        else
          let (kind, name) = split_qualifier maybe_qualified in
          begin match read_qualifier kind with
          | TUnknown | TModule | TModuleType
          | TType | TClass | TClassType | TPage as tag ->
            Some (Root(name, tag))
          | _ -> None
          end
      | idx ->
        let maybe_qualified = String.sub s (idx + 1) (pos - idx) in
        if String.length maybe_qualified = 0 then
          None
        else
          let (qualifier, name) = split_qualifier maybe_qualified in
          match read_qualifier qualifier with
          | TUnknown -> begin
              match loop_label_parent s (idx - 1) with
              | None -> None
              | Some parent -> Some (Dot(parent, name))
            end
          | TModule -> begin
              match loop_signature s (idx - 1) with
              | None -> None
              | Some parent -> Some (Module(parent, name))
            end
          | TModuleType -> begin
              match loop_signature s (idx - 1) with
              | None -> None
              | Some parent -> Some (ModuleType(parent, name))
            end
          | TType -> begin
              match loop_signature s (idx - 1) with
              | None -> None
              | Some parent -> Some (Type(parent, name))
            end
          | TClass -> begin
              match loop_signature s (idx - 1) with
              | None -> None
              | Some parent -> Some (Class(parent, name))
            end
          | TClassType -> begin
              match loop_signature s (idx - 1) with
              | None -> None
              | Some parent -> Some (ClassType(parent, name))
            end
          | _ -> None
  and loop_parent : string -> int -> parent option =
    fun s pos ->
      match String.rindex_from s pos '.' with
      | exception Not_found ->
        let maybe_qualified = String.sub s 0 (pos + 1) in
        if String.length maybe_qualified = 0 then
          None
        else
          let (kind, name) = split_qualifier maybe_qualified in
          begin match read_qualifier kind with
          | TUnknown
          | TModule | TModuleType | TType | TClass | TClassType as tag ->
            Some (Root(name, tag))
          | _ -> None
          end
      | idx ->
        let maybe_qualified = String.sub s (idx + 1) (pos - idx) in
        if String.length maybe_qualified = 0 then
          None
        else
          let (qualifier, name) = split_qualifier maybe_qualified in
          match read_qualifier qualifier with
          | TUnknown -> begin
              match loop_parent s (idx - 1) with
              | None -> None
              | Some parent -> Some (Dot(label_parent_of_parent parent, name))
            end
          | TModule -> begin
              match loop_signature s (idx - 1) with
              | None -> None
              | Some parent -> Some (Module(parent, name))
            end
          | TModuleType -> begin
              match loop_signature s (idx - 1) with
              | None -> None
              | Some parent -> Some (ModuleType(parent, name))
            end
          | TType -> begin
              match loop_signature s (idx - 1) with
              | None -> None
              | Some parent -> Some (Type(parent, name))
            end
          | TClass -> begin
              match loop_signature s (idx - 1) with
              | None -> None
              | Some parent -> Some (Class(parent, name))
            end
          | TClassType -> begin
              match loop_signature s (idx - 1) with
              | None -> None
              | Some parent -> Some (ClassType(parent, name))
            end
          | _ -> None
  in
  let loop : 'k. string -> int -> kind t option =
    fun s pos ->
      match String.rindex_from s pos '.' with
      | exception Not_found ->
        let maybe_qualified = String.sub s 0 (pos + 1) in
        if String.length maybe_qualified = 0 then
          None
        else
          let (kind, name) = split_qualifier maybe_qualified in
          Some (Root (name, read_qualifier kind))
      | idx ->
        let maybe_qualified = String.sub s (idx + 1) (pos - idx) in
        if String.length maybe_qualified = 0 then
          None
        else
          let (qualifier, name) = split_qualifier maybe_qualified in
          match read_qualifier qualifier with
          | TUnknown -> begin
              match loop_label_parent s (idx - 1) with
              | None -> None
              | Some parent -> Some (Dot(parent, name))
            end
          | TModule -> begin
              match loop_signature s (idx - 1) with
              | None -> None
              | Some parent -> Some (Module(parent, name))
            end
          | TModuleType -> begin
              match loop_signature s (idx - 1) with
              | None -> None
              | Some parent -> Some (ModuleType(parent, name))
            end
          | TType -> begin
              match loop_signature s (idx - 1) with
              | None -> None
              | Some parent -> Some (Type(parent, name))
            end
          | TConstructor -> begin
              match loop_datatype s (idx - 1) with
              | None -> None
              | Some parent -> Some (Constructor(parent, name))
            end
          | TField -> begin
              match loop_parent s (idx - 1) with
              | None -> None
              | Some parent -> Some (Field(parent, name))
            end
          | TExtension -> begin
              match loop_signature s (idx - 1) with
              | None -> None
              | Some parent -> Some (Extension(parent, name))
            end
          | TException -> begin
              match loop_signature s (idx - 1) with
              | None -> None
              | Some parent -> Some (Exception(parent, name))
            end
          | TValue -> begin
              match loop_signature s (idx - 1) with
              | None -> None
              | Some parent -> Some (Value(parent, name))
            end
          | TClass -> begin
              match loop_signature s (idx - 1) with
              | None -> None
              | Some parent -> Some (Class(parent, name))
            end
          | TClassType -> begin
              match loop_signature s (idx - 1) with
              | None -> None
              | Some parent -> Some (ClassType(parent, name))
            end
          | TMethod -> begin
              match loop_class_signature s (idx - 1) with
              | None -> None
              | Some parent -> Some (Method(parent, name))
            end
          | TInstanceVariable -> begin
              match loop_class_signature s (idx - 1) with
              | None -> None
              | Some parent -> Some (InstanceVariable(parent, name))
            end
          | TLabel -> begin
              match loop_label_parent s (idx - 1) with
              | None -> None
              | Some parent -> Some (Label(parent, name))
            end
          | TPage -> None
  in
    match loop s (String.length s - 1) with
    | None -> raise (InvalidReference s)
    | Some r -> r

let read_path_longident s =
  let open Paths.Path in
  let rec loop : 'k. string -> int -> ([< kind > `Module ] as 'k) t option =
    fun s pos ->
      try
        let idx = String.rindex_from s pos '.' in
        let name = String.sub s (idx + 1) (pos - idx) in
        if String.length name = 0 then None
        else
          match loop s (idx - 1) with
          | None -> None
          | Some parent -> Some (Dot(parent, name))
      with Not_found ->
        let name = String.sub s 0 (pos + 1) in
        if String.length name = 0 then None
        else Some (Root name)
  in
    match loop s (String.length s - 1) with
    | None -> raise (InvalidReference s)
    | Some r -> r

exception Expected_reference_to_a_module_but_got of string

let read_mod_longident lid : Paths.Reference.module_ =
  let open Paths.Reference in
  match read_longident lid with
  | Root (_, (TUnknown | TModule))
  | Dot (_, _)
  | Module (_,_) as r -> r
  | _ ->
      (* FIXME: propagate location *)
      raise (Expected_reference_to_a_module_but_got lid)

let read_tag : Doc_parser.Output.tag -> Model.Documentation.tag =
  function
  | Author s -> Author s
  | Version v -> Version v
  | See (r, t) -> See (r, t)
  | Since s -> Since s
  | Before (s, t) -> Before (s, t)
  | Deprecated t -> Deprecated t
  | Param (s, t) -> Param (s, t)
  | Raised_exception (s, t) -> Raise (s, t)
  | Return_value t -> Return t
  | Inline -> Inline
  | Custom (s, t) -> Tag (s, t)
  | Canonical p -> Canonical (read_path_longident p, read_mod_longident p)

let empty_body = {Model.Documentation.text = []; tags = []}

let empty : Model.Documentation.t = Ok empty_body

let read_offset err =
  let open Doc_parser.Error in
  let loc = err.location in
  let start =
    { Model.Documentation.Error.Position.
        line = loc.start.line;
        column = loc.start.column; }
  in
  let finish =
    { Model.Documentation.Error.Position.
        line = loc.finish.line;
        column = loc.finish.column; }
  in
    { Model.Documentation.Error.Offset.start; finish; }

let read_position offset pos =
  let open Lexing in
  let open Model.Documentation.Error in
  let off_line = offset.Position.line in
  let off_column = offset.Position.column in
  let line = pos.pos_lnum + off_line - 1 in
  let column =
    if off_line = 1 then
      (pos.pos_cnum - pos.pos_bol) + off_column + 3
    else off_column
  in
  { Position.line; column }

let read_location offset pos =
  let open Lexing in
  let open Model.Documentation.Error in
  if pos.pos_cnum >= 0 then begin
    let filename = pos.pos_fname in
    let start = read_position offset.Offset.start pos in
    let finish = read_position offset.Offset.finish pos in
    Some { Location.filename; start; finish }
  end else None

let read_error origin err pos =
  let open Model.Documentation.Error in
  let origin = Paths.Identifier.any origin in
  let offset = read_offset err in
  let location = read_location offset pos in
  let message = Doc_parser.Error.message err.Doc_parser.Error.error in
    { origin; offset; location; message }

let attribute_location loc =
  let open Lexing in
  let open Location in
  let open Model.Documentation.Error in
  let start = loc.loc_start in
  let finish = loc.loc_end in
  if start.pos_cnum >= 0 && finish.pos_cnum >= 0 then begin
    let filename = start.pos_fname in
    let read_pos pos =
      let line = pos.pos_lnum in
      let column = pos.pos_cnum - pos.pos_bol in
      { Position.line; column }
    in
    let start = read_pos start in
    let finish = read_pos finish in
    Some { Location.filename; start; finish }
  end else None

let invalid_attribute_error origin loc =
  let open Model.Documentation.Error in
  let origin = Paths.Identifier.any origin in
  let offset =
    let zero_pos = { Position.line = 0; column = 0 } in
    { Offset.start = zero_pos; finish = zero_pos }
  in
  let location = attribute_location loc in
  let message = "Invalid documentation attribute" in
    { origin; offset; location; message }

let invalid_reference_error origin loc s =
  let open Model.Documentation.Error in
  let origin = Paths.Identifier.any origin in
  (* TODO get an actual offset *)
  let dummy = { Position.line = 0; column = 0} in
  let offset = { Offset.start = dummy; finish = dummy } in
  (* TODO get an accurate location *)
  let location = attribute_location loc in
  let message = "Invalid reference: \"" ^ s ^ "\"" in
    {origin; offset; location; message}

let several_deprecated_error origin loc =
  let open Model.Documentation.Error in
  let origin = Paths.Identifier.any origin in
  (* TODO get an actual offset *)
  let dummy = { Position.line = 0; column = 0} in
  let offset = { Offset.start = dummy; finish = dummy } in
  (* TODO get an accurate location *)
  let location = attribute_location loc in
  let message = "Several deprecation tags are attached to this item" in
    {origin; offset; location; message}


let read_attributes parent id attrs =
  let ocaml_deprecated = ref None in
  let rec loop first nb_deprecated acc : _ -> Model.Documentation.t =
    function
    | ({Location.txt =
          ("doc" | "ocaml.doc"); loc}, payload) :: rest -> begin
        match Payload.read payload with
        | Some (str, loc) -> begin
            let start_pos = loc.Location.loc_start in
            let lexbuf = Lexing.from_string str in
            match Doc_parser.parse parent lexbuf with
            | Ok (text, tags) -> begin
                try
                  let text = if first then text else Newline :: text in
                  let tags = List.map read_tag tags in
                  let nb_deprecated =
                    List.fold_right (function
                      | Model.Documentation.Deprecated _ -> (+) 1
                      | _ -> fun x -> x
                    ) tags nb_deprecated
                  in
                  if nb_deprecated > 1 then
                    Error (several_deprecated_error id loc)
                  else
                    let acc =
                      Model.Documentation.{
                        text = acc.text @ text;
                        tags = acc.tags @ tags;
                      }
                    in
                    loop false nb_deprecated acc rest
                with InvalidReference s ->
                  Error (invalid_reference_error id loc s)
              end
            | Error err -> Error (read_error id err start_pos)
          end
        | None -> Error (invalid_attribute_error id loc)
      end
    | ({Location.txt =
          ("deprecated" | "ocaml.deprecated"); _}, payload) :: rest -> begin
        match Payload.read payload with
        | Some (str, _) ->
          (* Not parsing with octavius here, we take the string verbatim. *)
          let deprecated_tag = Model.Documentation.Deprecated [Raw str] in
          ocaml_deprecated := Some deprecated_tag;
          loop first nb_deprecated acc rest
        | None ->
          (* The compiler just ignores deprecated attributes whose payload is
             not a string, we do the same. *)
          loop first nb_deprecated acc rest
      end
    | _ :: rest -> loop first nb_deprecated acc rest
    | [] -> begin
        match nb_deprecated, !ocaml_deprecated with
        | 0, Some tag -> Ok { acc with tags = acc.tags @ [tag] }
        | _, _ -> Ok acc
      end
  in
    loop true 0 empty_body attrs

let read_string parent loc str : Model.Documentation.comment =
  let lexbuf = Lexing.from_string str in
  let start_pos = loc.Location.loc_start in
  let doc : Model.Documentation.t =
    match Doc_parser.parse parent lexbuf with
    | Ok (text, tags) -> begin
        try
          let tags = List.map read_tag tags in
          Ok {Model.Documentation.text; tags}
        with InvalidReference s ->
          Error (invalid_reference_error parent loc s)
      end
    | Error err -> Error (read_error parent err start_pos)
  in
  Documentation doc

let read_comment parent
    : Parsetree.attribute -> Model.Documentation.comment option =

  function
  | ({Location.txt =
        ("text" | "ocaml.text"); loc}, payload) -> begin
      match Payload.read payload with
      | Some ("/*", _loc) -> Some Stop
      | Some (str, loc) -> Some (read_string parent loc str)
      | None ->
          let doc : Model.Documentation.t =
            Error (invalid_attribute_error parent loc) in
            Some (Documentation doc)
    end
  | _ -> None

let read_comments parent attrs =
  let coms =
    List.fold_left
      (fun acc attr ->
         match read_comment parent attr  with
         | None -> acc
         | Some com -> com :: acc)
      [] attrs
  in
    List.rev coms
