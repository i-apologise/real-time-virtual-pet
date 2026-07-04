class_name SimConfig
extends RefCounted
## Global balance + death constants (Appendix A). Tunable in code only.

const STAT_MIN := 0.0
const STAT_MAX := 100.0
const ENABLE_SOFT_FLOOR := false
const STAT_FLOOR := 0.0  # unused while soft floor off

const NEEDY_THRESHOLD := 40.0
const CRITICAL_THRESHOLD := 15.0

const DEATH_AT_ZERO_HOLD_SEC := 21600.0  # 6 hours
const DEATH_MULTI_ZERO_HOLD_RATE := 2.0

const MAX_CATCHUP_SEC := 604800.0  # 7 days
const CHUNK_SEC := 60.0
const SIM_TICK_SEC := 2.0
const AUTOSAVE_SEC := 120.0

const ENERGY_SLEEP_REGEN_PER_HOUR := 12.0
const SLEEP_HUNGER_MULT := 0.5
const SLEEP_HAPPINESS_MULT := 0.5
const AUTO_WAKE_ENERGY := 95.0
## Must sleep at least this long (wall-clock) before energy-based auto-wake.
## Fixes "put to bed while energy high → reopen game already awake".
const MIN_SLEEP_SEC := 1800.0  # 30 minutes
const MAX_SLEEP_SEC := 36000.0  # 10 h

const FEED_HUNGER_DELTA := 30.0
const FEED_HYGIENE_DELTA := -2.0
const FEED_HAPPINESS_IF_WAS_NEEDY := 5.0
const FEED_COOLDOWN_SEC := 600.0
const FEED_DIMINISH_WINDOW_SEC := 1800.0
const FEED_DIMINISH_MULT := 0.5

const WALK_HAPPINESS_DELTA := 15.0
const WALK_DAY_BONUS_HAPPINESS := 3.0
const WALK_HUNGER_DELTA := -8.0
const WALK_ENERGY_DELTA := -12.0
const WALK_HYGIENE_DELTA := -10.0
const WALK_COOLDOWN_SEC := 1500.0
const WALK_MIN_ENERGY := 15.0

const PLAY_HAPPINESS_DELTA := 20.0
const PLAY_ENERGY_DELTA := -10.0
const PLAY_HUNGER_DELTA := -5.0
const PLAY_COOLDOWN_SEC := 900.0
const PLAY_MIN_ENERGY := 20.0

const CLEAN_HYGIENE_DELTA := 40.0
const CLEAN_HAPPINESS_IF_WAS_DIRTY := 5.0
const CLEAN_COOLDOWN_SEC := 300.0

const CROSS_HUNGER_LOW := 25.0
const CROSS_ENERGY_LOW := 20.0
const CROSS_HYGIENE_LOW := 20.0
const CROSS_HAPPINESS_EXTRA_PER_HOUR := 1.0
const CROSS_HUNGER_HAPPINESS_MULT := 1.5
const CROSS_ENERGY_HAPPINESS_MULT := 1.3

const NAME_MIN_LEN := 2
const NAME_MAX_LEN := 16
const GRAVEYARD_COLS := 20
const GRAVEYARD_ROWS := 20
const BURIAL_HOLD_SEC := 3.0
const ENABLE_LEGACY_HIBERNATION := false

## Default starter stats used when species does not override.
const DEFAULT_HUNGER := 80.0
const DEFAULT_ENERGY := 80.0
const DEFAULT_HAPPINESS := 70.0
const DEFAULT_HYGIENE := 80.0
