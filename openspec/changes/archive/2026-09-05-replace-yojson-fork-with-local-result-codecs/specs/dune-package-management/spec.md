## MODIFIED Requirements

### Requirement: Released PPX dependency
The project SHALL resolve the official `ppx_deriving_yojson` version `3.10.0` from the package repository through Dune Package Management without a project-level Git pin.

#### Scenario: Resolve the PPX dependency
- **WHEN** Dune resolves the project's dependencies with the committed lock directory present
- **THEN** it obtains the official `ppx_deriving_yojson` version `3.10.0` from the package repository without using a Git source

## RENAMED Requirements

- FROM: `### Requirement: Forked PPX dependency`
- TO: `### Requirement: Released PPX dependency`
