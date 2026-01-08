#!/usr/bin/env python3
"""
Tweak ball material and re-render.
Run with: blender --background ball_scene.blend --python tweak_ball.py
"""

import bpy
import os
import tempfile
import shutil

OUTPUT_DIR = os.path.dirname(os.path.abspath(__file__))
OUTPUT_FILE = os.path.join(OUTPUT_DIR, "..", "assets", "themes", "classic", "ball_new.png")
FRAME_COUNT = 25


def tweak_white_material():
    """Adjust white material to show more shading/roundness."""
    mat = bpy.data.materials.get("GlassMaterial")
    if not mat or not mat.use_nodes:
        print("GlassMaterial not found!")
        return False

    # Find the WhiteBSDF node
    white_bsdf = mat.node_tree.nodes.get("WhiteBSDF")
    if not white_bsdf:
        print("WhiteBSDF node not found!")
        return False

    # Bright white with diffuse gradient
    white_bsdf.inputs['Emission Strength'].default_value = 0.85  # Brighter glow
    white_bsdf.inputs['Roughness'].default_value = 0.25
    print(f"Set white emission to 0.85, roughness to 0.25")

    return True


def tweak_lighting():
    """Adjust lighting for wide diffuse gradient on white side."""
    # Large, bright key light for diffuse glare
    key_light = bpy.data.objects.get("KeyLight")
    if key_light and key_light.data:
        key_light.data.energy = 200
        key_light.data.size = 5
        print(f"Set key light energy to 200, size to 5")

    # Lower fill light for shadow contrast
    fill_light = bpy.data.objects.get("FillLight")
    if fill_light and fill_light.data:
        fill_light.data.energy = 10
        print(f"Set fill light energy to 10")


def render_sprite_sheet():
    """Render all frames and combine into sprite sheet."""
    scene = bpy.context.scene

    # Make sure we render with transparent background
    scene.render.film_transparent = True
    scene.render.image_settings.file_format = 'PNG'
    scene.render.image_settings.color_mode = 'RGBA'

    # Hide background plane if it exists
    bg_plane = bpy.data.objects.get("BackgroundPlane")
    if bg_plane:
        bg_plane.hide_render = True

    temp_dir = tempfile.mkdtemp()

    frame_width = scene.render.resolution_x
    frame_height = scene.render.resolution_y

    print(f"Rendering {FRAME_COUNT} frames at {frame_width}x{frame_height}...")

    for frame in range(1, FRAME_COUNT + 1):
        scene.frame_set(frame)
        scene.render.filepath = os.path.join(temp_dir, f"frame_{frame:03d}.png")
        bpy.ops.render.render(write_still=True)
        print(f"  Frame {frame}/{FRAME_COUNT}")

    print("Combining into sprite sheet...")

    first_frame = bpy.data.images.load(os.path.join(temp_dir, "frame_001.png"))
    width = first_frame.size[0]
    height = first_frame.size[1]

    sheet = bpy.data.images.new(
        name="SpriteSheet",
        width=width * FRAME_COUNT,
        height=height,
        alpha=True
    )

    sheet_pixels = list(sheet.pixels)

    for frame in range(1, FRAME_COUNT + 1):
        frame_path = os.path.join(temp_dir, f"frame_{frame:03d}.png")
        frame_img = bpy.data.images.load(frame_path)
        frame_pixels = list(frame_img.pixels)

        x_offset = (frame - 1) * width
        for y in range(height):
            for x in range(width):
                src_idx = (y * width + x) * 4
                dst_idx = (y * width * FRAME_COUNT + x_offset + x) * 4
                sheet_pixels[dst_idx:dst_idx+4] = frame_pixels[src_idx:src_idx+4]

        bpy.data.images.remove(frame_img)

    sheet.pixels = sheet_pixels

    os.makedirs(os.path.dirname(OUTPUT_FILE), exist_ok=True)
    sheet.filepath_raw = OUTPUT_FILE
    sheet.file_format = 'PNG'
    sheet.save()

    print(f"Sprite sheet saved to: {OUTPUT_FILE}")

    bpy.data.images.remove(first_frame)
    bpy.data.images.remove(sheet)
    shutil.rmtree(temp_dir)


def main():
    print("=" * 50)
    print("Ball Tweaker - Adding roundness to white side")
    print("=" * 50)

    tweak_white_material()
    tweak_lighting()
    render_sprite_sheet()

    print("Done!")


if __name__ == "__main__":
    main()
