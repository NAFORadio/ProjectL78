**Survival AI - Complete Documentation**

## **Overview**
The **Survival AI Assistant** is a fully offline AI-powered survival knowledge system that can run on **MacOS, Raspberry Pi OS, Linux (Ubuntu/Debian), and Windows**. It allows users to:

✅ Chat with an AI about survival topics
✅ Train the AI with new survival PDFs and videos
✅ Remove unwanted data (ads, disclaimers, irrelevant content) from training sets
✅ Integrate **retrieval-augmented generation (RAG)** data into the fine-tuned model
✅ Distribute the trained model using `.gguf` format
✅ Host the model via **torrent** for easy distribution

This guide will walk you through everything: setup, training, sanitization, and fine-tuning your own **Survival AI model**.

---

# **Installation & Setup**
### **1️⃣ Download and Run the Installer**
1. **Open a terminal** (or PowerShell on Windows).
2. Download the installer:
   ```bash
   curl -O https://raw.githubusercontent.com/yourrepo/survival_ai/main/Oma.sh
   ```
3. **Make the script executable** (for Mac/Linux):
   ```bash
   chmod +x Oma.sh
   ```
4. **Run the installer**:
   ```bash
   ./Oma.sh
   ```
   **For Windows**, use:
   ```powershell
   .\Oma.bat
   ```

### **What This Does:**
✅ Detects **MacOS, Raspberry Pi OS, Linux, or Windows**
✅ Installs **all necessary dependencies**
✅ Sets up a **virtual environment**
✅ Downloads the **TinyLlama 1B model**
✅ Creates a **data directory** for PDFs & training

---

# **Training the AI with New Data**
### **2️⃣ Adding Survival PDFs**
1. Move **your PDFs** to this folder:
   ```bash
   ~/survival_ai_data/
   ```
2. Run the **training script**:
   ```bash
   ./training_Oma.sh
   ```
   **On Windows:**
   ```powershell
   .\training_Oma.bat
   ```

✅ Extracts **text from PDFs**
✅ Converts knowledge into AI-readable format
✅ Saves data in the **AI model or RAG database**

---

# **Sanitizing Training Data (Removing Ads, Disclaimers, Junk)**
### **3️⃣ Cleaning the Extracted Text**
To remove **ads, disclaimers, and unwanted text**, run:
```bash
./sanitize_training.sh
```
**On Windows:**
```powershell
.\sanitize_training.bat
```
✅ Uses AI to clean extracted text **before training**
✅ Ensures **only relevant survival knowledge is kept**

---

# **Merging RAG Data into the Model**
### **4️⃣ How to Convert RAG Data into a Trainable Model**
If you want to **permanently integrate** your RAG knowledge into the AI model:

1. **Extract RAG data into training format:**
   ```python
   import chromadb
   
   vectorstore = chromadb.PersistentClient(path="survival_knowledge_db")
   texts = vectorstore.get_texts()
   
   with open("rag_training_data.txt", "w") as f:
       for text in texts:
           f.write(f"User: What is the survival advice on this topic?\nAI: {text}\n\n")
   ```

2. **Fine-tune the AI model with the new knowledge:**
   ```bash
   python train.py \
     --base_model "TinyLlama-1B" \
     --train_data "rag_training_data.txt" \
     --output_model "merged_survival_ai.gguf"
   ```

✅ The AI **now includes** all RAG knowledge permanently.

---

# **Distributing the Model**
### **5️⃣ Hosting Your `.gguf` Model as a Torrent**
Since `.gguf` models can be **too large for GitHub**, you can share them via **torrent**.

1. **Create the torrent file:**
   ```bash
   transmission-create -o ~/survival_ai_model.torrent -c "Survival AI Model" -t udp://tracker.opentrackr.org:1337/announce ~/trained_survival_ai.gguf
   ```

2. **Start Seeding:**
   ```bash
   transmission-cli -w ~/trained_survival_ai.gguf ~/survival_ai_model.torrent
   ```

3. **Share the Magnet Link:**
   ```bash
   transmission-show ~/survival_ai_model.torrent | grep 'magnet:'
   ```

✅ Now **anyone can download the trained AI model** using your **torrent link**.

---

# **FAQ & Troubleshooting**
### **Common Issues & Fixes**
#### **1️⃣ AI Model Not Loading?**
- Check if the **model file exists**:
  ```bash
  ls -lh ~ | grep .gguf
  ```
- If missing, manually download:
  ```bash
  wget -O ~/tinyllama-1b.Q4_K_M.gguf https://huggingface.co/TheBloke/TinyLlama-1B-GGUF/resolve/main/tinyllama-1b.Q4_K_M.gguf
  ```

#### **2️⃣ Training Script Fails?**
- Ensure PDFs are inside `~/survival_ai_data/`
- Run:
  ```bash
  ./training_Oma.sh
  ```

#### **3️⃣ Voice Input Not Working?**
- Ensure **pyaudio** is installed:
  ```bash
  pip install pyaudio
  ```
- Try:
  ```bash
  ./survival_ai --voice
  ```

---

# **Final Notes**
✅ **Works on MacOS, Linux, Raspberry Pi OS, and Windows**
✅ **Fully offline—no internet required after setup**
✅ **AI is fine-tuned for survival knowledge**
✅ **Torrent hosting allows easy distribution**

For additional support, visit the project repository:
[GitHub Repository - Survival AI](https://github.com/yourrepo/survival_ai)

🎉 **Enjoy your offline AI-powered survival assistant!** 🎉

