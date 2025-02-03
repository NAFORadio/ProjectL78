#!/bin/bash

# Detect OS
if [[ "$OSTYPE" == "darwin"* ]]; then
    OS="macos"
elif [[ -f "/etc/raspi-config" ]]; then
    OS="raspberrypi"
else
    echo "Unsupported OS. This script only works on MacOS or Raspberry Pi OS."
    exit 1
fi

echo "Detected OS: $OS"

# Update system and install dependencies
if [[ "$OS" == "macos" ]]; then
    echo "Updating MacOS system..."
    brew update
    echo "Installing dependencies..."
    brew install python3 git wget cmake poppler
else
    echo "Updating Raspberry Pi system..."
    sudo apt update && sudo apt upgrade -y
    echo "Installing dependencies..."
    sudo apt install -y python3-pip git wget cmake build-essential poppler-utils
fi

# Install AI libraries
echo "Installing AI libraries..."
pip3 install torch torchvision torchaudio
pip3 install llama-cpp-python whisper langchain chromadb pyaudio pdfminer.six

# Select a smaller AI model for Raspberry Pi
echo "Select an AI model (default: TinyLlama 1B)"
echo "1) TinyLlama (1.1B params) - Fastest option"
echo "2) Phi-2 (1.3B params) - Better reasoning"
read -p "Enter choice [1 or 2]: " model_choice

if [[ "$model_choice" == "2" ]]; then
    echo "Downloading Phi-2 (1.3B params)..."
    wget -O ~/phi-2.Q4_K_M.gguf https://huggingface.co/TheBloke/Phi-2-GGUF/resolve/main/phi-2.Q4_K_M.gguf
    MODEL_FILE="phi-2.Q4_K_M.gguf"
else
    echo "Downloading TinyLlama (1.1B params)..."
    wget -O ~/tinyllama-1b.Q4_K_M.gguf https://huggingface.co/TheBloke/TinyLlama-1B-GGUF/resolve/main/tinyllama-1b.Q4_K_M.gguf
    MODEL_FILE="tinyllama-1b.Q4_K_M.gguf"
fi

# Set up survival knowledge database
echo "Setting up survival knowledge database..."
mkdir -p ~/survival_ai_data
touch ~/survival_ai_data/survival_tips.txt
echo "Store offline survival knowledge here!" >> ~/survival_ai_data/survival_tips.txt

# Create AI control script
echo "Creating survival AI script..."
cat <<EOT > /usr/local/bin/survival_ai
#!/bin/bash
if [[ "\$1" == "--chat" ]]; then
    ~/llama.cpp/main -m ~/$MODEL_FILE --ctx-size 1024
elif [[ "\$1" == "--train" ]]; then
    python3 ~/survival_ai/train.py
elif [[ "\$1" == "--voice" ]]; then
    python3 ~/survival_ai/voice_input.py
else
    echo "Usage: survival_ai --chat | --train | --voice"
fi
EOT
chmod +x /usr/local/bin/survival_ai

echo "Installation complete! Run 'survival_ai --chat' to start."
#!/bin/bash

# Detect OS
if [[ "$OSTYPE" == "darwin"* ]]; then
    OS="macos"
elif [[ -f "/etc/raspi-config" ]]; then
    OS="raspberrypi"
else
    echo "Unsupported OS. This script only works on MacOS or Raspberry Pi OS."
    exit 1
fi

echo "Detected OS: $OS"

# Update system and install dependencies
if [[ "$OS" == "macos" ]]; then
    echo "Updating MacOS system..."
    brew update
    echo "Installing dependencies..."
    brew install python3 git wget cmake poppler
else
    echo "Updating Raspberry Pi system..."
    sudo apt update && sudo apt upgrade -y
    echo "Installing dependencies..."
    sudo apt install -y python3-pip git wget cmake build-essential poppler-utils
fi

# Install AI libraries
echo "Installing AI libraries..."
pip3 install torch torchvision torchaudio
pip3 install llama-cpp-python whisper langchain chromadb pyaudio pdfminer.six

# Clone llama.cpp for running local AI models
echo "Cloning llama.cpp for local AI model..."
git clone https://github.com/ggerganov/llama.cpp
cd llama.cpp
make
cd ..

# Download Mistral 7B model (quantized)
echo "Downloading Mistral 7B model..."
wget -O ~/mistral-7b.Q4_K_M.gguf https://huggingface.co/TheBloke/Mistral-7B-GGUF/resolve/main/mistral-7b.Q4_K_M.gguf

# Set up survival knowledge database
echo "Setting up survival knowledge database..."
mkdir -p ~/survival_ai_data
touch ~/survival_ai_data/survival_tips.txt
echo "Store offline survival knowledge here!" >> ~/survival_ai_data/survival_tips.txt

# Create AI control script
echo "Creating survival AI script..."
cat <<EOT > /usr/local/bin/survival_ai
#!/bin/bash
if [[ "\$1" == "--chat" ]]; then
    ~/llama.cpp/main -m ~/mistral-7b.Q4_K_M.gguf --ctx-size 2048
elif [[ "\$1" == "--train" ]]; then
    python3 ~/survival_ai/train.py
elif [[ "\$1" == "--voice" ]]; then
    python3 ~/survival_ai/voice_input.py
else
    echo "Usage: survival_ai --chat | --train | --voice"
fi
EOT
chmod +x /usr/local/bin/survival_ai

echo "Installation complete! Run 'survival_ai --chat' to start."
