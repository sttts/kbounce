#!/usr/bin/env python3
"""
Blender script to render a glass ball animation sprite sheet.
Run with: blender --background --python render_ball.py

Output: ball_spritesheet.png (horizontal strip of 25 frames)
"""

import bpy
import math
import os

# Configuration
FRAME_COUNT = 25
FRAME_SIZE = 64  # pixels per frame
OUTPUT_DIR = os.path.dirname(os.path.abspath(__file__))
OUTPUT_FILE = os.path.join(OUTPUT_DIR, "..", "assets", "themes", "classic", "ball_new.png")

def clear_scene():
    """Remove all objects from scene."""
    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.object.delete()

    # Clear materials
    for material in bpy.data.materials:
        bpy.data.materials.remove(material)

def create_glass_ball():
    """Create a glass sphere with diagonal half white/half red glass."""
    # Create UV sphere
    bpy.ops.mesh.primitive_uv_sphere_add(
        radius=1,
        segments=64,
        ring_count=32,
        location=(0, 0, 0)
    )
    ball = bpy.context.active_object
    ball.name = "GlassBall"

    # Smooth shading
    bpy.ops.object.shade_smooth()

    # Create glass material
    mat = bpy.data.materials.new(name="GlassMaterial")
    mat.use_nodes = True
    nodes = mat.node_tree.nodes
    links = mat.node_tree.links

    # Clear default nodes
    nodes.clear()

    # Output node
    output = nodes.new('ShaderNodeOutputMaterial')
    output.location = (600, 0)

    # --- White milky half (80% color, 20% transparent) ---
    # Glossy white (opaque colored part)
    glossy_white = nodes.new('ShaderNodeBsdfGlossy')
    glossy_white.location = (-400, 300)
    glossy_white.inputs['Color'].default_value = (0.95, 0.95, 0.95, 1.0)  # White
    glossy_white.inputs['Roughness'].default_value = 0.3  # Milky/soft

    # Glass for transparency
    glass_white = nodes.new('ShaderNodeBsdfGlass')
    glass_white.location = (-400, 150)
    glass_white.inputs['Color'].default_value = (1.0, 1.0, 1.0, 1.0)
    glass_white.inputs['Roughness'].default_value = 0.0  # Sharp glass
    glass_white.inputs['IOR'].default_value = 1.45

    # Mix: 80% glossy (color), 20% glass (transparent)
    mix_white = nodes.new('ShaderNodeMixShader')
    mix_white.location = (-200, 200)
    mix_white.inputs['Fac'].default_value = 0.2  # 20% glass = 80% color
    links.new(glossy_white.outputs['BSDF'], mix_white.inputs[1])
    links.new(glass_white.outputs['BSDF'], mix_white.inputs[2])

    # --- Red colorful half (80% color, 20% transparent) ---
    # Glossy red (opaque colored part)
    glossy_red = nodes.new('ShaderNodeBsdfGlossy')
    glossy_red.location = (-400, -100)
    glossy_red.inputs['Color'].default_value = (0.532, 0.0, 0.0, 1.0)  # Deep red
    glossy_red.inputs['Roughness'].default_value = 0.15  # Shiny

    # Glass for transparency
    glass_red = nodes.new('ShaderNodeBsdfGlass')
    glass_red.location = (-400, -250)
    glass_red.inputs['Color'].default_value = (1.0, 0.3, 0.3, 1.0)  # Tinted
    glass_red.inputs['Roughness'].default_value = 0.0  # Sharp glass
    glass_red.inputs['IOR'].default_value = 1.45

    # Mix: 80% glossy (color), 20% glass (transparent)
    mix_red = nodes.new('ShaderNodeMixShader')
    mix_red.location = (-200, -100)
    mix_red.inputs['Fac'].default_value = 0.2  # 20% glass = 80% color
    links.new(glossy_red.outputs['BSDF'], mix_red.inputs[1])
    links.new(glass_red.outputs['BSDF'], mix_red.inputs[2])

    # --- Diagonal gradient for mixing ---
    # Use object coordinates
    tex_coord = nodes.new('ShaderNodeTexCoord')
    tex_coord.location = (-600, 0)

    # Separate XYZ to get coordinates
    separate = nodes.new('ShaderNodeSeparateXYZ')
    separate.location = (-400, 0)
    links.new(tex_coord.outputs['Object'], separate.inputs['Vector'])

    # Add X + Y for diagonal (X + Y > 0 means top-right)
    math_add = nodes.new('ShaderNodeMath')
    math_add.location = (-200, 0)
    math_add.operation = 'ADD'
    links.new(separate.outputs['X'], math_add.inputs[0])
    links.new(separate.outputs['Y'], math_add.inputs[1])

    # Sharp edge: use step function (greater than 0)
    math_step = nodes.new('ShaderNodeMath')
    math_step.location = (0, 0)
    math_step.operation = 'GREATER_THAN'
    math_step.inputs[1].default_value = 0.0  # Threshold at diagonal
    links.new(math_add.outputs['Value'], math_step.inputs[0])

    # Mix the two halves (white and red, each already 80% color / 20% glass)
    mix_shader = nodes.new('ShaderNodeMixShader')
    mix_shader.location = (200, 0)
    links.new(math_step.outputs['Value'], mix_shader.inputs['Fac'])
    links.new(mix_white.outputs['Shader'], mix_shader.inputs[1])
    links.new(mix_red.outputs['Shader'], mix_shader.inputs[2])

    # Connect directly to output (no fresnel - cleaner edges)
    links.new(mix_shader.outputs['Shader'], output.inputs['Surface'])

    # Assign material
    ball.data.materials.append(mat)

    return ball

def create_background_plane():
    """Create a white background plane for visualization (remove for final render)."""
    bpy.ops.mesh.primitive_plane_add(size=20, location=(0, 5, 0))
    plane = bpy.context.active_object
    plane.name = "BackgroundPlane"

    # Rotate to face camera
    plane.rotation_euler = (math.radians(90), 0, 0)

    # Create emissive white material (self-lit)
    mat = bpy.data.materials.new(name="WhiteMaterial")
    mat.use_nodes = True
    nodes = mat.node_tree.nodes
    links = mat.node_tree.links

    # Clear default nodes
    nodes.clear()

    # Emission shader for bright white
    emission = nodes.new('ShaderNodeEmission')
    emission.location = (0, 0)
    emission.inputs['Color'].default_value = (1.0, 1.0, 1.0, 1.0)
    emission.inputs['Strength'].default_value = 1.0  # White background

    # Output
    output = nodes.new('ShaderNodeOutputMaterial')
    output.location = (200, 0)
    links.new(emission.outputs['Emission'], output.inputs['Surface'])

    plane.data.materials.append(mat)
    return plane


def setup_lighting():
    """Create studio lighting for the ball."""
    # Key light (main)
    bpy.ops.object.light_add(type='AREA', location=(3, -2, 4))
    key_light = bpy.context.active_object
    key_light.name = "KeyLight"
    key_light.data.energy = 80
    key_light.data.size = 4
    key_light.data.color = (1.0, 1.0, 1.0)

    # Fill light (softer, opposite side)
    bpy.ops.object.light_add(type='AREA', location=(-3, 2, 2))
    fill_light = bpy.context.active_object
    fill_light.name = "FillLight"
    fill_light.data.energy = 40
    fill_light.data.size = 4
    fill_light.data.color = (1.0, 1.0, 1.0)

    # Rim light (behind, for edge definition)
    bpy.ops.object.light_add(type='AREA', location=(0, 3, 1))
    rim_light = bpy.context.active_object
    rim_light.name = "RimLight"
    rim_light.data.energy = 25
    rim_light.data.size = 2

    # Environment lighting - low ambient
    world = bpy.data.worlds.get("World")
    if world:
        world.use_nodes = True
        bg = world.node_tree.nodes.get("Background")
        if bg:
            bg.inputs['Color'].default_value = (0.5, 0.5, 0.5, 1.0)  # Grey ambient
            bg.inputs['Strength'].default_value = 0.5

def setup_camera():
    """Set up orthographic camera for sprite rendering."""
    bpy.ops.object.camera_add(location=(0, -5, 0))
    camera = bpy.context.active_object
    camera.name = "SpriteCamera"

    # Point at origin
    camera.rotation_euler = (math.radians(90), 0, 0)

    # Orthographic projection for consistent sprite size
    camera.data.type = 'ORTHO'
    camera.data.ortho_scale = 2.05  # Ball diameter is 2, tiny margin for antialiasing

    bpy.context.scene.camera = camera

    return camera

def setup_render_settings():
    """Configure render settings for sprite output."""
    scene = bpy.context.scene

    # Render engine
    scene.render.engine = 'CYCLES'
    scene.cycles.samples = 512  # High samples for sharp result
    scene.cycles.use_denoising = False  # Denoiser causes blur

    # Output settings
    scene.render.resolution_x = FRAME_SIZE
    scene.render.resolution_y = FRAME_SIZE
    scene.render.resolution_percentage = 100

    # Transparent background
    scene.render.film_transparent = True
    scene.render.image_settings.file_format = 'PNG'
    scene.render.image_settings.color_mode = 'RGBA'

def animate_ball(ball):
    """Add rotation animation to the ball using a parent empty for tilted axis."""
    scene = bpy.context.scene
    scene.frame_start = 1
    scene.frame_end = FRAME_COUNT

    # Create an empty to act as the tilted rotation axis
    bpy.ops.object.empty_add(type='PLAIN_AXES', location=(0, 0, 0))
    axis_empty = bpy.context.active_object
    axis_empty.name = "RotationAxis"

    # Tilt the empty 45° around Y - this tilts the rotation axis
    axis_empty.rotation_euler = (0, math.radians(45), 0)

    # Parent the ball to the empty
    ball.parent = axis_empty
    ball.matrix_parent_inverse.identity()  # Clear parent inverse

    # Reset ball rotation (it will inherit the tilt from parent)
    ball.rotation_euler = (0, 0, 0)

    # Animate the ball's local Z rotation
    ball.rotation_euler = (0, 0, 0)
    ball.keyframe_insert(data_path="rotation_euler", frame=1)

    ball.rotation_euler = (0, 0, math.radians(360))
    ball.keyframe_insert(data_path="rotation_euler", frame=FRAME_COUNT + 1)

    # Linear interpolation (skip if API changed in Blender 5.0+)
    try:
        if ball.animation_data and ball.animation_data.action:
            action = ball.animation_data.action
            for fcurve in action.fcurves:
                for keyframe in fcurve.keyframe_points:
                    keyframe.interpolation = 'LINEAR'
    except (AttributeError, TypeError) as e:
        print(f"Note: Could not set linear interpolation ({e}), using default")

def render_sprite_sheet():
    """Render all frames and combine into sprite sheet."""
    import tempfile
    import shutil

    scene = bpy.context.scene
    temp_dir = tempfile.mkdtemp()

    print(f"Rendering {FRAME_COUNT} frames...")

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
    print("Glass Ball Sprite Sheet Generator")
    print("=" * 50)

    clear_scene()
    ball = create_glass_ball()
    create_background_plane()  # White background for visualization (remove for final)
    setup_lighting()
    setup_camera()
    setup_render_settings()
    animate_ball(ball)
    render_sprite_sheet()

    print("Done!")

if __name__ == "__main__":
    main()
