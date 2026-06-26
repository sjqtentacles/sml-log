(* log.sml *)

structure Log :> LOG =
struct
  datatype level = Debug | Info | Warn | Error

  fun levelName Debug = "debug"
    | levelName Info  = "info"
    | levelName Warn  = "warn"
    | levelName Error = "error"

  fun levelRank Debug = 0
    | levelRank Info  = 1
    | levelRank Warn  = 2
    | levelRank Error = 3

  type fields = (string * string) list
  type record = { level : level, msg : string, fields : fields }

  (* A value needs quoting if empty or containing space, quote, or '='. *)
  fun needsQuote s =
    s = "" orelse
    CharVector.exists (fn c => c = #" " orelse c = #"\"" orelse c = #"=" orelse c = #"\n") s

  fun escape s =
    String.translate
      (fn #"\"" => "\\\"" | #"\\" => "\\\\" | #"\n" => "\\n" | c => String.str c) s

  fun renderValue s = if needsQuote s then "\"" ^ escape s ^ "\"" else s

  (* Keys follow the same quoting rule as values, so `weird key`="v" round-trips
     unambiguously rather than producing a broken `weird key=v`. *)
  fun renderKey s = if needsQuote s then "\"" ^ escape s ^ "\"" else s

  fun renderField (k, v) = renderKey k ^ "=" ^ renderValue v

  fun format ({ level, msg, fields } : record) =
    let
      val base = ["level=" ^ levelName level, "msg=" ^ renderValue msg]
      val extra = List.map renderField fields
    in
      String.concatWith " " (base @ extra)
    end

  (* JSON string escaping per RFC 8259 (subset sufficient for our values). *)
  fun jsonEscape s =
    String.translate
      (fn #"\"" => "\\\""
        | #"\\" => "\\\\"
        | #"\n" => "\\n"
        | #"\r" => "\\r"
        | #"\t" => "\\t"
        | c => String.str c) s

  fun jsonStr s = "\"" ^ jsonEscape s ^ "\""

  fun formatJson ({ level, msg, fields } : record) =
    let
      val fs = String.concatWith ","
                 (List.map (fn (k, v) => jsonStr k ^ ":" ^ jsonStr v) fields)
    in
      "{\"level\":" ^ jsonStr (levelName level)
      ^ ",\"msg\":" ^ jsonStr msg
      ^ ",\"fields\":{" ^ fs ^ "}}"
    end

  type sink = string -> unit
  type logger = { min : level, sink : sink, render : record -> string,
                  bound : fields }

  fun makeWith render min sink =
    { min = min, sink = sink, render = render, bound = [] }
  fun make min sink = makeWith format min sink
  fun minLevel ({ min, ... } : logger) = min

  fun parseLevel s =
    case String.map Char.toLower s of
        "debug" => SOME Debug
      | "info"  => SOME Info
      | "warn"  => SOME Warn
      | "error" => SOME Error
      | _ => NONE

  fun setLevel ({ sink, render, bound, ... } : logger) min =
    { min = min, sink = sink, render = render, bound = bound }

  fun isEnabled ({ min, ... } : logger) level = levelRank level >= levelRank min

  fun withFields ({ min, sink, render, bound } : logger) fields =
    { min = min, sink = sink, render = render, bound = bound @ fields }

  fun log ({ min, sink, render, bound } : logger) level msg fields =
    if levelRank level >= levelRank min
    then sink (render { level = level, msg = msg, fields = bound @ fields })
    else ()

  fun debug l m f = log l Debug m f
  fun info  l m f = log l Info m f
  fun warn  l m f = log l Warn m f
  fun error l m f = log l Error m f

  fun tee sinks = fn line => List.app (fn s => s line) sinks
  fun filterSink p sink = fn line => if p line then sink line else ()

  fun capturing min =
    let
      val buf = ref ([] : string list)   (* reversed *)
      val sink = fn line => buf := line :: !buf
      val logger = make min sink
      fun lines () = List.rev (!buf)
    in
      (logger, lines)
    end
end
