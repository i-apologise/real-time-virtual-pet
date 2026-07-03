extends Node
## Global signals for pet/profile/UI updates.

signal pet_updated(snapshot: Dictionary)
signal profile_updated(snapshot: Dictionary)
signal pet_mood_changed(mood: StringName)
signal care_performed(action: StringName, result: Dictionary)
signal life_state_changed(from: StringName, to: StringName)
signal pet_died(detail: Dictionary)
signal burial_completed(grave: Dictionary)
signal pet_adopted(snapshot: Dictionary)
signal time_anomaly(kind: StringName, detail: Dictionary)
signal needs_onboarding()
signal needs_adoption()
signal load_failed(reason: StringName)
signal status_message(text: String)
signal save_failed(reason: StringName)
