#!/bin/bash

# Create placeholder icons for Chrome extension
# Uses macOS's built-in sips command to create colored squares

cd "$(dirname "$0")/icons"

# Function to create a colored square PNG
create_icon() {
    size=$1
    filename="icon-${size}.png"
    
    # Create a simple SVG and convert to PNG using Quick Look
    cat > temp.svg << EOF
<svg width="${size}" height="${size}" xmlns="http://www.w3.org/2000/svg">
  <rect width="${size}" height="${size}" fill="#4A90E2"/>
  <text x="50%" y="50%" font-family="Arial, sans-serif" font-size="$(($size/3))" font-weight="bold" fill="white" text-anchor="middle" dominant-baseline="middle">SF</text>
</svg>
EOF
    
    # Convert SVG to PNG using qlmanage
    qlmanage -t -s ${size} -o . temp.svg >/dev/null 2>&1
    mv temp.svg.png "$filename" 2>/dev/null || true
    
    # If qlmanage didn't work, create a simple colored square
    if [ ! -f "$filename" ]; then
        # Create using Python if available
        python3 << EOF
from PIL import Image, ImageDraw, ImageFont
import os

img = Image.new('RGB', ($size, $size), color='#4A90E2')
draw = ImageDraw.Draw(img)

# Try to add text
try:
    # Simple text in center
    text = "SF"
    font_size = int($size / 3)
    # Use default font
    bbox = draw.textbbox((0, 0), text)
    text_width = bbox[2] - bbox[0]
    text_height = bbox[3] - bbox[1]
    position = (($size - text_width) / 2, ($size - text_height) / 2)
    draw.text(position, text, fill='white')
except:
    pass

img.save('$filename')
print(f"Created $filename")
EOF
    fi
    
    rm -f temp.svg temp.svg.png
}

# Check if Python PIL is available, if not create simple colored squares
if ! python3 -c "import PIL" 2>/dev/null; then
    echo "Creating simple placeholder icons..."
    
    # Create simple colored squares using base64 encoded PNGs
    for size in 16 32 48 128; do
        filename="icon-${size}.png"
        
        # Create a blue square PNG using base64
        if [ $size -eq 16 ]; then
            # 16x16 blue square
            echo "iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAYAAAAf8/9hAAAABmJLR0QA/wD/AP+gvaeTAAAACXBIWXMAAAsTAAALEwEAmpwYAAAAB3RJTUUH6AEBAAEAJqV5VwAAABl0RVh0Q29tbWVudABDcmVhdGVkIHdpdGggR0lNUFeBDhcAAAAUSURBVDjLY2TAA0aR4v9pYsBIcgAANAQBASQox6AAAAAASUVORK5CYII=" | base64 -d > "$filename"
        elif [ $size -eq 32 ]; then
            # 32x32 blue square
            echo "iVBORw0KGgoAAAANSUhEUgAAACAAAAAgCAYAAABzenr0AAAABmJLR0QA/wD/AP+gvaeTAAAACXBIWXMAAAsTAAALEwEAmpwYAAAAB3RJTUUH6AEBAAEAJqV5VwAAABl0RVh0Q29tbWVudABDcmVhdGVkIHdpdGggR0lNUFeBDhcAAAAaSURBVFjD7c8BDQAACAOw/6ur4AoKbnRAYx8HtwEBnZKz2QAAAABJRU5ErkJggg==" | base64 -d > "$filename"
        elif [ $size -eq 48 ]; then
            # 48x48 blue square
            echo "iVBORw0KGgoAAAANSUhEUgAAADAAAAAwCAYAAABXAvmHAAAABmJLR0QA/wD/AP+gvaeTAAAACXBIWXMAAAsTAAALEwEAmpwYAAAAB3RJTUUH6AEBAAEAJqV5VwAAABl0RVh0Q29tbWVudABDcmVhdGVkIHdpdGggR0lNUFeBDhcAAAAeSURBVGje7cExAQAACAOg/av7cg0oaOCSAAAeBgMAD9sBATCb+mwAAAAASUVORK5CYII=" | base64 -d > "$filename"
        else
            # 128x128 blue square
            echo "iVBORw0KGgoAAAANSUhEUgAAAIAAAACACAYAAADDPmHLAAAABmJLR0QA/wD/AP+gvaeTAAAACXBIWXMAAAsTAAALEwEAmpwYAAAAB3RJTUUH6AEBAAEAJqV5VwAAABl0RVh0Q29tbWVudABDcmVhdGVkIHdpdGggR0lNUFeBDhcAAAAqSURBVHja7cExAQAAAMKg9U9tDB+gAAAAAAAAAAAAAAAAAAAAAACAXwM+gAABAj5YwAAAAABJRU5ErkJggg==" | base64 -d > "$filename"
        fi
        
        echo "Created $filename"
    done
else
    echo "Creating icons with Python PIL..."
    for size in 16 32 48 128; do
        create_icon $size
    done
fi

echo "Icon creation complete!"
ls -la