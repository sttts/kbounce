# test_i18n.gd - Unit tests for internationalization
#
# SPDX-FileCopyrightText: 2025 Stefan Schimanski <1Stein@gmx.de>
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0

extends RefCounted

const TestRunner = preload("res://tests/test_runner.gd")

# All translation files to check
const TRANSLATION_FILES := [
	"res://translations/de.po",
	"res://translations/fr.po",
	"res://translations/it.po",
	"res://translations/es.po",
	"res://translations/zh.po",
	"res://translations/is.po",
	"res://translations/pt.po",
	"res://translations/fi.po",
	"res://translations/sv.po",
	"res://translations/da.po",
	"res://translations/nl.po",
	"res://translations/pl.po",
	"res://translations/cs.po",
	"res://translations/ro.po",
	"res://translations/hu.po",
]


func test_all_translations_exist():
	var missing := []

	for po_path in TRANSLATION_FILES:
		var result := _check_po_file(po_path)
		if result.size() > 0:
			var lang: String = po_path.get_file().get_basename()
			for msgid in result:
				missing.append("%s: %s" % [lang, msgid.substr(0, 40)])

	if missing.size() > 0:
		return "Missing translations:\n    " + "\n    ".join(missing.slice(0, 10)) + \
			("\n    ... and %d more" % (missing.size() - 10) if missing.size() > 10 else "")
	return ""


func test_no_empty_msgstr():
	# Check that no translation has an empty msgstr (except for the header)
	var empty := []

	for po_path in TRANSLATION_FILES:
		var entries := _parse_po_file(po_path)
		var lang: String = po_path.get_file().get_basename()

		for entry in entries:
			var msgid: String = entry.get("msgid", "")
			var msgstr: String = entry.get("msgstr", "")

			# Skip header (empty msgid) and plurals
			if msgid.is_empty():
				continue

			if msgstr.is_empty():
				empty.append("%s: %s" % [lang, msgid.substr(0, 40)])

	if empty.size() > 0:
		return "Empty translations:\n    " + "\n    ".join(empty.slice(0, 10)) + \
			("\n    ... and %d more" % (empty.size() - 10) if empty.size() > 10 else "")
	return ""


func test_template_has_all_strings():
	# Check that messages.pot template exists and has entries
	var entries := _parse_po_file("res://translations/messages.pot")
	if entries.size() == 0:
		return "messages.pot is empty or missing"

	# Count non-header entries
	var count := 0
	for entry in entries:
		if not entry.get("msgid", "").is_empty():
			count += 1

	if count < 10:
		return "messages.pot has only %d entries, expected more" % count
	return ""


func test_all_po_files_have_same_msgids():
	# All .po files should have the same set of msgids as the template
	var template_ids := _get_msgids("res://translations/messages.pot")
	var errors := []

	for po_path in TRANSLATION_FILES:
		var po_ids := _get_msgids(po_path)
		var lang: String = po_path.get_file().get_basename()

		# Check for missing msgids in .po file
		for msgid in template_ids:
			if msgid not in po_ids:
				errors.append("%s missing: %s" % [lang, msgid.substr(0, 30)])

		# Check for extra msgids in .po file (not in template)
		for msgid in po_ids:
			if msgid not in template_ids:
				errors.append("%s extra: %s" % [lang, msgid.substr(0, 30)])

	if errors.size() > 0:
		return "Msgid mismatches:\n    " + "\n    ".join(errors.slice(0, 10)) + \
			("\n    ... and %d more" % (errors.size() - 10) if errors.size() > 10 else "")
	return ""


# =============================================================================
# Helper functions
# =============================================================================

## Parse a .po file and return list of {msgid, msgstr} entries
func _parse_po_file(path: String) -> Array:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return []

	var content := file.get_as_text()
	file.close()

	var entries := []
	var current_msgid := ""
	var current_msgstr := ""
	var in_msgid := false
	var in_msgstr := false

	for line in content.split("\n"):
		line = line.strip_edges()

		if line.begins_with("msgid "):
			# Save previous entry
			if in_msgstr:
				entries.append({"msgid": current_msgid, "msgstr": current_msgstr})

			# Start new msgid
			current_msgid = _extract_string(line.substr(6))
			current_msgstr = ""
			in_msgid = true
			in_msgstr = false

		elif line.begins_with("msgstr "):
			current_msgstr = _extract_string(line.substr(7))
			in_msgid = false
			in_msgstr = true

		elif line.begins_with("\"") and line.ends_with("\""):
			# Continuation line
			var continued := _extract_string(line)
			if in_msgid:
				current_msgid += continued
			elif in_msgstr:
				current_msgstr += continued

		elif line.is_empty() or line.begins_with("#"):
			# Empty line or comment - might end current entry
			pass

	# Don't forget the last entry
	if in_msgstr:
		entries.append({"msgid": current_msgid, "msgstr": current_msgstr})

	return entries


## Extract string content from a quoted PO string
func _extract_string(s: String) -> String:
	s = s.strip_edges()
	if s.begins_with("\"") and s.ends_with("\""):
		s = s.substr(1, s.length() - 2)
	# Handle escape sequences
	s = s.replace("\\n", "\n")
	s = s.replace("\\\"", "\"")
	s = s.replace("\\\\", "\\")
	return s


## Get set of all msgids from a .po file
func _get_msgids(path: String) -> Dictionary:
	var entries := _parse_po_file(path)
	var ids := {}
	for entry in entries:
		var msgid: String = entry.get("msgid", "")
		if not msgid.is_empty():
			ids[msgid] = true
	return ids


## Check a .po file for missing translations, returns list of missing msgids
func _check_po_file(path: String) -> Array:
	var entries := _parse_po_file(path)
	var missing := []

	for entry in entries:
		var msgid: String = entry.get("msgid", "")
		var msgstr: String = entry.get("msgstr", "")

		# Skip header (empty msgid)
		if msgid.is_empty():
			continue

		# Check for missing translation
		if msgstr.is_empty():
			missing.append(msgid)

	return missing
