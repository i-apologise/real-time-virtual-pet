class_name CatchupResult
extends RefCounted
## Result of NeedsSimulator.run_catchup — pure sim never mutates profile.

var events: Array = []
var death_committed_this_call: bool = false
var death_detail: Dictionary = {}
var life_state_before: StringName = &""
var life_state_after: StringName = &""
var integrated_sec: float = 0.0
var stalled: bool = false
var stall_reason: StringName = &""
