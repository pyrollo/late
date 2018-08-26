--[[
    Late library for Minetest - Library adding temporary effects.
    (c) Pierre-Yves Rollo

    This program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
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

-- Color management
local stdcolors = {
	aliceblue              = 0xf0f8ff,
	antiquewhite           = 0xfaebd7,
	aqua                   = 0x00ffff,
	aquamarine             = 0x7fffd4,
	azure                  = 0xf0ffff,
	beige                  = 0xf5f5dc,
	bisque                 = 0xffe4c4,
	black                  = 00000000,
	blanchedalmond         = 0xffebcd,
	blue                   = 0x0000ff,
	blueviolet             = 0x8a2be2,
	brown                  = 0xa52a2a,
	burlywood              = 0xdeb887,
	cadetblue              = 0x5f9ea0,
	chartreuse             = 0x7fff00,
	chocolate              = 0xd2691e,
	coral                  = 0xff7f50,
	cornflowerblue         = 0x6495ed,
	cornsilk               = 0xfff8dc,
	crimson                = 0xdc143c,
	cyan                   = 0x00ffff,
	darkblue               = 0x00008b,
	darkcyan               = 0x008b8b,
	darkgoldenrod          = 0xb8860b,
	darkgray               = 0xa9a9a9,
	darkgreen              = 0x006400,
	darkgrey               = 0xa9a9a9,
	darkkhaki              = 0xbdb76b,
	darkmagenta            = 0x8b008b,
	darkolivegreen         = 0x556b2f,
	darkorange             = 0xff8c00,
	darkorchid             = 0x9932cc,
	darkred                = 0x8b0000,
	darksalmon             = 0xe9967a,
	darkseagreen           = 0x8fbc8f,
	darkslateblue          = 0x483d8b,
	darkslategray          = 0x2f4f4f,
	darkslategrey          = 0x2f4f4f,
	darkturquoise          = 0x00ced1,
	darkviolet             = 0x9400d3,
	deeppink               = 0xff1493,
	deepskyblue            = 0x00bfff,
	dimgray                = 0x696969,
	dimgrey                = 0x696969,
	dodgerblue             = 0x1e90ff,
	firebrick              = 0xb22222,
	floralwhite            = 0xfffaf0,
	forestgreen            = 0x228b22,
	fuchsia                = 0xff00ff,
	gainsboro              = 0xdcdcdc,
	ghostwhite             = 0xf8f8ff,
	gold                   = 0xffd700,
	goldenrod              = 0xdaa520,
	gray                   = 0x808080,
	green                  = 0x008000,
	greenyellow            = 0xadff2f,
	grey                   = 0x808080,
	honeydew               = 0xf0fff0,
	hotpink                = 0xff69b4,
	indianred              = 0xcd5c5c,
	indigo                 = 0x4b0082,
	ivory                  = 0xfffff0,
	khaki                  = 0xf0e68c,
	lavender               = 0xe6e6fa,
	lavenderblush          = 0xfff0f5,
	lawngreen              = 0x7cfc00,
	lemonchiffon           = 0xfffacd,
	lightblue              = 0xadd8e6,
	lightcoral             = 0xf08080,
	lightcyan              = 0xe0ffff,
	lightgoldenrodyellow   = 0xfafad2,
	lightgray              = 0xd3d3d3,
	lightgreen             = 0x90ee90,
	lightgrey              = 0xd3d3d3,
	lightpink              = 0xffb6c1,
	lightsalmon            = 0xffa07a,
	lightseagreen          = 0x20b2aa,
	lightskyblue           = 0x87cefa,
	lightslategray         = 0x778899,
	lightslategrey         = 0x778899,
	lightsteelblue         = 0xb0c4de,
	lightyellow            = 0xffffe0,
	lime                   = 0x00ff00,
	limegreen              = 0x32cd32,
	linen                  = 0xfaf0e6,
	magenta                = 0xff00ff,
	maroon                 = 0x800000,
	mediumaquamarine       = 0x66cdaa,
	mediumblue             = 0x0000cd,
	mediumorchid           = 0xba55d3,
	mediumpurple           = 0x9370db,
	mediumseagreen         = 0x3cb371,
	mediumslateblue        = 0x7b68ee,
	mediumspringgreen      = 0x00fa9a,
	mediumturquoise        = 0x48d1cc,
	mediumvioletred        = 0xc71585,
	midnightblue           = 0x191970,
	mintcream              = 0xf5fffa,
	mistyrose              = 0xffe4e1,
	moccasin               = 0xffe4b5,
	navajowhite            = 0xffdead,
	navy                   = 0x000080,
	oldlace                = 0xfdf5e6,
	olive                  = 0x808000,
	olivedrab              = 0x6b8e23,
	orange                 = 0xffa500,
	orangered              = 0xff4500,
	orchid                 = 0xda70d6,
	palegoldenrod          = 0xeee8aa,
	palegreen              = 0x98fb98,
	paleturquoise          = 0xafeeee,
	palevioletred          = 0xdb7093,
	papayawhip             = 0xffefd5,
	peachpuff              = 0xffdab9,
	peru                   = 0xcd853f,
	pink                   = 0xffc0cb,
	plum                   = 0xdda0dd,
	powderblue             = 0xb0e0e6,
	purple                 = 0x800080,
	red                    = 0xff0000,
	rosybrown              = 0xbc8f8f,
	royalblue              = 0x4169e1,
	saddlebrown            = 0x8b4513,
	salmon                 = 0xfa8072,
	sandybrown             = 0xf4a460,
	seagreen               = 0x2e8b57,
	seashell               = 0xfff5ee,
	sienna                 = 0xa0522d,
	silver                 = 0xc0c0c0,
	skyblue                = 0x87ceeb,
	slateblue              = 0x6a5acd,
	slategray              = 0x708090,
	slategrey              = 0x708090,
	snow                   = 0xfffafa,
	springgreen            = 0x00ff7f,
	steelblue              = 0x4682b4,
	tan                    = 0xd2b48c,
	teal                   = 0x008080,
	thistle                = 0xd8bfd8,
	tomato                 = 0xff6347,
	turquoise              = 0x40e0d0,
	violet                 = 0xee82ee,
	wheat                  = 0xf5deb3,
	white                  = 0xffffff,
	whitesmoke             = 0xf5f5f5,
	yellow                 = 0xffff00,
    yellowgreen            = 0x9acd32,
}

--- color_to_table
-- Converts a colorstring to a {r,g,b,a} table.
-- @param colorspec Can be a standard color name, a 32 bit integer or a table
-- @returns A {r,g,b,a} table
function late.color_to_table(colorspec)
	if type(colorspec) == 'string' then
		if string.sub(colorspec, 1, 1) == "#" then
			if string.len(colorspec) == 4 then
				return {
					r = tonumber("0x"..string.sub(colorspec, 2, 2)),
					g = tonumber("0x"..string.sub(colorspec, 3, 3)),
					b = tonumber("0x"..string.sub(colorspec, 4, 4)),
					a = 0xFF,
				}
			elseif string.len(colorspec) == 5 then
				return {
					r = tonumber("0x"..string.sub(colorspec, 2, 2)),
					g = tonumber("0x"..string.sub(colorspec, 3, 3)),
					b = tonumber("0x"..string.sub(colorspec, 4, 4)),
					a = tonumber("0x"..string.sub(colorspec, 5, 5)),
				}
			elseif string.len(colorspec) == 7 then
				return {
					r = tonumber("0x"..string.sub(colorspec, 2, 3)),
					g = tonumber("0x"..string.sub(colorspec, 4, 5)),
					b = tonumber("0x"..string.sub(colorspec, 6, 7)),
					a = 0xFF,
				}
			elseif string.len(colorspec) == 9 then
				return {
					r = tonumber("0x"..string.sub(colorspec, 2, 3)),
					g = tonumber("0x"..string.sub(colorspec, 4, 5)),
					b = tonumber("0x"..string.sub(colorspec, 6, 7)),
					a = tonumber("0x"..string.sub(colorspec, 8, 9)),
				}
			end
		else
			colorspec = stdcolors[colorspec]
			if colorspec then
				return {
					a = 0xFF,
					r = math.floor(colorspec / 0x10000 % 0x100),
					g = math.floor(colorspec / 0x100 % 0x100),
					b = math.floor(colorspec % 0x100),
				}
			end
			return nil
		end
	end

	if type(colorspec) == 'number' then
		return {
			a = math.floor(colorspec / 0x1000000 % 0x100),
			r = math.floor(colorspec / 0x10000 % 0x100),
			g = math.floor(colorspec / 0x100 % 0x100),
			b = math.floor(colorspec % 0x100),
		}
	end

	if type(colorspec) == 'table' then
		return {
			a = (colorspec.a or 0),
			r = (colorspec.r or 0),
			g = (colorspec.g or 0),
			b = (colorspec.b or 0),
		}
	end
end

--- color_to_rgb_texture
-- Converts a colorspec to a #RRGGBB string ready to use in textures
-- @param colorspec Can be a standard color name, a 32 bit integer or a table
-- @returns A "#RRGGBB" string
function late.color_to_rgb_texture(colorspec)
	local color = late.color_to_table(colorspec)
	return string.format("#%02X%02X%02X", color.r, color.g, color.b)
end

function late.color_to_rgba_texture(colorspec)
	local color = late.color_to_table(colorspec)
	return string.format("#%02X%02X%02X%02X", color.r, color.g, color.b, color.a)
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


