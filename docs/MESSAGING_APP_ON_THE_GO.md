# FirstVue Messages — On-the-go design

This companion app is **not** a desk messenger clone. It’s for people already out: quick check-ins, “what’s happening now,” and easy talk while moving.

## Design intent

| Desk / web messaging | On-the-go Messages app |
| --- | --- |
| Dense inbox, many filters | Glanceable **Now** + short chat list |
| Long compose | One-tap **quick replies** |
| Event as a conversation type | **Gather** as a primary tab (near you / live) |
| Small rows | Big avatars, bold type, thumb-zone actions |
| Business inbox heavy | Still available, but not the home vibe |

**Voice:** warm, social, street-ready. Same FirstVue gold / teal / dark night palette — friendlier spacing and language (“What’s going on”, “I’m here”, “On my way”).

## Navigation

```
Now  ·  Chats  ·  Gather  ·  Me
```

- **Now** — live nearby + “what’s going on” + recent quick chats  
- **Chats** — people active now + unread-first list  
- **Gather** — near you / live / tonight gatherings → join chat  
- **Me** — status (Out · Downtown), quiet mode, location-while-out, open full FirstVue  

## Interaction patterns

1. **Glance** — open app → see live event + unread in one thumb scroll  
2. **Quick speak** — open thread → tap chip (`On my way`, `Running late`, `Where are you?`, `Be there in 5`)  
3. **Show up** — in live event chat → `I'm here` / `Share pin` / `Need help finding`  
4. **Find the night** — Gather → near-you list → Join chat  

## PNG mockups

| Screen | File |
| --- | --- |
| Now home | `fv-go-01-now-home.png` |
| Quick chats | `fv-go-02-quick-chats.png` |
| Quick-reply thread | `fv-go-03-quick-reply.png` |
| Gather near you | `fv-go-04-gather-near.png` |
| Live event chat | `fv-go-05-live-event.png` |
| Me / status | `fv-go-06-me-status.png` |

Folder: [`messaging-app-mockups/`](./messaging-app-mockups/)

Same account + same `fv_msg_*` data as web; this is a **friendlier mobile shell**, not a second identity.
