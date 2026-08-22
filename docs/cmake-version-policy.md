# CMake Version Policy

## Current Baseline

The global minimum CMake version is 3.25. This applies to the core install
path, root `CMakePresets.json`, and the minimum CI lane. New capabilities must
remain feature-gated unless the process below approves a floor increase.

## Producer And Consumer Requirements

Producer and consumer requirements are separate. A project may use a newer
CMake feature to produce a package without raising the requirement for every
consumer of ordinary CMake config packages.

| Package capability | Producer requirement | CMake consumer requirement |
|---|---:|---:|
| Core install/config package | 3.25 | 3.25 |
| C++ module file sets | 3.28 and a supported toolchain/generator | 3.28 and a compatible toolchain/generator |
| CPS metadata | 4.3 | 4.3 when discovering the `.cps` file |
| SPDX SBOM metadata | 4.3 plus its active experiment value | Not required to consume the CMake config package |
| `SOURCES` file sets | 4.4 | 4.4; generated config packages enforce this |

The published feature documentation must state a higher consumer requirement
and generated package diagnostics must enforce it where CMake cannot consume
the package correctly on an older version. Do not infer a consumer floor from
the producer's CMake version alone.

## Raising The Global Floor

A proposal must include all of the following:

1. A user-visible capability or measurable maintenance reduction that cannot
   be delivered with an existing feature gate.
2. The oldest supported distribution and toolchain combinations affected, plus
   a practical migration path for users below the proposed floor.
3. A list of deleted compatibility branches, tests, and documentation that
   proves the maintenance reduction is real.
4. A compatibility review for installed package consumers, preset schema
   versions, C++ modules, CPS, and SBOM output.
5. Passing CI evidence for the current floor, the proposed floor, and every
   independently supported feature lane before the old lane is removed.

The maintainer reviews the policy at each planned major release and whenever a
new CMake capability would otherwise add substantial compatibility code.

## Migration Process

1. Publish a deprecation notice in at least one minor release before the
   floor change, including the old floor, new floor, migration options, and
   planned major release.
2. Raise the global floor only in the next major release. A security or
   upstream correctness blocker may shorten the notice period, but the release
   notes must explain the exception.
3. Before merging, add a CI lane for the proposed floor and keep the existing
   lowest lane. Validate configure, build, test, install, and relocated
   consumer flows with both.
4. In the floor-change PR, update `cmake_minimum_required`, the root preset
   schema/minimum, CI lanes, compatibility documentation, examples, and all
   generated-package consumer diagnostics.
5. After the major release, remove only tests and branches made unreachable by
   the new floor. Keep separate feature lanes for C++ modules, CPS, SBOM, and
   source packages when their requirements remain higher.

## Feature Gates

Feature-gated work must fail clearly on unsupported CMake versions, preserve
the 3.25 behavior when unused, and add focused tests at the relevant version
boundary. The CMake 4.4 preset is deliberately separate from the root preset
because its schema and feature requirements exceed the global floor.
