# Introduction
LATE is a library for managing lasting effects, not instant effects.

**Targets**: Targets of effects. For now, players and mobs can be targets of effects.

**Impacts**: An elementary impact on target. Different effects can result in the same impact. In that case, their parameters and intensities are properly mixed to result in a single impact.

**Effects**: Combination of impacts, conditions and target. Many effects at once can be affected to a target, with different conditions (duration, area, equipment).

Conditions are only for stopping effect. LATE does not automatically start effects where condition are fulfilled. This would be far too difficult to continuously check for every possibility. Effect creation has to be triggered explicitely. Some helpers exist to start effects automatically on certain events.

# Effects management
Active effects are represented by Effect objects. Effect objects are created by calling `late.new_effect` method. Effects can also be automatically affected when using some items and blocks. In that case, they are defined in item or node definition.

## Effect phases
Effects have a cycle of life involving four phases:
### raise
Effect starts in this phase.  
It stops after `raise` seconds or if effect conditions are no longer fulfilled.  
Intensity of effect grows from 0 to 1 during this phase.
### still
Once raise phase is completed, effects enters the *still* phase.  
Intensity is full and the phases lasts until one of the conditions stops being fulfilled.
### fall
When conditions are no longer fulfilled, effect enters fall phase.  
This phase lasts `fall` seconds (if 0, effects gets to *end* phase instantly).
### end
This is the terminal phase.  
Effect will be deleted in next step.

## Effect definition table
Effect definition table may contain following fields:  
  * `id` Identifier. If given, should be unique for a target. If not given, an internal id is given.
  * `impacts` Impacts effect has (pair of impact name / impact parameters);
  * `raise` Time (in seconds) it takes to raise to full intensity (default 0: immediate);
  * `fall` Time (in seconds) it takes to fall, after end to no intensity (default 0: immediate);
  * `duration` Duration (in seconds) the effect lasts (default: always);
  * `distance` For effect associated to nodes, distance of action;
  * `stop_on_death` If true, the effect stops at player death;
  * `hud` Hud defition (see Hud definition table section);

All fields are optional but an effect without impacts would do nothing.

### Hud definition table
Hud definition table (hud field of effect definition) may contain following fields:
  * `icon` Texture used to display effect in hud;
  * `color` Color of the hud background;

### Example of effect definition
```lua
-- Run fast and make high jumps for 20 seconds
{
    impacts = { jump=3, speed=10 },
    fall = 2,
    duration = 20
}
```
Of course, *jump* and *speed* impacts have to be defined (they are included in base impacts).

## How to affect effects?

### With custom code
To affect a target with an effect, create a new effect using `late.new_effect`, giving the target and the effect definition.
Think about adding a `duration` or `stop_on_death` clause in effect definition to avoid permanent effect (unless expected).

Example :
```lua
-- Stuck player "toto" for 5 seconds
local player = minetest.get_player_by_name("toto")
if player then
    late.new_effect(player, { duration=5, impacts = { speed=0 } })
end
```

### Using items
Items can have effects on players or mobs when:
  * Equiped (in hand or in armor equipment): cloth, amulets, rings;
  * Used (effect on self): potion, food;
  * Used (on someone or something): magic wand, special weapon;

#### Effect when equiped
To create an item that have an effect when equiped, add to the item definition a field named `effect_equip` containing the effect definition.

Example:
```lua
-- Jump boots
minetest.register_tool("mymod:jump_boots", {
    description = "Jump boots",
	inventory_image = "mymod_boots.png",
    effect_equip = { impacts = { jump=3 } },
})
```
To make boots wearable as boots armor, refer to **3D Armor** mod API.

#### Effect when used
To create an item that have an effect when used:
  * Put the effect definition in item definition field `effect_use` (for use on self) or `effect_use_on` (for use on players or mobs);
  * Add a call to `late.on_use_tool_callback` in item `on_use`;
  * Add an end condition to avoid creating permanent effect : a `duration` clause or `stop_on_death=true` clause;

Example:
```lua
-- Poison potion
minetest.register_tool("mymod:poison", {
    description = "Poison potion",
	inventory_image = "mymod_potion.png",
    effect_use = { impacts = { damage={ 1, 2 } }, stop_on_death=true },
    on_use = late.on_use_tool_callback,
})
```

### Placing nodes
Effects can be triggered by the proximity of a specific node.

To create a node with effect:
  * Add the node in `effect_trigger` group (`effect_trigger=1` in groups table);
  * Add an `effect_near` field in the node definition __with a `distance`field__;

Example:
```lua
-- Darkness 20 nodes around dark stone
minetest.register_node("mymod:dark_stone", {
	description = "Dark stone",
	tiles = {"default_stone.png"},
    groups = { cracky = 3, stone = 1, effect_trigger = 1 },
    effect_near = { impacts = { daylight=0 }, distance = 20 },
})
```

## Methods
### get\_effect\_by\_id
```lua
function late.get_effect_by_id(target, id)
```
Retrieves an effect affecting a target by it's id.

`target`: Target of the effect.  
`id`: Identifier of the effect to retrieve.

Returns the Effect object if found, `nil` otherwise.

### on\_use\_tool\_callback
```lua
function late.on_use_tool_callback(itemstack, user, pointed_thing)
```
Standard `on_use` tool callback to be added to tools with effects (see above).

## Effect object
Effect object represent a temporary (or permanent) effect on a target (player or mob).

### Public methods
#### new
```lua
function Effect:new(target, definition)
```
Public API :
```lua
function late.new_effect(target, definition)
```
Creates a new effect on a target.

`target`: Target to be affected by the effect.  
`definition`: Effect defintion table.

Returns an Effect object if creation succeded, `nil` otherwise.

Possible cause of failure :
  * Target is not suitable (neither a player nor a mob);
  * `definition.id` (optional) field contains a value that is already in use for the target (check first with `late.get_effect_by_id` if you are using ids);

#### start
```lua
function Effect:start()
```
Starts an effect or restart it.

If conditions are not fulfilled, it will fall in *fall* phase again during next step. So `start`/`restart` should be called only if condition are fulfilled again.

#### restart
```lua
function Effect:restart()
```
Same as `start`.

#### stop
```lua
function Effect:stop()
```
Stops an effect. Actually set it in *fall* phase, regardless of conditions.

#### change\_intensity
```lua
function Effect:change_intensity(intensity)
```
Change intensity of effect.

`intensity`: New intensity (between 0.0 and 1.0)

Developed for internal purpose but safe to use as public method.

#### set\_conditions(conditions)
```lua
function Effect:set_conditions(conditions)
```
Sets or overrides condition(s) of an effect.
`conditions` Key / value table of conditions.

Developed for internal purpose but safe to use as public method.

### Internal use methods (unsafe)
#### add\_impact
```lua
function Effect:add_impact(type_name, params)
```
Add a new impact to the effect.

`type_name`: Impact type name  
`params`: Params for that impact (refer to the corresponding impact type definition)

#### remove\_impact
```lua
function Effect:remove_impact(type_name)
```
Remove an impact from effect.

`type_name`: Impact type name  

#### step
```lua
function Effect:step(dtime)
```
Performs a step calculation of effect.
`dtime`: Time since last step.

# Conditions registration
## register\_condition\_type
```lua
function late.register_condition_type(name, definition)
```
Registers a condition type.
Conditions are checked each step to determine if the effect should last or stop.
Registering new condition types allows to extend the available types of conditions.

`name`: Name of the condition type.  
`definition`: Definition table of the condition type.  

### Condition definition table
`definition` table may contain following fields:
  * `check` (optional) = function(data, target, effect) A function called to check is a condition is fulfilled. Should return true if condition still fulfilled, false otherwise. This function is not called at each step, only when engine needs it. Function parameters:
    * `data`: effect data
    * `target`: target affected,
    * `effect`: Effect object instance.
  * `step` (optional) = function(data, target, effect) A function called at each step. Could be useful to prepare condition checking. Same parameters as `check` function.

# Impacts registration
## register\_player\_impact\_type
```lua
function late.register_player_impact_type(target_types, name, definition)
```
Registers an impact type.

`target_types`: Target type or table of target types that can be affected by that impact type  
`name`: Name of the impact type  
`definition`: Definition table of the impact type

### Impact definition table
`definition` table may contain following fields:
  * `vars`Internal variables needed by the impact (variables will instantiated for each player) (optional);
  * `reset` (optional) = function(impact) Function called when impact stops to reset normal player state (optional);
  * `update` (optional) = function(impact) Function called when impact changes to apply impact on player;
  * `step` (optional) = function(impact, dtime) Function called every global step (optional);

### Impact instance table
`impact`argument passed to `reset`, `update` and `step` functions is a table representing the impact instance concerned. Table fields are :
  * `target` Player or mob ObjectRef affected by the impact;
  * `type` Impact type name;
  * `vars` Table of impact variables (copied from impact type definition) indexed by their name;
  * `params` Table of per effect params and intensity;
  * `changed` True if impact changed since last step;

Except variables in `vars`, nothing should be changed by the functions.

 # Impact Helpers

In following helpers, valint stands for a pair of value / intensity.

Each effect corresponding to an impact gives one or more parameters to the impact and an effect intensity.

The impact is responsible of computing a single values from these parameters and intensity. LATE provides helpers to perform common combination operations.
## get_valints
```lua
function late.get_valints(params, index)
```
Returns extacts value/intensity pairs from impact params table.

Impact params table contains params given by effects definition, plus an *intensity* field reflecting the corresponding effect intensity.

`params`: the impact.params field  
`index`: index of the params field to be extracted

## append_valints
```lua
function late.append_valints(valints, extravalints)
```
Appends a values and intensities list to another. Usefull to add extra values in further computation.

`valints`: List where extra valints will be append  
`extravalints`: Extra valints to append

## multiply_valints
```lua
function late.multiply_valints(valints)
```
Returns the result of a multiplication of values with intensities

`valints`: Value/Intensity list;

## sum_valints
```lua
function late.sum_valints(valints)
```
Returns the result of a sum of values with intensities

`valints`: Value/Intensity list

## superpose_valints
```lua
function late.superpose_valints(valints, base_value)
```
Returns a ratio superposition (like if each ratio was a greyscale value and intensities where alpha chanel).
`valints` Value/Intensity list of ratios (values should go from 0 to 1)  
`base_value` Base ratio value on which valints are superposed  

## superpose_color_valints
```lua
function late.superpose_color_valints(valints, background_color)
```
Returns a color superposition with alpha channel and intensity (actually, intensity is considered as a factor on alpha channel)
`valints` Value/Intensity list of colors  
`background_color` Background color (default none)

## mix_color_valints
```lua
function late.mix_color_valints(valints)
```
Mix colors with intensity. Returns {r,g,b,a} table representing the resulting color.

`valints` List of colorstrings (value=) and intensities

## color_to_table
```lua
function late.color_to_table(colorspec)
```
Converts a colorspec to a {r,g,b,a} table. Returns the conversion result.

`colorspec` Can be a standard color name, a 32 bit integer or a table

## color_to_rgb_texture
```lua
function late.color_to_rgb_texture(colorspec)
```
Converts a colorspec to a "#RRGGBB" string ready to use in textures.

`colorspec` Can be a standard color name, a 32 bit integer or a table

## Full example of impact type creation
```lua
-- Impacts on player speed
-- Params:
-- 1: Speed multiplier [0..infinite]. Default: 1
late.register_player_impact_type('speed', {
    -- Reset function basically resets target speed to default value
    reset = function(impact)
            impact.player:set_physics_override({speed = 1.0})
        end,
    -- Main function actually coding the impact
    update = function(impact)
        -- Use multiply_valints and get_valints to perform parameter and intensity mixing between all effects
        impact.player:set_physics_override({speed =
            speed = late.multiply_valints(
                late.get_valints(impact.params, 1))
        })
    end,
})
```

# More internal stuff
## get_storage_for_target
```lua
late.get_storage_for_target(target)
```
Retrieves or create the effects_api storage for a target.

`target`: Target

Returns storage associated with the target or `nil` if target not suitable.
