# Third-Party Notices

Bespoke Inferr itself is [MIT licensed](LICENSE). The desktop builds
bundle or build on the components below; each keeps its **own** license,
which continues to apply to those components. License texts live in each
component's upstream repository (linked), and components that embed
notices in-binary (Chromium) include them there (e.g. `about:credits`).

## Bundled in shipped artifacts

| Component | Used in | License |
|---|---|---|
| [Neutralinojs](https://neutralino.js.org) | Windows x64 + Linux builds (`apps/bespoke-inferr-neutralino`) | MIT |
| [NW.js](https://nwjs.io) (NW.js + Chromium) | Windows x86 build (`apps/bespoke-inferr-nw`) | MIT (Chromium: BSD-style notices, embedded in the binary) |
| [Electron](https://www.electronjs.org) | Legacy artifacts (`apps/bespoke-inferr`, `dist/all/`) | MIT (Chromium + Node.js notices embedded) |
| Swift runtime / standard library, where statically linked | macOS builds (`apps/bespoke-infer-1`) | Apache License 2.0 with LLVM exception |

## Build-time only (not redistributed as source)

| Component | Used for | License |
|---|---|---|
| [Tailwind CSS](https://tailwindcss.com) | Generating `shared.css` (`npm run build`) | MIT |
| [daisyUI](https://daisyui.com) | Component themes in `assets/app.css` | MIT |
| [@tailwindcss/cli](https://www.npmjs.com/package/@tailwindcss/cli) and lockfile deps | Build tooling | MIT (see `package-lock.json`) |

## Legacy engine variants

Older donors in `apps/` keep their upstream licenses — Tauri
(MIT / Apache-2.0), Electrobun, tinyjs. See each folder's upstream
project for the full text.

## External services and trademarks

- **Ollama** — not bundled; you install it yourself, and the app talks
  to your daemon at `localhost:11434`. Ollama is a trademark of
  Ollama, Inc. This project is not affiliated with or endorsed by
  Ollama.
- **Hugging Face** — model search uses the public Hugging Face API.
  "Hugging Face" is a trademark of Hugging Face, Inc. This project is
  not affiliated with or endorsed by Hugging Face.

## Apple platforms

macOS builds use WKWebView and other frameworks provided by the
operating system; no Apple software is redistributed with this project.
