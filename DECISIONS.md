# Implementation decisions

1. **Where does status truth live?** `VisitsController` separates confirmed server
   records from local intentions. Pending/uncertain intentions determine the
   display; rejected ones remain retryable but show the confirmed value. Flushed,
   atomically replaced JSON stores both before sending. Revision checks prevent
   older acknowledgements erasing newer taps. Search and refresh retain unsynced work.

2. **What happens when `updateStatus` throws?** For the latest intention,
   `ApiException` normally restores the confirmed status and shows “Not saved · Retry”
   plus a snackbar. A timeout keeps the desired status with “Unconfirmed · Retry”:
   the server may have committed. Earlier uncertainty survives later rejection.
   The intention stays on disk; retry sends its absolute `open`/`done` target.
   Pending work resumes on launch/foreground; failed/uncertain work needs explicit
   retry. Storage failures block edits and sends, with a storage-retry banner.

3. **What did the API reveal beyond its signatures?** Pages overlap: deduplicate
   IDs in server order. Searches race: hide old rows immediately, debounce 300ms,
   and discard stale responses using request generations. Refresh invalidates
   outstanding pages; later-page failure retains rows and the retry cursor. Null
   titles become “Untitled visit”; archived/unknown statuses stay noninteractive.
   `updatedAt` protects acknowledged writes from older fetches. A write can succeed
   before throwing, which requires the uncertainty handling above.

4. **Why Hooks and Riverpod, and what became harder?** Hooks own local controllers;
   Riverpod owns query, pagination and synchronization. Injectable API/storage
   dependencies make races testable. One `Notifier` keeps ordering rules together;
   extracted widgets receive state and callbacks. The cost is manually coordinating
   initialization, request generations and separate errors: a loaded list and a
   failed status update must coexist.

5. **What did I test, and why?** Controlled futures cover stale requests, pagination,
   rapid taps, persistence before sending, ambiguous/rejected writes, restore races
   and disposal. These failures can silently lose intent despite a correct-looking
   UI. Widget tests cover recovery, search, scrolling, real 48dp hit regions and
   six goldens, including 320dp/200% text. Android/iOS integration verifies real
   disk restoration and retry through app-scope reconstruction, not process killing.

6. **What was left out, and what comes next?** No background sync, automatic retry
   loops or multi-device conflict resolution. Explicit retries avoid failure loops.
   Cached search can be incomplete; durability begins when the local write completes.
   The mock server resets on restart, as the brief explains. Another four hours:
   automate process-kill/relaunch with pending writes, then audit VoiceOver/TalkBack
   and large-text recovery flows.

7. **How was AI used, and what needed correcting?** Codex assisted with Figma
   inspection, implementation, refactoring, tests and documentation. One generated
   toggle put a 48dp control inside a 24dp parent: it looked right but missed edge
   taps. The fix uses a real 48dp layout box, preserves icon alignment and adds
   edge-tap tests. Visual similarity alone did not establish accessibility.

8. **Where did I fill design gaps, and why?** Added “Unconfirmed · Retry” to
   distinguish lost responses from rejection, saved-data/storage banners to explain
   recovery, and “No visits assigned yet” for an empty list. These reuse the supplied
   palette and typography. The 44dp search appearance has a minimum 48dp interaction
   area; large text stacks badges and timestamps use device-local time.
