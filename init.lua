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

late = {}
late.name = minetest.get_current_modname()
late.path = minetest.get_modpath(late.name)

dofile(late.path.."/functions.lua")
dofile(late.path.."/effects.lua")
dofile(late.path.."/hud.lua")
dofile(late.path.."/integration.lua")
dofile(late.path.."/impacts.lua")
dofile(late.path.."/basic_impacts.lua")

-- Debug functions (to be removed)
minetest.register_chatcommand("clear_effects", {
	params = "",
	description = "Clears all effects",
	func = function(player_name, param)
			player = minetest.get_player_by_name(player_name)
			local data = late.get_storage_for_subject(player)
			data.effects = {}
			data.impacts = {}
			return true, "Done."
		end,
})

minetest.register_chatcommand("dump_data", {
	params = "",
	description = "Dump player data",
	func = function(player_name, param)
			player = minetest.get_player_by_name(player_name)
			local data = late.get_storage_for_subject(player)
			print(dump(data))
			return true, "Done."
		end,
})
