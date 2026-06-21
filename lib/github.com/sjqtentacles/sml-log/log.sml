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

  fun renderField (k, v) = k ^ "=" ^ renderValue v

  fun format ({ level, msg, fields } : record) =
    let
      val base = ["level=" ^ levelName level, "msg=" ^ renderValue msg]
      val extra = List.map renderField fields
    in
      String.concatWith " " (base @ extra)
    end

  type sink = string -> unit
  type logger = { min : level, sink : sink }

  fun make min sink = { min = min, sink = sink }
  fun minLevel ({ min, ... } : logger) = min

  fun log ({ min, sink } : logger) level msg fields =
    if levelRank level >= levelRank min
    then sink (format { level = level, msg = msg, fields = fields })
    else ()

  fun debug l m f = log l Debug m f
  fun info  l m f = log l Info m f
  fun warn  l m f = log l Warn m f
  fun error l m f = log l Error m f

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
