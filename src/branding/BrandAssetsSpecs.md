# Brand asset regression specification

Altab ships one fork-owned template menu-bar icon. The asset must remain legible at status-item size without clipping:

- visible artwork fills at least 75% of the square canvas height;
- visible artwork is no more than 1.15 times as wide as it is tall;
- visible artwork uses no more than 90% of the canvas width, preserving horizontal inset.

The regression test renders the bundled vector resource rather than a source-tree path so it also verifies that the test target packages the shipped asset.
