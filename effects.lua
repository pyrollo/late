--[[
	Late library for Minetest - Library adding temporary effects.
	(c) Pierre-Yves Rollo

	This program is free software: you can redistribute it and/or modify
	it under the terms of the GNU Lesser General Public License as published
	by the Free Software Foundation, either version 2.1 of the License, or
	(at your option) any later version.

	This program is distributed in the hope that it will be useful,
	but WITHOUT ANY WARRANTY; without even the implied warranty of
	MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
	GNU General Public License for more details.

	You should have received a copy of the GNU General Public License
	along with this program.  If not, see <http://www.gnu.org/licenses/>.
--]]

-- Mod internal data
--------------------

-- Name of the players meta in which is saved effects data
local save_meta_key = "late:active_effects"

-- Interval in seconds at which effects data is saved into players meta (only
-- usefull in case of abdnormal server termination)
-- TODO:Move into a mod settings
local save_interval = 1

-- Effect phases
----------------

local phase_raise = 1
-- Effects starts in this phase. It stops after effect.raise seconds or when
-- effect conditions are no longer fulfilled. Intensity of effect grows from 0
--  to 1 during this phase

local phase_still = 2
-- Once raise phase is completed, effects enters the still phase. Intensity is
-- full and the phases lasts as long as conditions are fulfilled.

local phase_fall  = 3
-- When conditions are no longer fulfilled, effect enters fall phase. This
-- phase lasts effect.fall seconds (if 0, effects gets to next phase
-- instantly).

local phase_end  = 4
-- This is the terminal phase. Effect in this phase are deleted.

-- Helper
---------

local function calliffunc(fct, ...)
	if type(fct) == 'function' then
		return fct(...)
	end
end

local function nvl(var, val)
	if var == nil then return val else return var end
end

-- Targets
----------

local target_data = {}
-- Automatically clean unused data by using a weak key table
setmetatable(target_data, {__mode = "k"})

-- Return data storage for target (nil for inapropriate targets)
local function data(target)
	if target_data[target] then
		return target_data[target]
	end

	-- Try to create a data entry for new target
	if minetest.is_player(target) then
		target_data[target] = {
			effects={}, impacts={}, type = 'player',
			string = string.format('Player "%s"', target:get_player_name())
		}
	elseif target.get_luaentity then
		local entity = target:get_luaentity()

		-- Mobs
		if entity and entity.type then
			target_data[target] = {
				effects={}, impacts={},	type = 'mob',
				string = string.format('Mob "%s"', entity.name)
			}
		end
	end

	return target_data[target]
end

-- Explose data function to API
late.get_storage_for_target = data

-- Item effects
---------------
-- TODO: To be moved ?

function late.set_equip_effect(target, item_name)
	local definition = minetest.registered_items[item_name] and
		minetest.registered_items[item_name].effect_equip or nil
	if definition then
		definition.id = 'equip:'..item_name

		local effect = late.get_effect_by_id(target, definition.id)
		if effect == nil then
			effect = late.new_effect(target, definition)
			effect:set_conditions({ equiped_with = item_name })
			effect:start()
		end
		-- Restart effect in case it was in fall phase
		effect:restart()
	end
end

function late.on_use_tool_callback(itemstack, user, pointed_thing)
	local def = minetest.registered_items[itemstack:get_name()]

	if def then
		if def.effect_use_on and pointed_thing.type == "object" then
		--TODO: if using Id, should restart existing item
			late.new_effect(pointed_thing.ref, def.effect_use_on)
		end
		if def.effect_use then
			late.new_effect(user, def.effect_use)
		end
	end
end

-- Effect object
----------------

local Effect = {}
Effect.__index = Effect

--- new
-- Creates an effect and affects it to a target
-- @param target Target of the effect (player, mob or world)
-- @param effect_definition Definition of the effect
-- @return effect affecting the player
--
-- effect_definition = {
--	groups = {},  -- Permet d'agir de l'exterieur sur l'effet
--	impacts = {}, -- Impacts effect has (pair of impact name / impact parameters
--	raise = x,    -- Time it takes in seconds to raise to its full intensity
--	fall = x,     -- Time it takes to fall, after end to no intensity
--  duration = x, -- Duration of maximum intensity in seconds (default always)
--  distance = x, -- In case of effect associated to a node, distance of action
--	stopondeath = true, --?
--}
-- impacts = { impactname = parameter, impactname2 = { param1, param2 }, ... }

function Effect:new(target, definition)
	-- Verify target
	local data = data(target)
	if data == nil then return nil end

	-- Check for existing ID
	if definition.id and data.effects[definition.id] then
		minetest.log('error', '[late] Effect ID "'..definition.id..
			'" already exists for '..data.string..'.')
		return nil
	end

	-- Instanciation
	self = table.copy(definition)
	setmetatable(self, Effect)

	-- Default values
	self.elapsed_time = self.elapsed_time or 0
	self.phase = self.phase or phase_raise
	self.target = target

	self.intensities = self.intensities or {}

	-- Duration condition
	if self.duration then
		self:set_conditions( { duration = self.duration } )  -- - ( effect.fall or 0 )
	end

	-- Affect to target
	if self.id then
		data.effects[self.id] = self
	else
		table.insert(data.effects, self)
	end

	-- Create impacts
	local impacts = self.impacts
	self.impacts = {}

	if impacts then
		for type_name, params in pairs(impacts) do
			self:add_impact(type_name, params)
		end
	end

	return self
end

-- Explose new method to API
function late.new_effect(...)
	return Effect:new(...)
end

-- TODO: Clip value to 0-1
function Effect:change_intensity(intensity)
	if self.intensities.custom == nil or self.intensities.custom ~= intensity then
		self.intensities.custom = intensity
		self.changed = true
	end
end

--- add_impact
-- Add a new impact to effect
-- @param type_name Impact type name
-- @param params Parameters of the impact

function Effect:add_impact(type_name, params)
	local data = data(self.target)
	local impact_type = late.get_impact_type(data.type, type_name)

	-- Impact type unknown or not for this type of target
	if not impact_type then	return end

	-- Add impact to effect
	if type(params) == 'table' then
		self.impacts[type_name] = table.copy(params)
	else
		self.impacts[type_name] = { params }
	end

	-- Link effect to target impact
	local impact = data.impacts[type_name]
	if not impact then
		-- First effect having this impact on target : create impact
		impact = {
			vars = table.copy(impact_type.vars or {}),
			params = {},
			target = self.target,
			type = type_name,
		}
		data.impacts[type_name] = impact
	end

	-- Link effect params to impact params
	impact.changed = true
	table.insert(impact.params, self.impacts[type_name])
end

--- remove_impact
-- Remove impact from effect
-- @param type_name Impact type name
function Effect:remove_impact(type_name)
	if not self.impacts[type_name] then return end

	local data = data(self.target)

	-- Mark target impact as ended for this effect
	self.impacts[type_name].ended = true
	data.impacts[type_name].changed = true

	-- Detach impact params from effect
	self.impacts[type_name] = nil
end

--- stop
-- Stops effect, with optional fall phase
function Effect:stop()
	if self.phase == phase_raise or
	   self.phase == phase_still then
		self.phase = phase_fall
	end
end

--- start
-- Starts or restarts effect if it's in fall or end phase
function Effect:start()
	if self.phase == phase_fall or
	   self.phase == phase_end then
		self.phase = phase_raise
	end
end

-- Restart is the same
Effect.restart = Effect.start

-- Effect step
--------------

--- step
-- Performs a step of calculation for the effect
-- @param dtime Time elapsed since last step

-- TODO: For a while after reconnecting, it seems that step runs and conditions
-- are not in place for effect conservation.
function Effect:step(dtime)
	-- Internal time
	self.elapsed_time = self.elapsed_time + dtime

	-- End effects that have no impact
	if not next(self.impacts, nil) then	self.phase = phase_end end

	-- If not in end phase, do steps in each conditions
	if (self.phase ~= phase_end) then
		for key, value in pairs(self.conditions or {}) do
			late.condition_step(key, value, self.target, self)
		end
	end

	-- Check effect conditions
	if (self.phase == phase_raise or self.phase == phase_still)
	then
		for key, value in pairs(self.conditions or {}) do
			if not late.condition_check(key, value, self.target, self) then
				self.phase = phase_fall
				break
			end
		end
	end

	-- Time intensity and phases
	if self.phase == phase_raise then
		self.intensities.time = (self.intensities.time or 0)
			+ (self.raise and dtime/self.raise or 1)
		if self.intensities.time >= 1 then self.phase = phase_still end
	end

	if self.phase == phase_still then self.intensities.time = 1 end

	if self.phase == phase_fall then
		self.intensities.time = (self.intensities.time or 0)
			- (self.fall and dtime/self.fall or 1)
		if self.intensities.time <= 0 then self.phase = phase_end end
	end

	if self.phase == phase_end then self.intensities.time = 0 end

	-- Commpute total intensity
	local intensity = 1
	for _, specific_intensity in pairs(self.intensities) do
		intensity = intensity * specific_intensity
	end

	-- Target modifiers (immunity, other effects interacting)
	if intensity > 0 and data(self.target).modifiers then
		for group, _ in pairs(self.groups or {}) do
			intensity = intensity * nvl(data(self.target).modifiers[group], 1)
		end
	end

	-- Propagate to impacts (intensity and end)
	for impact_name, impact in pairs(self.impacts) do
		if impact.intensity ~= intensity then
			impact.intensity = intensity
			data(self.target).impacts[impact_name].changed = true
		end
		if self.phase == phase_end then
			impact.ended = true
		end
	end
end

--- set_conditions
-- Add or replace conditions on the effect.
-- @param conditions A table of key/values describing the conditions
function Effect:set_conditions(conditions)
	self.conditions = self.conditions or {}
	for key, value in pairs(conditions) do
		self.conditions[key] = value
	end
end



-- On die player : stop effects that are marked stopondeath = true
minetest.register_on_dieplayer(function(player)
	local data = data(player)
	if data then
		for index, effect in pairs(data.effects) do
			if effect.stop_on_death then
				effect:stop()
			end
		end
	end
end)

-- TODO:
--- cancel_player_effects
-- Cancels all effects belonging to a group affecting a player
--function late.cancel_player_effects(player_name, effect_group)

-- Main globalstep loop
-----------------------

minetest.register_globalstep(function(dtime)
		-- Loop over all known targets
		for target, data in pairs(target_data) do

			-- Check target existence
			if target:get_properties() == nil then
				target_data[target] = nil
			else
				-- Wield item change check
				-- TODO: work only if target is known, what about mobs ?
				local stack = target:get_wielded_item()
				local item_name = stack and stack:get_name() or nil

				if data.wielded_item ~= item_name then
					data.wielded_item = item_name
					if item_name then
						late.set_equip_effect(target, item_name)
					end
				end

				-- Effects
				for index, effect in pairs(data.effects) do
					-- Compute effect elapsed_time, phase and intensity
					effect:step(dtime)

					-- Effect ends ?
					if effect.phase == phase_end then
						-- Inform observers
						late.trigger_event("on_effect_end", effect)
						-- Delete effect
						data.effects[index] = nil
					end
				end

				-- Impacts
				for impact_name, impact in pairs(data.impacts) do
					local impact_type = late.get_impact_type(
						data.type, impact_name)

					-- Check if there are still effects using this impact
					local remains = false
					for key, params in pairs(impact.params) do
						if params.ended then
							impact.params[key] = nil
						else
							remains = true
						end
					end

					if remains then
						-- Update impact if changed (effect intensity changed)
						if impact.changed then
							calliffunc(impact_type.update, impact)
						end

						-- Step
						calliffunc(impact_type.step, impact, dtime)
						impact.changed = false
					else
						-- Ends impact
						calliffunc(impact_type.reset, impact)
						data.impacts[impact_name] = nil
					end
				end
			end
		end
	end)

-- Effects persistance
----------------------

-- How effect data are stored:
-- Player: Serialized in a player attribute (In V5, it will be possible to use
--         StorageRef for players and entities)
-- Mob: (:TODO:)
-- World: minetest.get_mod_storage() (:TODO:)

-- Periodically, players and world effect are saved in case of server crash

-- TODO:Check that attributes are saved in case of server crash
-- TODO:Manage entity persistance with get_staticdata and on_activate

-- serialize_effects
function serialize_effects(target)
	local data = data(target)
	if not data then return end -- Not a suitable target

	local effects = table.copy(data.effects)

	-- remove target references from data to be serialized (not serializable)
	for _, effect in pairs(effects) do effect.target = nil	end

	return minetest.serialize(effects)
end

-- deserialize_effects
function deserialize_effects(target, serialized)
	if serialized == "" then return end

	local data = data(target)
	if not data then return end -- Not a suitable target

	if data.effects and next(data.effects, nil) then
		minetest.log('error', '[late] Trying to deserialize effects for '
			..data.string..' which already has effects.')
		return
	end

	-- Deseralization
	local effects = minetest.deserialize(serialized) or {}

	for _, fields in pairs(effects) do
		local effect = Effect:new(target, fields)
		effect.break_time = true
	end
end


local function periodic_save()
	for _,player in ipairs(minetest.get_connected_players()) do
		player:set_attribute(save_meta_key, serialize_effects(player))
	end
	minetest.after(save_interval, periodic_save)
end
minetest.after(save_interval, periodic_save)

minetest.register_on_joinplayer(function(player)
	deserialize_effects(player, player:get_attribute(save_meta_key))
end)

minetest.register_on_leaveplayer(function(player)
	player:set_attribute(save_meta_key, serialize_effects(player))
end)

minetest.register_on_shutdown(function()
	for _,player in ipairs(minetest.get_connected_players()) do
		player:set_attribute(save_meta_key, serialize_effects(player))
	end
end)

-- Effects management
---------------------

--- get_effect_by_id
-- Retrieves an effect by its ID for a given target
-- @param target Concerned target (player, mob, world)
-- @param id Id of the effect researched
-- @returns The Effect object or nil if not found
function late.get_effect_by_id(target, id)
	local data = data(target)
	if data then return data.effects[id] end
end

-- Hacks
--------

-- Awful hack for integration with other mods dealing with player physics

local physic_impacts =
	{ jump = 'jump', gravity = 'gravity', speed = 'speed' }

local function set_physics_override(player, ...)
	-- Separate physics managed by impacts from those still managed by
	-- core api set_physics_override
	local args = {...}
	local table = {}

	if #args == 1 and type(args[1]) == 'table' then
		table = args[1]
	elseif #args == 3 then -- Old non table version
		table = {speed = args[1], jump = args[2], gravity = args[3]}
	else
		minetest.log('error', '[LATE] set_physics_override called with bad arguments')
		return
	end

	local impacts = {}
	local physics = {}
	for physic, impact in pairs(physic_impacts) do
		if table[physic] then
			impacts[impact] = table[physic]
		else
			physics[physic] = table[physic]
		end
	end

	-- If impact managed physics, update or create specific effect
	if next(impacts, nil) then
		local effect = late.get_effect_by_id(player, 'core:physics')
			or Effect:new(player, {	id = 'core:physics' })

		for impact, value in pairs(impacts) do
			if value == 1 then
				effect:remove_impact(impact)
			else
				effect:add_impact(impact, { value })
			end
		end
	end

	-- If core api managed physics, call core api
	if next(physics, nil) then
		late.set_physics_override(player, physics)
	end

end

minetest.register_on_joinplayer(function(player)
	if late.set_physics_override == nil then
		print('[effect_api] Hacking Player:set_physics_override')
		local meta = getmetatable(player)
		late.set_physics_override = meta.set_physics_override
		meta.set_physics_override = set_physics_override
	end

	-- Create effect if there are already physic changes
	local physics = player:get_physics_override()
	set_physics_override(player, physics)
end)
