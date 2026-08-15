# FirstVue Messages — Dedicated App Markups

Companion app to FirstVue: same account, same encrypted conversations, event- and gathering-first UX. Reuses `fv_msg_*` + Supabase Auth (no separate identity).

## Visual mockups (PNG)

Phone layouts in FirstVue dark gold/teal branding live in [`messaging-app-mockups/`](./messaging-app-mockups/):

| Screen | File | Interaction |
| --- | --- | --- |
| Sign in | `fv-messages-01-signin.png` | Same FirstVue account |
| Messages inbox | `fv-messages-02-inbox.png` | Messages/Events toggle, identity, unread |
| Events hub | `fv-messages-03-events.png` | Live/going/hosting gatherings |
| Direct chat | `fv-messages-04-direct-chat.png` | Bubbles, media, reactions, call entry |
| Event chat | `fv-messages-05-event-chat.png` | Channels, pinned plan, who’s here |
| Business inbox | `fv-messages-06-entity-inbox.png` | Assign / tags / staff notes |
| Voice/video call | `fv-messages-07-call.png` | Mute, cam, end |
| Settings | `fv-messages-08-settings.png` | Devices, recovery, open full app |
| Compose | `fv-messages-09-compose.png` | People + businesses search |
| Message requests | `fv-messages-10-requests.png` | Accept / Decline / Block |

---

## 0. Product frame

```
┌─────────────────────────────────────┐
│  FirstVue Messages                  │
│  Communicate · Gather · Show up     │
│                                     │
│  Sign in with your FirstVue account │
│  Threads, events, and media sync   │
│  across web + this app.             │
└─────────────────────────────────────┘
```

**Auth:** email / username + password (existing Supabase session).  
**Sync:** same `fv_msg_*` rows + Realtime; device registers X25519 key → receives key envelopes → decrypts locally.  
**Migration:** legacy DMs import on-device (existing `fv_msg_migration` path); no re-upload of history by the user.

---

## 1. Sign in / device unlock

```
┌──────────────────────────┐
│  FirstVue Messages       │
│                          │
│  [ username / email    ] │
│  [ password            ] │
│                          │
│  [ Sign in ]             │
│                          │
│  First time on this      │
│  device? Keys are made   │
│  here; history unlocks   │
│  after key envelopes.    │
│                          │
│  [ Recover with phrase ] │
└──────────────────────────┘
```

Optional after first unlock: biometrics / PIN for local keystore only (not a second account).

---

## 2. Home shell (Messages | Events)

```
┌──────────────────────────┐
│ FV  Messages    Events   │  ← mode tabs
│ [ Search conversations ] │
│ Identity: You ▾          │  ← personal / business
├──────────────────────────┤
│ ● Jordan · Hey, you in?  │
│   Sat brunch · 2m        │
│ ○ Lake Run Crew          │
│   Event · Tonight 6pm    │
│ ○ Studio Blue inbox      │
│   Booking ask · 1h       │
│ ○ Maya · 👍 on photo     │
├──────────────────────────┤
│ [+]  Inbox  Calls  More  │
└──────────────────────────┘
```

**Filters (Messages mode):** Primary · Unread · Requests · Archived · Saved  
**Filters (Events mode):** Upcoming · Live · Past · Hosting · Going

---

## 3. Direct / group thread

```
┌──────────────────────────┐
│ ← Jordan        📞  📹 ⋮ │
│ personal · encrypted     │
├──────────────────────────┤
│              Sat 10:12   │
│     ┌───────────────┐    │
│     │ You free later?│   │
│     └───────────────┘    │
│ ┌───────────────────┐    │
│ │ Yeah — brunch?    │    │
│ └───────────────────┘    │
│     [ photo ]  ❤️ 😂     │
├──────────────────────────┤
│ [+]  Message…      Send  │
└──────────────────────────┘
```

**Thread ⋮:** mute · search · media · block · report · leave (groups)

---

## 4. New message / request

```
┌──────────────────────────┐
│ ← New message            │
│ [ Search people / biz ]  │
├──────────────────────────┤
│ People                   │
│  ○ Alex Rivera           │
│  ○ Sam Chen              │
│ Businesses               │
│  ○ Studio Blue           │
│  ○ Northside Gym         │
├──────────────────────────┤
│ Message requests (2)  →  │
└──────────────────────────┘
```

Requests: Accept · Decline · Block (same rules as web).

---

## 5. Events & gatherings hub

```
┌──────────────────────────┐
│ FV  Messages   [Events]  │
│ [ Search events ]        │
├──────────────────────────┤
│ LIVE · Lake Night Market │
│  48 in chat · Host: FV   │
│                          │
│ Tonight · Rooftop Set    │
│  Going · opens 5:30pm    │
│                          │
│ Sat · Community Brunch   │
│  Hosting · plan pinned   │
├──────────────────────────┤
│ [ Create gathering ]     │
└──────────────────────────┘
```

---

## 6. Event conversation

```
┌──────────────────────────┐
│ ← Lake Night Market   ⋮  │
│ Channels: General·Plans  │
├──────────────────────────┤
│ 📌 Meet at south gate    │
│    6:00 · Host           │
│                          │
│ Host: Gates open, come   │
│ through south.           │
│                          │
│ You: On my way 🚶        │
│                          │
│ [ Plans ] Who’s here (12)│
├──────────────────────────┤
│ [+]  Message…      Send  │
└──────────────────────────┘
```

**Features:** channels · pinned plan · RSVP / “who’s here” · host tools · media · mute event

---

## 7. Entity / business shared inbox

```
┌──────────────────────────┐
│ ← Studio Blue inbox      │
│ As: Studio Blue ▾        │
│ Open · Assigned · Closed │
├──────────────────────────┤
│ ● New booking · Taylor   │
│   “Sat 2pm available?”   │
│ ○ Follow-up · Chris      │
│   Assigned: you          │
├──────────────────────────┤
│ Internal notes (staff)   │
│ [ Assign ] [ Tag ] [✓]   │
└──────────────────────────┘
```

Staff-only notes never go to customers (existing note-epoch model).

---

## 8. Voice / video call

```
┌──────────────────────────┐
│                          │
│      ○ Jordan            │
│      Connecting…         │
│                          │
│   🔇   📷   ⟳   🔴      │
│  mute cam  flip  end     │
└──────────────────────────┘
```

1:1 WebRTC (existing `fv_call_service`); event/group calls = later phase.

---

## 9. Settings / safety

```
┌──────────────────────────┐
│ ← Messaging settings     │
│ Identities & devices     │
│ Notifications            │
│ Blocked accounts         │
│ Parental controls        │
│ Recovery phrase          │
│ Appearance               │
│ Open FirstVue (full app) │
│ Sign out                 │
└──────────────────────────┘
```

---

## Feature checklist (parity + app focus)

| Area | In markups | Notes |
| --- | --- | --- |
| Same FirstVue sign-in | ✓ | Supabase session shared |
| Direct / group / community | ✓ | `fv_msg` conversation kinds |
| Event & gathering chats | ✓ | App-home emphasis |
| Entity shared inbox | ✓ | Assign / tags / notes |
| E2EE + per-device keys | ✓ | Register device on install |
| Media + reactions | ✓ | Encrypted attachments |
| Message requests / blocks / reports | ✓ | |
| Voice & video | ✓ | 1:1 first |
| Parental / recovery | ✓ | |
| Seamless history | ✓ | Same backend; key envelopes to new device |
| Legacy DM migrate | ✓ | Existing on-device encrypt path |

---

## Suggested navigation map

```
SignIn → Shell
           ├─ Messages mode → Inbox → Thread | New | Requests
           ├─ Events mode   → Event list → Event thread (channels/plans)
           ├─ Calls         → Active / recent
           └─ More          → Settings, identity, open full FirstVue
```
```
