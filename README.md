# sml-log

[![CI](https://github.com/sjqtentacles/sml-log/actions/workflows/ci.yml/badge.svg)](https://github.com/sjqtentacles/sml-log/actions/workflows/ci.yml)

Leveled, structured logging for Standard ML with a pluggable sink.

The core is pure: a logger pairs a minimum level with a `sink : string ->
unit`. Records below the threshold are dropped before the sink runs. Records
render logfmt-style -- `level=info msg="started" port=8080` -- with automatic
quoting/escaping of **both keys and values** containing spaces, quotes, `=`, or
newlines. A logger can also bind contextual fields (`withFields`), use a custom
renderer such as the built-in JSON formatter (`makeWith` + `formatJson`), and
fan out or filter output with sink combinators (`tee`, `filterSink`).

Because the sink is just a function, tests use an in-memory collector
(`Log.capturing`) and assert over deterministic strings; a real application
supplies a sink that writes to stdout/stderr at the impure edge. Pure
Standard ML over the Basis library -- no dependencies.

Verified on **MLton** and **Poly/ML**.

## API

```sml
structure Log : sig
  datatype level = Debug | Info | Warn | Error
  val levelName : level -> string
  val levelRank : level -> int
  val parseLevel : string -> level option        (* inverse of levelName *)
  type fields = (string * string) list
  type record = { level : level, msg : string, fields : fields }
  val format     : record -> string              (* logfmt *)
  val formatJson : record -> string              (* single-line JSON object *)
  type logger
  type sink = string -> unit
  val make     : level -> sink -> logger                       (* logfmt *)
  val makeWith : (record -> string) -> level -> sink -> logger (* custom render *)
  val minLevel  : logger -> level
  val setLevel  : logger -> level -> logger       (* immutable; returns new *)
  val isEnabled : logger -> level -> bool
  val withFields : logger -> fields -> logger     (* child logger w/ bound fields *)
  val log   : logger -> level -> string -> fields -> unit
  val debug : logger -> string -> fields -> unit
  val info  : logger -> string -> fields -> unit
  val warn  : logger -> string -> fields -> unit
  val error : logger -> string -> fields -> unit
  val tee        : sink list -> sink              (* fan out *)
  val filterSink : (string -> bool) -> sink -> sink
  val capturing : level -> logger * (unit -> string list)
end
```

### Example

```sml
(* Production: write each line to stdout. *)
val logger = Log.make Log.Info (fn line => print (line ^ "\n"))
val () = Log.info logger "request" [("method", "GET"), ("path", "/users")]
(* -> level=info msg=request method=GET path=/users *)

(* Bind contextual fields once; they precede call-site fields. *)
val reqLog = Log.withFields logger [("service", "api"), ("req", "42")]
val () = Log.info reqLog "handled" [("ms", "12")]
(* -> level=info msg=handled service=api req=42 ms=12 *)

(* JSON renderer + fan-out to two sinks, one filtered. *)
val jlog = Log.makeWith Log.formatJson Log.Info
             (Log.tee [ fn l => print (l ^ "\n")
                      , Log.filterSink (String.isSubstring "error") errSink ])

(* Parse a level from config / env. *)
val lvl = Option.getOpt (Log.parseLevel "warn", Log.Info)

(* Tests: capture and assert. *)
val (cap, lines) = Log.capturing Log.Warn
val () = Log.debug cap "noise" []     (* dropped *)
val () = Log.error cap "boom" [("code", "500")]
(* lines () = ["level=error msg=boom code=500"] *)
```

## Build & test

```sh
make test        # MLton
make test-poly   # Poly/ML
make all-tests   # both
make clean
```

## Installing with smlpkg

```sh
smlpkg add github.com/sjqtentacles/sml-log
smlpkg sync
```

Reference `lib/github.com/sjqtentacles/sml-log/sml-log.mlb` from your own
`.mlb`, or feed `sources.mlb` to `tools/polybuild` (Poly/ML).

## Tests

29 deterministic checks: logfmt rendering (value and key quoting/escaping,
fields), JSON rendering, level names/ranks, `parseLevel` round-trips, threshold
filtering, immutable `setLevel`/`isEnabled`, `withFields` child loggers, custom
renderers via `makeWith`, and the `tee`/`filterSink` sink combinators -- all
captured via the in-memory sink. Run `make all-tests`.

## License

MIT. See [LICENSE](LICENSE).
