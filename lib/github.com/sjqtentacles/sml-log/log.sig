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

  (* Render a record to a single logfmt line (no trailing newline). Both keys
     and values are quoted/escaped when they contain spaces, quotes, '=', or
     newlines (an empty string is also quoted). *)
  val format : record -> string

  (* Render a record as a single-line JSON object:
     {"level":"info","msg":"started","fields":{"port":"8080"}} *)
  val formatJson : record -> string

  type logger
  type sink = string -> unit

  (* A logger with a minimum level and the default logfmt `format` renderer. *)
  val make    : level -> sink -> logger
  (* As `make`, but with a caller-supplied record renderer (e.g. `formatJson`
     or a custom one). *)
  val makeWith : (record -> string) -> level -> sink -> logger
  (* Minimum level of a logger. *)
  val minLevel : logger -> level

  (* Parse a level name (case-insensitive); inverse of `levelName`. *)
  val parseLevel : string -> level option

  (* Immutable level adjustment: returns a new logger at the given minimum. *)
  val setLevel : logger -> level -> logger
  (* Whether a record at this level would be emitted by the logger. *)
  val isEnabled : logger -> level -> bool

  (* Return a child logger that prepends the given fields to every record it
     emits (call-site fields are appended after the bound fields). *)
  val withFields : logger -> fields -> logger

  (* Emit a record if its level passes the threshold. *)
  val log     : logger -> level -> string -> fields -> unit
  val debug   : logger -> string -> fields -> unit
  val info    : logger -> string -> fields -> unit
  val warn    : logger -> string -> fields -> unit
  val error   : logger -> string -> fields -> unit

  (* A sink that forwards each line to every sink in the list, in order. *)
  val tee : sink list -> sink
  (* A sink that forwards a line only when the predicate accepts it. *)
  val filterSink : (string -> bool) -> sink -> sink

  (* Return a logger whose sink is a fresh in-memory collector, plus a
     function returning the accumulated lines (newest last). For tests. *)
  val capturing : level -> logger * (unit -> string list)
end
