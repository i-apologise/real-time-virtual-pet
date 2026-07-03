class_name LifeState
extends RefCounted
## Authoritative survival LifeState string names (StringName-friendly constants).
## No HIBERNATING in MVP.

const HEALTHY := &"HEALTHY"
const NEEDY := &"NEEDY"
const CRITICAL := &"CRITICAL"
const DYING := &"DYING"
const DEAD := &"DEAD"

const ALL: Array[StringName] = [HEALTHY, NEEDY, CRITICAL, DYING, DEAD]


static func is_alive(state: StringName) -> bool:
	return state != DEAD


static func is_terminal(state: StringName) -> bool:
	return state == DEAD
