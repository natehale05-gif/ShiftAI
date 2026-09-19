# Getting SHIFT AI into the two stores

What the project already does, and what is left. The second list is the
real one — most of it needs decisions or credentials that are not in the
codebase.

## Before the first native build

Run `bash tool/preflight.sh`. It checks what can be checked without Xcode
or the Android SDK: analyzer, tests, icons (including that the 1024 has
no alpha channel, which the App Store rejects outright), the privacy
manifest's membership in the Xcode project, both bundle ids, the INTERNET
permission, and the R8 keep rules. A minute, and cheaper than finding any
of it halfway through an archive.

What it cannot check is the build. Neither toolchain exists in the
environment this was written in, so **neither binary has ever been
compiled**. Expect the first build of each to surface something.

### The Android keystore

Make it once, and back it up somewhere that is not this laptop — losing
it means never being able to update the app again.

```bash
keytool -genkey -v -keystore ~/shift-upload.jks \
  -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

Then `android/key.properties` — gitignored, never committed:

```properties
storePassword=…
keyPassword=…
keyAlias=upload
storeFile=/Users/you/shift-upload.jks
```

Without that file a release build falls back to the debug key. It runs on
a device; Play refuses it.

### Then

```bash
flutter clean && flutter pub get
cd ios && pod install && cd ..      # first run only
flutter build appbundle --release
flutter build ipa --release
```

Open `ios/Runner.xcworkspace` — not the `.xcodeproj` — once CocoaPods has
run, and set the signing team on the Runner target.

## Done in the project

- **Identity.** `SHIFT AI` on both platforms. Bundle ids as they were:
  `club.shiftai.shift_ai` (Android), `club.shiftai.shiftAi` (iOS). See the
  warning about these below.
- **Version.** Reset to `1.0.0+1` in `pubspec.yaml`. It was `1.4.0+14`,
  which was prototype counting — a first submission should start at 1.
- **Network.** `INTERNET` added to the Android manifest. Flutter only puts
  it in the debug and profile manifests, so a release build had no network
  at all. This alone would have made a wired build fail on device while
  working in every test.
- **Permissions.** iOS usage strings for photos, camera and microphone.
  The avatar picker crashes the app without the photo one, and Apple
  rejects binaries that ask without explaining.
- **Signing.** `android/app/build.gradle.kts` reads `android/key.properties`
  and falls back to the debug key only when that file is absent. Release
  builds also shrink and minify now, with the Flutter engine kept.
  `android/key.properties.example` is the template; the real file and any
  `.jks` are gitignored.
- **Icons.** Generated for every Android density and every iOS slot, plus
  `store/` copies at 1024 and 512. The App Store icon has no alpha channel,
  which is a rejection if it does. **These are placeholders** — see below.
- **Pickers.** Attaching a file and choosing an avatar photo now work on
  iOS, Android and desktop, not only on the web. Before this they silently
  did nothing off the web, which would have shipped as two dead buttons.

## Blockers you have to clear

### 1. The app icon is a placeholder

`tool/make_icons.py` draws an S and the accent bar from the lockup. It is
legible and on-brand, but it is not a logo anyone designed. Put the real
1024×1024 artwork somewhere and re-run:

    python3 tool/make_icons.py path/to/icon-1024.png

### 2. Bundle ids differ between platforms

Android is `club.shiftai.shift_ai`, iOS is `club.shiftai.shiftAi`. Both are
valid and they are allowed to differ, but if either is already registered
in App Store Connect or Play, **changing it is not possible after the first
upload** — a new id is a new app, with no reviews and no installs. Decide
now, before the first submission, whether you want them unified. I did not
change them for exactly this reason.

### 3. There is no sign-in

`signedIn` is a boolean with nothing behind it. Before a store build:

- a real sign-in, and somewhere to keep the token that is not shared
  preferences (Keychain on iOS, Keystore on Android);
- **account deletion inside the app.** Apple has required this since 2022
  for any app with account creation, and it is a common rejection. A link
  to a web page is not enough on iOS — the path has to start in the app.

### 4. Privacy declarations

Both stores ask what you collect before they will take the build.

- **Apple:** the privacy nutrition label, plus a privacy policy URL that
  resolves. As the app stands it collects an email, a name, and a photo
  you choose. If the engine logs prompts, that is "User Content" and has to
  be declared.
- **Apple, additionally:** a privacy manifest (`PrivacyInfo.xcprivacy`) is
  now required, and `shared_preferences` uses `NSUserDefaults`, which is a
  declared-reason API. Its reason code is `CA92.1`.
- **Google:** the Data safety form, and a privacy policy URL in the
  listing. Play also wants a Deletion Request URL when accounts exist.

### 5. Private chat is a promise the server has to keep

The composer tells people "Private chat — nothing here is saved". The
client honours that — there is a test that fails if a private message
reaches storage — and it passes `private: true` to the engine. **If the
server logs those prompts anyway, the app is lying to its users**, which is
both a store problem and a real one. Decide what the engine does with that
flag before launch.

### 6. Things that only exist as seed data

Anything not listed in `docs/API.md` as wired is a fixture. Shipping the
app against a live engine but leaving these as fixtures means the screens
disagree with reality:

- Agent runs and jobs are read-only; nothing can be started or stopped.
- The Design editors render an honest blank artboard; no generation runs.
- Re-run, Share and "open in a new window" say what they need rather than
  doing it.
- The trophy catalogue is client-side by design, but nothing awards one.

### 7. Store listing material

Neither store takes a build without it: screenshots at the required sizes
(iPhone 6.7" and 6.5", plus iPad if you claim iPad support; Play wants
phone plus a feature graphic at 1024×500), a description, keywords, a
support URL, and an age rating questionnaire.

Note the app is currently configured for **portrait and landscape on iPad**
as Flutter ships it. If you do not intend to support iPad, say so in App
Store Connect, because if you claim it Apple will test it.

## Before each submission

    flutter analyze                 # must be clean
    flutter test                    # 47 tests
    flutter build appbundle --release
    flutter build ipa --release

The `.aab` goes to Play (not an `.apk` — Play has not taken those for new
apps since 2021). The `.ipa` goes up through Transporter or Xcode.

## What I could not verify here

This session has no Android SDK and no Xcode, so **neither mobile build has
ever been compiled**. The Dart analyzes clean and the tests pass, and the
web build runs, but the first `flutter build appbundle` and
`flutter build ipa` may still surface Gradle, CocoaPods or plugin problems
— `file_picker` in particular pulls in platform code that has never been
built here. Run both on a machine with the toolchains before you count on
the timeline.
