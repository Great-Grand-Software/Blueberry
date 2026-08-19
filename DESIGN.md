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
§7 so nobody mistakes an open slot for something already settled.

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

Three vertical tiers, top to bottom.

```
┌─────────────────────────────────┐  y=0
│ [II]   000 0 0 0 00 00          │  Tier 1 — UI band
│        MIL CEN DEC YRS MON DAY  │  (leftover space)
│        JANUARY          BEST 0  │
├──────┬───────────────────┬──────┤  y=100
│      │                   │      │
│      │   Tier 2 — image  │      │  420 x 420 square
│      │   (line drawing)  │      │
│      ├───────────────────┤      │  y=520
│      │                   │      │
│      │   Tier 3 — grid   │      │  420 x 420 square
│      │   (interactive)   │      │
└──────┴───────────────────┴──────┘  y=940
```

**Tier 1 — UI band.** Score/counter display, plus a small pause button pinned
to the upper-left corner leading to the pause menu. It has **no fixed height**;
it simply takes whatever vertical space the other two tiers leave over.

**Tier 2 — image panel.** A square holding a monochrome line drawing tied to
the current month.

**Tier 3 — calendar grid.** A square directly beneath the image panel, forming
a 1×2 stacked block with it. This is the only interactive area.

> **A geometric consequence worth knowing.** Two stacked squares plus a 3:4
> frame forces the block to be narrower than the screen: two full-width squares
> would need `2W` of height where only `1.33W` exists. At `720x960` with a
> 420-wide block, the tiers come to 100 / 420 / 420 with a 20px bottom margin,
> leaving 150px of ground either side. The generous side margins are a
> *result* of the brief, not a style choice layered on top of it. If the block
> should instead be wider, something else has to give — the squares, or the
> 3:4 frame.

---

## 3. Core loop

1. The player marks off days inside the calendar grid, either by tapping one
   at a time or by holding and dragging across several in one stroke.
2. Each day marked gets an **X**, like crossing a day off a physical wall
   calendar.
3. There are **30 days** to get through in a month. A tap crosses off one; a
   stroke crosses off every day it passes over.
4. Once every day on the page is marked, the page **folds down** automatically,
   revealing the next month underneath along with that month's line drawing.

The transition is a **fold**, hinged at the bottom edge — *not* a tear or a
rip. `MonthPage.fold_down()` collapses `scale.y` to zero with the pivot at the
bottom, so the page hinges downward and the next month is revealed from the
top down.

**Marking is a tap or a stroke, and a stroke is not a gesture.** Thirty
separate contacts to clear one page is tiring on a phone and slow everywhere
else, so a press that is held and moved keeps marking each new day the point
crosses. That is still the same one finger or one button — nothing here reads
a second contact, a pinch, or a fling — so the single-point-of-contact rule in
`CLAUDE.md` §2 is untouched. A press that never moves is exactly the old tap.

A stroke stops at the fold. The mark that completes a month ends the stroke,
so a swipe can never run on through the page revealed underneath; the player
lifts and starts again on the new month.

Re-marking an already-marked day does nothing, whether it is re-tapped or
swiped back over. Nothing can inflate the score by covering the same day
twice.

---

## 4. Score and counter

The score is a **raw count of days tapped**. One number.

It is displayed converted upward through several units **at once**, so the
player sees days, months, years, decades, centuries and millennia
simultaneously. Unfilled higher units read as zero and are padded with leading
zeros for visual weight:

```
 000   0    0    0    00   00
 MIL  CEN  DEC  YRS  MON  DAY
```

**There is no cap.** The counter climbs indefinitely; the largest unit simply
grows past its padding rather than saturating.

Months are a uniform **30 days**, which makes the ladder exact by
construction — 30 days to a month, 12 months to a year, then powers of ten.
Nothing rounds. `test_day_counter.gd` asserts the decomposition recombines
losslessly into the input for every count it checks.

---

## 5. Looping

There are **twelve** monthly drawings total, forming one theme. When month
twelve folds down, the calendar loops back to month one using **the exact same
twelve drawings**, forever. The theme never changes across loops.

This repetition is deliberate and intentionally underdeveloped. See §7.

---

## 6. End state, and visual style

**There is no end state.** The game does not end, win, or lose. It persists as
long as the player keeps tapping. The best raw day count is saved locally as a
personal best.

**Fully monochrome — no colour anywhere.** Near-black ink on off-white paper,
on a dark ground. A small drop shadow beneath the calendar block gives it a
touch of dimension. All imagery, the monthly drawings included, is simple line
work.

The presentation should read as **clean and presentable, not sparse or
unfinished**, despite the deliberately minimal scope. If a change makes it look
like a prototype someone abandoned, that is a regression even if it adds
features.

---

## 7. Explicitly open — not yet designed

**These are open slots, not oversights.** Nothing below has been decided, and
a PR proposing any of it is proposing something new rather than fixing
something broken.

- **Milestones.** What, if anything, happens on reaching one year, one decade,
  one century. Currently: nothing.
- **Whether the monthly image theme ever changes.** Currently the same twelve
  drawings loop forever. Alternate sets for later years, new themes, any other
  treatment — all undesigned.
- **Feedback, sound, animation** beyond the basic tap and fold. There is
  currently no audio at all.
- **Meta systems, social features, alternate modes.** None exist. None are
  planned. None are ruled out.

Smaller open questions, same status:

- Real 28/30/31-day months instead of a uniform 30. The uniform month is what
  makes the counter ladder exact, so changing it means redesigning the counter.
- Whether there is any way to reset a run. Without one, the personal best
  necessarily equals the current total during normal play.
- What the pause menu should hold beyond Resume and Main Menu.

If you build one of these, **update this file in the same PR** — move it out
of §7 and describe what you decided. An open slot that has quietly been filled
is worse than one that is still open.
