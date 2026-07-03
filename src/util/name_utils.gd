class_name NameUtils
extends RefCounted
## Pet display name rules: min 2, max 16, strip control chars only.

const NAME_MIN_LEN := 2
const NAME_MAX_LEN := 16


## Strip control characters (ASCII < 32 and DEL). Edge-trim whitespace; interior spaces OK.
static func sanitize_name(raw: String) -> String:
	var out := ""
	for i in raw.length():
		var c: int = raw.unicode_at(i)
		if c < 32 or c == 127:
			continue
		out += String.chr(c)
	return out.strip_edges()


static func is_valid_name(raw: String) -> bool:
	var s := sanitize_name(raw)
	return s.length() >= NAME_MIN_LEN and s.length() <= NAME_MAX_LEN


## Returns sanitized name if valid, else empty string.
static func accepted_name_or_empty(raw: String) -> String:
	var s := sanitize_name(raw)
	if s.length() >= NAME_MIN_LEN and s.length() <= NAME_MAX_LEN:
		return s
	return ""
