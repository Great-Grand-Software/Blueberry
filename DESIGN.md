# Design

Read this before opening a PR. `CLAUDE.md` tells you the rules; this file
tells you the *intent*, and — just as importantly — which parts were left
undesigned on purpose.

---

## What this is

**An experimental proof of concept, not a polished game.**

The goal is to prove that a minimal, deliberately underdeveloped core loop can
serve as a foundation that friends extend through pull requests on a shared
org. The loop is small because it is meant to be built on, not because it ran
out of time.

Several decisions below are intentionally incomplete. They are called out in
§9 so nobody mistakes an open slot for something already settled.

---

## 1. Platform and framing

The **portrait phone is the one true target**, at roughly a **3:4** aspect
ratio. The base viewport is `720x960`.

It has to run as a web page — phone browsers and desktop browsers alike — and
work as a plain clicker on a phone.

On any screen that isn't that shape (a desktop window, a much taller phone),
the game renders inside a **fixed-ratio frame at the correct phone
proportions, centred and letterboxed**. It does *not* reflow responsively.
This is `window/stretch/aspect="keep"` in `project.godot`, and it is not a
placeholder — the fixed frame is the design.

---

## 2. Screen layout

A fixed UI band across the top, and everything else in a pager beneath it.

```
┌─────────────────────────────────┐  y=0
│ [II]   1  DAILY CALENDAR        │  UI band — 720x96, always visible
│          PTS  17 MAR  YEAR 1  ○●○│
├─────────────────────────────────┤  y=96
│                                 │
│      ┌───────────────────┐      │  the wall — 720x864
│      │  ○ backing + tack │      │  one of three views
│      ├───────────────────┤      │
│      │                   │      │
│      │  the calendar     │      │  page: 440x620 at (140, 104)
│      │  page hanging     │      │  inside the view
│      │  off the tack     │      │
│      │                   │      │
│      └───────────────────┘      │
│                                 │
└─────────────────────────────────┘  y=960
```

**The UI band.** A fixed 96px strip: the pause button, the running point
total, which calendar is on the wall, the date it currently reads, and three
dots showing which view is in front. It never scrolls, so the point total is
visible from every view.

**The three views** live in a pager filling everything below the band. Left to
right: **Stats**, **Calendar**, **Store**. The calendar is the middle one, so
both others are exactly one swipe away.

**The calendar view** is a plain white cubicle wall — faint fabric grain, one
panel seam near the bottom — with a single thumbtack holding a paper backing
strip, and the current page hanging off it. That is the whole scene. It is
bare on purpose: dressing the wall is a progression reward, not part of this
build. See §9.

**A geometric note.** The page is 440x620, which is as tall as it can be while
leaving room below for the point flash and the panel seam. Everything on the
page is budgeted against that: illustration 180, title 48, body 252, holiday
strip 52. If one grows, another has to give.

---

## 3. Core loop

1. A calendar page hangs off the thumbtack. **Tap it to rip it off.**
2. The page tears loose, tumbles down past the bottom of the wall, and is
   gone. The next page was already hanging underneath it.
3. Ripping advances the calendar by **whatever a page is worth on the tier you
   are on** — one day, one month, one quarter, or one whole year.
4. It never ends. There is no last page.

**The transition is a rip, hinged on nothing.** `CalendarPage.rip_off()` plays
a short tear off the tack, then a fall with rotation and a fade, and frees the
page at the end. This replaced a fold that collapsed the page downward; the
brief asks for a rip, and the tumble reads far better against a wall than a
hinge did.

**One tap is one page.** There is no stroke-marking, no dragging across cells,
nothing to complete before the page comes off. That is what makes the tiers
mean something: a page is a page whether it is one day or a whole year.

---

## 4. The four calendars

Each tier is a **distinct calendar object**, not a multiplier on the same one.
Buying one swaps the object entirely and starts it back at the 1st of January.

| Tier | Rips per year | The page shows |
|---|---|---|
| Daily | 365 | one enormous day number, and which day of 365 it is |
| Monthly | 12 | the month as a real 7x5 grid of its own days |
| Quarterly | 4 | its three months side by side, as grids of dots |
| Yearly | 1 | all twelve months, one track each, like a year planner |

Every page also carries the line drawing for its first month, the title of
what it covers, and a strip along the bottom naming the holidays on it.

**The year is real: 365 days, months at their real lengths, no leap day.**
Real lengths are what let holidays sit on real dates — the 31st of October has
to exist for Halloween to. Dropping the leap day keeps every year identical,
so a tier's rips-per-year is a constant.

A monthly or quarterly page always spans exactly to the next real boundary,
and every tier starts on the 1st of January, so the calendar can never drift
half a page out of alignment. `test_calendar_tier.gd` asserts this for all
four tiers: a year of rips lands on New Year again, exactly.

---

## 5. Score

**Points come from holidays and from nothing else.** Most rips award nothing,
which is what makes a page with a holiday on it feel like something.

There are **eight holidays**, all on fixed dates:

| | | | |
|---|---|---|---|
| 1 Jan — New Year's Day | 14 Feb — Valentine's Day | 17 Mar — St. Patrick's Day | 1 Apr — April Fools' Day |
| 4 Jul — Independence Day | 31 Oct — Halloween | 11 Nov — Veterans Day | 25 Dec — Christmas Day |

One holiday is one point. They are **not** spread evenly through the year — Q1
and Q4 hold three each, Q2 and Q3 one apiece — so a quarterly page is worth
one to three points depending on which quarter it is.

**A coarser page collects every holiday it covers, at once.** A monthly page
banks the holidays in that month; a yearly page banks all eight. This was the
open question the brief flagged, and it is now decided: it means **a year is
worth eight points on every calendar**, so an upgrade buys the same points for
fewer rips rather than a different amount of points. Every page prints the
holidays it holds, so the player can see what a rip is about to be worth.

**There is no cap.** The count climbs for as long as anyone keeps ripping. The
best total ever held is saved locally.

---

## 6. Store and upgrades

The store shows exactly **one** calendar for sale: the next one up.

Costs are `BASE_COST * COST_RATIO^tier` — **3, 24, 192 points**, a factor of
eight each time. Read as rips-to-afford at the tier you are on, the three
upgrades land at roughly 76, 36 and 96 rips: expensive enough to be earned,
cheap enough that one session reaches the top.

A purchase is gated on the points already being in hand. The buy panel is
**filled and tappable** when affordable and **outlined with the shortfall
spelled out** when not, so the gate never looks like a broken button. Buying
spends the points, swaps the calendar, resets the calendar to New Year, and
sends the player back to the wall to see what they bought.

---

## 7. Navigation, and the one contact rule

Swipe left or right between the three views. The calendar is in the middle,
Stats to its left, Store to its right.

**`ViewPager` owns every gameplay contact.** It is the only thing reading the
press, and it decides what the contact was: a drag past `SWIPE_THRESHOLD`
sideways is a swipe, and a press that lifts within `TAP_SLOP` is a tap, handed
on to whichever view is in front. Nothing underneath does its own hit-testing.

That single owner is the whole point. A rip and a swipe are the *same* one
finger, and two independent readers of it would both claim it — a swipe that
started on the calendar would also rip the page under it.
`test_view_pager.gd` asserts it does not.

It is still one point of contact throughout: touch index 0 or the left mouse
button, pressed, moved, released. No second index is ever consulted and no
gesture event is read anywhere, so the rule in `CLAUDE.md` §2 holds.

A press that starts in the UI band above the pager is deliberately left alone,
because the pause button lives up there and is a real `Button`.

---

## 8. End state, and visual style

**There is no end state.** The game does not end, win, or lose. It persists as
long as the player keeps ripping. The best point total is saved locally.

**Fully monochrome — no colour anywhere.** Near-black ink, off-white paper, a
near-white cubicle wall, and a near-black UI band. All imagery, the monthly
drawings included, is simple line work.

The presentation should read as **clean and presentable, not sparse or
unfinished**, despite the deliberately minimal scope. If a change makes it look
like a prototype someone abandoned, that is a regression even if it adds
features.

---

## 9. Explicitly open — not yet designed

**These are open slots, not oversights.** Nothing below has been decided, and
a PR proposing any of it is proposing something new rather than fixing
something broken.

- **Dressing the wall.** The cubicle wall is deliberately bare. Making it
  something the player earns — posters, a window, a second tack — is the
  obvious next progression system, and none of it is designed.
- **Milestones.** What, if anything, happens on reaching a decade or a
  century. Currently: nothing.
- **Whether the monthly image theme ever changes.** The same twelve drawings
  loop forever, on every tier. Alternate sets, new themes — all undesigned.
- **Feedback, sound, animation** beyond the rip and the point flash. There is
  currently no audio at all.
- **Meta systems, social features, alternate modes.** None exist. None are
  planned. None are ruled out.

Smaller open questions, same status:

- **Whether holidays should ever move.** All eight are fixed-date, which is
  why no rule needs to know about weekdays. Floating holidays (Thanksgiving,
  Easter) would need a weekday model the calendar does not have.
- **Whether a tier can be sold back or downgraded.** Currently the ladder only
  goes up.
- **Whether there is any way to reset a run.** Without one, the personal best
  necessarily equals the peak of the current run.
- **What the pause menu should hold** beyond Resume and Main Menu.
- **Whether a fifth tier exists above Yearly.** Decade? The cost curve would
  reach 1536 points, and one rip would be worth 80.

If you build one of these, **update this file in the same PR** — move it out
of §9 and describe what you decided. An open slot that has quietly been filled
is worse than one that is still open.
