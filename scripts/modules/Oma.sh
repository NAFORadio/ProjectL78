#!/bin/bash
# AI Chat Project Setup Script using Ollama

# Set up error handling
set -e
set -o pipefail

# Detect WSL
if [[ -n "$WSL_DISTRO_NAME" ]]; then
    echo "🐧 Running in WSL: $WSL_DISTRO_NAME"
else
    echo "❌ This script requires WSL (Windows Subsystem for Linux)"
    exit 1
fi

# Debug function
debug() {
    echo "🔍 $1"
}

# Install Ollama
install_ollama() {
    debug "Installing Ollama..."
    
    # Install snapd if not present
    if ! command -v snap &> /dev/null; then
        sudo apt update
        sudo apt install -y snapd
    fi
    
    # Install Ollama
    sudo snap install ollama
    
    # Verify installation
    if ! command -v ollama &> /dev/null; then
        echo "❌ Ollama installation failed"
        exit 1
    fi
    
    echo "✅ Ollama installed successfully"
}

# Pull the model
setup_model() {
    debug "Pulling TinyLlama model..."
    ollama pull tinyllama
}

# Main installation
main() {
    echo "🚀 Starting Ollama installation..."
    
    install_ollama
    setup_model
    
    echo "✅ Installation complete!"
    echo ""
    echo "To use the model, run:"
    echo "ollama run tinyllama"
}

# Run installation
main

