# LATE - Basic impacts
This documents describes basic impacts provided by LATE mod. Basic impacts deals with simple minetest parameters. More complex impacts are provided by Late Extra Impacts mod.

## Effect groups modifiers [effects]
**Targets**: All  
**Status**: Ok

This is a special impact that multiplies intensities of effects belonging to given group (effects affecting the same target).

Can be used to immunize the target against some effects, using a 0 multiplier.

### Parameters
Parameters are a list of key/value pairs. Key is the name of effect group, value is a positive multiplier.

### Example

```{ poison = 0, damage = 0.5 }```

Immunizes againts *poison* and halves *damage* effects. *poison* and *damage* do not refer to any impact name but to effect group given in the ```groups``` field of effects definition.

## Jump [jump]
**Targets**: Player  s
**Status**: Ok

Changes the jump height of the target (jump parameter of ```player:set_physics_override```).

### Parameters
| Parameter | Description     | Value         |
|-----------|-----------------|---------------|
| 1         | Jump multiplier | 0 to infinite |

## Speed [speed]
**Targets**: Players  
**Status**: Ok

Changes the speed of the target (speed parameter of ```player:set_physics_override```).

### Parameters
| Parameter | Description      | Value         |
|-----------|------------------|---------------|
| 1         | Speed multiplier | 0 to infinite |

## Gravity [gravity]
**Targets**: Players  
**Status**: Ok

Changes the gravity of the target (gravity parameter of ```player:set_physics_override```).

### Parameters
| Parameter | Description        | Value         |
|-----------|--------------------|---------------|
| 1         | Gravity multiplier | 0 to infinite |

## Damage [damage]
**Targets**: Players, Mobs  
**Status**: Needs improving (armors prevents from damaging)

Periodically damages or heals (negative damages) target.

### Parameters
| Parameter | Description                          | Values                    |
|-----------|--------------------------------------|---------------------------|
| 1         | Damage amount (negative for healing) | any number                |
| 2         | Period lenght in seconds             | 0 to infinite (default 1) |

## Breath [breath]
**Targets**: Players  
**Status**: Ok

Periodically adds or remove breath points to target.

### Parameters
| Parameter | Description              | Values                    |
|-----------|--------------------------|---------------------------|
| 1         | Breath amount            | any number                |
| 2         | Period lenght in seconds | 0 to infinite (default 1) |

## Daylight [daylight]
**Targets**: Players  
**Status**: Needs improving (better combination system)

Change the daylight perceived by the target.

### Parameters
| Parameter| Description              | Values                           |
|----------|--------------------------|----------------------------------|
| 1        | Daylight                 |  0 (pitch black) to 1 (full day) |

## Texture [texture]
**Targets**: Players, Mobs  
**Status**: Ok

Makes changes on target texture. Can be used to colorize or make invisible.

### Parameters
| Parameter| Description                     | Values                          |
|----------|---------------------------------|---------------------------------|
| colorize | Color to colorize with          |  Any colorstring (default none) |
| opacity  | Opacity (0=invisible, 1=opaque) |  0 to 1 (default 1)             |

## Nametag [nametag]
**Targets**: Players  
**Status**: Ok

Makes changes on target nametag. Can be used to colorize or make invisible.

### Parameters
| Parameter| Description                     | Values                          |
|----------|---------------------------------|---------------------------------|
| colorize | Color to colorize with          |  Any colorstring (default none) |
| opacity  | Opacity (0=invisible, 1=opaque) |  0 to 1 (default 1)             |

## Vision [vision]
**Targets**: Players  
**Status**: WIP

Alters player vision

### Parameters
| Parameter| Description                      | Values  |
|----------|----------------------------------|---------|
| 1        | Vision ( 0 = blind, 1 = normal)  | 0 to 1  |

## Fly [fly]
**Targets**: Players  
**Status**: WIP (actualy fly privs is not satisfying)

Makes target able to fly

### Parameters
| Parameter| Description              | Values  |
|----------|--------------------------|---------|
| 1        | 1 for fly, 0 for no fly  | 0 to 1  |
