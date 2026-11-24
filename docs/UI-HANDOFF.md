# ShiftAi UI: handoff spec

Everything needed to rebuild the ShiftAi interface exactly, in any stack.
The live app is <https://natehale05-gif.github.io/ShiftAI/>, and the
source is Flutter in this repository. This document is the
stack-independent version of it.

**How to use this kit.** Read sections 1–4 first: they are the rules that
every screen follows. Then build the shell (section 5), the components
(section 6), and the screens (section 7), checking each one against its
screenshot in `screens/`. Where a measurement says "≈", it was taken from
a screenshot rather than from code, so match the screenshot.

---

## 1. What it is

ShiftAi is a creator suite: an AI chat that makes text, pictures,
video, music and web pages ("Suite"), plus Agents, Design, Notes, a
Vault of everything made, a weekly earnings Leaderboard, Trophies, and
Projects that group chats with shared instructions and files.

## 2. Principles (these decide every ambiguous case)

1. **It looks and behaves like an Apple app on every platform**, the
   Android web app included: iOS navigation (screens slide in from the
   right, swipe back, scrolling bounces), Cupertino alerts and action
   sheets, iOS activity spinners, iOS switches. There is no ink ripple
   and no Material splash anywhere. Pressed states are a subtle fill.
2. **Colour comes only from the tokens in section 3.** No other hex
   values exist in the UI, apart from the brand gradient, the tier
   colours and the media ink, which are listed there too.
3. **Type is a named style on one ramp (section 4).** No ad-hoc sizes.
4. **Sentence case everywhere.** No uppercase labels, no tracked mono
   text, no title case on buttons ("New chat", not "NEW CHAT" or "New
   Chat").
5. **Quiet chrome, loud content.** Surfaces are flat fills, not
   outlines. A light theme keeps a 0.5 px hairline on cards because
   white on near-white needs an edge, but a dark theme does not.
6. **Plain words.** Errors say what happened and what to do next ("That
   did not reach the server. Nothing was charged."), never codes alone.
7. **44 px minimum hit target** for every control.

## 3. Colour

### 3.1 Themes

There are four themes. **Retro neon is the default** for a new account,
and "Match system" (on by default) swaps between the two of a pair by
day and night: Retro neon ↔ Retro light, Dark ↔ Light.

| Token | Retro neon (default) | Retro light | Dark | Light | Used for |
|---|---|---|---|---|---|
| `bg` | `#0A0A0F` | `#F7F7F8` | `#0E1628` | `#F4F6FA` | Page ground |
| `surface` | `#14141A` | `#FFFFFF` | `#16203A` | `#FFFFFF` | Sidebar, cards, composer, list groups |
| `surfaceRaised` | `#1F1F26` | `#EDEDEF` | `#1E2A48` | `#EAEEF6` | Your chat bubble, inputs, segmented thumb track, snackbar |
| `border` | `#2A2A31` | `#D8D8DC` | `#2A3A5E` | `#D6DEEC` | Hairlines, dividers |
| `borderStrong` | `#BFBFBF` | `#55555C` | `#5E74A6` | `#6B7A96` | Outlined buttons, selected tile outline |
| `text` | `#FFFFFF` | `#0A0A0F` | `#F2F5FA` | `#0E1628` | Primary text |
| `textMuted` | `#BFBFBF` | `#5F5F67` | `#A7B4CC` | `#4A5872` | Secondary text, icons, placeholders |
| `accent` | `#FF1A8C` | `#C4005F` | `#5B8CFF` | `#1F5AE6` | Primary buttons, active nav, links, focus |
| `accentHover` | `#FF54A8` | `#99004A` | `#7BA2FF` | `#1848BE` | Hover/pressed accent |
| `accentSoft` | `#2A0A1C` | `#FFE1EE` | `#17254A` | `#E4ECFF` | Active nav row fill, "You" row, selection |
| `onAccent` | `#0A0A0F` | `#FFFFFF` | `#0E1628` | `#FFFFFF` | Text/icons on accent fills |
| `sky` | `#00E5FF` | `#0A6E88` | `#56CCF8` | `#096A8A` | Rank badge, "in review", info |
| `success` | `#34D399` | `#15642F` | `#34D399` | `#13702F` | "ahead", passed checks |
| `warning` | `#FBBF24` | `#965700` | `#FBBF24` | `#B45309` | "needs you" |
| `danger` | `#F87171` | `#BC241D` | `#F87171` | `#CE2020` | Destructive actions, "behind", failures |
| `onStatus` | `#0A0A0F` | `#FFFFFF` | `#0E1628` | `#FFFFFF` | Text on status fills |

Rules: a card always sits *lighter* than the page on light themes and
*lighter* than the page on dark themes (surface sits above bg). Never use
pure white as a light page; that leaves nothing to raise a card to.

Ready-to-paste CSS (Retro neon as the default; the others as
`[data-theme]` blocks):

```css
:root, [data-theme="retro"] {
  --bg:#0A0A0F; --surface:#14141A; --surface-raised:#1F1F26;
  --border:#2A2A31; --border-strong:#BFBFBF; --text:#FFFFFF; --text-muted:#BFBFBF;
  --accent:#FF1A8C; --accent-hover:#FF54A8; --accent-soft:#2A0A1C; --on-accent:#0A0A0F;
  --sky:#00E5FF; --success:#34D399; --warning:#FBBF24; --danger:#F87171; --on-status:#0A0A0F;
}
[data-theme="retro-light"] {
  --bg:#F7F7F8; --surface:#FFFFFF; --surface-raised:#EDEDEF;
  --border:#D8D8DC; --border-strong:#55555C; --text:#0A0A0F; --text-muted:#5F5F67;
  --accent:#C4005F; --accent-hover:#99004A; --accent-soft:#FFE1EE; --on-accent:#FFFFFF;
  --sky:#0A6E88; --success:#15642F; --warning:#965700; --danger:#BC241D; --on-status:#FFFFFF;
}
[data-theme="dark"] {
  --bg:#0E1628; --surface:#16203A; --surface-raised:#1E2A48;
  --border:#2A3A5E; --border-strong:#5E74A6; --text:#F2F5FA; --text-muted:#A7B4CC;
  --accent:#5B8CFF; --accent-hover:#7BA2FF; --accent-soft:#17254A; --on-accent:#0E1628;
  --sky:#56CCF8; --success:#34D399; --warning:#FBBF24; --danger:#F87171; --on-status:#0E1628;
}
[data-theme="light"] {
  --bg:#F4F6FA; --surface:#FFFFFF; --surface-raised:#EAEEF6;
  --border:#D6DEEC; --border-strong:#6B7A96; --text:#0E1628; --text-muted:#4A5872;
  --accent:#1F5AE6; --accent-hover:#1848BE; --accent-soft:#E4ECFF; --on-accent:#FFFFFF;
  --sky:#096A8A; --success:#13702F; --warning:#B45309; --danger:#CE2020; --on-status:#FFFFFF;
}
```

### 3.2 Colours outside the themes

- **Brand neon** (the logo's "ai" badge, never themed): gradient from
  `#EC01E7` to `#0061F1`, left to right.
- **Tiers** (trophies, podium). On dark grounds: bronze `#D9853D`,
  silver `#C9D2E0`, gold `#FBBF24`, platinum `#56CCF8`. On light grounds:
  bronze `#A3461C`, silver `#64707F`, gold `#946400`, platinum `#0A6E88`.
- **Over media** (photos, video): white `#FFFFFF` glyphs over a black
  `#000000` scrim at partial alpha, the same in every theme.
- **Shadows**: black at low alpha, only on things that float (sheets,
  alerts, popovers). Cards have no shadow.

## 4. Type

Two faces, both bundled (in `fonts/`, OFL licensed): **Outfit**
(variable) for display and titles, and **Manrope** (variable) for copy,
labels and numbers. Fallbacks are Helvetica Neue, then Arial. Set weight
through the variable axis (`font-variation-settings: "wght" N`) as well
as `font-weight`.

| Style | Face | Size / line height | Weight | Tracking | Use |
|---|---|---|---|---|---|
| displayXl | Outfit | 56 / 60 | 300 | −0.56 | Hero numbers |
| displayL | Outfit | 40 / 46 | 300 | −0.4 | Big figures |
| largeTitle | Outfit | 32 / 38 | 700 | −0.3 | A screen's title ("Leaderboard") |
| title1 | Outfit | 28 / 34 | 700 | −0.2 | Document/project title |
| heading | Outfit | 28 / 34 | 500 | – | Suite greeting (in `textMuted`) |
| title2 | Outfit | 22 / 28 | 600 | – | Lead figure on a card |
| subheading | Outfit | 20 / 28 | 500 | – | Sheet titles |
| sectionTitle | Outfit | 20 / 26 | 600 | – | Section heads ("Bronze", "Austin Metro") |
| body | Manrope | 17 / 28 | 400 | – | Chat text, composer, list rows |
| headline | Manrope | 17 / 24 | 600 | – | A row's name, a bar's title |
| callout | Manrope | 16 / 22 | 400 | – | App bar title, text buttons |
| bodySm | Manrope | 15 / 24 | 400 | – | Secondary copy, your chat bubble |
| bodyStrong | Manrope | 15 / 24 | 600 | – | Buttons, emphasis |
| caption | Manrope | 13 / 20 | 500 | – | Meta lines, hints, tooltips |
| eyebrow | Manrope | 13 / ≈17 | 600 | – | Group labels ("Modes", "Instructions"), in `textMuted` |
| figures | Manrope | 15 (varies) | 600 | – | Numbers with **tabular figures** (`font-feature-settings: "tnum"`) |

## 5. Layout and the shell

- **Breakpoint 900 px.** At 900 or more, a persistent left **sidebar
  rail 260 px wide** sits beside the content (collapsible by the
  hamburger, sliding open and shut over 220 ms, ease-out-cubic). Under
  900 it becomes a **drawer 306 px wide** over the content with a dark
  scrim. Screens: `01`, `31`.
- **App bar**, 60 px tall, the page colour, no shadow or border.
  - Left: the hamburger (22 px icon, 44 px target) and the screen
    title (callout). With the rail open, these sit inside the sidebar's
    own top row instead, so the sidebar runs unbroken to the top of the
    window.
  - Centre: the **ShiftAi lockup** (`brand/shift-ai-lockup.svg`), 20 px
    tall. The wordmark ink takes the theme's `text` colour; the "ai"
    badge keeps the neon gradient.
  - Right, on the chat only: "…" (options for the open chat, only once
    it is saved), the daily-rings button (concentric circles), and the
    ghost (private chat; `accent` when on, `textMuted` when off).
- **Content widths**: the chat column is max **820 px**, centred; the
  composer max **950 px**; your chat bubble max **560 px**; a made
  picture max **520 × 520**; the project page max **760 px**; app-wide
  content max **1200 px**. Side padding is 16 px on phones, ≈32–36 px on
  desktop.
- **Screen changes** cross-fade over 180 ms, with the incoming screen
  rising 1.2 % of its height (ease-out in, ease-in out).
- **Spacing scale (px):** 4, 8, 12, 16, 24, 32, 48, 64. Use only these.
- **Radii (px):** small 6 (tooltips, thumbnails in lists), medium 10
  (buttons, inputs, nav rows, snackbars), large 16 (cards, list groups,
  media, sheets' top corners), pill 999 (New chat, composer, badges,
  segmented controls).

### 5.1 Sidebar (screens `01`, `31`)

Top to bottom, on `surface`:

1. (Rail only) a 60 px row: hamburger plus the current screen title.
2. **New chat**: a full-width pill button, 46 px tall, `accent` fill,
   `onAccent` text, "+" icon 18 px, 16 px side margins.
3. Groups, each headed by an eyebrow label, separated by a 1 px `border`
   hairline with 16 px of space above and below:
   - **Modes**: Suite, Agents, Design, Notes.
   - **Workspace**: Leaderboard (with a rank badge "#13": a pill in
     `sky` at 14 % alpha, `sky` tabular text 12/600), Trophies, Vault.
   - **Projects**: one row per project (folder icon), then "New project"
     (folder-plus icon).
   - **Recents**: saved chats, newest first, each ending in a "…"
     button (18 px icon, 32 px target). Past 6 chats a search field
     appears above them. At most 30 are listed, with "N older chats.
     Search to find one." under them.
4. Pinned to the bottom, an **account row**: a 60 px pill on
   `surfaceRaised` with a `border` outline, an avatar circle (initials),
   the name (bodyStrong), "Membership" (caption, muted), and a chevron.

**Nav row**: 38 px tall on the rail, 44 in the drawer, radius 10, 12 px
side padding, icon 19 px, label 15 px. The active row has an
`accentSoft` fill, with the icon and label in `accent` and the label at
weight 600; every other row is `text` at 400 with a `textMuted` icon.
Rows have no outline and no left accent bar.

## 6. Components

**Buttons**
- *Primary*: `accent` fill, `onAccent` label, bodyStrong 15/600, 44 px
  min height, 16 px side padding, radius 10. Big page-level actions (New
  chat, New chat in this project) are full-width **pills** 46 px tall.
- *Secondary / outlined*: transparent, 1 px `borderStrong`, `text`
  label, radius 10 ("Sign out", "Create an avatar").
- *Text button*: `accent` label (callout), no fill ("Edit", "Upload",
  "Add", "< Create" back links).
- *Icon button*: `textMuted` glyph, 44 px target, no fill.

**Composer** (bottom of Suite, Agents, Design, Notes)
- A pill on `surface`, ≈56 px tall, max 950 px wide, 16 px clear of the
  bottom.
- Left: "+" (attach any files, 22 px, `textMuted`). Then the field:
  body 17, hint in `textMuted` ("Ask anything", "Give an agent a task",
  "Describe a page", "Write a note"). It grows to 8 lines.
- On Suite only, the right side also has an avatar picker (face icon)
  and a sparkle (rewrite into a fuller brief).
- Last, a 44 px **circular send button** in `accent` with an up-arrow in
  `onAccent`. While an answer is coming, after 20 s it becomes **Stop**.
- Attached files show as chips above the pill.

**Your message**: right-aligned, max 560 px, on `surfaceRaised`, radius
16, 16 px × 12 px padding, bodySm in `text`. Files you sent sit above it
as chips (icon + name, `surface`, radius 10).

**A reply** (left-aligned, full column width, no bubble), in order:
1. The model's name, if any ("Mock A", "Showcase video (with sound)"):
   Manrope 13/600, `textMuted`.
2. An eyebrow, if any ("ShiftAi · Video"): a 6 px `accent` dot, 8 px gap,
   then the eyebrow text.
3. The body, rendered from Markdown (headings, lists, code blocks, bold,
   links) in body 17.
4. Anything it made, as a card (below).
5. An action row: Copy · Retry · Edit (14 px icon + caption label,
   `textMuted`, 8 px padding).

**Made picture / video card** (`04`): the image at its own aspect,
clamped to 0.5–2, max 520 × 520, radius 16, on `surface`. A video shows
its first frame with a 56 px play disc. Under it: Edit image · Share ·
Open in Vault (same style as the action row). A note under it may say
"Edited from …", "Made from …", or warn that it may not be the picture
you sent. While a file is still being made: a 14 px spinner and "Making
the video. It will appear here when it is in your vault."

**Website card** (`05`, `05b`): a card on `surface` with a 1 px `border`
and radius 16. It has three parts:
- *Header*: a globe icon in `accent`, the page title (bodyStrong), and
  "Website · N lines" (caption) under it.
- *Preview*: a live preview of the page, ≈380 px tall, in a sandboxed
  iframe.
- *Footer*: Open · Copy code · Download · View code.

Open goes full screen on black, with a top bar holding ✕, the title,
copy and download.

**Action sheet** (`06`), the iOS kind: it rises from the bottom, with
rows of centred `accent` text (17 px) on a translucent `surfaceRaised`
card. A destructive row is in `danger`. The title sits on top in caption
`textMuted`. Below, set apart, is a separate rounded **Cancel** card at
weight 600. It is used for every "…" menu.

**Alert** (`08a`), the iOS kind: a centred card ≈270 px wide, with the
title (Manrope 17/600) and the message (caption) centred. It may hold
an optional field (filled, radius 6, with an `accent` outline on focus).
Below, buttons are split by hairlines: Cancel and the main action side
by side. The main action is in bold (or `danger` if destructive). In a
one-line field, Return takes the main action. It is used for every
confirmation and every "name it" prompt.

**Segmented control** (Local/Global, My vault/EcoVault, Agents/Jobs): a
pill track in `surfaceRaised`, with a raised thumb (`surface` lighter
than the track; white on light themes) that slides to the chosen
segment. Labels are bodyStrong; the chosen one is `text`, the others
`textMuted`. Segments are equal widths.

**Search field**: filled `surfaceRaised`, radius 10, a magnifier icon,
the hint in `textMuted`, and a clear button once text is in.

**Card**: `surface` fill, radius 16, padding 24. On light themes only,
add a 0.5 px `border` hairline.

**Grouped list**: rows inside one `surface` card of radius 16, divided
by 0.5 px `border` hairlines inset from the leading edge. Each row has
an icon, a title (body), and a meta line (caption, muted), with an
optional trailing "…" or ✕.

**Eyebrow / group label**: Manrope 13/600 in `textMuted`, sentence case.

**Badge**: a pill with the colour at 14 % alpha behind tabular text in
the colour ("#13" in `sky`, "Included with membership" in `accent`).

**Avatar**: a circle of initials (bodyStrong, `accent`) on `accentSoft`
with a 1 px `accent` ring, or a photo.

**Empty state**: a 72 px circle in `accentSoft` holding an `accent` icon
(46 % of the circle), then a title (sectionTitle), one line of
`textMuted`, and an optional primary button. Max 340 px wide. A compact
version (52 px circle) is used for empty searches.

**Snackbar**: it floats ≈16 px above the bottom, on `surfaceRaised`,
radius 10, with bodySm text. It never sits over the composer.

**Spinner**: the iOS activity indicator (petals), in `textMuted`.
Never a Material ring.

**Switch**: iOS switch, `accent` when on. **Checkbox**: an iOS-style
check row, never a Material box.

**Icons**: Material Symbols rounded/outlined at 18–22 px, in `textMuted`
unless active (`accent`). Examples: `auto_awesome` (Suite), `bolt`
(Agents), `draw` (Design), `sticky_note_2` (Notes), `bar_chart`
(Leaderboard), `emoji_events` (Trophies), `grid_view` (Vault),
`folder` (project), `create_new_folder`, `chat_bubble_outline`,
`more_horiz`, `add`, `arrow_upward`.

## 7. Screens

Each has a screenshot in `screens/`; numbers refer to the file names.

| # | Screen | What is on it |
|---|---|---|
| 00 | Sign in | A centred card (max ≈440 px) on `surface`, radius 16. The lockup sits above it. Inside: "Sign in" (title), a short line, then labelled Email and Password fields, a full-width primary "Sign in", an info box (`accentSoft` with an `accent` info icon), and a "Trouble signing in?" link. |
| 01, 03, 30 | Suite, empty | The sidebar, and a centred greeting in heading/`textMuted` that rotates ("What are we making today?", "Ready when you are."). Under it, in a project: a folder icon and "In <project>" in `accent`. The composer sits at the bottom. |
| 02 | Daily rings | A full-screen sheet opened on launch: three concentric rings (Create / Publish / Compete) with "0 of 3 closed today" and three ticked rows. A ✕ sits top left. |
| 04 | Chat with a made picture | See "A reply" and "Made picture" in section 6. |
| 05, 05b | Chat with a website | Website card, and its full-screen view. |
| 06 | Chat "…" menu | Action sheet: Add to project… / Move… / Remove from "<project>" / Delete chat (danger) / Cancel. |
| 08a, 08b, 08c, 09a | Projects | The New project alert, an empty project, a filled project, and a new chat in a project. The project page has a 26 px `accent` folder icon and the name (title1) with a "…" button. Under them: a full-width pill "New chat in this project", then the **Instructions** eyebrow with an "Edit" text button above a card of the instructions (or a muted placeholder). Next, **Files and notes** with "Upload" and "Add" (a grouped list of resources, each with a ✕), then **Chats** (a grouped list, each with a "…"). |
| 10 | Agents | A segmented Agents/Jobs control with a repo picker on the right in `accent`. Four stat tiles (In all / Working / Need you / In review), each a figure coloured by status: `text` / `accent` / `warning` / `sky`. The selected tile gets a 1 px `borderStrong` outline. Then a grouped list of runs, each with a status dot, a title, a meta line and a chevron. The composer reads "Give an agent a task". |
| 11 | Design | "Make something new": four tiles (Slides, Design, Design in codebase, Brand), each a `surface` card ≈246×164 with a centred 28 px `accent` icon and its label below. Then a search field and a grid of design cards with kind chips ("Brand", "Page"). Composer: "Describe a page". |
| 12 | Notes | A large title "Notes" with "N notes" under it. Then a grouped list (title in headline, first line in bodySm muted, a trash icon), a floating 56 px `accent` circle compose button bottom right, and the composer "Write a note". |
| 13, 21, 32 | Leaderboard | "< Create" back link and largeTitle. "Week 47" (sectionTitle) with the pool line; "Ends in 0d 07:20:42" in tabular figures. Next, Local/Global segmented, the league name and line, and a **podium**: 2-1-3 blocks in silver/gold/bronze gradients fading to the ground, with avatars above (the gold one bigger, a trophy icon over #1), names and $ figures. A **"You" row** comes next: `accentSoft`, radius 16, the rank in displayL `accent`, "↑ 2 up this week" in `success`, and the $ figure in title2. Last, a grouped list of nearby rivals ("$54.35 ahead" in `success`, "$12.35 behind" in `danger`). |
| 14 | Trophies | Back link and title. A card: "Trophy points", **55** in displayL `accent` with "of 610", "4 of 18 earned · 22%", a 4 px progress bar in `accent` on `surfaceRaised`, and a "Next up: …" line with a flag. Then tier sections (sectionTitle "Bronze" with "3 of 6" on the right), each a row of 64 px circular medals. Earned ones are filled in the tier colour with a 3 px ring; unearned are `surfaceRaised` with a muted icon and a progress arc. Under each: the name (bold if earned) and pts or "x of y". |
| 15, 22 | Vault | My vault/EcoVault segmented with "12 made · 2 saved" on the right, a search field, then a **3-column masonry** of media at their own aspect ratios. Each is radius 16, with a duration chip bottom right (white on a dark scrim) and a heart button top right on saved items. Under each: the title (bodyStrong) and "Video · 1080 × 1920" (caption). EcoVault is a one-post-at-a-time feed with the maker, a heart count and the prompt. |
| 16, 23 | Settings | Stacked cards. *Account*: avatar, name, email, @handle with a pencil, an "Included with membership" badge, and "Sign out" outlined. *Your avatars*: tiles ≈148×190, radius 16; the personal one has a 1 px `accent` outline with "Personal" in `accent`, and a training one says "Training…". Below them, the built-in avatar row and "+ Create an avatar" outlined. *Appearance*: "Match system" with an iOS switch, then four 44 px circular theme swatches (the chosen one has an `accent` ring and a check). Further down (scroll): features on/off, connectors, account deletion. |
| 20–23 | Theme variants | The same screens in Retro light, Dark and Light. Only the tokens change; layout is identical. |
| 31 | Phone drawer | The sidebar as a 306 px drawer, with 44 px rows. |

## 8. Behaviour worth copying

- **"…" everywhere** for per-item actions, opening an action sheet.
  Long-press does the same on touch, but is never the only way.
- **Destructive actions confirm** with an alert. Cancel is the bold
  default; the destructive button is in `danger`.
- **Return** in a one-line alert field takes the main action; a
  multi-line field keeps Return for new lines.
- **Optimistic updates**: changes show at once and roll back with a
  sentence if the server refuses.
- **Loading**: iOS spinners, and a "Still working" line after 20 s
  rather than a frozen screen.
- **Private chat** (ghost icon): the ghost turns `accent`, and nothing
  of that chat is saved.
- **Projects**: a chat started from a project says "In <project>", and
  the bar shows the project's name.

## 9. Do not

- Use Material ripples, Material dialogs, Material spinners, checkboxes
  or sliders.
- Use any colour not in section 3, or put a shadow on a card.
- Use uppercase or tracked labels, or a monospace face for UI text.
- Outline every card, or add a coloured bar to the active nav row.
- Leave the drawer open over a screen you just navigated to, or let a
  snackbar cover the composer.

## 10. In this kit

- `UI-HANDOFF.md`: this file.
- `screens/*.png`: 33 screenshots. Desktop shots are 1280 × 860; phone
  shots are 390 × 844 at 2×. Retro neon unless the name says otherwise.
- `brand/shift-ai-lockup.svg`: the logo. Ink `#F2F5FA` stands in for the
  theme's `text`; the gradient is fixed.
- `fonts/`: Outfit and Manrope variable TTFs, with their OFL licences.
