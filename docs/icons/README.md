# Drag-handle icons

`Icons/draghandle.tga` (unlocked, green) and `Icons/draghandle-checked.tga` (locked, red)
are drawn by [make_icons.py](make_icons.py); they are not copied from anywhere. The game
shows them at 16x16 from a 32x32 texture.

The design in use is **set 2, variant I** (glass band in a metal socket). The other
designs are kept for reference:

- [designs-set1.png](designs-set1.png): first round
- [designs-set2.png](designs-set2.png): second round, keeping A, B, C and G from the first

Each sheet shows every design at 16, 24 and 32 pixels and enlarged, on a dark and on a
green "game world" background.

## Regenerating

Needs Python 3 with numpy and Pillow.

```powershell
python docs\icons\make_icons.py $env:TEMP\buffpower-icons
Copy-Item $env:TEMP\buffpower-icons\set2\I\*.tga Icons\
```

The script writes `<set>\<variant>\draghandle.tga`, `draghandle-checked.tga` and one
`sheet.png` per set. To change a design, edit its `v_*` function, rerun, and compare the
sheets before copying the TGAs into `Icons/`.
