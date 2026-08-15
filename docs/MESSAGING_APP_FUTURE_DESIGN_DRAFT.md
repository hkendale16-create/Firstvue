# FirstVue Messages — Future design draft

**Status:** Draft for future build. Kendale’s locked direction.  
**Shell:** three phones / three tabs only — **Now · Gather · Events** (no Home).  
**Account:** same FirstVue sign-in + same messaging/event data (`fv_msg_*`).

Visual anchors (keep these):

| Tab | Locked mockup |
| --- | --- |
| Now | `messaging-app-mockups/fv-final-01-now-map.png` (+ feature drafts below) |
| Gather | `messaging-app-mockups/fv-final-02-gather.png` |
| Events | `messaging-app-mockups/fv-final-03-events-clean.png` |

Feature-draft PNGs for the map:

- `fv-draft-now-map-features.png` — multi-pin 3D map + “In this area” feed  
- `fv-draft-now-pin-detail.png` — pin tap → event profile + chat entry  

---

## Product intent

Out-and-about FirstVue Messages: glance what’s going on, move on the map, join the right chat fast. Not a desk inbox.

---

## Bottom nav (only these)

```
Now (map) · Gather (near + tonight) · Events (featured + upcoming)
```

Each icon is its own phone section. No Home tab.

---

## 1. Now — 3D map (primary)

**Keep the exact 3D isometric night-map look** from the locked Now mockup (glowing streets, elevated blocks, gold/teal). That map language stays.

### Map features (future)

1. **Many pins** — not one. Show locations of live gatherings, events, and “things going on” in view (LIVE / soon / friend-active as distinct pin styles).
2. **Navigate the map** — pan, pinch-zoom, and move to another neighborhood or block.
3. **Feed follows the map** — the bottom “In this area” list **updates from the current map viewport / center**, not only GPS. Move the map → feed refreshes for that area.
4. **Optional recenter** — control to jump back to “me,” without forcing the feed to ignore where the user is exploring.
5. **Tap a pin (or feed row)** — opens the **corresponding event / happening profile** on this screen, with:
   - cover / title / live or time  
   - who’s going (faces + count)  
   - short what’s going on  
   - **Open chat** (event / gathering thread)  
   - **View event** (full event profile)  
   - light **recent chat** preview when useful  

```
┌──────────────────────────┐
│ FirstVue           Now   │
│ ┌──────────────────────┐ │
│ │  3D MAP (locked look)│ │
│ │  ● you  ✦ ✦ ✦ pins   │ │
│ │  (pan / zoom area)   │ │
│ └──────────────────────┘ │
│ In this area  (viewport) │
│ · Live thing A           │
│ · Live thing B           │
│ · Soon C                 │
├──────────────────────────┤
│ ◎Now  ○Gather  ○Events   │
└──────────────────────────┘

Tap pin / row → sheet
┌──────────────────────────┐
│ [ event cover ]    LIVE  │
│ Lake Night Market        │
│ (faces) 48 going · 6 min │
│ What’s going on blurb    │
│ [ Open chat ] [ Event ]  │
│ Recent in chat…          │
└──────────────────────────┘
```

### Now interactions (summary)

| Action | Result |
| --- | --- |
| Pan / zoom map | “In this area” feed updates for that region |
| Tap pin | Event/happening profile sheet + chat entry |
| Tap feed row | Same profile/chat sheet for that item |
| Open chat | Event / gathering conversation |
| View event | Full event profile |
| Recenter | Map returns to user; feed can follow |

---

## 2. Gather — near you + tonight

Locked combo: horizontal **Near you** + **Tonight** grid, chips Near · Live · Tonight.

- Browse nearby visually  
- **Join chat** from a tile or near-you item → gathering thread  

(Mockup: `fv-final-02-gather.png`)

---

## 3. Events — featured + upcoming people

Locked combo: **one prominent featured** event on top; **Upcoming gatherings** as its own section with **profile photos of people going + counts**.

- Featured → Join chat / open event  
- Upcoming row → event + who’s going  

(Mockup: `fv-final-03-events-clean.png`)

---

## Cross-tab flow

```
Now map explore → pin → profile sheet → Open chat
Gather tonight  → Join chat → gathering thread
Events featured → Join chat / upcoming faces → event + chat
```

DMs, business inbox, and settings stay reachable from **inside chats / overflow**, not as a Home tab.

---

## Build notes (when implementing later)

- Map: keep isometric 3D visual language; pins from live/upcoming geo data for viewport bounds  
- Feed query: `bbox` / center+radius from map camera, refresh on pan end  
- Pin tap: deep-link to same event entity used by Gather + Events tabs  
- Chat: existing FirstVue encrypted event/gathering conversations  

---

## Out of scope for this draft

- Home / desk inbox as a main tab  
- Replacing Gather or Events with the discarded layout experiments  

---

*End of draft — Now (3D map + area feed + pin profiles/chats), Gather, Events.*
