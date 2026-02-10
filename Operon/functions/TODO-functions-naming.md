# Functions Nomenclature TODO

## Completed in this pass
- Add domain index exports for clients and raw-materials.
- Route root exports through domain indexes for a consistent entry point.

## Next steps (naming consistency)
- Align WhatsApp-related function names to a single verb pattern (e.g., use `SendWhatsapp` everywhere) while keeping existing callable names as aliases to avoid breaking clients.
- Standardize callable verb prefixes for similar actions (e.g., `generateDM` vs `onTripReturnedCreateDM`) without changing deployed names.
- Ensure any future renames keep backward-compatible exports in domain index files.
