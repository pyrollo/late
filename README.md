# LATE - Library Adding Temporary Effects
This Minetest library adds possibility to easily create temporary effects affecting players and mobs.

**Version**: Alpha

**Dependancies**: default, 3d_armor (optional)

**License**: LGPL v2.1

This library does not directly offer anything new to the game. It has to be used by other mods.

**API**: See [API.md](https://github.com/pyrollo/late/blob/master/API.md) document please.

## Related mods

  * [late_demo](https://github.com/pyrollo/late_demo): A basic demo mod ([impacts documented here](basic_impacts.md)).
  * [late_extra_impacts](https://github.com/pyrollo/late_extra_impacts): Adds more elaborated impacts (only *illuminate* impact for now)

## Expected improvements

### Short term

  * Effect cancellation
  * Several effects on items and nodes
  * More impact types, on mobs in particular

### Long term

  * Effects on world itself
  * Persistance of effects on mobs (now only player effects persist)
  * Particles

## Version history

### 2018-11-21 Hud improvements by texmex

  * HUD system improved, added to demo and documentation
  * Custom conditions can now be registered

### 2018-08-05 Ongoing development

  * Demo mod (see [late_demo](https://github.com/pyrollo/late_demo))
  * HUD system (not in demo yet)
  * Distance fading effects
  * Effects modifiers impact (allows creation of antidote effects)
  * New impact types: breath, nametag

### 2018-08-26 Alpha version (dev still in progress)
