(* log.sig

   Leveled, structured logging with a pluggable sink. The core is pure: a
   logger holds a minimum level and a sink (a function consuming formatted
   records). The default sink in tests is an in-memory string collector, so
   output is fully deterministic and assertable; a real application supplies
   a sink that writes to stdout/stderr at the impure edge.

   A record is a level, a message, and a list of structured key/value fields,
   rendered logfmt-style: `level=info msg="started" port=8080`. *)

signature LOG =
sig
  datatype level = Debug | Info | Warn | Error

  val levelName : level -> string
  (* Ordering used for threshold filtering (Debug < Info < Warn < Error). *)
  val levelRank : level -> int

  type fields = (string * string) list
  type record = { level : level, msg : string, fields : fields }

  (* Render a record to a single logfmt line (no trailing newline). Values
     are quoted/escaped when they contain spaces, quotes, or '='. *)
  val format : record -> string

  type logger
  type sink = string -> unit

  (* A logger with a minimum level and a sink. Records below the minimum are
     dropped before the sink is called. *)
  val make    : level -> sink -> logger
  (* Minimum level of a logger. *)
  val minLevel : logger -> level

  (* Emit a record if its level passes the threshold. *)
  val log     : logger -> level -> string -> fields -> unit
  val debug   : logger -> string -> fields -> unit
  val info    : logger -> string -> fields -> unit
  val warn    : logger -> string -> fields -> unit
  val error   : logger -> string -> fields -> unit

  (* Return a logger whose sink is a fresh in-memory collector, plus a
     function returning the accumulated lines (newest last). For tests. *)
  val capturing : level -> logger * (unit -> string list)
end
