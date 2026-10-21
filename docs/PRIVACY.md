# Privacy: what the app collects, a draft policy, and the store forms

**Status: draft.** Everything in section 1 is taken from the code as it
stands (21 Oct 2026). The policy in section 2 is a starting point to be
read by whoever signs off on legal text, not legal advice. Anything in
[brackets] is a fact only the team or the server can supply. Section 5
lists the decisions that have to be made before it is published.

Both stores need the policy at a public URL before they take a build
(App Store Connect → App Privacy; Play Console → Store listing and Data
safety). Google also wants a URL where someone can ask for their account
to be deleted without opening the app.

## 1. What the app collects (from the code)

| What | When | Why | Where it goes |
|---|---|---|---|
| Email and password | Signing in | The account | The server. The password is never kept on the device; the session tokens are in the Keychain (iOS) or Keystore (Android), never in plain storage. |
| Name and username (handle) | The account | Profile, leaderboards, EcoVault | The server; shown to other people on the boards and on anything published. |
| Rough location | Only when the local leaderboard is opened or updated, after the system asks | Placing you in a local league | Rounded to 2 decimal places (about 1 km) on the device, then `PATCH /v1/me/location`. Never in the background, never continuously. |
| Photos for an avatar | When you create one, after a consent step | Training a likeness to generate as | `POST /v1/uploads`, then the avatar provider [HeyGen, if that stays the plan]. |
| Messages, and files attached with "+" | When you send them | The AI answering | The server, which passes them to the AI model that answers. |
| Saved chats | As they happen | Recents | The device (in a cache tied to your account) and the server (`/v1/threads`). |
| Private chats | Never kept | | Not written to the device. Sent to the server marked `private: true`; the server has to honour that (section 5). |
| What the AI makes (pictures, videos, songs, pages) | When made | Your vault | The server. Published pieces are visible to everyone in EcoVault. |
| Notes, hearts, designs | When you make them | The features themselves | The server. |
| On the device only | Always | Theme, last screen, a cached copy of your own data, the home screen widgets' numbers | Cleared on sign-out. The cache is refused for any other account. |

Not in the app: advertising, tracking, analytics or crash-reporting SDKs,
selling data, or sharing it with data brokers. The iOS manifest says
`NSPrivacyTracking` false, and that has to stay true.

The camera and photo library are only opened when you pick a photo, and
location is "when in use" only.

## 2. Draft privacy policy

> **ShiftAi Privacy Policy**
>
> Effective [date]. ShiftAi is run by [legal name of the company]
> ("we"). This policy explains what we collect when you use the ShiftAi
> app and website, why, and what you can do about it. Questions:
> [privacy contact email].
>
> **What we collect**
>
> - *Account details:* your email address, name and username. Your
>   username and name are shown on leaderboards and with anything you
>   publish.
> - *What you create:* the messages you send, files you attach, chats,
>   notes, designs, and everything the AI makes for you, which is kept in
>   your vault. Anything you publish to EcoVault can be seen by everyone
>   using ShiftAi.
> - *Avatar photos:* if you create an avatar, the photos you choose are
>   used to make a digital likeness of you that ShiftAi can generate
>   with. We ask for your consent first. Only make an avatar of yourself,
>   or of someone who has agreed to it.
> - *Approximate location:* only if you open the local leaderboard and
>   allow it. We use a rough position (about 1 km) to place you in a
>   regional league. We do not track your location in the background.
>
> **How we use it**
>
> To run the app: signing you in, answering your requests, keeping your
> work, and showing the leaderboards. [We do / do not] use your content
> to train AI models. We do not sell your data, show you advertising, or
> track you across other apps and websites.
>
> **Who we share it with**
>
> ShiftAi works by passing your requests to AI providers that make what
> you ask for: [list, e.g. Anthropic for chat, the image, video and music
> providers, HeyGen for avatars]. They receive what is needed to answer
> that request and [process it on our behalf under their terms / do not
> use it to train their models — confirm per provider]. We also use
> [hosting provider] to run our servers. We share data with authorities
> only when the law requires it.
>
> **Private chats**
>
> A private chat is not saved on your device and is sent marked private.
> [We do not store private chats on our servers / we keep them only for
> as long as it takes to answer.]
>
> **How long we keep it**
>
> Your account and work are kept until you delete them or your account.
> [Logs are kept for N days.]
>
> **Your choices**
>
> You can delete pieces from your vault, and delete your account in the
> app under Settings → Delete account, or by writing to [privacy contact
> email]. Deleting your account deletes your work, avatars and saved
> chats [within N days]. Depending on where you live you may also have
> the right to see, correct or export your data; ask us at the address
> above.
>
> **Children**
>
> ShiftAi is not for children under [13 / 16 in the EU and UK]. We do
> not knowingly collect data from them.
>
> **Changes**
>
> If we change this policy we will update the date above and, for
> significant changes, tell you in the app.

## 3. App Store Connect → App Privacy

"Do you or your third-party partners collect data from this app?" **Yes.**
For every type below: **Linked to the user: yes. Used for tracking: no.
Purpose: App Functionality.** These are the same types as
`ios/Runner/PrivacyInfo.xcprivacy`; `test/privacy_manifest_test.dart`
fails if the manifest drops one the app still collects.

| Apple category | Type | Why it applies |
|---|---|---|
| Contact Info | Name | The account name |
| Contact Info | Email Address | Signing in |
| Identifiers | User ID | The username |
| Location | Coarse Location | The local league (rounded to about 1 km) |
| User Content | Photos or Videos | Avatar photos, attached pictures, made pictures and videos |
| User Content | Other User Content | Messages, chats, notes, made songs and pages |

Not collected: Health, Financial, Contacts, Browsing or Search History,
Purchases, Usage Data, Diagnostics, Sensitive Info. **If the server adds
logging or analytics of how the app is used, or uses content for anything
beyond answering (training, for instance), the label and the manifest
both have to change in the same submission.**

The avatar feature uses people's faces. Say plainly in the App Review
notes that photos are used only to generate that person's likeness, with
consent, and are deleted with the avatar or the account.

## 4. Play Console → Data safety

- Does the app collect or share any of the required user data types?
  **Yes.**
- Is all collected data encrypted in transit? **Yes**, provided the
  server is HTTPS only [confirm].
- Can people request that their data is deleted? **Yes**: in the app,
  and at [deletion URL].

Collected, **not shared**. Google does not count transfers to service
providers that process data on your behalf (the AI providers, the host)
as sharing, as long as their terms say so; confirm that per provider.
All are processed ephemerally: **no**. The purpose for every type is
**App functionality**, plus **Account management** for the email.

| Play category | Type | Required or optional |
|---|---|---|
| Location | Approximate location | Optional (only the local league) |
| Personal info | Name | Required |
| Personal info | Email address | Required |
| Personal info | User IDs | Required |
| Photos and videos | Photos | Optional |
| Photos and videos | Videos | Optional |
| Files and docs | Files and docs | Optional (anything attached with "+") |
| App activity | Other user-generated content | Required (messages, chats, notes) |

## 5. Decided before this is published

1. **What the server keeps.** Does it log prompts, and for how long? Are
   private chats stored at all? The app tells people "nothing here is
   saved"; the server has to make that true (`docs/RELEASE.md` §5).
2. **Which AI providers get what,** and whether any of them may train on
   it. Each one named in the policy.
3. **Avatar photos:** where they are kept, and that deleting an avatar
   deletes the photos and the trained likeness at the provider.
4. **Account deletion:** `DELETE /v1/me` on the server (it does not exist
   yet), what it deletes, and how fast. Plus a web page for Google's
   deletion URL.
5. **The company name, contact address, minimum age,** and where the data
   is stored, if users in the EU or UK are expected.
