# FirstVue Messages — Final combined markup

One app. Three sections. Split only by the **bottom icons** (no Home).

```
┌─────────┬─────────┬─────────┐
│  Now    │ Gather  │ Events  │
│  (map)  │ near +  │ featured│
│         │ tonight │ + going │
└─────────┴─────────┴─────────┘
```

Same FirstVue account / `fv_msg_*` data. This shell is for out-and-about.

---

## Bottom nav (only these)

| Icon | Tab | Job |
| --- | --- | --- |
| Map pin | **Now** | Live map + one prominent nearby jump-in |
| People / spark | **Gather** | Near you + Tonight join-chat |
| Calendar | **Events** | Featured event + upcoming with faces & counts |

**Removed:** Home tab, inbox-as-home, quick-chat home stacks on Now.

---

## 1. Now = Map A + D (no home)

**Chosen pieces:** hero live energy (A) + map peek / sheet (D).  
**Cut:** quick chats / home list under the map.

```
┌──────────────────────────┐
│ FirstVue            Now  │
│ ┌──────────────────────┐ │
│ │   MAP (night)        │ │
│ │   ● you   ✦ LIVE pin │ │
│ └──────────────────────┘ │
│ ── sheet ─────────────── │
│ Lake Night Market  LIVE  │
│ 6 min · 48 in chat       │
│ [ Jump in chat ]         │
│                          │
│ (nothing else — no home) │
├──────────────────────────┤
│  ◎Now   ○Gather  ○Events │
└──────────────────────────┘
```

**Interactions**
- Pan/zoom map; tap LIVE pin → same sheet focuses that gathering  
- **Jump in chat** → event conversation  
- No DM inbox on this tab  

**PNG:** `fv-final-01-now-map.png`

---

## 2. Gather = B + C Tonight

**Chosen pieces:** horizontal Near you (B) + Tonight grid (C).

```
┌──────────────────────────┐
│ Gather                   │
│ Near you                 │
│ (○) (○) (○) (○)  scroll  │
│                          │
│ [ Near ] [ Live ][Tonight]│
│                          │
│ Tonight                  │
│ ┌─────┐ ┌─────┐          │
│ │evt  │ │evt  │  Join    │
│ └─────┘ └─────┘          │
│ ┌─────┐ ┌─────┐          │
│ │evt  │ │evt  │  Join    │
│ └─────┘ └─────┘          │
├──────────────────────────┤
│  ○Now   ◎Gather  ○Events │
└──────────────────────────┘
```

**Interactions**
- Horizontal Near you → open / join that chat  
- Chips filter Near · Live · Tonight  
- Grid tile **Join chat** → gathering thread  

**PNG:** `fv-final-02-gather.png`

---

## 3. Events = C Featured + upcoming (faces & counts)

**Why this wins:** one prominent event on top; **Upcoming gatherings** is its own section with **profile photos of who’s going + total count**.

```
┌──────────────────────────┐
│ FirstVue · Events        │
│ ┌──────────────────────┐ │
│ │ FEATURED (wide)      │ │
│ │ Lake Night Market    │ │
│ │ LIVE  [ Join chat ]  │ │
│ └──────────────────────┘ │
│                          │
│ Upcoming gatherings      │
│ Rooftop Set              │
│ (☺☺☺) 24 going    Tonight│
│ Community Brunch         │
│ (☺☺☺) 18 going    Sat    │
│ Open Mic                 │
│ (☺☺) 9 going      Tonight│
├──────────────────────────┤
│  ○Now   ○Gather  ◎Events │
└──────────────────────────┘
```

**Interactions**
- Featured **Join chat** / tap image → that event thread  
- Upcoming row → event detail / chat  
- Face stack → who’s going sheet  

**PNG:** `fv-final-03-events-clean.png` (preferred; no top Messages tab — sections only via bottom icons)

---

## One product map

```
Launch → last tab or Now
  Now     → map + sheet → Jump in chat → event thread
  Gather  → near / tonight → Join chat → gathering thread
  Events  → featured / upcoming → Join or row → event thread
```

Threads (DM, business inbox, settings) can open from inside a chat or a later **overflow** control — not as a fourth “Home” tab.

---

## File index

| Tab | Markup above | Mockup |
| --- | --- | --- |
| Now | §1 | `messaging-app-mockups/fv-final-01-now-map.png` |
| Gather | §2 | `messaging-app-mockups/fv-final-02-gather.png` |
| Events | §3 | `messaging-app-mockups/fv-final-03-events-clean.png` |
