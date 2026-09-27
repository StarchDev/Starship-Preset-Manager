# 🚀 Starship Preset Manager

> A friendly, lightweight terminal UI to manage, preview, download, and back up your [Starship](https://starship.rs/) prompt configurations without breaking a sweat! ✨

---

## 🌟 Features

- 🎮 **Interactive Menu:** Navigate smoothly using your **Arrow keys** or classic `j` / `k` vim keys.
- 🎨 **Built-in Presets:** Instantly preview and apply official Starship presets (like Catppuccin, Gruvbox, and Tokyo Night).
- 📁 **Custom Local Presets:** Store and swap your own favorite `.toml` files inside `~/.config/starship/presets/`.
- 👁️ **Live Prompt Preview:** Test out built-in configs, local files, or remote URLs live in your terminal before applying them!
- 🌐 **Smart Remote Downloads:** Fetch themes directly via URLs with auto-conversion for GitHub and GitLab web links.
- 🛡️ **HTML & Syntax Guard:** Never worry about broken prompts again—downloads are validated before anything changes!
- 💾 **Automatic Backups:** Every configuration swap creates a timestamped backup so you can restore anytime.

---

## ⚡ Quick Install

You can install the manager with a single command! Just open your terminal and run:

```bash
curl -fsSL [https://raw.githubusercontent.com/StarchDEV/starship-preset-manager/main/install.sh](https://raw.githubusercontent.com/StarchDEV/starship-preset-manager/main/install.sh) | sh
```
Once installed, simply run:

```bash
starship-mgr
