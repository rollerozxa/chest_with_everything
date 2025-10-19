
-- Simple formspec wrapper that does variable substitution.
local function substitute(formspec, variables)
	for k,v in pairs(variables) do
		formspec = formspec:gsub("${"..k.."}", v)
	end
	return formspec
end

local inv_everything = core.create_detached_inventory("everything", {
	allow_move = function() return 0 end,
	allow_put = function() return 0 end,
	allow_take = function(inv, listname, index, stack, player)
		if core.check_player_privs(player, 'give') then
			return -1
		end
		return 0
	end,
})
local inv_trash = core.create_detached_inventory("trash", {
	allow_move = function() return 0 end,
	allow_take = function() return 0 end,
	on_put = function(inv, listname, index, stack, player)
		inv:set_list(listname, {})
	end,
})
inv_trash:set_size("main", 1)

local max_page = 1
local items_per_page = 12*5

local show_nici = core.settings:get("cwe_show_nici") or false

local function get_chest_formspec(page)
	local start = ( page - 1 ) * items_per_page

	return substitute([[
		formspec_version[4]
		size[15.7,10.5]

		list[detached:everything;main;0.5,0.3;12,5;${start}]

		button[0.5,6.4;1,1;cwe_prev;\<]
		style[pagelbl;border=false]
		button[1.5,6.4;4,1;pagelbl;Page: ${page} / ${max_page}]
		button[5.52,6.4;1,1;cwe_next;\>]

		style[trashlbl;border=false]
		button[12.75,6.4;1.5,1;trashlbl;Trash:]
		list[detached:trash;main;14.25,6.4;1,1]

		listring[current_player;main]
		list[current_player;main;1.8,8;10,2;0]

		listring[detached:everything;main]
		listring[current_player;main]
		listring[detached:trash;main]
		field[-10,-10;0,0;internal_paginator;;${page}]
	]], {
		start = start,
		page = page,
		max_page = max_page
	})
end

local function sheet(id)
	return "chest_with_everything.png^[sheet:2x2:"..(id % 2)..","..math.floor(id / 2)
end

core.register_node("chest_with_everything:chest", {
	description = "Chest with Everything",
	tiles = {
		sheet(0), sheet(0),
		sheet(1), sheet(1),
		sheet(1), sheet(2)},
	paramtype2 = "facedir",
	groups = {dig_immediate=2,choppy=3},
	on_rightclick = function(pos, node, clicker)
		local name = clicker:get_player_name()
		if not core.check_player_privs(clicker, 'give') and false then
			core.chat_send_player(name, core.colorize("#ff0000", "Hey, no touching!"))
			core.log("action", name.." tried to access a Chest with Everything")
			return
		end
		core.show_formspec(name, "chest_with_everything:chest", get_chest_formspec(1))
	end
})

core.register_on_player_receive_fields(function(player, formname, fields)
	if formname ~= "chest_with_everything:chest" then return end
	if not fields.cwe_prev and not fields.cwe_next then return end

	local page = tonumber(fields.internal_paginator)
	if not page then return end
	page = math.floor(page)

	if fields.cwe_prev then		page = page - 1
	elseif fields.cwe_next then	page = page + 1 end

	-- Wrap-around
	if page < 1 then page = max_page end
	if page > max_page then page = 1 end

	core.show_formspec(player:get_player_name(), "chest_with_everything:chest", get_chest_formspec(page))
end)

core.register_on_mods_loaded(function()
	local items = {}
	for name, def in pairs(core.registered_items) do
		if (def.groups.not_in_creative_inventory or 0) == 0 or show_nici then
			items[#items+1] = name
		end
	end
	--[[ If built-in grouping is on, sort items into these groups:
	* Chest with Everything
	* Tools
	* Craftitems
	* Other items
	Then always by the 'order' property of their definitions,
	and finally their item IDs. ]]
	local grouping = core.settings:get_bool("cwe_built_in_grouping", true)
	local function compare(item1, item2)
		local def1 = core.registered_items[item1]
		local def2 = core.registered_items[item2]

		if grouping then
			local tool1 = def1.type == "tool"
			local tool2 = def2.type == "tool"
			local craftitem1 = def1.type == "craft"
			local craftitem2 = def2.type == "craft"
			if     item1 == "chest_with_everything:chest" then return true
			elseif item2 == "chest_with_everything:chest" then return false
			elseif     tool1 and not tool2 then return true
			elseif not tool1 and     tool2 then return false
			elseif     craftitem1 and not craftitem2 then return true
			elseif not craftitem1 and     craftitem2 then return false
			end
		end

		local order1 = def1.order
		local order2 = def2.order
		if order1 and order2 then
			return order1 < order2
		elseif order1 then return true
		elseif order2 then return false
		else
			return item1 < item2
		end
	end
	table.sort(items, compare)
	inv_everything:set_size("main", #items)
	max_page = math.ceil(#items / items_per_page)
	for i=1, #items do
		inv_everything:add_item("main", items[i])
	end
end)
