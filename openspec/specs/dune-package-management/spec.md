# dune-package-management Specification

## Purpose

Provides reproducible project builds without requiring an active opam-switch to supply project dependencies.

## Requirements

### Requirement: Dune-managed dependency resolution
The project SHALL enable Dune Package Management for its regular `dune` commands. A `dune build` or `dune test` invocation SHALL resolve project dependencies through Dune rather than from libraries installed in the active opam-switch.

#### Scenario: Build from a fresh checkout
- **WHEN** a developer runs `dune build` in a checkout without project dependencies installed in the active opam-switch
- **THEN** Dune obtains the dependencies needed to build the project and the build can proceed

### Requirement: Forked PPX dependency
The project SHALL resolve `ppx_deriving_yojson` from the configured `y2k/ppx_deriving_yojson` Git source through Dune Package Management. The committed `dune.lock` directory SHALL record commit `b10a96d` as that dependency's source revision.

#### Scenario: Resolve the PPX dependency
- **WHEN** Dune resolves the project's dependencies with the committed lock directory present
- **THEN** it obtains `ppx_deriving_yojson` from the configured fork at commit `b10a96d`

### Requirement: Locked dependency graph
The repository SHALL contain a `dune.lock` directory that records the resolved compiler and transitive package sources. Regular Dune-managed builds SHALL use that lock directory until it is explicitly regenerated.

#### Scenario: Repeat a locked build
- **WHEN** a developer runs `dune build` with the committed `dune.lock` directory present
- **THEN** Dune uses the package versions and sources recorded in the lock directory
