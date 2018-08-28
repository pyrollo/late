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

-- Impact registry
------------------

local impact_types = { player = {}, mob = {} }

--- register_impact_type
-- Registers a player impact type.
-- @param target_type Target type or table of target types affected by the impact
-- @param name Unique (for a target type) name of the impact
-- @param def Definition of the impact type
-- def = {
--	vars = { a=1, b=2, ... }       Internal variables needed by the impact (per
--                                 impact context : player / mob)
--	reset = function(impact)       Function called when impact stops
--	update = function(impact)      Function called to apply effect
--	step = function(impact, dtime) Function called every global step
--}
-- Impact passed to functions is:
-- impact = {
--  target = player or mob ObjectRef
-- 	name = '...',         Impact type name.
--  vars = {},            Internal vars (indexed by name).
-- 	params = {},          Table of per effect params and intensity.
--	changed = true/false  Indicates wether the impact has changed or not since
--                        last step.
-- }
function late.register_impact_type(target_types, name, definition)
	if type(target_types) == 'string' then target_types = { target_types } end
	if type(target_types) ~= 'table' then
		error ('[late] Target types is expected to be either a string or '..
		       'a table of target types names)', 2)
	end

	for _, target_type in ipairs(target_types) do

		if impact_types[target_type] == nil then
			error ('[late] Target type "'..target_type..'" unknown.', 2)
		end

		if impact_types[target_type][name] then
			error ('Impact type "'..name..'" already registered for '..
				target_type..'.', 2)
		end

		local def = table.copy(definition)
		def.name = name
		def.target_type = target_type
		impact_types[target_type][name] = def
	end
end

--- get_impact_type
-- Retrieves an impact type definition
-- @param target_type Target type to be affected
-- @param name Name of the impact type
-- @returns Impact type definition table
function late.get_impact_type(target_type, name)
	if impact_types[target_type] == nil then
		error('[late] Target type "'..target_type..'" unknown.', 2)
	end

	if impact_types[target_type][name] == nil then
		minetest.log('error', '[late] Impact type "'..name
			..'" not registered for '..target_type..'.')
	end

	return impact_types[target_type][name]
end

-- Impact helpers
-----------------

--- get_valints
-- Extract values and intensities from impact params array
-- @param params An impact param array
-- @param index Index of the value to be exported from @params entries
-- @returns An array of { value=, intensity= }
function late.get_valints(params, index)
	local result = {}
	for _, param in pairs(params) do
		if param[index] then
			table.insert(result,
				{ value = param[index], intensity = param.intensity or 0 })
		end
	end
	return result
end

--- append_valints
-- Appends a values and intensities list to another
-- @param valints List where extra valints will be append
-- @param extravalints Extra valints to append
function late.append_valints(valints, extravalints)
	for _, valint in pairs(extravalints) do
		table.insert(valints, valint)
	end
end

--- multiply_valints
-- Computes a sum of values with intensities
-- @param valints Value/Intensity list
-- @returns Resulting sum
function late.multiply_valints(valints)
	local result = 1.0
	for _, v in ipairs(valints) do
		result = result * (1+((v.value or 1)-1)*(v.intensity or 0))
	end
	return result
end

--- sum_valints
-- Computes a product of values with intensities
-- @param valints Value/Intensity list
-- @returns Resulting product
function late.sum_valints(valints)
	local result = 0.0
	for _, v in ipairs(valints) do
		result = result + (v.value or 0)*(v.intensity or 0)
	end
	return result
end

--- superpose_valints
-- Computes a ratio superposition (like if each ratio was a greyscale value and
-- intensities where alpha chanel).
-- @param valints Value/Intensity list of ratios (values should go from 0 to 1)
-- @param base_value Base ratio value on which valints are superposed
-- @returns Resulting ration
function late.superpose_valints(valints, base_value)
	local default_intensity = 1.0
	local intensity_sum = 0.0
	local value_sum = 0.0
	for _, valint in ipairs(valints) do
		if valint.intensity > 0 then
			if valint.intensity > 1 then
				default_intensity = 0
				intensity_sum = intensity_sum + 1
				value_sum = value_sum + valint.value
			else
				default_intensity = default_intensity * (1 - valint.intensity)
				intensity_sum = intensity_sum + valint.intensity
				value_sum = value_sum + valint.value * valint.intensity
			end
		end
	end
	intensity_sum = intensity_sum + default_intensity
	value_sum = value_sum + base_value * default_intensity
	return value_sum / intensity_sum
end

--- superpose_color_valints
-- Computes a color superposition with alpha channel and intensity (actually,
-- intensity is considered as a factor on alpha channel)
-- @param valints Value/Intensity list of colors
-- @param background_color Background color (default none)
-- @returns Resulting color
function late.superpose_color_valints(valints, background_color)
	local bg_color = { r=0, g=0, b=0, a=0 }
	if background_color then
		bg_color = late.color_to_table(background_color)
	end
	local bg_intensity = 1.0
	local intensity_sum = 0.0
	local color = { r=0, g=0, b=0, a=0 }
	local color_val

	for _, valint in ipairs(valints) do
		if valint.intensity > 0 then
			color_val = late.color_to_table(valint.value)
			if valint.intensity > 1 then
				bg_intensity = 0
				color.r = color.r + color_val.r * color_val.a
				color.g = color.g + color_val.g * color_val.a
				color.b = color.b + color_val.b * color_val.a
				intensity_sum = intensity_sum + color_val.a
			else
				bg_intensity = bg_intensity * (1 - valint.intensity)
				color.r = color.r + color_val.r * color_val.a * valint.intensity
				color.g = color.g + color_val.g * color_val.a * valint.intensity
				color.b = color.b + color_val.b * color_val.a * valint.intensity
				intensity_sum = intensity_sum + color_val.a * valint.intensity
			end
		end
	end

	intensity_sum = intensity_sum + bg_color.a * bg_intensity
	color.r = (color.r + bg_color.r * bg_color.a * bg_intensity) / intensity_sum
	color.g = (color.g + bg_color.g * bg_color.a * bg_intensity) / intensity_sum
	color.b = (color.b + bg_color.b * bg_color.a * bg_intensity) / intensity_sum
	-- TODO: color.a = ? --
	color.a = 0xff
	return color
end

--- Mix colors with intensity
-- @param valints List of colorstrings (value=) and intensities
-- @results A colorstring representing the sum
function late.mix_color_valints(valints)
	local total = 0.0
	for _, v in pairs(valints) do
		total = total + (v.intensity or 0)
	end

	if total == 0 then return nil end

	local sum = { a=0, r=0, g=0, b=0 }
	local color

	for _, v in pairs(valints) do
		color = color_to_table(v.value) -- Can be done once at first when creating impact
		sum.a = sum.a + color.a * v.intensity
		sum.r = sum.r + color.r * v.intensity
		sum.g = sum.g + color.g * v.intensity
		sum.b = sum.b + color.b * v.intensity
	end

	return { a=sum.a/total, r=sum.r/total, g=sum.g/total, b=sum.b/total }
end


