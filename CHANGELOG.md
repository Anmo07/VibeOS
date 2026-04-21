# VibeOS — Architecture Evolution & Build System Changelog

> **From Kickstart Monolith → Modular, AI-Native, Atomically-Updatable OS**
>
> This document covers the complete transformation of the VibeOS build system across 7 major phases.

---

## Phase 1: Modular Kickstart Architecture

**Problem:** A single 1439-line `vibeos.ks` containing packages for both architectures, ~880 lines of base64 wallpaper data, and all post-install logic in one file. `build.sh` used fragile `sed` to strip packages at runtime.

**Solution:** Decomposed into **10 focused modules** under `kickstart/`:

```text
kickstart/
├── base.ks                    ← Fedora include + partition
├── packages-common.ks         ← Legacy (kept for reference)
├── arch/
│   ├── packages-x86_64.ks    ← grub2-efi-x64, shim-x64
│   └── packages-aarch64.ks   ← grub2-efi-aa64, shim-aa64
└── post/
    ├── branding.ks            ← Wallpaper, os-release, Plymouth
    ├── ui-config.ks           ← dconf, GNOME settings
    ├── system-setup.ks        ← DNS, Zsh, Oh My Zsh
    ├── apps.ks                ← Flatpak setup, browser, VS Code
    ├── security.ks            ← Firewall, USBGuard, SSH
    └── cleanup.ks             ← Cache purge, dracut, NM
```

**Key wins:**

- ❌ Removed all runtime `sed` filtering
- ✅ Architecture separation at file level via `%include`
- ✅ Persistent Docker DNF cache volumes for faster rebuilds
- ✅ Post-build EFI validation checks

---

## Phase 2: Build Profiles & CLI Interface

**Problem:** One-size-fits-all builds. No way to produce a lightweight ISO for testing or a developer-focused build.

**Solution:** Split `packages-common.ks` into **5 independent package groups** with **3 profiles**:

| Profile   | Groups Included                         | Use Case              |
| --------- | --------------------------------------- | --------------------- |
| `full`    | core + ui + dev + media + hardware + ai | Production ISO        |
| `minimal` | core + ui                               | Lightweight testing   |
| `dev`     | core + ui + dev + ai                    | Developer builds      |

```text
kickstart/profiles/
├── packages-core.ks       ← System essentials (40 pkgs)
├── packages-ui.ks         ← GNOME extensions, themes, fonts
├── packages-dev.ks        ← pip, fd-find, ImageMagick
├── packages-media.ks      ← Codecs, viewers
├── packages-hardware.ks   ← Firmware, VM tools, fprintd
└── packages-ai.ks         ← curl, zenity (AI deps)
```

**CLI:**

```bash
./build.sh                                    # Both arches, full
./build.sh --arch=x86_64 --profile=minimal    # x86_64, lightweight
./build.sh --arch=aarch64 --profile=dev       # ARM64, developer
./build.sh --help                             # Usage reference
```

---

## Phase 3: OSBuild Parallel Backend

**Problem:** Kickstart files are imperative bash scripts — hard to audit, non-deterministic, and fragile.

**Solution:** Introduced **declarative TOML blueprints** using OSBuild (Fedora Image Builder) as a parallel backend:

```text
osbuild/
├── vibeos-full.toml        ← Full profile blueprint
├── vibeos-minimal.toml     ← Minimal profile blueprint
├── Dockerfile              ← osbuild-composer container
└── build-osbuild.sh        ← Push → depsolve → compose → download
```

**Usage:**

```bash
./build.sh --backend=osbuild --profile=full
```

> **Note:** OSBuild backend is experimental — requires a Fedora host with `osbuild-composer` running (systemd dependency). The Kickstart backend remains default.

---

## Phase 4: Flatpak-First App Delivery

**Problem:** Browsers, editors, and media players installed as RPMs caused architecture branching (Chrome vs Chromium), ISO bloat (~400MB), no auto-updates, and no sandboxing.

**Solution:** Created a **declarative JSON manifest** (`flatpak-apps.json`) that drives first-boot Flatpak installation:

| App     | Before (RPM)                                | After (Flatpak)                      |
| ------- | ------------------------------------------- | ------------------------------------ |
| Browser | `google-chrome`/`chromium` + arch branching | `org.chromium.Chromium` (universal)  |
| Editor  | `code` + Microsoft repo                     | `com.visualstudio.code`              |
| Media   | `vlc` + RPM Fusion                          | `org.videolan.VLC`                   |
| Office  | `libreoffice-*` (3 RPMs)                    | `org.libreoffice.LibreOffice`        |
| AI      | `bavarder`                                  | `io.github.Bavarder.Bavarder`        |

**What stays as RPM:** System codecs, Broadcom WiFi drivers, RPM Fusion repos.

**First-boot flow:** `vibeos-flatpak-init.service` reads `/etc/vibeos-profile`, parses `flatpak-apps.json`, installs apps for the active profile, sets MIME defaults, then self-disables.

---

## Phase 5: AI System Integration

**Problem:** AI existed only as standalone web app shortcuts (ChatGPT, Gemini) — no system-level capability.

**Solution:** VibeOS now ships a **local AI inference engine** (Ollama) integrated into the shell, file manager, and desktop:

| Component                   | What It Does                                                       |
| --------------------------- | ------------------------------------------------------------------ |
| `vibe-ai.service`           | Ollama daemon with systemd security hardening                      |
| `vibeos-ai-setup.service`   | Pulls `tinyllama` model on first boot                              |
| `/usr/local/bin/vibe-ai`    | CLI: ask, explain, summarize, models, pull                         |
| Zsh plugin                  | `? query` for command suggestions, `Alt+A` to explain current line |
| Nautilus script             | Right-click any file → "Ask AI" → analysis in dialog              |

**Usage:**

```bash
vibe-ai "What does exit code 137 mean?"      # Direct question
vibe-ai explain /etc/fstab                    # File analysis
dmesg | vibe-ai summarize                     # Pipe to AI
? how to recursively rename files              # Shell magic
```

---

## Phase 6: OSTree Atomic Updates

**Problem:** Traditional LiveCD ISOs have no safe upgrade path — updates can break the system with no rollback.

**Solution:** Added OSTree/rpm-ostree as a third build backend, enabling immutable deployments with instant rollback:

```text
ostree/
├── vibeos.yaml          ← rpm-ostree treefile (full system definition)
├── build-ostree.sh      ← Compose commits + optional ISO
└── Dockerfile           ← rpm-ostree build container
```

**User-facing update tool** (installed on all profiles):

```bash
vibeos-update check       # Check for available updates
vibeos-update upgrade     # Stage update → reboot to apply
vibeos-update rollback    # Instantly revert to previous OS
vibeos-update status      # Show deployment info
vibeos-update history     # View update log
```

Includes a **weekly auto-check timer** via systemd.

---

## Phase 7: CI/CD Pipeline & Distribution

**Problem:** No automated builds, no versioning, no reproducible releases.

**Solution:** GitHub Actions pipeline with automated multi-arch builds and GitHub Releases:

**Triggers:**

- Push to `main` → builds artifacts (14-day retention)
- Push tag `v2026.03.1` → builds + creates GitHub Release
- Manual dispatch → pick profile + arch in GitHub UI

**Versioning:** Calendar format `YYYY.MM.patch` (e.g., `2026.03.1`)

**Release workflow:**

```bash
./build.sh                          # Build ISOs
./release.sh 2026.03.1 --tag        # Checksums + metadata + git tag
git push origin v2026.03.1          # → GitHub Actions creates release
```

**Release artifacts:** ISO + SHA256 checksum + build metadata JSON per architecture.

---

## Final Project Structure

```text
Project/
├── build.sh                         ← Main CLI (--arch, --profile, --backend)
├── release.sh                       ← Release prep (checksums, metadata, tags)
├── Dockerfile                       ← livecd-creator container
├── live.py / creator.py / fs.py     ← Patched livecd-tools
├── vibeos.ks                        ← Legacy monolithic (rollback)
│
├── .github/workflows/
│   └── build-iso.yml                ← CI/CD pipeline
│
├── kickstart/                       ← Modular kickstart system
│   ├── base.ks                      ← Fedora include + partition
│   ├── flatpak-apps.json            ← Declarative app manifest
│   ├── profiles/                    ← 6 package groups
│   │   ├── packages-core.ks
│   │   ├── packages-ui.ks
│   │   ├── packages-dev.ks
│   │   ├── packages-media.ks
│   │   ├── packages-hardware.ks
│   │   └── packages-ai.ks
│   ├── arch/                        ← Arch-specific bootloaders
│   │   ├── packages-x86_64.ks
│   │   └── packages-aarch64.ks
│   ├── post/                        ← 8 post-install modules
│   │   ├── branding.ks
│   │   ├── ui-config.ks
│   │   ├── system-setup.ks
│   │   ├── apps.ks
│   │   ├── ai.ks
│   │   ├── updates.ks
│   │   ├── security.ks
│   │   └── cleanup.ks
│   └── vibeos-{arch}-{profile}.ks   ← 6 entry points
│
├── osbuild/                         ← OSBuild backend
│   ├── vibeos-full.toml
│   ├── vibeos-minimal.toml
│   ├── build-osbuild.sh
│   └── Dockerfile
│
└── ostree/                          ← OSTree backend
    ├── vibeos.yaml
    ├── build-ostree.sh
    └── Dockerfile
```
