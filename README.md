# wow-sims

A small toolkit repository for working with legacy WoW simulation workflows.

This repo currently contains:

- A packaged copy of Rawr v2.3.23 (desktop optimizer)
- The WowSimsExporter WoW addon used to export character data for simulators

## Repository Layout

- `Rawr v2.3.23/`
  - Standalone Rawr distribution files and data caches.
  - Includes `Rawr.exe.config`, data XML files, images, and talent image assets.

- `WowSimsExporter/`
  - World of Warcraft addon for exporting character information.
  - Supports generating WowSims JSON and Rawr XML export formats.
  - Includes embedded libraries under `Libs/` and addon skin assets under `Skins/`.

## What This Is For

Use this repository if you want to:

- Keep a local copy of Rawr v2.3.23 assets
- Work on or test the WowSimsExporter addon
- Export in-game character setup from WotLK Classic for external tools

## Quick Start

### Rawr

1. Open `Rawr v2.3.23/`.
2. Run `Rawr.exe`.
3. In Rawr, import a character or load data manually.

### WowSimsExporter Addon

1. Copy `WowSimsExporter/` into your WoW `Interface/AddOns/` folder.
2. Start World of Warcraft and enable the addon.
3. Use one of the commands:
   - `/wse`
   - `/wse open`
   - `/wse export` (WowSims JSON)
   - `/wse rawr` (Rawr XML)

## Rawr XML Import Flow

1. Generate Rawr XML in-game with `/wse rawr`.
2. Save the output to a file, for example `Character.xml`.
3. In Rawr, open the XML file with File -> Open.

## Notes

- `WowSimsExporter` includes third-party libraries in `Libs/`.
- Some files in this repo are legacy assets preserved for compatibility.
- Line ending warnings on Windows are expected when Git normalizes files.

## License

See the license files inside component folders, especially:

- `WowSimsExporter/LICENSE`
- Any bundled library license files under `WowSimsExporter/Libs/`
