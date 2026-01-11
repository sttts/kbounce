# kbounce-godot

## Testing
- Run `/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script tests/test_runner.gd` before every commit and ensure all tests pass.

## Export Settings
- Be careful when modifying export_presets.cfg - settings like `html/experimental_virtual_keyboard` are critical for mobile web functionality.
- The test suite includes checks for critical export settings.

## Mobile/Web Compatibility
- Always consider mobile (iOS, Android) and web platforms when making UI changes.
- Virtual keyboard support requires both scene properties (`virtual_keyboard_enabled`) and code (`DisplayServer.virtual_keyboard_show()`).
