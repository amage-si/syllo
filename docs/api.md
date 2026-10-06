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
