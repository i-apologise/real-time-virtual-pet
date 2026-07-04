# UX polish checklist (agent should fix without re-prompting)

Living list of player-facing papercuts. When changing care/HUD/nav, scan this list.

## Fixed (2026-07 — sleep / CARE menu)

- [x] **Feed/walk/play/clean while sleeping** no longer runs full choreography then `PET_SLEEPING` — gated up front with “Zzz… wake them first”.
- [x] **Zzz** label above pet while sleeping (bobbing Z/Zz/Zzz).
- [x] Stats title shows **[Zzz sleeping]** when asleep.
- [x] **CARE menu** high-contrast panel, red selected row, grey disabled actions.
- [x] While sleeping, only **WAKE** (+ CANCEL) enabled; cursor defaults to WAKE; ↑↓ skips disabled.
- [x] Friendly fail toasts (cooldown, energy, already awake/asleep).
- [x] Sleep pet animation **loops** (not one-shot).

## Still open / watch

- [ ] Cooldown remaining seconds in toast (sim already has `remaining_sec`).
- [ ] Auto-wake option on FEED (optional design — currently must wake first).
- [ ] Energy/hygiene thresholds shown on greyed menu rows (“too tired”).
- [ ] CARE menu clickable with mouse.
- [ ] SFX on care success / fail.
- [ ] Toast auto-clear after 3s.
- [ ] First-time tooltips collapse after N sessions.
- [ ] Leash thickness / visibility (playtest P1).
- [ ] Town/yard art still blocky (presentation, not logic).

## Rules for agents

1. Never show raw enum reasons (`PET_SLEEPING`) to players — always friendly copy.
2. Never start a multi-second care walk if the sim will reject the action.
3. State that blocks actions (sleep, dead, busy) must be **visible** (Zzz, death panel, timer).
4. Selected UI must pass a contrast check (light panel + dark text, or dark panel + light text — not both mid-grey).
