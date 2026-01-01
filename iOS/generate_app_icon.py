#!/usr/bin/env python3
"""
Generate app icon for AI Translate iOS app.
Creates a modern translation-themed icon with speech bubbles.
"""

import os
import math

try:
    from PIL import Image, ImageDraw, ImageFont
except ImportError:
    print("Installing Pillow...")
    os.system("pip3 install Pillow")
    from PIL import Image, ImageDraw, ImageFont


def create_app_icon(size=1024):
    """Create a translation app icon with speech bubbles and arrow."""

    # Create canvas with transparent background initially
    img = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    # Colors - Modern gradient-like appearance using the app's accent color theme
    primary_color = (0, 122, 255)  # iOS blue (accent color)
    secondary_color = (88, 86, 214)  # Purple accent
    white = (255, 255, 255)
    light_blue = (230, 242, 255)

    # Draw rounded rectangle background with gradient effect
    # Create a radial gradient effect
    center = size // 2
    for i in range(size):
        for j in range(size):
            # Distance from center
            dist = math.sqrt((i - center) ** 2 + (j - center) ** 2)
            max_dist = math.sqrt(2) * center

            # Interpolate between primary and secondary color
            t = min(dist / max_dist, 1.0)
            r = int(primary_color[0] * (1 - t * 0.3) + secondary_color[0] * (t * 0.3))
            g = int(primary_color[1] * (1 - t * 0.5) + secondary_color[1] * (t * 0.5))
            b = int(primary_color[2] * (1 - t * 0.2) + secondary_color[2] * (t * 0.2))

            img.putpixel((j, i), (r, g, b, 255))

    # Apply iOS-style rounded corners
    corner_radius = size // 4.5
    mask = Image.new('L', (size, size), 0)
    mask_draw = ImageDraw.Draw(mask)
    mask_draw.rounded_rectangle(
        [(0, 0), (size - 1, size - 1)],
        radius=int(corner_radius),
        fill=255
    )
    img.putalpha(mask)

    draw = ImageDraw.Draw(img)

    # Calculate dimensions for speech bubbles
    margin = size * 0.12
    bubble_width = size * 0.38
    bubble_height = size * 0.28

    # Left speech bubble (source text)
    left_bubble_x = margin
    left_bubble_y = size * 0.22

    # Right speech bubble (translated text)
    right_bubble_x = size - margin - bubble_width
    right_bubble_y = size * 0.50

    bubble_radius = size * 0.06

    # Draw left speech bubble with tail
    draw.rounded_rectangle(
        [(left_bubble_x, left_bubble_y),
         (left_bubble_x + bubble_width, left_bubble_y + bubble_height)],
        radius=int(bubble_radius),
        fill=white
    )

    # Left bubble tail (pointing down-left)
    tail_points_left = [
        (left_bubble_x + bubble_width * 0.2, left_bubble_y + bubble_height),
        (left_bubble_x + bubble_width * 0.1, left_bubble_y + bubble_height + size * 0.08),
        (left_bubble_x + bubble_width * 0.35, left_bubble_y + bubble_height)
    ]
    draw.polygon(tail_points_left, fill=white)

    # Draw right speech bubble with tail
    draw.rounded_rectangle(
        [(right_bubble_x, right_bubble_y),
         (right_bubble_x + bubble_width, right_bubble_y + bubble_height)],
        radius=int(bubble_radius),
        fill=light_blue
    )

    # Right bubble tail (pointing up-right)
    tail_points_right = [
        (right_bubble_x + bubble_width * 0.65, right_bubble_y),
        (right_bubble_x + bubble_width * 0.9, right_bubble_y - size * 0.08),
        (right_bubble_x + bubble_width * 0.8, right_bubble_y)
    ]
    draw.polygon(tail_points_right, fill=light_blue)

    # Draw text lines in bubbles (representing text)
    line_color_left = (180, 180, 180)
    line_color_right = (120, 140, 180)
    line_height = size * 0.025
    line_margin = size * 0.04

    # Lines in left bubble
    for i in range(3):
        y = left_bubble_y + line_margin + (line_height + line_margin) * i + size * 0.03
        width_factor = [0.85, 0.7, 0.55][i]
        draw.rounded_rectangle(
            [(left_bubble_x + line_margin, y),
             (left_bubble_x + line_margin + bubble_width * width_factor, y + line_height)],
            radius=int(line_height / 2),
            fill=line_color_left
        )

    # Lines in right bubble
    for i in range(3):
        y = right_bubble_y + line_margin + (line_height + line_margin) * i + size * 0.03
        width_factor = [0.8, 0.65, 0.5][i]
        draw.rounded_rectangle(
            [(right_bubble_x + line_margin, y),
             (right_bubble_x + line_margin + bubble_width * width_factor, y + line_height)],
            radius=int(line_height / 2),
            fill=line_color_right
        )

    # Draw curved arrow between bubbles
    arrow_color = white
    arrow_width = size * 0.035

    # Arrow from left bubble to right bubble (curved path)
    # Using a bezier-like curve approximated with line segments
    start_x = left_bubble_x + bubble_width * 0.8
    start_y = left_bubble_y + bubble_height * 0.5
    end_x = right_bubble_x + bubble_width * 0.2
    end_y = right_bubble_y + bubble_height * 0.5

    # Control point for curve
    ctrl_x = (start_x + end_x) / 2 + size * 0.05
    ctrl_y = (start_y + end_y) / 2

    # Draw curved arrow body using thick line segments
    num_segments = 20
    points = []
    for t in range(num_segments + 1):
        t_norm = t / num_segments
        # Quadratic bezier
        x = (1-t_norm)**2 * start_x + 2*(1-t_norm)*t_norm * ctrl_x + t_norm**2 * end_x
        y = (1-t_norm)**2 * start_y + 2*(1-t_norm)*t_norm * ctrl_y + t_norm**2 * end_y
        points.append((x, y))

    # Draw the curve with circles for smooth appearance
    for i, (x, y) in enumerate(points[:-3]):
        draw.ellipse(
            [(x - arrow_width/2, y - arrow_width/2),
             (x + arrow_width/2, y + arrow_width/2)],
            fill=arrow_color
        )

    # Draw arrowhead
    arrow_head_size = size * 0.07
    # Calculate angle at the end of the curve
    dx = points[-1][0] - points[-3][0]
    dy = points[-1][1] - points[-3][1]
    angle = math.atan2(dy, dx)

    # Arrowhead points
    tip_x, tip_y = end_x + size * 0.02, end_y
    arrow_points = [
        (tip_x, tip_y),
        (tip_x - arrow_head_size * math.cos(angle - math.pi/6),
         tip_y - arrow_head_size * math.sin(angle - math.pi/6)),
        (tip_x - arrow_head_size * 0.6 * math.cos(angle),
         tip_y - arrow_head_size * 0.6 * math.sin(angle)),
        (tip_x - arrow_head_size * math.cos(angle + math.pi/6),
         tip_y - arrow_head_size * math.sin(angle + math.pi/6)),
    ]
    draw.polygon(arrow_points, fill=arrow_color)

    return img


def save_app_icons(base_path):
    """Generate and save all required app icon sizes."""

    # iOS requires a 1024x1024 icon, Xcode auto-generates other sizes
    sizes = {
        'AppIcon-1024.png': 1024,
        # Mac sizes for Catalyst support
        'AppIcon-16.png': 16,
        'AppIcon-32.png': 32,
        'AppIcon-64.png': 64,
        'AppIcon-128.png': 128,
        'AppIcon-256.png': 256,
        'AppIcon-512.png': 512,
    }

    icon_path = os.path.join(base_path, 'Resources', 'Assets.xcassets', 'AppIcon.appiconset')

    # Generate the master icon at highest resolution
    print("Generating app icon...")
    master_icon = create_app_icon(1024)

    for filename, size in sizes.items():
        if size == 1024:
            icon = master_icon
        else:
            icon = master_icon.resize((size, size), Image.Resampling.LANCZOS)

        filepath = os.path.join(icon_path, filename)
        icon.save(filepath, 'PNG')
        print(f"  Created {filename}")

    # Update Contents.json with filenames
    contents_json = '''{
  "images" : [
    {
      "filename" : "AppIcon-1024.png",
      "idiom" : "universal",
      "platform" : "ios",
      "size" : "1024x1024"
    },
    {
      "filename" : "AppIcon-16.png",
      "idiom" : "mac",
      "scale" : "1x",
      "size" : "16x16"
    },
    {
      "filename" : "AppIcon-32.png",
      "idiom" : "mac",
      "scale" : "2x",
      "size" : "16x16"
    },
    {
      "filename" : "AppIcon-32.png",
      "idiom" : "mac",
      "scale" : "1x",
      "size" : "32x32"
    },
    {
      "filename" : "AppIcon-64.png",
      "idiom" : "mac",
      "scale" : "2x",
      "size" : "32x32"
    },
    {
      "filename" : "AppIcon-128.png",
      "idiom" : "mac",
      "scale" : "1x",
      "size" : "128x128"
    },
    {
      "filename" : "AppIcon-256.png",
      "idiom" : "mac",
      "scale" : "2x",
      "size" : "128x128"
    },
    {
      "filename" : "AppIcon-256.png",
      "idiom" : "mac",
      "scale" : "1x",
      "size" : "256x256"
    },
    {
      "filename" : "AppIcon-512.png",
      "idiom" : "mac",
      "scale" : "2x",
      "size" : "256x256"
    },
    {
      "filename" : "AppIcon-512.png",
      "idiom" : "mac",
      "scale" : "1x",
      "size" : "512x512"
    },
    {
      "filename" : "AppIcon-1024.png",
      "idiom" : "mac",
      "scale" : "2x",
      "size" : "512x512"
    }
  ],
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}'''

    contents_path = os.path.join(icon_path, 'Contents.json')
    with open(contents_path, 'w') as f:
        f.write(contents_json)
    print(f"  Updated Contents.json")

    print("\nApp icon generation complete!")


if __name__ == '__main__':
    # Get the directory where this script is located
    script_dir = os.path.dirname(os.path.abspath(__file__))
    base_path = os.path.join(script_dir, 'AITranslate')

    save_app_icons(base_path)
