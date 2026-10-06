# Syllo: instructions for contributors and agents

Syllo is the text shaping and layout layer of the AMAGE UI ecosystem,
implemented in **Bend 2**: it turns text into positioned glyphs and lines, and
exposes the relations between text and glyphs that cursor, selection, and
editing need. Read the README for current capabilities and limits; a roadmap
item is not implemented merely because it appears in the project scope.

## Implementation

- Implement library logic in Bend 2, rather than wrapping an existing shaping or
  layout engine (HarfBuzz, ICU, Pango, ...).
- Font data comes from Runika; rasterization belongs to Dithra. Keep Syllo's
  output in logical units and document every conversion at the boundary.
- Index text by Unicode scalar, never by UTF-8 byte. Reject unsupported text
  with a clear error instead of producing a plausible but wrong layout.
- The official Bend compiler/runtime, OS APIs, and drivers remain external
  dependencies. Keep any future native bridge minimal, explicit, and separate.
- Before writing Bend, run `bend version` and read `bend guide` from the installed
  toolchain. Verify available syntax/effects instead of assuming old examples work.
- Keep source, comments, documentation, and commit messages in English.

## Linux first

The initial goal is excellent behavior on Ian's actual Linux development machine:
legible, correctly measured text in everyday use, starting with Portuguese and
its accents, then broader coverage with verifiable examples. Inspect the
effective environment before choosing integrations.

Build compatibility layers as the project progresses, after visible, well-made
Linux results. Do not let speculative Windows or macOS abstractions delay local
quality. Introduce abstractions from concrete needs.

## Working practice

- Preserve existing work and keep the library's boundary clear. Dithra, Mokko,
  and other siblings import Syllo by relative path; coordinate API changes with them.
- Favor simple, maintainable code. Pursue fast, polished behavior with evidence.
- Run the native checks after changes. When layout changes visible text, render
  it through Dithra and look at the result.
- Compilation is not visual proof. Runtime checks are not proofs of the entire
  system. State partial support and unverified behavior explicitly.
- Build sequentially. Do not impose virtual-address limits on the Bend runtime
  or suppress crash reporting. Investigate failures before retrying.
- Keep generated binaries, logs, crash dumps, credentials, font files, and
  machine-specific evidence out of Git. Stage explicit paths and preserve
  concurrent changes.

See [CONTRIBUTING.md](CONTRIBUTING.md) for validation commands.
