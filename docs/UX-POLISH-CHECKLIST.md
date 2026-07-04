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

## Fixed (need meters + ETAs)

- [x] Need meters show **numeric value** (not bar-only).
- [x] Per-need **ETA** (hungry / sleepy / lonely / dirty in Xm).
- [x] Summary line from `NeedsForecast` (e.g. hungry in 3h · sleepy in 5h).
- [x] Feed toast shows **Hunger now X/100** and real applied delta (after clamp).
- [x] Bar **green flash** when a need rises from care.

## Still open / nice-to-have (ideas)

- [ ] Cooldown remaining on CARE rows (“FEED · ready in 4m”).
- [ ] Auto-wake option on FEED (optional — currently must wake first).
- [ ] Grey CARE rows when energy too low for walk/play.
- [ ] CARE menu mouse click.
- [ ] SFX + particles on care success.
- [ ] Toast auto-clear after 3s.
- [ ] First-time tooltips collapse after N sessions.
- [ ] “Suggested care” tip (e.g. “Hunger low — FEED”).
- [ ] Day/night phase chip on HUD.
- [ ] Pet age / days owned.
- [ ] Leash thickness / town art / SFX (presentation).

### Why feed looked broken

Starter hunger is **80/100**; feed +30 **clamps to 100**. Bar can look “full already” without numbers. Cooldown is **10 minutes** real-time — second feed fails until ready. Fix: numbers + ETA + explicit toast.

## Rules for agents

1. Never show raw enum reasons (`PET_SLEEPING`) to players — always friendly copy.
2. Never start a multi-second care walk if the sim will reject the action.
3. State that blocks actions (sleep, dead, busy) must be **visible** (Zzz, death panel, timer).
4. Selected UI must pass a contrast check (light panel + dark text, or dark panel + light text — not both mid-grey).
