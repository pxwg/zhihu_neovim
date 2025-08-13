#!/bin/bash

make chrome_cookie_lua51
make markdown_to_html_lua51

# Define the project root and virtual environment directory
PROJECT_ROOT="/Users/pxwg-dogggie/zhihu_on_nvim"
VENV_DIR="$PROJECT_ROOT/.venv"

# Create virtual environment if it doesn't exist
if [ ! -d "$VENV_DIR" ]; then
  echo "Creating virtual environment..."
  python3 -m venv "$VENV_DIR"
fi

# Activate the virtual environment
source "$VENV_DIR/bin/activate"

# Install required Python packages
echo "Installing required Python packages..."
pip install --upgrade pip
pip install mistune beautifulsoup4 pychrome websocket

# Deactivate the virtual environment
deactivate

echo "Virtual environment setup complete."
