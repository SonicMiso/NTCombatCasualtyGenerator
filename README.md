# NT Combat Casualty Generator

Barotrauma LuaCs + Neurotrauma addon.

## Requirements
- Barotrauma 1.13.x
- Neurotrauma
- LuaCsForBarotrauma

Neurotrauma remains the source of the medical afflictions and body-trauma helpers used by this mod.

## Usage
1. Put this folder in `Barotrauma/LocalMods/`.
2. Enable the mod after Neurotrauma in the server's Lua/content load order.
3. In the Submarine Editor, place **NT Combat Casualty Revolver**.
4. Fire it.

Each shot generates **5 inert human NPCs** within a few pixels of the revolver.

## What is randomized?
There are five triage profiles:
- isolated limb gunshot
- multiple extremity wounds
- major torso hemorrhage
- severe penetrating polytrauma with coma
- critical, barely survivable polytrauma

The profiles are shuffled for every activation, while wound strength, body region, bleeding, organ damage, and secondary physiology are randomized inside the profiles.

## Neurotrauma effects used
The script uses Neurotrauma's existing afflictions/helpers, including:
- gunshot wound / foreign body
- bleeding
- internal bleeding
- organ / lung / heart damage
- pneumothorax
- tamponade
- fractures / dislocation
- limb-specific arterial bleeding through `NT.ArteryCutLimb`
- hypoxemia
- cerebral hypoxia
- concussion
- acidosis
- hypoventilation / respiratory arrest
- coma / stun

Acidosis is intentionally treated as a downstream consequence of severe hemorrhagic/respiratory compromise rather than being added to every casualty.

## Notes
The goal is a gameplay/medical-simulation approximation, not clinical validation. Exact outcomes depend on the installed Neurotrauma version and its configured medical model.

The Lua source prints debug output to the console when the revolver is used and when casualties are generated.
