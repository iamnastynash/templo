# Notice

## Templo (this fork)

Templo is a modified version of OpenStrap Edge (https://github.com/OpenStrap/edge),
distributed under the same AGPL-3.0 licence (see `LICENSE`). Modified starting
2026-11-17. Changes, by area:

- Design system (`lib/ui2/theme.dart`): new palette, day/night grounds, quality
  colour scale, hero numerals; `lib/ui2/pulso_chart.dart` (GlowLine) is new.
- New features: `lib/compute/pulso/*`, `lib/state/pulso_store.dart`,
  `lib/ui2/screens/pulso_*.dart`; Home, Health and the tab bar wire them in.
- Branding: app name, icons and user-facing strings changed from OpenStrap to
  Templo; community, donation, crash-report, issue-report and data-contribution
  features removed; Firebase is not initialised.
- Tests updated or added for all of the above.

Templo is not affiliated with OpenStrap or WHOOP, Inc.

---

## Original notice (OpenStrap Edge)

Edge is an independent, open-source project (AGPL-3.0, see `LICENSE`; versions up to
commit 1140dac1 were MIT, see `NOTICE`). It
is not affiliated with, sponsored by, or endorsed by WHOOP, Inc. or any of its
trademarks.

No WHOOP source code, binaries, firmware, or copyrighted assets are included
in this repository.

## wger exercise data

`lib/ui2/activity/wger_exercises.g.dart` contains selected fields (names,
aliases, muscles, equipment, categories) from the [wger](https://wger.de)
exercise database, limited to the movements listed in
`tool/wger_weightlifting_selection.dart`. Each entry is available under
CC BY-SA 3.0, CC BY-SA 4.0 or CC0, and each row keeps its source UUID and the
author/license credits of its base data and translations. This data stays under
those licenses, separate from the AGPL-licensed code. Refresh with
`dart run tool/update_wger_exercises.dart`.

## Templo

Templo es una modificación independiente de [OpenStrap Edge](https://github.com/OpenStrap/edge), basada en el commit `cd64eaa8`. El 17 de noviembre de 2026 se modificó la identidad visual, se añadieron pantallas y cálculos de bienestar y se retiraron las integraciones con los servicios alojados de OpenStrap. Véase el [registro de cambios](CHANGELOG.md). Se conservan el [aviso original](NOTICE), la [GNU AGPL v3](LICENSE) y los avisos de las dependencias.

Templo bundles [Geist](https://github.com/vercel/geist-font) under the [SIL Open Font License 1.1](assets/fonts/Geist/OFL.txt).
