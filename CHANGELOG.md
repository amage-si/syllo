# Changelog

All notable changes to Syllo are recorded here. Syllo follows
[semantic versioning](https://semver.org) in its 0.x form: while the API is
experimental, a minor version (0.2.0) may change it in breaking ways and a
patch version (0.1.1) only fixes. Syllo is built from source together with its
sibling AMAGE libraries; the set of versions tested together is listed in
[eco-build's releases](https://github.com/amage-si/eco-build/tree/main/releases).

## [0.1.0] - 2026-10-09

First tagged release, tested with Bend 2.0.35 on Linux (X11/XWayland) as part
of AMAGE Eco 0.1.0.

### Included

- Left-to-right layout of Latin (with Extended-A/B and Additional), Greek,
  Cyrillic, general punctuation, currency, letterlike, arrows and math
  symbols, one glyph each, when the font has the glyph; anything else fails
  the whole call, never substituted.
- Composition of listed Latin combining accents before the glyph lookup.
- Greedy line breaking at spaces, line feeds, and logical measurements.
- Caret and selection queries on one line (`caret.bend`): caret stops, hit
  testing, selection bands, and `unsupported` to name a refused character.
- 26 layout checks and 45 caret checks.

[0.1.0]: https://github.com/amage-si/syllo/releases/tag/v0.1.0
