# AlTab brand asset provenance

The application and menu-bar artwork was imported from the maintainer's separate AlTab repository:

- Source repository: `salasebas/altab-archived`
- Source revision: `6fe0c6455c00c050f8ac061621117f50adcf1c71`
- Copyright: © 2026 salasebas
- License: [MIT](ALTAB-BRAND-LICENSE.txt)

| Archived source path | Bundled destination | SHA-256 |
| --- | --- | --- |
| `AlTab/Assets.xcassets/AppIcon.appiconset/icon_32x32@2x.png` | `resources/icons/app/app.iconset/icon_32x32@2x.png` | `e2bc864b21c2698133935f9a34979fd308e2ddc4ff992ba86559a8292c5db763` |
| `AlTab/Assets.xcassets/AppIcon.appiconset/icon_128x128.png` | `resources/icons/app/app.iconset/icon_128x128.png` | `fa8acb9c1abec0458d2377f38e3528ce25ad24ce7bf5d5522b6782a973118c9c` |
| `AlTab/Assets.xcassets/AppIcon.appiconset/icon_512x512@2x.png` | `resources/icons/app/app.iconset/icon_512x512@2x.png` and `docs/brand/altab-icon.png` | `d8fe1ed4abf8d95a22c82282cc88cf8d92a1b93cbba362ed135f321df17a29f9` |
| `AlTab/Assets.xcassets/MenubarIcon.imageset/menubar-0.pdf` | `resources/icons/menubar/menubar-0.pdf` | `1069b0146c793f2731f6b6aae2f5aa6775951ae6e82a03a8d4829dc331de6ef9` |

`resources/icons/app/app.icns` is generated from the three tracked app-icon representations by `scripts/assets/convert_iconset_to_icns.sh`. The generated file's SHA-256 at this revision is `32297ebdca878749869529ea893843c066ca26d96855dc3a2cb1806e7b7f74d1`.

These assets are not the upstream AltTab artwork. The MIT notice is also reproduced in the acknowledgments bundled with the application.
