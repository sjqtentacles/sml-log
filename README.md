# sml-log

[![CI](https://github.com/sjqtentacles/sml-log/actions/workflows/ci.yml/badge.svg)](https://github.com/sjqtentacles/sml-log/actions/workflows/ci.yml)

Leveled, structured logging for Standard ML with a pluggable sink.

The core is pure: a logger pairs a minimum level with a `sink : string ->
unit`. Records below the threshold are dropped before the sink runs. Records
render logfmt-style -- `level=info msg="started" port=8080` -- with automatic
quoting/escaping of values containing spaces, quotes, `=`, or newlines.

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
  type fields = (string * string) list
  type record = { level : level, msg : string, fields : fields }
  val format : record -> string
  type logger
  type sink = string -> unit
  val make    : level -> sink -> logger
  val minLevel : logger -> level
  val log   : logger -> level -> string -> fields -> unit
  val debug : logger -> string -> fields -> unit
  val info  : logger -> string -> fields -> unit
  val warn  : logger -> string -> fields -> unit
  val error : logger -> string -> fields -> unit
  val capturing : level -> logger * (unit -> string list)
end
```

### Example

```sml
(* Production: write each line to stdout. *)
val logger = Log.make Log.Info (fn line => print (line ^ "\n"))
val () = Log.info logger "request" [("method", "GET"), ("path", "/users")]
(* -> level=info msg=request method=GET path=/users *)

(* Tests: capture and assert. *)
val (logger, lines) = Log.capturing Log.Warn
val () = Log.debug logger "noise" []     (* dropped *)
val () = Log.error logger "boom" [("code", "500")]
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

11 deterministic checks: logfmt rendering (quoting, escaping, fields), level
names/ranks, and threshold filtering at Debug/Info/Error captured via the
in-memory sink. Run `make all-tests`.

## License

MIT. See [LICENSE](LICENSE).
