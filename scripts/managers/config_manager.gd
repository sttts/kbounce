# config_manager.gd - Remote configuration manager (Autoload)
#
# Fetches API URL from remote config on startup (if CONFIG_URL is set).
# Caches the result for offline support.
#
# SPDX-FileCopyrightText: 2025 Stefan Schimanski <1Stein@gmx.de>
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0

extends Node

## Emitted when config is ready (fetched, cached, or defaulted)
signal config_ready

## API base URL (resolved from remote config, cache, or default)
var api_url: String = "http://localhost:8787"

## Whether config has been resolved
var is_ready: bool = false

## Cache file path
const CACHE_PATH := "user://config_cache.json"

## Fetch timeout in seconds
const FETCH_TIMEOUT := 3.0

## HTTP request node
var _http: HTTPRequest = null


func _ready():
	if BuildInfo.config_url.is_empty():
		# No remote config URL - use localhost default
		print("[Config] No CONFIG_URL set, using localhost")
		is_ready = true
		config_ready.emit()
	else:
		# Fetch remote config
		print("[Config] Fetching config from %s" % BuildInfo.config_url)
		_fetch_config()


func _fetch_config():
	_http = HTTPRequest.new()
	_http.timeout = FETCH_TIMEOUT
	add_child(_http)
	_http.request_completed.connect(_on_fetch_completed)

	var headers := PackedStringArray([
		"User-Agent: KBounce/%s (%s)" % [BuildInfo.version_tag, OS.get_name()]
	])

	var err := _http.request(BuildInfo.config_url, headers)
	if err != OK:
		print("[Config] Failed to start request: %d" % err)
		_use_cached_or_default()


func _on_fetch_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray):
	if result != HTTPRequest.RESULT_SUCCESS:
		print("[Config] Fetch failed (result=%d), using cache/default" % result)
		_use_cached_or_default()
		return

	if response_code != 200:
		print("[Config] Fetch failed (status=%d), using cache/default" % response_code)
		_use_cached_or_default()
		return

	# Parse JSON response
	var text := body.get_string_from_utf8()
	var json = JSON.parse_string(text)
	if json == null or not json is Dictionary or not json.has("api_url"):
		print("[Config] Invalid config response, using cache/default")
		_use_cached_or_default()
		return

	var fetched_url: String = json["api_url"]
	if fetched_url.is_empty():
		print("[Config] Empty api_url in config, using cache/default")
		_use_cached_or_default()
		return

	# Success - use fetched URL and cache it
	api_url = fetched_url
	_save_to_cache(api_url)
	print("[Config] Using remote config: %s" % api_url)

	is_ready = true
	config_ready.emit()


func _use_cached_or_default():
	var cached := _load_from_cache()
	if not cached.is_empty():
		api_url = cached
		print("[Config] Using cached config: %s" % api_url)
	else:
		print("[Config] No cache, using default: %s" % api_url)

	is_ready = true
	config_ready.emit()


func _load_from_cache() -> String:
	if not FileAccess.file_exists(CACHE_PATH):
		return ""

	var file := FileAccess.open(CACHE_PATH, FileAccess.READ)
	if file == null:
		return ""

	var text := file.get_as_text()
	file.close()

	var json = JSON.parse_string(text)
	if json == null or not json is Dictionary or not json.has("api_url"):
		return ""

	return json["api_url"]


func _save_to_cache(url: String):
	var file := FileAccess.open(CACHE_PATH, FileAccess.WRITE)
	if file == null:
		print("[Config] Failed to save cache")
		return

	var data := {
		"api_url": url,
		"cached_at": Time.get_datetime_string_from_system()
	}
	file.store_string(JSON.stringify(data))
	file.close()
