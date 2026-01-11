# share_manager.gd - Cross-platform share functionality (Autoload)
#
# SPDX-FileCopyrightText: 2025 Stefan Schimanski <1Stein@gmx.de>
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0

extends Node

signal share_completed(success: bool)


signal show_notification(message: String)


func share_score(score: int, level: int, screenshot: Image = null):
	var balls := level + 1
	var text := "I scored %s points with %d balls in KBounce! Can you beat my score?\n\nPlay now: https://kbounce.app" % [_format_score(score), balls]

	if OS.has_feature("web"):
		_share_web(text, screenshot)
	elif OS.has_feature("ios") or OS.has_feature("android"):
		_share_mobile(text, screenshot)
	else:
		_share_desktop(text, screenshot)


func _share_web(text: String, screenshot: Image):
	if screenshot != null:
		var png_data := screenshot.save_png_to_buffer()
		var base64 := Marshalls.raw_to_base64(png_data)

		var js_code := """
		(async function() {
			try {
				const base64 = '%s';
				const byteString = atob(base64);
				const ab = new ArrayBuffer(byteString.length);
				const ia = new Uint8Array(ab);
				for (let i = 0; i < byteString.length; i++) {
					ia[i] = byteString.charCodeAt(i);
				}
				const blob = new Blob([ab], {type: 'image/png'});
				const file = new File([blob], 'kbounce-score.png', {type: 'image/png'});

				if (navigator.canShare && navigator.canShare({files: [file]})) {
					await navigator.share({
						title: 'KBounce Score',
						text: '%s',
						files: [file]
					});
					return 'success';
				} else if (navigator.share) {
					await navigator.share({
						title: 'KBounce Score',
						text: '%s',
						url: 'https://kbounce.app'
					});
					return 'success';
				} else {
					return 'no_api';
				}
			} catch (e) {
				if (e.name === 'AbortError') {
					return 'cancelled';
				}
				return 'error:' + e.message;
			}
		})();
		""" % [base64, text.replace("'", "\\'").replace("\n", "\\n"), text.replace("'", "\\'").replace("\n", "\\n")]

		var result = JavaScriptBridge.eval(js_code)
		share_completed.emit(str(result) == "success")
	else:
		var js_code := """
		(async function() {
			try {
				if (navigator.share) {
					await navigator.share({
						title: 'KBounce Score',
						text: '%s',
						url: 'https://kbounce.app'
					});
					return 'success';
				} else {
					return 'no_api';
				}
			} catch (e) {
				if (e.name === 'AbortError') {
					return 'cancelled';
				}
				return 'error:' + e.message;
			}
		})();
		""" % text.replace("'", "\\'").replace("\n", "\\n")

		var result = JavaScriptBridge.eval(js_code)
		share_completed.emit(str(result) == "success")


func _share_mobile(text: String, screenshot: Image):
	# Check for native share plugin (godot-ios-share-plugin / godot-android-share-plugin)
	if Engine.has_singleton("SharePlugin"):
		var share_plugin = Engine.get_singleton("SharePlugin")
		var share_data := {
			"title": "KBounce Score",
			"subject": "My KBounce Score",
			"content": text
		}
		if screenshot != null:
			# Save image to user:// directory (required by plugins)
			screenshot.save_png("user://share_screenshot.png")
			# Get absolute path for plugin
			share_data["file_path"] = OS.get_user_data_dir().path_join("share_screenshot.png")
			share_data["mime_type"] = "image/png"
		else:
			share_data["mime_type"] = "text/plain"
		share_plugin.share(share_data)
		share_completed.emit(true)
	else:
		# No native plugin - fall back to clipboard
		if screenshot != null:
			screenshot.save_png("user://share_screenshot.png")
		DisplayServer.clipboard_set(text)
		share_completed.emit(true)


func _share_desktop(text: String, screenshot: Image):
	var saved_path := ""

	# Save screenshot to Downloads folder
	if screenshot != null:
		var downloads_path := _get_downloads_path()
		if not downloads_path.is_empty():
			var timestamp := Time.get_datetime_string_from_system().replace(":", "-").replace("T", "_")
			var filename := "kbounce-score-%s.png" % timestamp
			saved_path = downloads_path.path_join(filename)
			screenshot.save_png(saved_path)

	# Copy text to clipboard
	DisplayServer.clipboard_set(text)

	# Show notification about where files were saved
	if not saved_path.is_empty():
		show_notification.emit("Screenshot saved to %s\nText copied to clipboard" % saved_path)
	else:
		show_notification.emit("Text copied to clipboard")

	share_completed.emit(true)


func _get_downloads_path() -> String:
	var os_name := OS.get_name()

	if os_name == "macOS" or os_name == "Linux":
		var home := OS.get_environment("HOME")
		if not home.is_empty():
			return home.path_join("Downloads")
	elif os_name == "Windows":
		var userprofile := OS.get_environment("USERPROFILE")
		if not userprofile.is_empty():
			return userprofile.path_join("Downloads")

	return ""


func _format_score(score: int) -> String:
	var s := str(score)
	var result := ""
	var count := 0
	for i in range(s.length() - 1, -1, -1):
		if count > 0 and count % 3 == 0:
			result = "," + result
		result = s[i] + result
		count += 1
	return result


func share_logs():
	var logs := _get_logs()
	if logs.is_empty():
		show_notification.emit("No logs available")
		share_completed.emit(false)
		return

	if OS.has_feature("web"):
		_share_logs_web(logs)
	elif OS.has_feature("ios") or OS.has_feature("android"):
		_share_logs_mobile(logs)
	else:
		_share_logs_desktop(logs)


func _get_logs() -> String:
	# Try to read Godot's log file
	var log_path := "user://logs/godot.log"
	if FileAccess.file_exists(log_path):
		var file := FileAccess.open(log_path, FileAccess.READ)
		if file:
			var content := file.get_as_text()
			# Return last 50KB to avoid huge files
			if content.length() > 50000:
				content = "...[truncated]...\n" + content.substr(content.length() - 50000)
			return content
	return ""


func _share_logs_web(logs: String):
	var escaped := logs.replace("\\", "\\\\").replace("'", "\\'").replace("\n", "\\n").replace("\r", "")
	var js_code := """
	(async function() {
		try {
			const logs = '%s';
			const blob = new Blob([logs], {type: 'text/plain'});
			const file = new File([blob], 'kbounce-logs.txt', {type: 'text/plain'});

			if (navigator.canShare && navigator.canShare({files: [file]})) {
				await navigator.share({
					title: 'KBounce Logs',
					files: [file]
				});
				return 'success';
			} else if (navigator.share) {
				await navigator.share({
					title: 'KBounce Logs',
					text: logs.substring(0, 1000) + '...[truncated for sharing]'
				});
				return 'success';
			} else {
				return 'no_api';
			}
		} catch (e) {
			if (e.name === 'AbortError') {
				return 'cancelled';
			}
			return 'error:' + e.message;
		}
	})();
	""" % escaped

	var result = JavaScriptBridge.eval(js_code)
	if str(result) == "no_api":
		DisplayServer.clipboard_set(logs)
		show_notification.emit("Logs copied to clipboard")
	share_completed.emit(str(result) == "success")


func _share_logs_mobile(logs: String):
	# Save logs to file for sharing
	var file := FileAccess.open("user://kbounce-logs.txt", FileAccess.WRITE)
	if file:
		file.store_string(logs)
		file.close()

	if Engine.has_singleton("SharePlugin"):
		var share_plugin = Engine.get_singleton("SharePlugin")
		var share_data := {
			"title": "KBounce Logs",
			"subject": "KBounce Debug Logs",
			"content": "KBounce debug logs attached",
			"file_path": OS.get_user_data_dir().path_join("kbounce-logs.txt"),
			"mime_type": "text/plain"
		}
		share_plugin.share(share_data)
		share_completed.emit(true)
	else:
		DisplayServer.clipboard_set(logs)
		show_notification.emit("Logs copied to clipboard")
		share_completed.emit(true)


func _share_logs_desktop(logs: String):
	var downloads_path := _get_downloads_path()
	var saved_path := ""

	if not downloads_path.is_empty():
		var timestamp := Time.get_datetime_string_from_system().replace(":", "-").replace("T", "_")
		var filename := "kbounce-logs-%s.txt" % timestamp
		saved_path = downloads_path.path_join(filename)
		var file := FileAccess.open(saved_path, FileAccess.WRITE)
		if file:
			file.store_string(logs)
			file.close()

	DisplayServer.clipboard_set(logs)

	if not saved_path.is_empty():
		show_notification.emit("Logs saved to %s\nAlso copied to clipboard" % saved_path)
	else:
		show_notification.emit("Logs copied to clipboard")

	share_completed.emit(true)
