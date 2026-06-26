(* Tests for sml-log. Uses the in-memory capturing sink so all assertions
   are over deterministic strings. *)

structure LogTests =
struct
  open Harness

  fun run () =
    let
      val () = section "format (logfmt)"
      val () = checkString "simple"
                 ("level=info msg=started",
                  Log.format { level = Log.Info, msg = "started", fields = [] })
      val () = checkString "quotes message with space"
                 ("level=warn msg=\"disk almost full\"",
                  Log.format { level = Log.Warn, msg = "disk almost full", fields = [] })
      val () = checkString "fields"
                 ("level=error msg=boom code=500 path=/x",
                  Log.format { level = Log.Error, msg = "boom",
                               fields = [("code", "500"), ("path", "/x")] })
      val () = checkString "escapes quotes in value"
                 ("level=info msg=hi note=\"a \\\"q\\\" b\"",
                  Log.format { level = Log.Info, msg = "hi",
                               fields = [("note", "a \"q\" b")] })

      val () = section "level names and ranks"
      val () = checkString "name debug" ("debug", Log.levelName Log.Debug)
      val () = checkString "name error" ("error", Log.levelName Log.Error)
      val () = checkBool "rank order"
                 (true, Log.levelRank Log.Debug < Log.levelRank Log.Info
                        andalso Log.levelRank Log.Info < Log.levelRank Log.Warn
                        andalso Log.levelRank Log.Warn < Log.levelRank Log.Error)

      val () = section "threshold filtering"
      val (logger, lines) = Log.capturing Log.Info
      val () = Log.debug logger "hidden" []
      val () = Log.info logger "shown" []
      val () = Log.warn logger "also shown" [("k", "v")]
      val () = checkStringList "below threshold suppressed, rest captured"
                 (["level=info msg=shown", "level=warn msg=\"also shown\" k=v"],
                  lines ())

      val () = section "error level passes at Error threshold"
      val (l2, lines2) = Log.capturing Log.Error
      val () = Log.warn l2 "nope" []
      val () = Log.error l2 "yes" []
      val () = checkStringList "only error captured"
                 (["level=error msg=yes"], lines2 ())

      val () = section "debug threshold captures everything"
      val (l3, lines3) = Log.capturing Log.Debug
      val () = Log.debug l3 "d" []
      val () = Log.info l3 "i" []
      val () = checkInt "two lines" (2, List.length (lines3 ()))
      val () = checkBool "minLevel" (true, Log.minLevel l3 = Log.Debug)

      val () = section "key escaping in format"
      val () = checkString "key with space quoted"
                 ("level=info msg=hi \"odd key\"=v",
                  Log.format { level = Log.Info, msg = "hi",
                               fields = [("odd key", "v")] })
      val () = checkString "key with equals quoted"
                 ("level=info msg=hi \"a=b\"=v",
                  Log.format { level = Log.Info, msg = "hi",
                               fields = [("a=b", "v")] })

      val () = section "parseLevel"
      val () = checkBool "info" (true, Log.parseLevel "info" = SOME Log.Info)
      val () = checkBool "case-insensitive" (true, Log.parseLevel "ERROR" = SOME Log.Error)
      val () = checkBool "unknown is NONE" (true, Log.parseLevel "trace" = NONE)
      val () = checkBool "roundtrips every level"
                 (true, List.all (fn lv => Log.parseLevel (Log.levelName lv) = SOME lv)
                                 [Log.Debug, Log.Info, Log.Warn, Log.Error])

      val () = section "setLevel / isEnabled"
      val (l4, _) = Log.capturing Log.Info
      val () = checkBool "info enabled" (true, Log.isEnabled l4 Log.Info)
      val () = checkBool "debug disabled" (false, Log.isEnabled l4 Log.Debug)
      val l5 = Log.setLevel l4 Log.Debug
      val () = checkBool "original unchanged" (true, Log.minLevel l4 = Log.Info)
      val () = checkBool "new logger lowered" (true, Log.minLevel l5 = Log.Debug)
      val () = checkBool "debug now enabled" (true, Log.isEnabled l5 Log.Debug)

      val () = section "withFields child logger"
      val (base, blines) = Log.capturing Log.Debug
      val child = Log.withFields base [("service", "api"), ("ver", "2")]
      val () = Log.info child "req" [("path", "/x")]
      val () = Log.info base "no fields" []
      val () = checkStringList "child prepends bound fields; base unaffected"
                 (["level=info msg=req service=api ver=2 path=/x",
                   "level=info msg=\"no fields\""],
                  blines ())
      val grandchild = Log.withFields child [("trace", "abc")]
      val () = Log.info grandchild "deep" []
      val () = checkBool "grandchild accumulates"
                 (true, List.last (blines ())
                        = "level=info msg=deep service=api ver=2 trace=abc")

      val () = section "formatJson"
      val () = checkString "json basic"
                 ("{\"level\":\"info\",\"msg\":\"started\",\"fields\":{}}",
                  Log.formatJson { level = Log.Info, msg = "started", fields = [] })
      val () = checkString "json fields and escaping"
                 ("{\"level\":\"error\",\"msg\":\"a \\\"q\\\"\",\"fields\":{\"k\":\"v\",\"n\":\"1\"}}",
                  Log.formatJson { level = Log.Error, msg = "a \"q\"",
                                   fields = [("k", "v"), ("n", "1")] })

      val () = section "makeWith custom renderer"
      val jbuf = ref ([] : string list)
      val jlog = Log.makeWith Log.formatJson Log.Info (fn s => jbuf := s :: !jbuf)
      val () = Log.info jlog "hi" [("a", "b")]
      val () = checkString "renders via formatJson"
                 ("{\"level\":\"info\",\"msg\":\"hi\",\"fields\":{\"a\":\"b\"}}",
                  hd (!jbuf))

      val () = section "tee and filterSink"
      val b1 = ref ([] : string list)
      val b2 = ref ([] : string list)
      val teed = Log.tee [fn s => b1 := s :: !b1, fn s => b2 := s :: !b2]
      val () = teed "x"
      val () = checkBool "both sinks got it" (true, !b1 = ["x"] andalso !b2 = ["x"])
      val fb = ref ([] : string list)
      val fsink = Log.filterSink (fn s => String.isSubstring "keep" s)
                                 (fn s => fb := s :: !fb)
      val () = fsink "drop me"
      val () = fsink "keep me"
      val () = checkStringList "only matching forwarded" (["keep me"], !fb)
    in
      ()
    end
end
