# Contributing to Bespoke Inferr

Thanks for helping. Bug reports, fixes, and docs are all welcome.

## Where to start

- **Bugs / feature ideas** → GitHub Issues (search first)
- **UI, `scripts/server.py`, landing page, help/FAQ content** → PRs
  against this repo
- **Security issues** → open a private report via GitHub Security
  Advisories rather than a public issue

## Development

```bash
python3 scripts/server.py   # app + API → http://localhost:8080/
npm install                  # first time
npm run build                # assets/app.css → assets/shared.css
```

Rules of the road:

- Keep UI changes in the shared files — `index.html`, `help.html`,
  `faqs.html`, and `assets/` — never fork the markup.
- After editing `assets/app.css`, run `npm run build` and commit the
  regenerated `assets/shared.css`.
- Desktop builds and rebuild recipes: [`../docs/OPERATIONS.md`](../docs/OPERATIONS.md).

## Scope

This repository contains the web app, landing page, styles, and
scripts needed to run the UI locally. Engine sources and build
documentation are maintained separately — see
[`../docs/OPERATIONS.md`](../docs/OPERATIONS.md).

## License and trademark

- Contributions are accepted under the [MIT License](LICENSE); you keep
  copyright, and you agree your contribution is licensed under it.
- The "Bespoke Inferr" name, logo, and brand imagery are excluded from
  MIT — see [TRADEMARK.md](TRADEMARK.md).
- Bundled third-party components keep their own licenses — see
  [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).
