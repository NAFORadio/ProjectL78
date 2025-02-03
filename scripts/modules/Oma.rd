**Survival AI Assistant - Installation & Usage Guide**

### **What is This?**
The **Survival AI Assistant** is a **fully offline AI-powered survival knowledge system** that runs on **MacOS and Raspberry Pi OS**. It lets you:
- **Chat with an AI about survival topics**
- **Search through survival PDFs and books offline**
- **Use voice commands for hands-free operation**

This guide will walk you through setting it up from scratch, even if you’ve never done anything like this before. 

---

## **🚀 Step 1: Install the Survival AI System**
### **Download and Run the Installer**
1. Open a **terminal** (Command Line). You can find this by searching for **Terminal** on your Mac or Pi.
2. Run this command to **download the installer**:
   ```bash
   curl -O https://raw.githubusercontent.com/yourrepo/survival_ai/main/Oma.sh
   ```
3. Run this command to **make the script executable**:
   ```bash
   chmod +x Oma.sh
   ```
4. Run the installer:
   ```bash
   ./Oma.sh
   ```

### **What This Does:**
✅ Detects if you are on **MacOS or Raspberry Pi OS**
✅ Installs **all necessary software**
✅ Sets up an **AI model (TinyLlama 1B)**
✅ Creates a **virtual environment** to keep everything organized
✅ Adds a **command-line tool (`survival_ai`)** to make it easy to use

When the installation is **done**, move to Step 2.

---

## **🎯 Step 2: Using the Survival AI Assistant**
### **1️⃣ Start the AI Chatbot**
To talk to the AI about survival topics, run:
```bash
survival_ai --chat
```
This will start an **offline AI chatbot** that can answer your survival questions.

---

### **2️⃣ Train the AI with New PDFs**
You can add new survival books and guides to the AI’s knowledge.
#### **How to Add Survival PDFs:**
1. **Move your PDFs** to this folder:
   ```
   ~/survival_ai_data/
   ```
   If this folder does not exist, create it:
   ```bash
   mkdir -p ~/survival_ai_data/
   ```
2. **Run the training command:**
   ```bash
   survival_ai --train
   ```

### **What Happens?**
✅ Finds all PDFs and converts them into text
✅ Stores the knowledge for fast searches
✅ Makes the AI smarter with your survival books

When it’s done, you can search for information from the new PDFs anytime!

---

### **3️⃣ Use Voice Commands (Optional)**
If you want to **talk to the AI using your voice**, follow these steps:
1. **Record your voice** and save it as `voice_command.mp3`
2. **Run the voice command processor:**
   ```bash
   survival_ai --voice
   ```
3. The AI will **transcribe your command** and respond accordingly!

---

## **🔧 Troubleshooting (Fixing Problems)**
### **1️⃣ AI Chatbot Won’t Start**
**Fix:** Ensure the installation completed and run:
```bash
survival_ai --chat
```
If you get an error, try:
```bash
source ~/survival_ai_env/bin/activate
```
Then rerun the chat command.

---

### **2️⃣ PDFs Not Being Processed**
**Fix:**
1. Check that your PDFs are inside `~/survival_ai_data/`
2. Run the training command again:
   ```bash
   survival_ai --train
   ```
3. If errors occur, reinstall dependencies:
   ```bash
   source ~/survival_ai_env/bin/activate
   pip install --upgrade pdfminer.six langchain chromadb
   ```

---

### **3️⃣ Voice Commands Not Working**
**Fix:**
- Ensure `pyaudio` is installed:
  ```bash
  pip install pyaudio
  ```
- Ensure the **audio file is named correctly** (`voice_command.mp3`)
- Try running:
  ```bash
  survival_ai --voice
  ```

---

## **📌 Final Notes**
- **This AI runs completely offline**—you do NOT need the internet after installation.
- **It works best on MacOS and Raspberry Pi**.
- **You can add new PDFs anytime** and train the AI with new knowledge.
- **If anything breaks, reinstall dependencies using:**
  ```bash
  source ~/survival_ai_env/bin/activate
  pip install --upgrade pdfminer.six langchain chromadb
  ```

For additional support, visit the project repository: 
[GitHub Repository - Survival AI](https://github.com/yourrepo/survival_ai)

🎉 **Enjoy your offline AI-powered survival assistant!** 🎉

