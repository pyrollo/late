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

-- Integration with 3D armor
if minetest.global_exists("armor") then
	print("[late] Integration with 3D Armors")

	-- Item equipment. May trigger an effect
	armor:register_on_equip(function(player, index, stack)
		late.set_equip_effect(player, stack:get_name())
	end)

	-- Extend equip condition to armors
	late.register_condition_type('equiped_with', {
		check = function(data, target, effect)
			-- Is the target equiped with item_name?
			-- Check wielded item
				local stack = target:get_wielded_item()
				if stack and stack:get_name() == data then return true end

				-- Check only for players
				if target.is_player and target:is_player() then
					local inv = minetest.get_inventory({ type="detached",
						name= target:get_player_name().."_armor" })
					if inv then
						local list = inv:get_list("armor")
						if list then
							for _, stack in pairs(list) do
								if stack:get_name() == item_name then return true end
							end
						end
					end
				end
				return false
			end,
	})

	-- In case of armor update, inform texture impact that base texture has changed
	armor:register_on_update(function(player)
			local data = late.get_storage_for_target(player)
			if data.impacts and data.impacts['texture'] then
				local impact_type = late.get_impact_type('player', 'texture')
				data.impacts['texture'].vars.initial_textures = nil
				-- TODO: add impact_type as metatable of impacts?
				impact_type.update(data.impacts['texture'])
			end
		end)

end
