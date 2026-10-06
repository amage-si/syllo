# Contributing to Syllo

Use Bend 2.0.35 for the current baseline. Read `bend guide` before editing Bend
and keep project text in English. Library implementation belongs in Bend; the
official runtime and operating system remain external dependencies.

Clone [Runika](https://github.com/amage-si/runika) and
[Splina](https://github.com/amage-si/splina) next to Syllo (as `Runika` and
`Splina`), and install Liberation Sans 2.1.5 at
`/usr/share/fonts/liberation/LiberationSans-Regular.ttf`.

## Validation

From the repository root:

```sh
export BEND_NO_TELEMETRY=1
mkdir -p build
bend tests.bend -o build/tests
./build/tests --threads 2 --gpu off
bend examples/layout.bend -o build/layout
./build/layout --threads 2 --gpu off
```

When a change affects visible text, also build Dithra's text demo with Syllo in
place and inspect the exported image (see Dithra's README). Numbers alone do
not show overlapping glyphs, misplaced accents, or bad breaks.

Build one target at a time. The native Bend runtime reserves substantial virtual
address space; a virtual-memory limit is not a resident-memory limit. Preserve
crash evidence and investigate before repeating a failed compiler invocation.

## Changes

Keep the API small and the units explicit. Add a focused regression check when
behavior changes, including the rejection of input just outside the new
coverage, update affected contracts, and report what was actually validated.

Use English commit messages that explain the result. Do not commit `build/`,
generated C, logs, crash dumps, font files, credentials, or machine-specific
paths. Do not publish BendHub packages or create releases as a side effect of
validation.
