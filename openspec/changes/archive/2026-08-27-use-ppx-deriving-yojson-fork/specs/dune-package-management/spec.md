## MODIFIED Requirements

### Requirement: Forked PPX dependency
The project SHALL resolve `ppx_deriving_yojson` from the configured `y2k/ppx_deriving_yojson` Git source through Dune Package Management. The committed `dune.lock` directory SHALL record commit `b10a96d` as that dependency's source revision.

#### Scenario: Resolve the PPX dependency
- **WHEN** Dune resolves the project's dependencies with the committed lock directory present
- **THEN** it obtains `ppx_deriving_yojson` from the configured fork at commit `b10a96d`

## RENAMED Requirements

- FROM: `### Requirement: Released PPX dependency`
- TO: `### Requirement: Forked PPX dependency`
