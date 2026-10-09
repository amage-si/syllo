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
- Caret and selection queries on one line ([caret.bend](caret.bend)): caret
  stops (one per placement plus an end stop), snapping an index off the
  inside of a combining cluster, the caret's x, the nearest stop to a pointer
  x (an exact tie goes left), and the selection band. `unsupported` names the
  first scalar `layout` would reject, with its index, so an editor can refuse
  an edit and say which character.

The native suite has **19 checks**: composed and combining pairs, source spans,
identical layout for precomposed and combining text, rejected input (a leading
mark, an unlisted pair, two marks in one cluster, emoji, Arabic, tab), empty
text, line feeds, exact fit, word and cluster wrapping, single-glyph overflow,
invalid sizes, and a layout that is bit-for-bit the same with and without the
font's Latin-1 table (and fails the same way on unsupported text). With Liberation Sans at 20 px, "AA" measures exactly
26.6796875 units: it fits in that width and wraps to two lines at width 26.

The caret suite ([caret_tests.bend](caret_tests.bend)) has **37 checks**. With
Liberation Sans at 20 px, "AA" has stops at x 0, 13.33984375, and 26.6796875;
x 6.669921875, the exact midpoint, hits index 0 and 6.67 hits index 1. "ãé"
with a combining accent has stops at indices 0, 1, and 3, and index 2 snaps to
1. `unsupported("café ☕")` is index 5, scalar 9749. Multi-line layouts are
refused.

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
normalization, grapheme segmentation (UAX #29), font fallback, and generic mark
positioning. Cursor and selection queries work on one line only: a layout
with a line feed or a wrap is refused, there is no vertical movement, word
boundaries are left to the caller, and stops follow placements left to
right (no bidirectional caret). Carriage return, CRLF, and
tab are rejected in this version. Latin-1 symbols map directly to glyphs; that
does not implement every editorial rule for those characters. Supported
combining accents are composed before the character map lookup, not drawn by
placing one glyph over another.

Unsupported text is an error with a message, never a silent substitution: a
character without a glyph, a script outside the declared range, or an unlisted
combining pair fails the whole call.

Cost: characters come from the Latin-1 table every Runika font carries
(`F.info`, eight steps; the `cmap` and `hmtx` otherwise), normalizing and
shaping carry their state in parameters rather than a closure per character,
and a word is measured once, where it starts. Laying out the integrated
demo's seven texts (about 250 characters) takes ~60 µs (~1.8 ms before).
Layout uses persistent lists, and the measurement of one very long word is
linear in its length per word start. Syllo keeps no cache of its own: a
caller that lays the same text out again (Chromi's demo text) keeps the
results. The 4096-scalar limit bounds work; it is not a latency guarantee.

Caret queries on a 256-scalar line at 20 px
([examples/caret_bench.bend](examples/caret_bench.bend), Liberation Sans,
`--threads 2`, three runs): `layout` ~51 µs, `stops` ~12 µs, `unsupported`
~13.5 µs, and `hit`, `caret_x`, and `selection` ~1 µs each. One edit that
re-lays out the text and its stops costs ~65 µs; a pointer move or caret
query reuses the stops.

## Repository map

| Path | Purpose |
| --- | --- |
| [main.bend](main.bend) | Glyph mapping, advances, line breaking, and `layout`. |
| [unicode.bend](unicode.bend) | Accepted scalars, combining-pair composition, and clusters. |
| [caret.bend](caret.bend) | Caret stops, snap, hit testing, selection bands, and `unsupported`. |
| [tests.bend](tests.bend) | Native checks with Liberation Sans. |
| [caret_tests.bend](caret_tests.bend) | Caret checks with Liberation Sans. |
| [examples/layout.bend](examples/layout.bend) | Lays out a sentence and prints placements. |
| [examples/caret.bend](examples/caret.bend) | Prints the caret stops, hits, and a selection band of one line. |
| [examples/caret_bench.bend](examples/caret_bench.bend) | Times the caret queries on a 256-scalar line. |
| [docs/api.md](docs/api.md) | Types, units, limits, and contracts. |

## Direction

Next are kerning, more scripts with real shaping data, Unicode line breaking,
and multi-line cursor and selection queries, each with tests on real text. These are goals, not supported features.

See [CONTRIBUTING.md](CONTRIBUTING.md) for development rules. The API is
experimental and may change. Licensed under either of [Apache License 2.0](LICENSE-APACHE) or [MIT](LICENSE-MIT), at your option.

## License

Licensed under either of

- Apache License, Version 2.0 ([LICENSE-APACHE](LICENSE-APACHE))
- MIT license ([LICENSE-MIT](LICENSE-MIT))

at your option. Unless you explicitly state otherwise, any contribution
intentionally submitted for inclusion in this work, as defined in the
Apache-2.0 license, shall be dual licensed as above, without any additional
terms or conditions.
