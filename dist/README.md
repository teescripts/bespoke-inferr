# Downloads

One folder per platform/architecture — exactly what the landing page
cards link to. Engine sources and rebuild recipes are maintained
outside this repository.

| Folder | Target | Artifact | Size | Status |
|---|---|---|---|---|
| `macos-x86_64/` | macOS Intel | `Bespoke Inferr-mac-x64.zip` | 366 KB (612 KB app) | ✓ verified |
| `macos-arm64/` | macOS Apple Silicon | `Bespoke Inferr-mac-arm64.zip` | 364 KB (640 KB app) | ⇄ cross-built from Intel |
| `windows-x64/` | Windows x64 | `Bespoke Inferr 0.1.0_x64-setup.exe` (+ portable zip) | **1.4 MB** | ✓ verified (Neutralino) |
| `windows-x86/` | Windows x86 | `Bespoke Inferr 0.1.0_x86-setup.exe` (+ portable zip) | 101 MB (NW.js) | ⇄ cross-build — **not in git** (97 MiB), ship via Releases |
| `linux-x86_64/` | Linux x86_64 | `bespoke-inferr-linux-x64.tar.gz` | 1.2 MB | ⇄ cross-build (Neutralino) |
| `linux-arm64/` | Linux ARM64 | `bespoke-inferr-linux-arm64.tar.gz` | 1.2 MB | ⇄ cross-build (Neutralino) |

Notes:

- **macOS**: Swift + WKWebView shell, ad-hoc signed. Unzip and run; first
  launch may need right-click → Open (ad-hoc signature).
- **Windows x64**: Neutralino — the size champion. NSIS installer compiled
  on macOS with electron-builder's bundled makensis; verified structurally
  (cannot execute on macOS).
- **Windows x86**: NW.js is the only wired engine that still ships 32-bit
  Windows binaries (Neutralino never did; Electron dropped win32). The
  installer is 97 MiB — allowed by GitHub (<100 MiB) but heavy for every
  clone, so the folder is gitignored and ships as a
  [GitHub Release](../../../releases) asset.
- **Linux**: portable tarball — `tar -xzf`, then `./bespoke-inferr`
  (binary + `resources.neu` next to each other).
- All variants require a local [Ollama](https://ollama.com) daemon.
- `all/` — legacy per-engine artifacts from the first build pass
  (electron, tauri, nw x64, electrobun, swift, tinyjs, …); kept on disk,
  gitignored.
