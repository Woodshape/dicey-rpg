# Visual & Polish Issues

## Dice Type Representation (Milestone 8)

- Currently dice are represented by plain colours only. No icons or distinct shapes.
- Goal: make each die type immediately recognisable at a glance without relying on colour alone.
- Options:
  - Draw the die face count as a polygon (d4 = triangle, d6 = square, d8 = diamond, d10 = pentagon, d12 = hexagon)
  - Use icons/symbols rendered as text or sprites
  - Show the die type label (d4, d6, etc.) rendered inside the die shape
- Skull dice already have a distinct pale bone-white colour — may also benefit from a symbol.

## Rolled Value Display

- Rolled values are shown on dice after rolling. Confirm that matched dice vs unmatched dice remain clearly distinguishable at a glance (colour highlight or border).

## Combat Log

- Combat log with file output is implemented. Verify the on-screen portion is readable during fast play without obscuring the board or character panels.

## Ability Name Display

- Ability names and effects are shown on screen. Ensure layout doesn't overlap with character stat display or the combat log, especially in 2v2.
