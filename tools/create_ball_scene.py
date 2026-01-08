#!/usr/bin/env python3
"""
Blender script to create a glass ball scene for tweaking.
Run with: blender --background --python create_ball_scene.py

Output: ball_scene.blend (open in Blender to tweak, then render with render_ball.py)
"""

import bpy
import math
import os

OUTPUT_DIR = os.path.dirname(os.path.abspath(__file__))
OUTPUT_FILE = os.path.join(OUTPUT_DIR, "ball_scene.blend")

def clear_scene():
    """Remove all objects from scene."""
    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.object.delete()

    # Clear materials
    for material in bpy.data.materials:
        bpy.data.materials.remove(material)

def create_glass_ball():
    """Create a glass sphere with diagonal half white/half red - matching icon style."""
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

    # Create material matching icon style - clean, polished look
    mat = bpy.data.materials.new(name="GlassMaterial")
    mat.use_nodes = True
    nodes = mat.node_tree.nodes
    links = mat.node_tree.links

    # Clear default nodes
    nodes.clear()

    # Output node
    output = nodes.new('ShaderNodeOutputMaterial')
    output.location = (800, 0)

    # --- White half: Bright white with visible shading for roundness ---
    white_bsdf = nodes.new('ShaderNodeBsdfPrincipled')
    white_bsdf.location = (-200, 300)
    white_bsdf.name = "WhiteBSDF"
    # Pure bright white
    white_bsdf.inputs['Base Color'].default_value = (1.0, 1.0, 1.0, 1.0)
    white_bsdf.inputs['Roughness'].default_value = 0.15  # Slightly rougher to show more shading
    white_bsdf.inputs['IOR'].default_value = 1.45
    # No transmission - keep colors solid and vibrant
    white_bsdf.inputs['Transmission Weight'].default_value = 0.0
    # Reduced emission to let lighting create shadows and show roundness
    white_bsdf.inputs['Emission Color'].default_value = (1.0, 1.0, 1.0, 1.0)
    white_bsdf.inputs['Emission Strength'].default_value = 0.3  # Lower for visible shading

    # --- Red half: Bright strong red ---
    red_bsdf = nodes.new('ShaderNodeBsdfPrincipled')
    red_bsdf.location = (-200, -100)
    red_bsdf.name = "RedBSDF"
    # Bright strong red
    red_bsdf.inputs['Base Color'].default_value = (1.0, 0.0, 0.0, 1.0)  # Full red
    red_bsdf.inputs['Roughness'].default_value = 0.06  # Very shiny
    red_bsdf.inputs['IOR'].default_value = 1.45
    # No transmission - keep colors solid and vibrant
    red_bsdf.inputs['Transmission Weight'].default_value = 0.0
    # Strong emission for glow
    red_bsdf.inputs['Emission Color'].default_value = (0.7, 0.0, 0.0, 1.0)
    red_bsdf.inputs['Emission Strength'].default_value = 0.5

    # --- Diagonal gradient for mixing ---
    # Use object coordinates for consistent diagonal regardless of view
    tex_coord = nodes.new('ShaderNodeTexCoord')
    tex_coord.location = (-600, 100)

    # Separate XYZ to get coordinates
    separate = nodes.new('ShaderNodeSeparateXYZ')
    separate.location = (-400, 100)
    links.new(tex_coord.outputs['Object'], separate.inputs['Vector'])

    # Add X + Y for diagonal (X + Y > 0 means top-right = white)
    math_add = nodes.new('ShaderNodeMath')
    math_add.location = (-200, 100)
    math_add.operation = 'ADD'
    links.new(separate.outputs['X'], math_add.inputs[0])
    links.new(separate.outputs['Y'], math_add.inputs[1])

    # Sharp edge: use step function (greater than 0)
    math_step = nodes.new('ShaderNodeMath')
    math_step.location = (0, 100)
    math_step.operation = 'GREATER_THAN'
    math_step.inputs[1].default_value = 0.0  # Threshold at diagonal
    links.new(math_add.outputs['Value'], math_step.inputs[0])

    # Mix the two halves
    mix_shader = nodes.new('ShaderNodeMixShader')
    mix_shader.location = (400, 0)
    links.new(math_step.outputs['Value'], mix_shader.inputs['Fac'])
    links.new(red_bsdf.outputs['BSDF'], mix_shader.inputs[1])  # Red when Fac=0
    links.new(white_bsdf.outputs['BSDF'], mix_shader.inputs[2])  # White when Fac=1

    # Connect to output
    links.new(mix_shader.outputs['Shader'], output.inputs['Surface'])

    # Assign material
    ball.data.materials.append(mat)

    return ball

def create_background_plane():
    """Create a white background plane for visualization."""
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
    """Create studio lighting - with visible highlights and shadows for roundness."""
    # Main key light (upper left for specular highlight)
    bpy.ops.object.light_add(type='AREA', location=(-2, -3, 3))
    key_light = bpy.context.active_object
    key_light.name = "KeyLight"
    key_light.data.energy = 120  # Stronger for visible highlight
    key_light.data.size = 1.5  # Smaller for sharper, more defined highlight
    key_light.data.color = (1.0, 1.0, 1.0)
    # Point at ball
    key_light.rotation_euler = (math.radians(45), math.radians(-30), 0)

    # Soft fill light (lower, opposite side) - reduced to create more shadow
    bpy.ops.object.light_add(type='AREA', location=(3, -2, -1))
    fill_light = bpy.context.active_object
    fill_light.name = "FillLight"
    fill_light.data.energy = 15  # Lower for more shadow contrast
    fill_light.data.size = 5
    fill_light.data.color = (1.0, 1.0, 1.0)

    # Rim light (behind, subtle edge definition)
    bpy.ops.object.light_add(type='AREA', location=(0, 3, 0))
    rim_light = bpy.context.active_object
    rim_light.name = "RimLight"
    rim_light.data.energy = 25  # Slight increase for edge definition
    rim_light.data.size = 4

    # Environment lighting - reduced for more contrast
    world = bpy.data.worlds.get("World")
    if world:
        world.use_nodes = True
        bg = world.node_tree.nodes.get("Background")
        if bg:
            bg.inputs['Color'].default_value = (0.25, 0.25, 0.25, 1.0)  # Darker
            bg.inputs['Strength'].default_value = 0.3  # Lower ambient

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

    # Set viewport to camera view with material preview
    for area in bpy.context.screen.areas:
        if area.type == 'VIEW_3D':
            for space in area.spaces:
                if space.type == 'VIEW_3D':
                    space.region_3d.view_perspective = 'CAMERA'
                    space.shading.type = 'MATERIAL'  # Material preview mode
                    break

    return camera

def setup_render_settings():
    """Configure render settings for sprite output."""
    scene = bpy.context.scene

    # Render engine - Cycles for quality
    scene.render.engine = 'CYCLES'
    scene.cycles.samples = 256  # Good quality without excessive render time
    scene.cycles.use_denoising = True  # Use denoiser for cleaner result

    # Output settings
    scene.render.resolution_x = 64
    scene.render.resolution_y = 64
    scene.render.resolution_percentage = 100

    # Transparent background
    scene.render.film_transparent = True
    scene.render.image_settings.file_format = 'PNG'
    scene.render.image_settings.color_mode = 'RGBA'

def animate_ball(ball):
    """Add rotation animation to the ball using a parent empty for tilted axis."""
    scene = bpy.context.scene
    scene.frame_start = 1
    scene.frame_end = 25

    # Create an empty to act as the tilted rotation axis
    bpy.ops.object.empty_add(type='PLAIN_AXES', location=(0, 0, 0))
    axis_empty = bpy.context.active_object
    axis_empty.name = "RotationAxis"

    # Tilt the empty 45 around Y - this tilts the rotation axis
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
    ball.keyframe_insert(data_path="rotation_euler", frame=26)

    # Set linear interpolation for smooth rotation (Blender 5.0 API may differ)
    try:
        if ball.animation_data and ball.animation_data.action:
            for fcurve in ball.animation_data.action.fcurves:
                for keyframe in fcurve.keyframe_points:
                    keyframe.interpolation = 'LINEAR'
    except (AttributeError, TypeError):
        pass  # Skip if API changed


def main():
    print("=" * 50)
    print("Glass Ball Scene Creator")
    print("=" * 50)

    clear_scene()
    ball = create_glass_ball()
    create_background_plane()
    setup_lighting()
    setup_camera()
    setup_render_settings()
    animate_ball(ball)

    # Save the blend file
    bpy.ops.wm.save_as_mainfile(filepath=OUTPUT_FILE)
    print(f"Saved to: {OUTPUT_FILE}")
    print("Open in Blender, tweak as needed, then save.")
    print("Press Space to play animation, or drag timeline.")
    print("Done!")

if __name__ == "__main__":
    main()
