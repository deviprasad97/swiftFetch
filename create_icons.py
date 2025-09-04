#!/usr/bin/env python3

import os
from PIL import Image, ImageDraw, ImageFont
import math

def create_gradient_background(size, color1, color2):
    """Create a radial gradient background"""
    image = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(image)
    
    center_x, center_y = size // 2, size // 2
    max_radius = size // 2
    
    for r in range(max_radius, 0, -1):
        # Interpolate between colors
        ratio = r / max_radius
        r_color = int(color1[0] * ratio + color2[0] * (1 - ratio))
        g_color = int(color1[1] * ratio + color2[1] * (1 - ratio))
        b_color = int(color1[2] * ratio + color2[2] * (1 - ratio))
        
        draw.ellipse(
            [center_x - r, center_y - r, center_x + r, center_y + r],
            fill=(r_color, g_color, b_color, 255)
        )
    
    return image

def create_download_icon(size):
    """Create a modern download manager icon"""
    # Create base image with rounded corners
    image = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    
    # Create rounded rectangle mask
    mask = Image.new('L', (size, size), 0)
    mask_draw = ImageDraw.Draw(mask)
    corner_radius = size // 8
    mask_draw.rounded_rectangle(
        [0, 0, size, size], 
        radius=corner_radius, 
        fill=255
    )
    
    # Create gradient background (blue to darker blue)
    bg = create_gradient_background(size, (74, 144, 226), (45, 87, 150))
    
    # Apply mask to background
    image.paste(bg, (0, 0))
    
    draw = ImageDraw.Draw(image)
    
    # Calculate sizes based on icon size
    arrow_size = size * 0.3
    document_width = size * 0.4
    document_height = size * 0.5
    
    # Document background (slightly offset stack of documents)
    doc_x = size * 0.3
    doc_y = size * 0.2
    
    # Draw multiple document layers for depth
    for i in range(3):
        offset = i * (size * 0.02)
        # Document shadow
        draw.rounded_rectangle(
            [doc_x + offset + 2, doc_y + offset + 2, 
             doc_x + document_width + offset + 2, doc_y + document_height + offset + 2],
            radius=size // 32,
            fill=(0, 0, 0, 50)
        )
        # Document
        alpha = 200 - (i * 30)
        draw.rounded_rectangle(
            [doc_x + offset, doc_y + offset, 
             doc_x + document_width + offset, doc_y + document_height + offset],
            radius=size // 32,
            fill=(255, 255, 255, alpha)
        )
    
    # Draw download arrow (prominent and modern)
    arrow_x = size * 0.5
    arrow_y = size * 0.45
    arrow_width = arrow_size * 0.6
    arrow_height = arrow_size * 0.8
    
    # Arrow shaft
    shaft_width = arrow_width * 0.3
    shaft_x = arrow_x - shaft_width / 2
    draw.rounded_rectangle(
        [shaft_x, arrow_y - arrow_height * 0.3, 
         shaft_x + shaft_width, arrow_y + arrow_height * 0.1],
        radius=size // 64,
        fill=(45, 187, 87, 255)
    )
    
    # Arrow head (triangle)
    head_width = arrow_width
    head_height = arrow_height * 0.4
    head_y = arrow_y + arrow_height * 0.1
    
    arrow_points = [
        (arrow_x, head_y + head_height),  # Bottom point
        (arrow_x - head_width / 2, head_y),  # Left point
        (arrow_x + head_width / 2, head_y)   # Right point
    ]
    
    draw.polygon(arrow_points, fill=(45, 187, 87, 255))
    
    # Add subtle speed lines for motion effect
    for i in range(3):
        line_y = arrow_y + (i * size * 0.03) - size * 0.03
        line_start_x = size * 0.15
        line_end_x = size * 0.35
        line_width = max(1, size // 128)
        
        draw.line(
            [(line_start_x, line_y), (line_end_x, line_y)],
            fill=(255, 255, 255, 150 - i * 40),
            width=line_width
        )
    
    # Add highlight for 3D effect
    highlight_gradient = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    highlight_draw = ImageDraw.Draw(highlight_gradient)
    
    # Top-left highlight
    for r in range(size // 4):
        alpha = int(30 * (1 - r / (size // 4)))
        highlight_draw.ellipse(
            [size * 0.15 - r, size * 0.15 - r, size * 0.15 + r, size * 0.15 + r],
            fill=(255, 255, 255, alpha)
        )
    
    # Composite highlight
    image = Image.alpha_composite(image, highlight_gradient)
    
    return image

def main():
    """Generate all required app icon sizes"""
    sizes = [16, 32, 64, 128, 256, 512, 1024]
    
    # Create output directory
    icon_dir = "/Users/devitripathy/code/download_manager/SwiftFetch/SwiftFetch/Assets.xcassets/AppIcon.appiconset"
    
    print("Creating SwiftFetch app icons...")
    
    for size in sizes:
        print(f"Creating {size}x{size} icon...")
        icon = create_download_icon(size)
        
        # Save regular size
        filename = f"icon_{size}x{size}.png"
        icon.save(os.path.join(icon_dir, filename), "PNG")
        
        # Save 2x version if size <= 512
        if size <= 512:
            filename_2x = f"icon_{size}x{size}@2x.png"
            icon_2x = create_download_icon(size * 2)
            icon_2x.save(os.path.join(icon_dir, filename_2x), "PNG")
    
    print("✅ App icons created successfully!")

if __name__ == "__main__":
    main()