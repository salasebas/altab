# Acknowledgments

## Upstream lineage

AlTab is derived from [AltTab for macOS](https://github.com/lwouis/alt-tab-macos). Its Git history, GPL-3.0 license, copyright notices, and contributor authorship are retained. AlTab is an independent fork and is not affiliated with or endorsed by the upstream maintainers.

## Third-party libraries

These third-party libraries are used:

**ShortcutRecorder**

AlTab vendors source from [lwouis/ShortcutRecorder](https://github.com/lwouis/ShortcutRecorder) at commit `52c6273d233f7794e4fd5d22f50d2de0e4e41b19`, rearranged for Swift Package Manager and patched to locate its resource bundle. It is distributed under the [Creative Commons Attribution 4.0 International license](../vendor/ShortcutRecorder/LICENSE.txt).

**Apple SF Symbols subset**

The app includes a tracked subset of Apple SF Pro Text glyphs used to render SF Symbols on supported Apple platforms. Its exact build input is `resources/SF-Pro-Text-Regular.otf` with SHA-256 `aa702e9da824bc3d251076afd93ed431dc9142d04b24411282e169bb07c98831`; use remains subject to [Apple's San Francisco font license and SF Symbols terms](https://developer.apple.com/fonts/). The release process does not regenerate this file from a maintainer's locally installed font.

## Build tools included with the source

- [xcbeautify 3.0.0](https://github.com/cpisciotta/xcbeautify), MIT license: [`scripts/licenses/xcbeautify-LICENSE.txt`](../scripts/licenses/xcbeautify-LICENSE.txt)
- [createicns](https://github.com/lwouis/createicns), BSD 2-Clause license: [`scripts/licenses/createicns-LICENSE.txt`](../scripts/licenses/createicns-LICENSE.txt)

Binary release packages copy these license texts into their top-level `licenses` directory.

## AlTab brand artwork

The application icon and menu-bar artwork come from [salasebas/altab-archived](https://github.com/salasebas/altab-archived) at revision `6fe0c6455c00c050f8ac061621117f50adcf1c71`.

MIT License

Copyright (c) 2026 salasebas

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
