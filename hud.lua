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

local hud_update_period = 0.3
local hud_template = {
	position = { x=1, y=0.2 },
	alignment = { x=-1, y=-1 },
	offset = { x = 18, y = 34},
	icon_scale = 1.7,
	max_anim = 25
}

hud_template.position.x = tonumber(minetest.settings:get(
"late.hud.position.x")) or hud_template.position.x

hud_template.position.y = tonumber(minetest.settings:get(
"late.hud.position.y")) or hud_template.position.y

hud_template.alignment.x = tonumber(minetest.settings:get(
"late.hud.alignment.x")) or hud_template.alignment.x

hud_template.alignment.y = tonumber(minetest.settings:get(
"late.hud.alignment.y")) or hud_template.alignment.y

hud_template.icon_scale = tonumber(minetest.settings:get(
"late.hud.icon_scale")) or hud_template.icon_scale

hud_template.offset.x = tonumber(minetest.settings:get(
"late.hud.offset.x")) or hud_template.offset.x

hud_template.offset.y = tonumber(minetest.settings:get(
"late.hud.offset.y")) or hud_template.offset.y

local function get_hud_slot(effect)
	local data = late.get_storage_for_target(effect.target)

	if not data.huds then data.huds = {} end

	for slot, hud in pairs(data.huds) do
		if hud.effect == effect then
			return slot
		end
	end

	-- If not found, create new slot
	local slot = 1
	while data.huds[slot] do slot = slot + 1 end

	data.huds[slot] = { effect = effect,
	offset = {
		x = hud_template.alignment.x * hud_template.offset.x,
		y = hud_template.alignment.y * (slot-1) * hud_template.offset.y } }
	return slot
end

local function get_hud_data(effect)
	local slot = get_hud_slot(effect)
	return late.get_storage_for_target(effect.target).huds[slot]
end

local function hud_remove(effect)
	local data = late.get_storage_for_target(effect.target)
	local slot = get_hud_slot(effect)

	if data.huds[slot].ids then
		for _, id in pairs(data.huds[slot].ids) do
			effect.target:hud_remove(id)
		end
	end
	data.huds[slot] = nil
end

local function hud_update(effect)
	if not effect.hud then return end
	local data = late.get_storage_for_target(effect.target)
	if data.type ~= 'player' then return end

	local hud = get_hud_data(effect)

	local texture

	if effect.hud.duration ~= false then
		if effect.conditions and effect.conditions.duration
		   and effect.conditions.duration > 0 then
			local frame = math.floor(hud_template.max_anim * math.max(math.min(
				effect.elapsed_time / effect.conditions.duration, 1),0))
			texture = "late_hud_time.png^[verticalframe:"..hud_template.max_anim..
				":"..frame
		else
			texture = "late_hud_still.png"
		end
	else
		texture = ""
	end

	local color = { r=0x7f, g=0x7f, b=0x7f }
	if effect.hud.color then
		color = late.color_to_table(effect.hud.color)
	end
	color.a = 0x80
	texture = texture.."^[colorize:"..late.color_to_rgba_texture(color)

	if not hud.ids then
		hud.ids = {}
		hud.ids.circle = effect.target:hud_add({
			hud_elem_type = "image", scale = {x=1, y=1},
			position = hud_template.position,
			alignment = hud_template.alignment,
			offset = hud.offset,
			text = texture,
			scale = { x = 1, y = 1 },
		})
		if effect.hud.icon then
			hud.ids.icon = effect.target:hud_add({
				hud_elem_type = "image", scale = {x=1, y=1},
				position = hud_template.position,
				alignment = hud_template.alignment,
				offset = {
					x = hud.offset.x + hud_template.alignment.x * 3,
					y = hud.offset.y + hud_template.alignment.y * 3,
				},
				text = effect.hud.icon.."^[resize:16x16",
				scale = { x = hud_template.icon_scale, y = hud_template.icon_scale },
			})
		end
		if effect.hud.label then
			hud.ids.label = effect.target:hud_add({
				hud_elem_type = "text", scale = {x=1, y=1},
				position = hud_template.position,
				alignment = hud_template.alignment,
				offset = {
					x=hud.offset.x + ( hud_template.alignment.x
						* (hud_template.icon_scale * 16) ) + ( hud_template.alignment.x * 10 ),
					y=hud.offset.y + hud_template.alignment.y * 4
				},
				text = effect.hud.label,
				number = "0xFFFFFF",
				scale = { x = 1, y = 1 },
			})
		end
	end

	effect.target:hud_change(hud.ids.circle, "text", texture)
end

local function update_all_huds()
	for _, player in ipairs(minetest.get_connected_players()) do
		local data = late.get_storage_for_target(player)
		for _, effect in pairs(data.effects) do
			hud_update(effect)
		end
	end
	minetest.after(hud_update_period, update_all_huds)
end
minetest.after(hud_update_period, update_all_huds)

late.event_register("on_effect_end", function(effect)
	if effect.hud then
		hud_remove(effect)
	end
end)
