
-- Simple formspec wrapper that does variable substitution.
local function formspec_wrapper(formspec, variables)
	local retval = formspec

	for k,v in pairs(variables) do
		retval = retval:gsub("${"..k.."}", v)
	end

	return retval
end

-- Create a detached inventory
local inv_everything = minetest.create_detached_inventory("everything", {
	allow_move = function(inv, from_list, from_index, to_list, to_index, count, player)
		return 0
	end,
	allow_put = function(inv, listname, index, stack, player)
		return 0
	end,
	allow_take = function(inv, listname, index, stack, player)
		return -1
	end,
})
local inv_trash = minetest.create_detached_inventory("trash", {
	allow_take = function(inv, listname, index, stack, player)
		return 0
	end,
	allow_move = function(inv, from_list, from_index, to_list, to_index, count, player)
		return 0
	end,
	on_put = function(inv, listname, index, stack, player)
		inv:set_list("main", {})
	end,
})
inv_trash:set_size("main", 1)

local max_page = 1
local items_per_page = 60

local function get_chest_formspec(page)
	local start = 0 + ( page - 1 ) * items_per_page

	return formspec_wrapper([[
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
	]], {
		start = start,
		page = page,
		max_page = max_page
	})
end

local function sheet(id)
	return "chest_with_everything.png^[sheet:2x2:"..(id % 2)..","..math.floor(id / 2)
end

minetest.register_node("chest_with_everything:chest", {
	description = "Chest with Everything",
	tiles = {
		sheet(0), sheet(0),
		sheet(1), sheet(1),
		sheet(1), sheet(2)},
	paramtype2 = "facedir",
	groups = {dig_immediate=2,choppy=3},
	on_construct = function(pos)
		local meta = minetest.get_meta(pos)
		meta:set_int("page", 1)
		meta:set_string("formspec", get_chest_formspec(1))
	end,
	on_receive_fields = function(pos, formname, fields, sender)
		if formname ~= "" then return end

		local meta = minetest.get_meta(pos)
		local page = meta:get_int("page")

		if fields.cwe_prev then		page = page - 1
		elseif fields.cwe_next then	page = page + 1 end

		-- Wrap-around
		if page < 1 then page = max_page end
		if page > max_page then page = 1 end

		meta:set_int("page", page)
		meta:set_string("formspec", get_chest_formspec(page))
	end,
})

minetest.register_on_mods_loaded(function()
	local items = {}
	for itemstring, def in pairs(minetest.registered_items) do
		if itemstring ~= ""
		and itemstring ~= "unknown"
		and itemstring ~= "ignore"
		and itemstring ~= "air"
		and itemstring ~= "worldedit:placeholder"
		and def.groups.not_in_creative_inventory ~= 1 then
			table.insert(items, itemstring)
		end
	end
	--[[ Sort items in this order:
	* Chest with Everything
	* Test tools
	* Other tools
	* Craftitems
	* Other items ]]
	local function compare(item1, item2)
		local def1 = minetest.registered_items[item1]
		local def2 = minetest.registered_items[item2]
		local tool1 = def1.type == "tool"
		local tool2 = def2.type == "tool"
		local craftitem1 = def1.type == "craft"
		local craftitem2 = def2.type == "craft"
		if item1 == "chest_with_everything:chest" then
			return true
		elseif item2 == "chest_with_everything:chest" then
			return false
		elseif tool1 and not tool2 then
			return true
		elseif not tool1 and tool2 then
			return false
		elseif craftitem1 and not craftitem2 then
			return true
		elseif not craftitem1 and craftitem2 then
			return false
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
