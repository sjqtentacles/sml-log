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
    in
      ()
    end
end
