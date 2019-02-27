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

-- Interval in seconds of ABM checking for targets being near nodes with effect
-- TODO:Move into a mod settings
local abm_interval = 1

-- Conditions registry
----------------------

local condition_types = { }

function late.register_condition_type(name, definition)
	local def = table.copy(definition)
	def.name = name
	condition_types[name] = def
end

function late.get_condition_type(name)
	return condition_types[name]
end

local function call_condition_function(function_name, type_name, data, target, effect)
	local condition_type = condition_types[type_name]
	if condition_type and condition_type[function_name] and
	   type(condition_type[function_name]) == "function"
	then
		return condition_type[function_name](data, target, effect)
	else
		return nil
	end
end

function late.condition_check(type_name, data, target, effect)
	return call_condition_function('check', type_name, data, target, effect)
		or false -- unknown condition always false
end

function late.condition_step(type_name, data, target, effect)
	call_condition_function('step', type_name, data, target, effect)
end

-- Base conditions
------------------

late.register_condition_type('duration', {
	check = function(data, target, effect)
			return effect.elapsed_time < data
		end,
})

late.register_condition_type('equiped_with', {
	check = function(data, target, effect)
			-- Is the target equiped with item_name?
			-- Check wielded item
				local stack = target:get_wielded_item()
				return (stack and stack:get_name() == data) or false
			end,
})

-- ABM to detect if player gets nearby a nodes with effect (belonging to
-- group:effect_trigger and having an effect in node definition)

minetest.register_abm({
	label = "late player detection",
	nodenames = "group:effect_trigger",
	interval = abm_interval,
	chance = 1,
	catch_up = true,
	action = function(pos, node)
		local ndef = minetest.registered_nodes[node.name]
		local effect_def = ndef.effect_near
		if effect_def then
			for _, target in pairs(minetest.get_objects_inside_radius(
				pos, (effect_def.distance or 0) + (effect_def.spread or 0))) do
				effect_def.id = 'near:'..node.name

				local effect = late.get_effect_by_id(target, effect_def.id)

				if effect == nil then
					effect = late.new_effect(target, effect_def)
					if effect then
						effect:set_conditions({ near_node = {
							node_name = node.name,
							radius = effect_def.distance,
							spread = effect_def.spread,
							active_pos = {}
						} } )
					end
				end

				if effect then
					-- Register node position as an active position
					effect.conditions.near_node
						.active_pos[minetest.hash_node_position(pos)] = true

					-- Restart effect in case it was in fall phase
					effect:restart()
				end
			end
		end
	end,
})

late.register_condition_type('near_node', {
	check = function(data, target, effect)
			return effect.intensities.distance ~= nil
		end,
	step = function(data, target, effect)
		-- Discard too far or not uptodate nodes from near_nodes list and compute min
		-- distance and intensity according to it
			local distance, min_distance
			for hash, _ in pairs(data.active_pos) do
				local pos = minetest.get_position_from_hash(hash)
				distance = vector.distance(target:get_pos(), pos)

				if distance < (data.radius or 0) + (data.spread or 0) and
					minetest.get_node(pos).name == (data.node_name or "")
				then
					min_distance = math.min(min_distance or distance, distance)
				else
					data.active_pos[hash] = nil
				end
			end

			if min_distance == nil then effect.intensities.distance = nil
			else
				--
				effect.intensities.distance = data.spread and math.min(1, ((data.radius
					or 0) + data.spread - min_distance) / data.spread) or 1
			end
		end,
})
