(* demo.sml - exercise sml-log's leveled logging: an in-memory capturing
   sink, threshold filtering, a child logger via withFields, and the
   logfmt/JSON renderers used directly on a literal record. Deterministic:
   no real stdout/stderr side effects, only the in-memory sink. *)

val () = print "sml-log demo\n"

(* 1. A capturing logger at Info: Debug is filtered out, Info/Warn/Error
   pass through, rendered logfmt-style. *)
val (logger, lines) = Log.capturing Log.Info
val () = Log.debug logger "connecting" [("host", "db.internal")]
val () = Log.info logger "request" [("method", "GET"), ("path", "/users")]
val () = Log.warn logger "slow query" [("ms", "420")]

(* 2. A child logger with bound fields, prepended to each record's fields. *)
val reqLog = Log.withFields logger [("service", "api"), ("req", "42")]
val () = Log.error reqLog "handled" [("status", "500")]

val () = print "captured lines (Info threshold):\n"
val () = List.app (fn l => print ("  " ^ l ^ "\n")) (lines ())

(* 3. `format`/`formatJson` applied directly to a literal record. *)
val rec1 = { level = Log.Warn, msg = "disk almost full", fields = [("pct", "97")] }
val () = print "format/formatJson on a literal record:\n"
val () = print ("  format     = " ^ Log.format rec1 ^ "\n")
val () = print ("  formatJson = " ^ Log.formatJson rec1 ^ "\n")

(* 4. `parseLevel` round-tripping level names. *)
val () = print "parseLevel:\n"
val () = List.app
  (fn s => print ("  parseLevel \"" ^ s ^ "\" = "
                  ^ (case Log.parseLevel s of
                         SOME lvl => Log.levelName lvl
                       | NONE => "NONE")
                  ^ "\n"))
  ["debug", "WARN", "bogus"]
