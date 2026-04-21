# VibeOS Builder 🚀

A Linux-based custom OS build system that automates ISO creation using scripts and configuration files.

## 🔧 Features
- Automated ISO generation
- Custom kickstart configuration (`.ks`)
- Shell + Python based build pipeline
- Lightweight and customizable

## 📁 Project Structure
.
├── creator.py          # Main build logic
├── build.sh            # Build script
├── vibeos.ks        # Kickstart config
├── Dockerfile          # Optional container build
├── repack-iso.sh       # ISO repack logic
## ⚙️ Requirements
- Linux environment (recommended)
- `lorax`, `dnf`, `rpm` tools
- Python 3

## 🚀 Usage

```bash
chmod +x build.sh
./build.sh
👨‍💻 Author

Anmol (anmthinks)
---
