# Classroom360 phone app (Flutter)

For deans and administrators. It does two jobs and nothing else, and tells you when something needs one of them:

1. **Watch the classrooms.** Every room with its class, its key and its camera, rooms that need attention first, and a live camera picture.
2. **Accept or reject room requests** from instructors.
3. **Notifications** (the bell at the top): a message for each new room request and for each urgent alert (a key not returned, a locker station that stopped reporting, repeated denied taps), as the web app has them.

It uses the **same Supabase project** as the web app. The database files it relies on (the SQL migrations and the optional demo data) are in the `supabase/` folder of the web repository, not in this one. Nothing is filtered on the phone: the database's row-level security decides what each person gets, so an instructor who signs in here sees nothing and is told to use the web app. It does not schedule (that stays on the web).

| Page | What it shows |
|---|---|
| Rooms | A dark **ledger plate** with the day's three figures on flap digits (rooms in use, keys out, keys not returned) and a line saying how many rooms need a look. Under it **the key locker drawn as a steel cabinet**: a door for each room's key, with its lamp (dim: the key is inside; brass: it is out, with who took it and when; red and blinking: the class ended and it is not back). Press a door to open that room. Then the rooms, each styled as a locker door, with chips to show All, Needs a look, or Key out. Each room: the verdict (Teacher present, Teacher not here, Key with someone else, and so on), the class now, who holds the key and since when, what the camera counted and how long ago. Press a room for the reason in words, **the room's schedule for the week**, and a "Watch the camera" button. The schedule has a tab for each day of the week (with a bar for how full the day is and a blinking lamp on today while a class is on); under it, that day's classes and room requests in time order: the class that is on **now is highlighted** (a brass card, "Happening now", a bar for how far along it is and how long is left), the next one says how long until it starts, and the ones that are over are greyed. Weekly classes come from the published timetable, and a one-off room request appears on its date once it is **approved** (a request still waiting is shown too, marked "Waiting for a decision"; a rejected or cancelled one is not). It follows the school's clock, and it changes by itself when a request is decided. The number on the tab counts the rooms that need a look. |
| Requests | Each request is a **slip**: the room as a key tag, the day, the hours in large type, the instructor and the reason, with a perforated tear-off at the bottom holding Reject and Approve. Approve asks first; Reject needs a reason, which the instructor sees. Decided requests carry an ink stamp (Approved, Rejected) and the decision note. New requests arrive by themselves (Realtime), with a timer as a back-up; the number on the tab counts the ones waiting. |
| Notifications (bell) | The person's messages, newest first, as notes with a stripe in the colour of how urgent they are (red urgent, amber look soon) and a lamp that is lit while unread (it blinks if urgent). The number on the bell counts the unread ones. Tap a message to mark it read and go to the page it is about (a request opens Requests, a key or station alert opens Rooms; a timetable message says "Open this in the web app"). **Mark all read** clears them; pull down to check again. While the app is open, a message that arrives shows a banner at the bottom with a **View** button (Realtime, with a one-minute timer as a back-up, and every minute the app also asks the database to turn the alerts into messages). The bell is hidden until database update 12 has been run. |
| Cameras | The active cameras, each a monitor in a steel frame with the room's key tag on it. Press one to watch it live; the picture sits in a bezel with a lamp that says Live, Connecting or Offline, and below it is what the key locker and the camera say about that room. |

The verdict wording is the same text as the web app (`web/src/lib/presence/labels.ts`); the verdict itself comes from the database (`room_status_now.presence`) and is never recomputed here.

## The Locker look

The phone uses the same colours and the same motif as the web app: the room code as a key tag with a punched hole, lamps that glow, screws on a steel plate, a rack of hooks.

- **Colours** are the web app's own (`web/src/index.css`): ink navy for steel, brass for the key tag and the highlights, and green, amber and rose for status. They are in `lib/ui/theme.dart` (`Palette`).
- **Letters** are IBM Plex, the same three families as the web app: Sans for text, Sans Condensed for titles and door numbers, Mono for room codes and times. The font files are in `assets/fonts` and are listed in `pubspec.yaml`, so the phone never needs the network to draw them (SIL Open Font License, copy in `assets/fonts/OFL-IBM-Plex.txt`).
- **Motion** is used for things that changed (flap digits turn over, a lamp blinks when a key is not back, a tag swings once on the sign-in page) and every animation stops when the phone is set to reduce motion.
- **Reading aloud**: every card, door and button has a spoken label; the lamps are drawn only, with the same information in words.

## Set up

You need the Flutter SDK (3.35 or newer, because the current `supabase_flutter` asks for that) and, for a phone build, Android Studio or Xcode. Node 18 or newer is used by one small helper script.

Run these in the `mobile` folder, in this order:

```
flutter create . --platforms=android,ios --project-name classroom360_mobile
node tool/setup_platforms.mjs
flutter pub get
dart run flutter_launcher_icons
```

- `flutter create .` only adds the `android/` and `ios/` folders (and a few project files). It is why a plain `flutter run` says "AndroidManifest.xml could not be found" before this step. Check afterwards that `pubspec.yaml` and `lib/` are as they were (they are the ones in this folder).
- `node tool/setup_platforms.mjs` makes the platform settings for you, and is safe to run again:
  - **Android:** adds the permissions `INTERNET`, `ACCESS_NETWORK_STATE`, `CHANGE_NETWORK_STATE`, `MODIFY_AUDIO_SETTINGS` and sets `minSdk` to `23`, which `flutter_webrtc` needs. For a release build also add the plugin's ProGuard rules (see the `flutter_webrtc` README).
  - **iOS:** adds `NSLocalNetworkUsageDescription` (the cameras are on the school's network) and the camera and microphone texts `flutter_webrtc` asks for. If the build complains about the Podfile, add the `ONLY_ACTIVE_ARCH` line that README shows.
  - Removes the sample `test/widget_test.dart` that `flutter create` adds, because it does not match this app.
- `dart run flutter_launcher_icons` makes the home-screen icon (the Classroom360 mark: brass ring on navy) from `assets/icon`.

Give the app the project's address and **publishable** key, the same two values as `VITE_SUPABASE_URL` and `VITE_SUPABASE_ANON_KEY` in `web/.env.local`. The easiest way is a file: copy `dart_defines.example.json` to `dart_defines.json` and fill it in (it is ignored by git), then:

```
flutter run --dart-define-from-file=dart_defines.json
```

In Android Studio: Run, Edit Configurations, and put `--dart-define-from-file=dart_defines.json` in "Additional run args". Without the two values the app opens on a notice that says they are missing.

The same two values can be given one by one:

```
flutter run --dart-define=SUPABASE_URL=https://YOUR-PROJECT.supabase.co --dart-define=SUPABASE_ANON_KEY=sb_publishable_xxxxx
```

The app refuses to start with a secret key (`sb_secret_...` or a `service_role` token) and says why. A phone app must never hold one.

Sign in with the same account as on the web (email and password). The account's role must be **Dean** or **Administrator**.

On the Android emulator the cameras are only reachable if the computer running it can reach the Raspberry Pi's address; rooms, requests and notifications work wherever there is internet.

## The camera picture

The picture comes straight from the parent Raspberry Pi (`pi/camera-gateway`) over the school network, as WebRTC (WHEP). The app shows the signed-in person's token to the gateway; the gateway asks Supabase whether that person may watch before it sends anything. So:

- **The phone must be on the school's Wi-Fi to see video.** Rooms and requests work from anywhere with internet; the picture does not, because the gateway address (for example `http://192.168.1.50:8889`) is on the school network. No STUN or TURN server is used, so the app contacts no outside server for video.
- If the picture drops the app tries again by itself (after 2, 4, 8, 16 and then every 30 seconds), and gives up only when the gateway refuses the sign-in. "Try again now" restarts the waiting.
- The messages say what is wrong: the gateway did not accept the sign-in, the camera is not sending, the gateway has no stream with that name (the name on the Cameras page of the web app does not match `mediamtx.yml`), the gateway cannot be reached.

## How the code is laid out

```
lib/
  core/         Plain Dart, no Flutter: the rows (models), the wording (presence, format, errors, inbox),
                the data store that loads and refreshes, the camera request (whep), keeping a picture connected (feed),
                locker_view.dart: the counting and ordering behind the ledger plate, the cabinet and the filter chips, and
                room_week.dart: the school's clock and a room's week (classes plus requests, what is on now, what is next)
  data/         supabase_backend.dart (the real calls: same selects and RPC as the web app) and
                webrtc_feed.dart (the phone's WebRTC engine)
  ui/           The screens and what they are made of:
                  theme.dart       colours, fonts, the app theme, the page transition
                  art.dart         the drawings: logo, drafting grid, hooks, key rack, hanging tags, empty-state tag, slip, viewfinder
                  widgets.dart     lamps, screws, key-tag chip, badges, section headings, banners, loading placeholders
                  ledger.dart      the dark ledger plate with flap digits
                  cabinet.dart     the key locker as a cabinet of doors
                  room_schedule.dart  a room's week in the room sheet: day tabs, the day's classes and requests, what is on now
                  page_header.dart the header of pages opened over the tabs
                  home_shell.dart  header with the clock, the three tabs, the bar at the bottom
                  sign_in_page, rooms_page, requests_page, cameras_page, camera_view_page, inbox_page
  app.dart      Sign-in gate: sign-in page, or "this app is for deans and administrators", or the app
  env.dart      The two --dart-define settings and the check that no secret key is used
test/           107 tests of core/ and the settings check (run them with: flutter test)
tool/setup_platforms.mjs       Makes the Android and iOS settings after flutter create (see Set up)
tool/make_parity_fixture.mjs   Regenerates test/fixtures/web_parity.json from the web app's own helpers
                               (node --experimental-strip-types tool/make_parity_fixture.mjs, Node 22 or newer)
```

`test/web_parity_test.dart` checks that this app words things exactly as the web app does (verdict labels, which rooms need attention, times, dates, errors, the camera address). If someone changes the wording on the web, regenerate the fixture and the test shows what to change here.

## What was and was not checked

Checked (the Flutter SDK itself could not be installed where this was written, so these used the real source code of Flutter 3.47, `supabase_flutter` 2.18 and `flutter_webrtc` 1.6 fetched from GitHub):

- **All of `lib/ui`, `lib/core` and `lib/app.dart`, the whole Locker look, type-checks with no errors** (`flutter_lints` rules, run through the Dart analyzer against those real sources). The only two notes are old "dangling library comment" hints in `format.dart` and `models.dart`.
- **107 unit tests of `core/` pass** (88 from before and 19 for a room's week: the school's clock in Manila time whatever zone the phone is in, which classes fall on which day and inside their term, how requests join in and which are left out, what is on now and what is next, the rows from the database, and the store's two calls; the 88 were 76 from before and 12 for `locker_view.dart`: the figures on the ledger plate, the filter chips, the door states and order, the initials in the round badge, the key-tag swing), including the inbox (what is announced once and only once, marking read at once on screen and putting the database's truth back when it refuses, the sweep, and the whole feature switching itself off quietly when the database does not have update 12), run with a small stand-in for `flutter_test` (the real one needs the Flutter SDK).
- **The two selects behind a room's week against a real database** (PostgREST 12, PostgreSQL 16, migrations 1 to 10, as a dean; 8 checks): only the published meetings of that room come back with their course, section, instructor and the term's dates, and only approved and waiting requests inside the week.
- **The data logic against a real database:** the same selects and RPC against PostgREST 12 and PostgreSQL 16 with all ten migrations, as a dean (22 checks): the rows parse, requests list with instructor and room, approving and rejecting (a reason is required and trimmed), a request someone else already decided gives a plain sentence, an instructor cannot decide and sees no cameras, an expired sign-in and a dropped server give readable messages and keep the last good data on screen.
- **The camera request against the real gateway:** the app's own Dart code posted a real offer (made by Chrome) to the real MediaMTX behind the real `camera_auth.py`, got the answer, Chrome played it and showed a 640 pixel wide picture; a wrong token is reported as "not accepted", a stream the Pi has no setting for and a camera that is not sending are explained, ending the viewing really ends the session, and the token appears in no log (13 checks, including the same for the web app's client).

**Not checked, so expect to meet these:**

- The app has never been built or run on a phone or an emulator: **the Locker look has been written and type-checked but not once seen on a screen.** Spacing, how the cabinet and the slips sit on a small phone, the animations and the exact feel are untried, so expect to adjust some sizes the first time you run it (start with `flutter pub get`, then `flutter analyze`, `flutter test` and `flutter run`). No widget tests exist; the layout was checked by reading it against Flutter's own layout rules, which found and fixed a few problems, but that is not the same as looking.
- A platform setup step above may need adjusting for your Flutter version.
- `flutter_webrtc` has not played video on a real phone. The picture exchange with the gateway is checked (above); the phone's WebRTC engine, and a phone's Wi-Fi reaching the Pi, are not.
- `supabase_flutter` itself (sign-in, token refresh, the Realtime feeds of requests and of messages) has not run against a live Supabase project. The queries it sends were checked against PostgREST, not through the library.
- **No push to a closed app.** Messages show while the app is open (a banner and the number on the bell) and are there, unread, the next time it is opened or brought back. Waking a phone whose app is closed needs Firebase Cloud Messaging and a server that sends it, and on an iPhone Apple's push service, which a free Apple developer account cannot use. That is not built.
- The phone does not count people in the picture. The count the database holds comes from a web page that is watching the camera (the web app's Cameras page); the phone shows the verdict.
- Times of classes and requests are shown as the school has them (the school's time zone). "Now" on a room's schedule is the school's clock for zones that have no daylight saving (Asia/Manila and the other common ones in `lib/core/room_week.dart`); for any other zone it falls back to the phone's own clock. "x minutes ago" and "key out since" use the phone's clock and time zone.
- A room's schedule shows the current week only, and the day tabs and the highlight have not been seen on a screen, like the rest of the Locker look.
