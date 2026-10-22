# Decisions

1. **Status truth.** Last confirmed server task plus durable local intent.
   Pending/uncertain intents overlay the server; rejected intents remain retryable
   but display the confirmed value. Serialized, flushed atomic JSON snapshots
   store both. No request sends before its revision is durable. Newer taps replace
   the intention; older acknowledgements cannot erase it.

2. **updateStatus throws.** `ApiException`: revert the display, retain the intended
   status, show a retry badge and snackbar. Timeout: keep the desired value with
   “Unconfirmed · Retry”, since the server may have saved it. Retry sends absolute
   `open`/`done`, never another toggle. Older ambiguity survives a newer rejection.
   Pending work resumes on launch/foreground; failed/uncertain work needs explicit
   retry. Disk failure blocks sending/editing and shows a storage retry banner.

3. **Backend surprises.** Pages overlap: deduplicate IDs in encounter order.
   Searches race: clear old rows immediately, debounce 300ms, gate responses by
   generation. Refresh invalidates pending pages. Compare `updatedAt` to protect
   acknowledged writes from stale fetches. Null titles become italic “Untitled
   visit”; archived/unknown statuses stay noninteractive. Convert UTC timestamps
   to device-local time. The mock resets on restart: preserve pending intentions,
   assume a real server retains accepted writes, leave backend behavior unchanged.
   Save-then-timeout requires idempotent replay.

4. **State choice.** Hooks own text/focus/scroll/lifecycle/animation controllers;
   Riverpod owns query, pages, cache and outbox. Plain `Notifier` with immutable
   snapshots and injectable API/store avoids generators and supports deterministic
   interleaving tests. The cost is manually coordinating initialization,
   invalidation and separate page/refresh errors rather than one `AsyncValue`.

5. **Tests.** Controlled futures cover stale requests, pagination, rapid taps,
   durability-before-send, rejections, ambiguous writes across revisions, storage
   failure and restoration. These failures can silently corrupt intent. Widget
   tests cover search/error flows, actual 48dp hit regions and Figma snapshots,
   including 320dp/200% text. Native integration reconstructs the app scope from
   real disk storage, retries retained work and searches the real archived record.

6. **Scope/next four hours.** iOS first; Android added on request. No background
   sync, connectivity package, unbounded retries or generic repository framework. Manual retries avoid failure
   loops. Next: OS process-kill automation, broader VoiceOver review and a server
   revision/idempotency contract for multi-device conflicts. Cached search can be
   incomplete while offline and is labelled accordingly.

7. **AI use.** Codex assisted with implementation, Figma extraction, tests and
   documentation. An initial 48dp toggle overflowed a 24dp parent and missed edge
   taps; the fix uses a real 48dp layout box plus edge-tap tests. Generic
   rollback-on-exception was rejected because this API can throw after committing.

8. **Design gaps.** Bundle exact SVGs and IBM Plex Sans; centralize colors/type.
   Preserve the 44dp search appearance inside a 48dp hit area. Stack badges/wrap
   times at large text sizes. Add “Unconfirmed”, cached-data and storage banners,
   plus “No visits assigned yet”, for states without frames. Respect native safe
   areas and 48dp controls.
