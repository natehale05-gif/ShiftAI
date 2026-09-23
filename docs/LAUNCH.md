# Launch: where the 25th actually lands

Written 18 September 2026. Target: public on the App Store and Google
Play by the 25th.

## The short version

**The App Store is reachable. Google Play, on a personal developer
account, is not** — and no amount of work on our side changes that,
because the constraint is Google's calendar, not ours.

If the Play account is a **personal** account created on or after
13 November 2023, Google requires 12 testers opted in and actively using
a closed-testing build for **14 continuous days** before the "apply for
production access" button appears at all. The questionnaire that follows
is reviewed by a human, which takes a further 3–7 business days, and
Google checks that the testers genuinely used the app rather than merely
opting in. Starting the clock today puts production access around
**16 October at the earliest**.

If the account is an **organization** account registered with a D-U-N-S
number, none of that applies and Play can ship the same week as iOS.

**Check which one it is before anything else.** Play Console →
Settings → Developer account → Account details. The account type is
named there. This single fact decides whether there is one launch date
or two.

## What still has to be true before either store

Ordered by who is blocked on whom.

### 1. The server exists

The client half is **done**. Sign-in, refresh, sign-out and account
deletion are built against the contract in `docs/API.md`; tokens live in
the iOS Keychain and the Android Keystore, a 401 refreshes once and then
signs you out, and every screen the engine owns has been driven against
a mock implementation of that contract end to end.

So the only thing left here is the server itself. Hand `docs/API.md` to
whoever is building it — it is specific enough to work from without a
conversation, and the client will talk to it the moment the base URL is
set, with no further client release.

One route in it is store-blocking rather than nice to have:
**`DELETE /v1/me`**. Apple rejects any app that creates accounts but
cannot delete them from inside the app (Guideline 5.1.1(v)). The button
and the confirmation are built; they need something to call.

### 2. The app has been compiled for a phone — even once

Neither the iOS nor the Android binary has ever been built. Not "built
and found wanting" — never compiled at all. This environment has no
Xcode and no Android SDK, so the first native build has to happen on
your machine, and first builds surface things nothing else does:
missing entitlements, a plugin that needs a higher minimum iOS version,
a Gradle version disagreement.

Budget a day for this and do it **first**, not on the 24th.

```
flutter build appbundle --release      # needs the signing key in place
flutter build ipa --release            # needs a Mac and Xcode
```

### 3. Bundle identifiers, decided once and never changed

They cannot be changed after the first upload. Pick both now:

- iOS: `club.shiftai.app` (or whatever matches the domain you own)
- Android: the same string, as `applicationId`

Set them in Xcode (Runner → General → Bundle Identifier) and in
`android/app/build.gradle.kts`.

### 4. The signing key, backed up somewhere that is not one laptop

`android/key.properties` and the `.jks` are gitignored, correctly —
which means if that machine dies, the ability to update the app dies
with it. Put the keystore in a password manager today.

### 5. A privacy policy at a public URL

Both stores require one, entered in the listing before submission. It
has to actually describe what the server stores. It cannot be a
placeholder page.

## What is ready

- **Auth, client side.** Keychain/Keystore token storage, sign-in with
  the engine's own error messages shown verbatim, one refresh on 401
  then sign-out, and account deletion behind a type-DELETE confirmation.
- **Every empty state.** A new account opens on an empty vault, an
  unearned shelf, and a board that says the week has not scored yet —
  all verified against a mock server that implements the contract.
- **Bundle identifiers.** `club.shiftai.app` on both platforms. These
  can never be changed after the first upload, so change it now if you
  want something else.

- **Icons.** Generated from the real wordmark, every iOS size, Android
  adaptive (foreground, background, monochrome) plus legacy launcher,
  the 1024 App Store icon and the 512 Play icon. `python3
  tool/make_icons.py` rebuilds them all.
- **Play feature graphic.** `store/feature-graphic.png`, 1024×500.
- **Screenshots.** `store/screenshots/`, six screens at 1320×2868
  (Apple's required 6.9"), 1242×2688 (6.5") and 1080×1920 (Play).
- **iOS privacy manifest.** `ios/Runner/PrivacyInfo.xcprivacy`, declaring
  the email address and user content the server will hold, and the
  UserDefaults access `shared_preferences` makes (reason CA92.1). **It
  is not yet in the Xcode project** — open Runner in Xcode, drag the
  file into the Runner group, and confirm it lands in Target
  Membership → Runner. A manifest that is not in Copy Bundle Resources
  is a manifest Apple never sees.
- **Store text.** Below.

## The seeded-data leak, and why it mattered

Worth recording, because it was the most serious thing in the build.

`AppState.load()` used to fall back to the seeded catalogue whenever the
engine could not be reached. With no backend that is correct — it is the
demo. With a backend configured and somebody signed in, it meant a
server hiccup showed **one person another person's vault, trophy shelf
and weekly earnings, labelled as their own.**

The same bug had a second head: the trophy decoder started from the
seeded trophy and overwrote it with whatever the server sent, so an
account the server said nothing about inherited the seed's earned dates
and progress. A brand new account opened on a shelf reading 55 points,
four trophies earned.

Both are fixed, and there are tests that fail if either comes back:

- With a base URL set, a failed load yields empty screens and an error.
  The seeded catalogue is unreachable in that mode.
- Every trophy is blanked before the server's progress is applied.
- The local cache carries the account's email and is not read back for a
  different account. Signing out empties it.
- An empty leaderboard no longer crashes — `you` used to resolve to
  `standings.last`, which threw on an empty board and pointed at a
  stranger's row when it did not.

## Screenshots

`store/screenshots/`, five screens at each of the three required sizes.
The leaderboard shot has been dropped: it showed `$767.09` earned and a
board of dollar figures, all of it seeded fiction, which is not a thing
to put in a store listing for an app about creators getting paid.

## Store listing text

**Name (30 char limit):** ShiftAi

**Subtitle / short description (30 / 80):**
- iOS: `Make it. Keep it. Get paid.`
- Play: `A creator suite: make in chat, keep it in your vault, see where you rank.`

**Description:**

> ShiftAi is a creator suite that lives in one place. Ask for a clip, a
> still, a track or a read, and it is made in the same chat you asked in.
> Everything you make lands in your vault, where you can rename it,
> re-run the prompt behind it, or publish it out.
>
> Agents take the work you would rather not do by hand — running against
> a repository, or a folder of files — and report back when they need
> you. Notes keep the thinking. Design keeps the pages, decks and brand
> work.
>
> The weekly board shows where you sit against everyone else, and the
> trophy shelf keeps what you have earned.
>
> Every mode is included with membership. There is no separate plan to
> buy.

**Keywords (iOS, 100 char):**
`creator,ai,video,image,vault,agents,notes,design,leaderboard,suite,prompt,studio`

**Category:** Photo & Video, secondary Productivity (iOS) / Art & Design
(Play)

**Content rating:** answer honestly that the app has user-generated
content and a social leaderboard; both stores ask, and a wrong answer is
found later rather than never.

## Dates, if the Play account is personal

| Date | What happens |
|---|---|
| **Thu 18 Sep** | Confirm account type. Hand `docs/API.md` to the server developer. First native build attempt on your machine. |
| **Fri 19 Sep** | Bundle IDs set, keystore made and backed up. Privacy policy published. Both store listings created as drafts. |
| **Sat 20 Sep** | Server's auth routes live on a staging URL. The client needs no work — set the base URL and it connects. |
| **Mon 22 Sep** | Upload the Play closed-testing build. **The 14-day clock starts when the 12th tester opts in, not when you upload** — so recruit the testers first and have them all accept the same day. |
| **Tue 23 Sep** | TestFlight build up. Real devices, real people. |
| **Wed 24 Sep** | Submit to App Review. 90% of submissions clear in under 48 hours; the average is about a day and a half. |
| **Thu 25 Sep** | **iOS live, realistically.** Play is in closed testing, not launched. |
| **~Mon 6 Oct** | 14-day tester window closes; apply for production access. |
| **~10–16 Oct** | Google's review of that application. **Play live.** |

If the account is an organization account, delete the last two rows and
Play ships on the 24th alongside iOS.

## What I would cut to make the date

If the server slips, the honest options are to launch iOS only and let
Play follow on its own clock anyway, or to move the date. What is not an
option is shipping the seeded build: it opens on another person's vault,
another person's earnings and a leaderboard of invented names, and
Apple rejects that under Guideline 2.1 as a demo more often than not.
