# Syllo API

Syllo depends on `Base` from the official Bend toolchain and on
[Runika](https://github.com/amage-si/runika) (`Runika/font.bend`,
`Runika/bytes.bend`), which in turn needs
[Splina](https://github.com/amage-si/splina). Import paths are relative to the
calling file. A module next to the `Syllo`, `Runika`, and `Splina` directories uses:

```bend
import Base
import ./Runika/font.bend as F
import ./Syllo/main.bend as S
```

## Entry point

```bend
S.layout(font: F.Font, text: String, size: F32, max_width: F32)
  -> Result<&2, &2, String, S.Layout>
```

`size` is the font size in logical units, in `(0, 256]`. `max_width` is the
line width in logical units, in `(0, 1000000]`. NaN, infinities, and
non-positive values fail. Text is limited to 4096 scalars per call. A missing
glyph, an unsupported scalar, or an unsupported combining sequence fails the
whole call with a descriptive message.

## Types

```bend
Layout{placements: List<&2, Placement>, width: F32, height: F32,
       ascender: F32, descender: F32, line_height: F32, line_count: U32}

Placement{glyph: U32, source_start: U32, source_end: U32,
          x: F32, baseline: F32, advance: F32, line: U32}
```

- `glyph` is the Runika glyph id.
- `source_start`/`source_end` index **Unicode scalars** in the input,
  start inclusive and end exclusive. A cluster built from a base and a
  combining mark spans two scalars. A line feed produces no placement.
- `x` and `baseline` are logical coordinates with the origin at the top left of
  the text box and y down. `x` is the pen position (glyph origin), not the ink's
  left edge.
- `advance` is the scaled `hmtx` advance. `line` starts at 0.

## Measurements

With `scale = size / upem` from the font:

- `ascender = hhea.ascender × scale`; `descender = hhea.descender × scale`
  (negative for fonts that descend below the baseline).
- `line_height = (ascender − descender + lineGap) × scale` in font units.
- The first baseline is `ascender`; each later line adds `line_height`.
- `width` is the widest line's sum of advances, including spaces.
- `height = line_count × line_height`.

These are layout measurements, not ink bounds. Glyphs with negative bearings or
tall accents can draw outside `width × height`. A single glyph wider than
`max_width` is kept on its line, and `width` then exceeds `max_width`.

For a preferred size in [Tessra](https://github.com/amage-si/tessra), use
`Size{layout.width, layout.height}`.

## Line breaking

1. A line feed ends the line. Text ending in a line feed has an empty last line.
2. After an ASCII space, a word that does not fit the remaining width moves to
   the next line when it fits a whole line.
3. A word wider than a whole line breaks between clusters.
4. Spaces are kept in the placements and count toward `width`; a space that
   does not fit also wraps. No-break space (U+00A0) is not a break opportunity.

## Accepted text

| Input | Behavior |
| --- | --- |
| U+0020–007E, U+00A0–00FF | One cluster per scalar. |
| U+000A | Line break; no glyph. |
| Base + U+0300/0301/0302/0303/0308/0327 | Composed to the precomposed Latin-1 scalar when the pair is listed in `unicode.bend::compose`. |
| Any other combining mark (U+0300–036F), a leading mark, or two marks on one base | Error. |
| Any other scalar, including U+000D and U+0009 | Error. |

`unicode.bend::normalize(text)` exposes the clustering step as
`List<&2, Cluster{code, start, end}>`. It is an explicit Latin-1 composition, not
Unicode NFC.

## Rendering

`Dithra/main.bend::render(font, layout, size, device_scale)` rasterizes a layout
into positioned coverage masks. Dithra multiplies sizes and positions by
`device_scale`; Syllo's own output stays logical.

## Caret and selection (single line)

```bend
import ./Syllo/caret.bend as SC

type Stop is Data:  Stop{index: U32, x: F32}
type Band is Data:  Band{x: F32, top: F32, width: F32, height: F32}
type Unsupported is Data:  Unsupported{index: U32, scalar: U32}

SC.stops(l: S.Layout) -> Result<&2, &2, String, List<&2, Stop>>
SC.snap(stops: List<&2, Stop>, i: U32) -> U32
SC.caret_x(stops: List<&2, Stop>, i: U32) -> F32
SC.hit(stops: List<&2, Stop>, x: F32) -> U32
SC.selection(stops: List<&2, Stop>, from: U32, to: U32, line_height: F32) -> List<&2, Band>
SC.unsupported(font: F.Font, text: String) -> Maybe<&2, Unsupported>
```

- `stops` gives one `Stop{source_start, x}` per placement, in order, then the
  end stop `Stop{source_end, x + advance}` of the last placement; its x equals
  the layout's `width`. Empty text gives `[Stop{0, 0.0}]`. A layout with more
  than one line (a line feed or a wrap) fails: lay a field out with a width
  that cannot wrap.
- `snap(stops, i)` is the largest stop index `<= i`: the index between a base
  and its combining mark snaps to the base, and an index past the end clamps
  to the end stop. `caret_x` is that stop's x.
- `hit(stops, x)` is the index of the stop nearest to `x`, measured as
  `|x - stop.x|`; an exact tie goes to the left stop. Negative `x` gives the
  first stop and `x` past the end gives the end stop. `x` is relative to the
  layout origin: subtract the text origin and add any scroll before calling.
- `selection` snaps both ends, orders them, and returns no band when they
  meet, otherwise one band from the left caret x to the right one, with
  `top = 0` (the top of the line box) and `height = line_height`.
- `unsupported(font, text)` applies `layout`'s rules (accepted scalars, listed
  combining pairs, the font's glyphs, the 4096-scalar limit) and returns the
  first problem in text order, or `None` exactly when `layout` would accept the
  text at a valid size and width. A rejected mark (leading, unlisted pair or
  second mark) is reported at its own index. A cluster without a glyph is
  reported at its start with the scalar looked up, which is the composed
  Latin-1 scalar for a base and mark. The length limit reports `(4096, scalar)`.

All queries walk the stop list once, without closures.
