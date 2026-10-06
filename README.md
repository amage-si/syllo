# Syllo

**Latin text layout in Bend 2: characters to positioned glyphs, lines, and measurements.**

Syllo is the text layout layer of the AMAGE UI ecosystem. It takes a string and
a font opened by [Runika](https://github.com/amage-si/runika), maps characters
to glyphs, places them on lines with greedy word wrapping, and reports logical
measurements that layout and rendering can use. It is written in Bend 2 and
calls no native text engine.

**Status:** early Linux implementation, tested with **Bend 2.0.35**. The first
coverage is Portuguese and other Latin-1 text, left to right, without
universal OpenType shaping.

## What works today

- Printable ASCII (U+0020–007E), Latin-1 (U+00A0–00FF), and line feed
  (U+000A), when the font has the glyphs. Line feed starts a new line and
  produces no glyph.
- Combining accents composed before the glyph lookup, from an explicit list of
  Latin pairs: grave, acute, circumflex, tilde, diaeresis, and cedilla. It
  includes every pair used in Portuguese, upper and lower case. "ã" written as
  U+00E3 or as U+0061 U+0303 gives the same glyph; the combining form keeps a
  two-scalar source span.
- Greedy line breaking before a word that follows an ASCII space. A word wider
  than the line breaks between clusters. A single glyph wider than the line
  stays whole, and the returned width shows the overflow. Spaces are kept and
  can also wrap; no-break space (U+00A0) is not a break opportunity.
- Explicit and trailing line feeds keep empty lines. Empty text has width 0,
  no glyphs, and one line box.
- Logical measurements: the widest line's sum of advances (spaces included),
  the total height of the line boxes, ascender, descender, line height, and
  line count.

The native suite has **17 checks**: composed and combining pairs, source spans,
identical layout for precomposed and combining text, rejected input (a leading
mark, an unlisted pair, two marks in one cluster, emoji, Arabic, tab), empty
text, line feeds, exact fit, word and cluster wrapping, single-glyph overflow,
and invalid sizes. With Liberation Sans at 20 px, "AA" measures exactly
26.6796875 units: it fits in that width and wraps to two lines at width 26.

## Quick start

Requirements: the [Bend 2 toolchain](https://bend-lang.com), Clang 14 or newer,
and two sibling repositories cloned next to Syllo:
[Runika](https://github.com/amage-si/runika) (fonts) and
[Splina](https://github.com/amage-si/splina) (path types used by Runika).
The tests and example read Liberation Sans 2.1.5 from
`/usr/share/fonts/liberation/LiberationSans-Regular.ttf`; see Runika's README
for how to obtain that exact file.

```sh
mkdir amage && cd amage
git clone https://github.com/amage-si/syllo.git Syllo
git clone https://github.com/amage-si/runika.git Runika
git clone https://github.com/amage-si/splina.git Splina
cd Syllo
export BEND_NO_TELEMETRY=1
bend version
mkdir -p build
bend tests.bend -o build/tests
./build/tests --threads 2 --gpu off
```

The directory names matter: imports use relative paths such as
`../Runika/font.bend`.

Lay out a short sentence in a 120-unit box and print every placement:

```sh
bend examples/layout.bend -o build/layout
./build/layout --threads 2 --gpu off
```

```text
line 0  glyph 36  source [0,1)  x 0  baseline 18.105469  advance 13.339844
...
line 1  glyph 171  source [16,18)  x 26.679688  baseline 41.103516  advance 11.123047
line 1  glyph 17  source [18,19)  x 37.802734  baseline 41.103516  advance 5.5566406
lines 2  width 116.73828  height 45.996094  line height 22.998047
```

The `[16,18)` span is the "é" written with a combining accent.

## Using the API

```bend
import ../Runika/font.bend as F
import ../Syllo/main.bend as S

S.layout(font: F.Font, text: String, size: F32, max_width: F32)
  -> Result<&2, &2, String, S.Layout>
```

`Layout{placements, width, height, ascender, descender, line_height, line_count}`
lists one `Placement{glyph, source_start, source_end, x, baseline, advance, line}`
per glyph. Source indices count **Unicode scalars** (start inclusive, end
exclusive), not UTF-8 bytes. Coordinates are logical units with the origin at
the top left and y down. `width` and `height` are layout measurements, not the
exact ink bounds: negative bearings and accents can draw outside the advances.

Render the result with [Dithra](https://github.com/amage-si/dithra)
(`render(font, layout, size, device_scale)`), or give `Size{width, height}` to
[Tessra](https://github.com/amage-si/tessra) as a preferred size. Read the
[API reference](docs/api.md) for the full contract.

## Current boundaries

Not implemented: bidirectional text, Arabic and Indic scripts, emoji and ZWJ
sequences, ligatures, kerning, GSUB/GPOS, hyphenation, Unicode line breaking
(UAX #14), conditional soft hyphens, canonical ordering, full NFC
normalization, grapheme segmentation (UAX #29), font fallback, generic mark
positioning, and complete cursor/selection support. Carriage return, CRLF, and
tab are rejected in this version. Latin-1 symbols map directly to glyphs; that
does not implement every editorial rule for those characters. Supported
combining accents are composed before the character map lookup, not drawn by
placing one glyph over another.

Unsupported text is an error with a message, never a silent substitution: a
character without a glyph, a script outside the declared range, or an unlisted
combining pair fails the whole call.

Cost: the `cmap` lookup scans segments linearly, layout uses persistent lists,
and word lookahead can be quadratic for one very long word. There is no shaping
cache. The 4096-scalar limit bounds work; it is not a latency guarantee.

## Repository map

| Path | Purpose |
| --- | --- |
| [main.bend](main.bend) | Glyph mapping, advances, line breaking, and `layout`. |
| [unicode.bend](unicode.bend) | Accepted scalars, combining-pair composition, and clusters. |
| [tests.bend](tests.bend) | Native checks with Liberation Sans. |
| [examples/layout.bend](examples/layout.bend) | Lays out a sentence and prints placements. |
| [docs/api.md](docs/api.md) | Types, units, limits, and contracts. |

## Direction

Next are kerning, more scripts with real shaping data, Unicode line breaking,
and the cursor and selection queries that editing needs, each with tests on
real text. These are goals, not supported features.

See [CONTRIBUTING.md](CONTRIBUTING.md) for development rules. The API is
experimental and may change. A distribution license has not yet been selected.
