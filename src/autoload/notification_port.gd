extends Node
## No-op OS notification port (MVP). Behind flag.

const ENABLE_OS_NOTIFICATIONS := false


func notify_critical_if_unfocused(title: String, body: String) -> void:
	if not ENABLE_OS_NOTIFICATIONS:
		return
	print("[NotificationPort] ", title, " — ", body)
