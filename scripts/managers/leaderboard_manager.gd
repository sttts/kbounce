# leaderboard_manager.gd - Online leaderboard manager (Autoload)
#
# SPDX-FileCopyrightText: 2025 Stefan Schimanski <1Stein@gmx.de>
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0

extends Node

## Emitted when user identity is ready
signal identity_ready(user_id: String, nickname: String)
## Emitted when game token is received
signal token_received(token: String)
## Emitted when token request fails
signal token_failed(error: String)
## Emitted when score is submitted (returns score_id and update_token for nickname updates)
signal score_submitted(score_id: String, update_token: String, rank: int, stored: bool)
## Emitted when score submission fails (request_id for bug reports)
signal score_failed(error: String, request_id: String)
## Emitted when nickname is updated
signal nickname_updated(success: bool, error: String)
## Emitted when leaderboard is loaded (entries around user, user_entries are all user's scores)
signal leaderboard_loaded(entries: Array, user_rank: int, user_entries: Array)
## Emitted when leaderboard load fails
signal leaderboard_failed(error: String)
## Emitted when report is submitted
signal report_submitted()
## Emitted when report fails
signal report_failed(error: String)
## Emitted when rate limited (retry_after in seconds)
signal rate_limited(retry_after: int)

## API base URL (from BuildInfo with dev defaults)
var API_URL: String:
	get: return BuildInfo.leaderboard_api_url

## Config file path for user identity
const CONFIG_PATH := "user://leaderboard.cfg"

## Funny name components for anonymous players
const ADJECTIVES := [
	"Lucky", "Bouncy", "Speedy", "Sleepy", "Grumpy", "Happy", "Sneaky", "Fluffy",
	"Mighty", "Tiny", "Giant", "Frozen", "Blazing", "Dancing", "Flying", "Jumping",
	"Lazy", "Crazy", "Dizzy", "Fuzzy", "Jolly", "Silly", "Wiggly", "Wobbly",
	"Cosmic", "Electric", "Mystic", "Rainbow", "Golden", "Silver", "Crystal", "Shadow",
	"Brave", "Clever", "Swift", "Noble", "Fierce", "Gentle", "Wild", "Calm",
	"Bright", "Dark", "Loud", "Quiet", "Hungry", "Thirsty", "Curious", "Cautious",
	"Daring", "Timid", "Bold", "Shy", "Proud", "Humble", "Fancy", "Plain",
	"Sparkly", "Glowing", "Shiny", "Dusty", "Rusty", "Fresh", "Ancient", "Young",
	"Wise", "Foolish", "Quick", "Slow", "Hot", "Cold", "Warm", "Cool",
	"Sweet", "Sour", "Spicy", "Salty", "Bitter", "Tangy", "Zesty", "Mellow",
	"Bubbly", "Fizzy", "Crunchy", "Squishy", "Bumpy", "Smooth", "Rough", "Soft",
	"Hyper", "Manic", "Chill", "Zen", "Funky", "Groovy", "Radical", "Epic"
]
const ANIMALS := [
	"Penguin", "Elephant", "Giraffe", "Kangaroo", "Dolphin", "Panda", "Koala", "Tiger",
	"Hamster", "Rabbit", "Squirrel", "Hedgehog", "Octopus", "Flamingo", "Pelican", "Toucan",
	"Raccoon", "Otter", "Sloth", "Lemur", "Walrus", "Narwhal", "Unicorn", "Dragon",
	"Phoenix", "Yeti", "Sasquatch", "Kraken", "Griffin", "Sphinx", "Chimera", "Pegasus",
	"Hippo", "Rhino", "Zebra", "Lion", "Leopard", "Cheetah", "Jaguar", "Panther",
	"Wolf", "Fox", "Bear", "Moose", "Deer", "Elk", "Bison", "Buffalo",
	"Gorilla", "Chimp", "Monkey", "Baboon", "Gibbon", "Orangutan", "Mandrill", "Tamarin",
	"Parrot", "Macaw", "Cockatoo", "Owl", "Eagle", "Hawk", "Falcon", "Vulture",
	"Shark", "Whale", "Seal", "Manatee", "Stingray", "Jellyfish", "Starfish", "Seahorse",
	"Turtle", "Tortoise", "Iguana", "Gecko", "Chameleon", "Cobra", "Python", "Viper",
	"Frog", "Toad", "Newt", "Axolotl", "Salamander", "Cricket", "Beetle", "Mantis",
	"Butterfly", "Moth", "Firefly", "Ladybug", "Dragonfly", "Bumblebee", "Wasp", "Ant"
]

## User's unique ID (UUID v4)
var user_id: String = ""
## User's display nickname
var nickname: String = ""
## User's country (from last score submission)
var country: String = ""
## User's city (from last score submission)
var city: String = ""
## Cached lowest score from user's top 10 (to skip replay for low scores)
var _cached_lowest_score: int = 0

## Current game token (single-use, expires after 30 min)
var _game_token: String = ""
## Token expiry timestamp
var _token_expires_at: int = 0
## Refresh token 5 minutes before expiry
const TOKEN_REFRESH_BUFFER := 300

## Current score's update token (for nickname updates)
var _current_score_id: String = ""
var _current_update_token: String = ""

## Pending screenshot for submission (resized to fixed width)
var pending_screenshot: Image = null
## Pending thumbnail for submission (small for leaderboard display)
var pending_thumbnail: Image = null
## Screenshot width (popup displays at 650px, slightly larger for quality)
const SCREENSHOT_WIDTH := 800
## Thumbnail width (leaderboard button is 48x32, we generate slightly larger for quality)
const THUMBNAIL_WIDTH := 96

## HTTP request nodes (created on demand)
var _http_token: HTTPRequest = null
var _http_score: HTTPRequest = null
var _http_nickname: HTTPRequest = null
var _http_leaderboard: HTTPRequest = null
var _http_report: HTTPRequest = null

## Request start times for duration tracking
var _request_start_times: Dictionary = {}
## Request URLs for logging in response handlers
var _request_urls: Dictionary = {}

## Debug: simulate network failure on next score upload
var debug_next_upload_fail_network: bool = false
## Debug: taint replay on next score upload to trigger server rejection
var debug_next_upload_taint_replay: bool = false


func _ready():
	_load_identity()


## Get standard HTTP headers with User-Agent
func _get_headers(content_type: bool = true) -> PackedStringArray:
	var headers := PackedStringArray()
	headers.append("User-Agent: KBounce/%s (%s)" % [BuildInfo.version_tag, OS.get_name()])
	if content_type:
		headers.append("Content-Type: application/json")
	return headers


## Load user identity from config file, or create new one
func _load_identity():
	var config := ConfigFile.new()
	var err := config.load(CONFIG_PATH)

	if err == OK:
		user_id = config.get_value("identity", "user_id", "")
		nickname = config.get_value("identity", "nickname", "")
		country = config.get_value("identity", "country", "")
		city = config.get_value("identity", "city", "")
		_cached_lowest_score = config.get_value("identity", "lowest_score", 0)

	# Generate new UUID if none exists
	if user_id.is_empty():
		user_id = _generate_uuid_v4()

	# Generate funny name if no nickname set
	if nickname.is_empty():
		nickname = _generate_funny_name(user_id.hash())

	_save_identity()

	if not user_id.is_empty():
		identity_ready.emit(user_id, nickname)


## Generate a funny random name from a seed (deterministic)
func _generate_funny_name(seed_value: int) -> String:
	var adj_idx := absi(seed_value) % ADJECTIVES.size()
	var animal_idx := (absi(seed_value) / ADJECTIVES.size()) % ANIMALS.size()
	return ADJECTIVES[adj_idx] + " " + ANIMALS[animal_idx]


## Save user identity to config file
func _save_identity():
	var config := ConfigFile.new()
	config.set_value("identity", "user_id", user_id)
	config.set_value("identity", "nickname", nickname)
	config.set_value("identity", "country", country)
	config.set_value("identity", "city", city)
	config.set_value("identity", "lowest_score", _cached_lowest_score)
	config.save(CONFIG_PATH)


## Update cached lowest score from user's entries
func _update_cached_lowest_score(user_entries: Array):
	if user_entries.size() >= 10:
		# User has 10 scores, cache the lowest
		var lowest := 999999999
		for entry in user_entries:
			var s: int = entry.get("score", 0)
			if s < lowest:
				lowest = s
		_cached_lowest_score = lowest
		_save_identity()
	elif user_entries.size() > 0:
		# Less than 10 scores, any new score will be stored
		_cached_lowest_score = 0


## Set the user's nickname locally (call update_nickname to sync to server)
func set_nickname(new_nickname: String):
	nickname = new_nickname.strip_edges()
	_save_identity()
	identity_ready.emit(user_id, nickname)


## Pending nickname waiting for server confirmation
var _pending_nickname: String = ""

## Update nickname on server for current score
func update_nickname(new_nickname: String):
	if _current_score_id.is_empty() or _current_update_token.is_empty():
		nickname_updated.emit(false, "No score to update")
		return

	# Store pending - only save locally after server confirms
	_pending_nickname = new_nickname.strip_edges()

	if _http_nickname == null:
		_http_nickname = HTTPRequest.new()
		add_child(_http_nickname)
		_http_nickname.request_completed.connect(_on_nickname_update_completed)

	var data := {
		"update_token": _current_update_token,
		"nickname": _pending_nickname
	}

	var body := JSON.stringify(data)
	var url := API_URL + "/score/" + _current_score_id
	_request_start_times["nickname"] = Time.get_ticks_msec()
	_request_urls["nickname"] = url
	print("[API] PATCH %s" % url)
	var err := _http_nickname.request(url, _get_headers(), HTTPClient.METHOD_PATCH, body)

	if err != OK:
		nickname_updated.emit(false, "HTTP request failed")


func _on_nickname_update_completed(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray):
	var duration: int = Time.get_ticks_msec() - int(_request_start_times.get("nickname", 0))
	var url: String = _request_urls.get("nickname", "/score")
	var request_id := _parse_request_id(headers)
	print("----> PATCH %s rc=%d dur=%dms size=%d req=%s" % [url, response_code, duration, body.size(), request_id])
	if result != HTTPRequest.RESULT_SUCCESS:
		var error_msg := "Request failed: %s" % _http_result_to_string(result)
		print("      ERROR: %s" % error_msg)
		nickname_updated.emit(false, error_msg)
		return

	if response_code == 429:
		var retry_after := _parse_retry_after(headers)
		rate_limited.emit(retry_after)
		nickname_updated.emit(false, "Rate limited")
		return

	if response_code != 200:
		var error_msg := _parse_error_response(body, response_code)
		print("      ERROR: %s" % error_msg)
		nickname_updated.emit(false, error_msg)
		return

	# Server confirmed - now save nickname locally
	nickname = _pending_nickname
	_pending_nickname = ""

	# Update local country/city from response
	var json = _parse_json_response(body, "nickname")
	if json != null:
		print("      response: %s" % JSON.stringify(json))
		if json.has("country"):
			country = json["country"]
		if json.has("city"):
			city = json["city"]
	_save_identity()

	nickname_updated.emit(true, "")


## Check if user has set a nickname
func has_nickname() -> bool:
	return not nickname.is_empty() and nickname.length() >= 3


## Generate a crypto-secure UUID v4
func _generate_uuid_v4() -> String:
	var crypto := Crypto.new()
	var bytes := crypto.generate_random_bytes(16)

	# Set version (4) and variant (RFC 4122)
	bytes[6] = (bytes[6] & 0x0f) | 0x40  # Version 4
	bytes[8] = (bytes[8] & 0x3f) | 0x80  # Variant RFC 4122

	# Format as UUID string
	var hex := bytes.hex_encode()
	return "%s-%s-%s-%s-%s" % [
		hex.substr(0, 8),
		hex.substr(8, 4),
		hex.substr(12, 4),
		hex.substr(16, 4),
		hex.substr(20, 12)
	]


## Request a game token before starting a game
func request_game_token():
	if user_id.is_empty():
		token_failed.emit("No user identity")
		return

	if _http_token == null:
		_http_token = HTTPRequest.new()
		add_child(_http_token)
		_http_token.request_completed.connect(_on_token_request_completed)

	var body := JSON.stringify({"user_id": user_id})
	var url := API_URL + "/token"
	_request_start_times["token"] = Time.get_ticks_msec()
	_request_urls["token"] = url
	print("[API] POST %s" % url)
	var err := _http_token.request(url, _get_headers(), HTTPClient.METHOD_POST, body)

	if err != OK:
		token_failed.emit("HTTP request failed: %d" % err)


func _on_token_request_completed(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray):
	var duration: int = Time.get_ticks_msec() - int(_request_start_times.get("token", 0))
	var url: String = _request_urls.get("token", "/token")
	var request_id := _parse_request_id(headers)
	print("----> POST %s rc=%d dur=%dms size=%d req=%s" % [url, response_code, duration, body.size(), request_id])
	if result != HTTPRequest.RESULT_SUCCESS:
		var error_msg := "Request failed: %s" % _http_result_to_string(result)
		print("      ERROR: %s" % error_msg)
		token_failed.emit(error_msg)
		return

	if response_code == 429:
		var retry_after := _parse_retry_after(headers)
		rate_limited.emit(retry_after)
		token_failed.emit("Rate limited")
		return

	if response_code != 200:
		var error_msg := _parse_error_response(body, response_code)
		print("      ERROR: %s" % error_msg)
		token_failed.emit(error_msg)
		return

	var json = _parse_json_response(body, "token")
	if json == null or not json.has("token"):
		token_failed.emit("Invalid response from server")
		return
	print("      response: %s" % JSON.stringify(json))

	_game_token = json["token"]
	var expires_in: int = json.get("expires_in", 1800)
	_token_expires_at = int(Time.get_unix_time_from_system()) + expires_in

	token_received.emit(_game_token)


## Check if we have a valid (unused, not expired) game token
func is_token_valid() -> bool:
	if _game_token.is_empty():
		return false
	if int(Time.get_unix_time_from_system()) >= _token_expires_at:
		_game_token = ""
		return false
	return true


## Check if token needs refreshing (within buffer time of expiry)
func should_refresh_token() -> bool:
	if _game_token.is_empty():
		return false
	var time_remaining := _token_expires_at - int(Time.get_unix_time_from_system())
	return time_remaining > 0 and time_remaining < TOKEN_REFRESH_BUFFER


## Capture screenshot from viewport for later submission
## Crop margin to exclude UI buttons on the right (in logical pixels)
const SCREENSHOT_RIGHT_CROP_LOGICAL := 60

func capture_screenshot(viewport: Viewport):
	# Capture immediately (synchronous) to avoid overlays appearing
	var image := viewport.get_texture().get_image()

	# Calculate scale factor between logical and actual pixels
	var logical_size := viewport.get_visible_rect().size
	var actual_size := Vector2(image.get_width(), image.get_height())
	var scale := actual_size.x / logical_size.x

	# Crop right side to exclude UI buttons (convert logical to actual pixels)
	var crop_pixels := int(SCREENSHOT_RIGHT_CROP_LOGICAL * scale)
	var crop_width := image.get_width() - crop_pixels
	image = image.get_region(Rect2i(0, 0, crop_width, image.get_height()))

	# Create thumbnail first (before resizing the main image)
	# Keep original aspect ratio, scale to THUMBNAIL_WIDTH
	var thumb := image.duplicate()
	var aspect := float(thumb.get_height()) / float(thumb.get_width())
	var thumb_height := int(THUMBNAIL_WIDTH * aspect)
	thumb.resize(THUMBNAIL_WIDTH, thumb_height, Image.INTERPOLATE_LANCZOS)
	pending_thumbnail = thumb

	# Resize to fixed width for consistent upload size (aspect ratio same as thumbnail)
	var screenshot_height := int(SCREENSHOT_WIDTH * aspect)
	image.resize(SCREENSHOT_WIDTH, screenshot_height, Image.INTERPOLATE_LANCZOS)
	pending_screenshot = image


## Submit score to leaderboard (can be called without nickname - update later via PATCH)
func submit_score(score: int, level: int):
	if score <= 0:
		# Score of 0 shouldn't be submitted (handled by GameManager skipping leaderboard)
		return

	# Skip /score if this won't beat user's lowest stored score - just load leaderboard
	if _cached_lowest_score > 0 and score <= _cached_lowest_score:
		print("[API] Skipping /score (score %d <= cached lowest %d), loading leaderboard" % [score, _cached_lowest_score])
		load_leaderboard("around_user", score)
		return

	# Debug: simulate network failure
	if debug_next_upload_fail_network:
		debug_next_upload_fail_network = false
		print("[API] DEBUG: Simulating network failure")
		score_failed.emit("Request failed: Can't connect to host", "debug-net-fail")
		return

	if not is_token_valid():
		score_failed.emit("No valid game token", "")
		return

	if _http_score == null:
		_http_score = HTTPRequest.new()
		add_child(_http_score)
		_http_score.request_completed.connect(_on_score_request_completed)

	# Prepare request body
	var data := {
		"token": _game_token,
		"user_id": user_id,
		"nickname": nickname,  # May be empty on first submission
		"score": score,
		"level": level,
		"platform": OS.get_name(),
		"os_version": OS.get_version(),
		"app_version": ProjectSettings.get_setting("application/config/version", "unknown")
	}

	# Add replay data for server-side verification (only if score might be stored)
	# Skip replay for scores that won't beat user's lowest stored score
	if _cached_lowest_score == 0 or score > _cached_lowest_score:
		var replay := ReplayManager.get_replay()
		if not replay.is_empty():
			# Debug: modify replay score to trigger server rejection (score mismatch)
			if debug_next_upload_taint_replay:
				debug_next_upload_taint_replay = false
				print("[API] DEBUG: Modifying replay score to cause mismatch")
				replay["score"] = score + 1000
			data["replay"] = replay

	# Dry-run mode for debug cheats (API processes but doesn't persist)
	if GameManager.debug_cheated:
		data["dry_run"] = true

	# Add screenshot if available (already resized to 50%)
	if pending_screenshot != null:
		var png_data := pending_screenshot.save_png_to_buffer()
		data["screenshot"] = Marshalls.raw_to_base64(png_data)
		pending_screenshot = null

	# Add thumbnail if available (small square for leaderboard)
	if pending_thumbnail != null:
		var thumb_data := pending_thumbnail.save_png_to_buffer()
		data["screenshot_thumbnail"] = Marshalls.raw_to_base64(thumb_data)
		pending_thumbnail = null

	# Clear token (single-use)
	_game_token = ""

	var body := JSON.stringify(data)
	var url := API_URL + "/score"
	_request_start_times["score"] = Time.get_ticks_msec()
	_request_urls["score"] = url
	print("[API] POST %s (%dKB)" % [url, body.length() / 1024])
	var err := _http_score.request(url, _get_headers(), HTTPClient.METHOD_POST, body)

	if err != OK:
		score_failed.emit("HTTP request failed: %d" % err, "")


func _on_score_request_completed(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray):
	var duration: int = Time.get_ticks_msec() - int(_request_start_times.get("score", 0))
	var url: String = _request_urls.get("score", "/score")
	var request_id := _parse_request_id(headers)
	print("----> POST %s rc=%d dur=%dms size=%d req=%s" % [url, response_code, duration, body.size(), request_id])
	if result != HTTPRequest.RESULT_SUCCESS:
		var error_msg := "Request failed: %s" % _http_result_to_string(result)
		print("      ERROR: %s" % error_msg)
		score_failed.emit(error_msg, request_id)
		return

	if response_code == 429:
		var retry_after := _parse_retry_after(headers)
		rate_limited.emit(retry_after)
		score_failed.emit("Rate limited", request_id)
		return

	if response_code != 200:
		var error_msg := _parse_error_response(body, response_code)
		print("      ERROR: %s" % error_msg)
		score_failed.emit(error_msg, request_id)
		return

	var json = _parse_json_response(body, "score")
	if json == null:
		score_failed.emit("Invalid response from server", request_id)
		return

	var score_id: String = json.get("score_id", "")
	var update_token: String = json.get("update_token", "")
	var rank: int = json.get("rank", 0)
	var stored: bool = json.get("stored", false)
	var dry_run: bool = json.get("dry_run", false)
	var verified: bool = json.get("verified", false)
	var entries: Array = json.get("entries", [])
	var user_entries: Array = json.get("user_entries", [])

	# Log response (summarize arrays to avoid huge output)
	print("      score_id=%s rank=%d stored=%s verified=%s dry_run=%s entries=%d user_entries=%d" % [
		score_id, rank, stored, verified, dry_run, entries.size(), user_entries.size()
	])

	# Store for later nickname updates
	_current_score_id = score_id
	_current_update_token = update_token

	# Update local country/city from response
	if json.has("country"):
		country = json["country"]
	if json.has("city"):
		city = json["city"]
	_save_identity()

	score_submitted.emit(score_id, update_token, rank, stored)

	# Emit leaderboard entries (always emit, even if empty, so UI can update)
	_update_cached_lowest_score(user_entries)
	leaderboard_loaded.emit(entries, rank, user_entries)


## Load leaderboard entries
## mode: "top" for top 10 global, "around_user" for entries around user's position
func load_leaderboard(mode: String = "around_user", around_score: int = 0):
	if user_id.is_empty():
		leaderboard_failed.emit("No user identity")
		return

	if _http_leaderboard == null:
		_http_leaderboard = HTTPRequest.new()
		add_child(_http_leaderboard)
		_http_leaderboard.request_completed.connect(_on_leaderboard_request_completed)

	var url := API_URL + "/leaderboard?user_id=" + user_id.uri_encode() + "&mode=" + mode
	if around_score > 0:
		url += "&score=" + str(around_score)
	_request_start_times["leaderboard"] = Time.get_ticks_msec()
	_request_urls["leaderboard"] = url
	print("[API] GET %s" % url)
	var err := _http_leaderboard.request(url, _get_headers(false))

	if err != OK:
		leaderboard_failed.emit("HTTP request failed: %d" % err)


func _on_leaderboard_request_completed(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray):
	var duration: int = Time.get_ticks_msec() - int(_request_start_times.get("leaderboard", 0))
	var url: String = _request_urls.get("leaderboard", "/leaderboard")
	var request_id := _parse_request_id(headers)
	print("----> GET %s rc=%d dur=%dms size=%d req=%s" % [url, response_code, duration, body.size(), request_id])
	if result != HTTPRequest.RESULT_SUCCESS:
		var error_msg := "Request failed: %s" % _http_result_to_string(result)
		print("      ERROR: %s" % error_msg)
		leaderboard_failed.emit(error_msg)
		return

	if response_code == 429:
		var retry_after := _parse_retry_after(headers)
		rate_limited.emit(retry_after)
		leaderboard_failed.emit("Rate limited")
		return

	if response_code != 200:
		var error_msg := _parse_error_response(body, response_code)
		print("      ERROR: %s" % error_msg)
		leaderboard_failed.emit(error_msg)
		return

	var json = _parse_json_response(body, "leaderboard")
	if json == null or not json.has("entries"):
		leaderboard_failed.emit("Invalid response from server")
		return

	var entries: Array = json["entries"]
	var user_rank: int = json.get("user_rank", 0)
	var user_entries: Array = json.get("user_entries", [])
	print("      user_rank=%d entries=%d user_entries=%d" % [user_rank, entries.size(), user_entries.size()])
	_update_cached_lowest_score(user_entries)

	leaderboard_loaded.emit(entries, user_rank, user_entries)


## Report a score entry for inappropriate content
func report_score(score_id: String):
	if user_id.is_empty():
		report_failed.emit("No user identity")
		return

	if _http_report == null:
		_http_report = HTTPRequest.new()
		add_child(_http_report)
		_http_report.request_completed.connect(_on_report_request_completed)

	var body := JSON.stringify({
		"score_id": score_id,
		"user_id": user_id
	})
	var url := API_URL + "/report"
	_request_start_times["report"] = Time.get_ticks_msec()
	_request_urls["report"] = url
	print("[API] POST %s" % url)
	var err := _http_report.request(url, _get_headers(), HTTPClient.METHOD_POST, body)

	if err != OK:
		report_failed.emit("HTTP request failed: %d" % err)


func _on_report_request_completed(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray):
	var duration: int = Time.get_ticks_msec() - int(_request_start_times.get("report", 0))
	var url: String = _request_urls.get("report", "/report")
	var request_id := _parse_request_id(headers)
	print("----> POST %s rc=%d dur=%dms size=%d req=%s" % [url, response_code, duration, body.size(), request_id])
	if result != HTTPRequest.RESULT_SUCCESS:
		var error_msg := "Request failed: %s" % _http_result_to_string(result)
		print("      ERROR: %s" % error_msg)
		report_failed.emit(error_msg)
		return

	if response_code == 429:
		var retry_after := _parse_retry_after(headers)
		rate_limited.emit(retry_after)
		report_failed.emit("Rate limited")
		return

	if response_code != 200:
		var error_msg := _parse_error_response(body, response_code)
		print("      ERROR: %s" % error_msg)
		report_failed.emit(error_msg)
		return

	var json = _parse_json_response(body, "report")
	if json != null:
		print("      response: %s" % JSON.stringify(json))
	report_submitted.emit()


## Parse Retry-After header value
func _parse_retry_after(headers: PackedStringArray) -> int:
	for header in headers:
		if header.to_lower().begins_with("retry-after:"):
			var value := header.substr(12).strip_edges()
			if value.is_valid_int():
				return value.to_int()
	return 60  # Default to 60 seconds


## Parse X-Request-Id header value
func _parse_request_id(headers: PackedStringArray) -> String:
	for header in headers:
		var lower := header.to_lower()
		if lower.begins_with("x-request-id:"):
			return header.substr(13).strip_edges()
		if lower.begins_with("cf-ray:"):
			return header.substr(7).strip_edges()
	return ""


## Parse error response body to extract error message
func _parse_error_response(body: PackedByteArray, response_code: int) -> String:
	var text := body.get_string_from_utf8()
	var json = JSON.parse_string(text)
	if json != null and json is Dictionary and json.has("error"):
		var error: String = json["error"]
		# Return user-friendly messages for known errors
		if error == "Nickname contains inappropriate content":
			return "Nickname not allowed"
		return error

	# Log non-JSON error response for debugging (e.g. HTML error pages from proxies)
	if not text.is_empty():
		var snippet := text.substr(0, 200)
		if text.length() > 200:
			snippet += "..."
		print("      Non-JSON error body: %s" % snippet)
	return "Server error: %d" % response_code


## Parse JSON response body, logging non-JSON content for debugging
func _parse_json_response(body: PackedByteArray, endpoint: String) -> Variant:
	var text := body.get_string_from_utf8()
	var json = JSON.parse_string(text)
	if json == null and not text.is_empty():
		# Log snippet of non-JSON response for debugging (e.g. HTML error pages)
		var snippet := text.substr(0, 200)
		if text.length() > 200:
			snippet += "..."
		print("      WARNING: Non-JSON response from %s: %s" % [endpoint, snippet])
	return json


## Convert HTTPRequest.Result to human-readable string
func _http_result_to_string(result: int) -> String:
	match result:
		HTTPRequest.RESULT_SUCCESS:
			return "Success"
		HTTPRequest.RESULT_CHUNKED_BODY_SIZE_MISMATCH:
			return "Chunked body size mismatch"
		HTTPRequest.RESULT_CANT_CONNECT:
			return "Can't connect to host"
		HTTPRequest.RESULT_CANT_RESOLVE:
			return "Can't resolve hostname"
		HTTPRequest.RESULT_CONNECTION_ERROR:
			return "Connection error"
		HTTPRequest.RESULT_TLS_HANDSHAKE_ERROR:
			return "TLS handshake error"
		HTTPRequest.RESULT_NO_RESPONSE:
			return "No response from server"
		HTTPRequest.RESULT_BODY_SIZE_LIMIT_EXCEEDED:
			return "Body size limit exceeded"
		HTTPRequest.RESULT_BODY_DECOMPRESS_FAILED:
			return "Body decompress failed"
		HTTPRequest.RESULT_REQUEST_FAILED:
			return "Request failed"
		HTTPRequest.RESULT_DOWNLOAD_FILE_CANT_OPEN:
			return "Can't open download file"
		HTTPRequest.RESULT_DOWNLOAD_FILE_WRITE_ERROR:
			return "Download file write error"
		HTTPRequest.RESULT_REDIRECT_LIMIT_REACHED:
			return "Redirect limit reached"
		HTTPRequest.RESULT_TIMEOUT:
			return "Request timeout"
		_:
			return "Unknown error (%d)" % result
