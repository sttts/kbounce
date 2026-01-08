#!/usr/bin/env python3
"""
Render sprite sheet from the ball_scene.blend file.
Run with: blender --background ball_scene.blend --python render_from_blend.py

Uses the .blend file as the source of truth - just renders the animation.
"""

import bpy
import os
import tempfile
import shutil

# Configuration
FRAME_COUNT = 25
OUTPUT_DIR = os.path.dirname(os.path.abspath(__file__))
OUTPUT_FILE = os.path.join(OUTPUT_DIR, "..", "assets", "themes", "classic", "ball_new.png")


def setup_render_for_sprite():
    """Ensure render settings are correct for sprite output."""
    scene = bpy.context.scene

    # Make sure we render with transparent background
    scene.render.film_transparent = True
    scene.render.image_settings.file_format = 'PNG'
    scene.render.image_settings.color_mode = 'RGBA'

    # Hide background plane if it exists
    bg_plane = bpy.data.objects.get("BackgroundPlane")
    if bg_plane:
        bg_plane.hide_render = True


def render_sprite_sheet():
    """Render all frames and combine into sprite sheet."""
    scene = bpy.context.scene
    temp_dir = tempfile.mkdtemp()

    # Get frame size from render settings
    frame_width = scene.render.resolution_x
    frame_height = scene.render.resolution_y

    print(f"Rendering {FRAME_COUNT} frames at {frame_width}x{frame_height}...")

    # Render each frame
    for frame in range(1, FRAME_COUNT + 1):
        scene.frame_set(frame)
        scene.render.filepath = os.path.join(temp_dir, f"frame_{frame:03d}.png")
        bpy.ops.render.render(write_still=True)
        print(f"  Frame {frame}/{FRAME_COUNT}")

    # Combine into horizontal sprite sheet
    print("Combining into sprite sheet...")

    # Load first frame to get dimensions
    first_frame = bpy.data.images.load(os.path.join(temp_dir, "frame_001.png"))
    width = first_frame.size[0]
    height = first_frame.size[1]

    # Create new image for sprite sheet
    sheet = bpy.data.images.new(
        name="SpriteSheet",
        width=width * FRAME_COUNT,
        height=height,
        alpha=True
    )

    # Copy pixels from each frame
    sheet_pixels = list(sheet.pixels)

    for frame in range(1, FRAME_COUNT + 1):
        frame_path = os.path.join(temp_dir, f"frame_{frame:03d}.png")
        frame_img = bpy.data.images.load(frame_path)
        frame_pixels = list(frame_img.pixels)

        # Copy frame pixels to sprite sheet
        x_offset = (frame - 1) * width
        for y in range(height):
            for x in range(width):
                src_idx = (y * width + x) * 4
                dst_idx = (y * width * FRAME_COUNT + x_offset + x) * 4
                sheet_pixels[dst_idx:dst_idx+4] = frame_pixels[src_idx:src_idx+4]

        bpy.data.images.remove(frame_img)

    sheet.pixels = sheet_pixels

    # Save sprite sheet
    os.makedirs(os.path.dirname(OUTPUT_FILE), exist_ok=True)
    sheet.filepath_raw = OUTPUT_FILE
    sheet.file_format = 'PNG'
    sheet.save()

    print(f"Sprite sheet saved to: {OUTPUT_FILE}")

    # Cleanup
    bpy.data.images.remove(first_frame)
    bpy.data.images.remove(sheet)
    shutil.rmtree(temp_dir)


def main():
    print("=" * 50)
    print("Sprite Sheet Renderer (from .blend file)")
    print("=" * 50)

    setup_render_for_sprite()
    render_sprite_sheet()

    print("Done!")


if __name__ == "__main__":
    main()
