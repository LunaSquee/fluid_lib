local node_io_present = minetest.get_modpath("node_io") ~= nil
local S = core.get_translator("fluid_lib")

-- Network graphs are built eminating from provider nodes.
-- TODO: Caching
-- TODO: replace "back" side with the actual side

---------------------
-- Graph Functions --
---------------------

local function flatten(map)
	local list = {}
	for key, value in pairs(map) do
		list[#list + 1] = value
	end
	return list
end

local function get_node_property(meta, pos, prop)
	local value = meta:get_int(prop)

	if value == 0 or value == nil then
		local nname = minetest.get_node(pos).name
		local ndef  = minetest.registered_nodes[nname]
		value = ndef[prop]
	end

	if not value then return 0 end

	return value
end

local function face_front(pos, fd)
	local back = minetest.facedir_to_dir(fd)
	local front = table.copy(back)

	front.x = front.x * -1 + pos.x
	front.y = front.y * -1 + pos.y
	front.z = front.z * -1 + pos.z

	return front
end

local function clear_networks_from_node(pos)
	local meta = minetest.get_meta(pos)
	meta:set_string("network_id", "")
end

local function add_node(nodes, pos, pnodeid)
	local node_id = minetest.hash_node_position(pos)
	if nodes[node_id] then
		return false
	end
	nodes[node_id] = pos
	return true
end

local function add_duct_node(nodes, pos, pnodeid, queue)
	if add_node(nodes, pos, pnodeid) then
		queue[#queue + 1] = pos
	end
end

local function check_node(targets, all_nodes, pos, p_pos, pnodeid, queue)
	local node = minetest.get_node(pos)
	local meta = minetest.get_meta(pos)
	local ndef = minetest.registered_nodes[node.name]

	if not ndef then return end

	if minetest.get_item_group(node.name, "fluid_transport") > 0 then
		add_duct_node(all_nodes, pos, pnodeid, queue)
		return
	end

	if not ndef['node_io_can_put_liquid'] or not ndef['node_io_can_put_liquid'](pos, node, "back") then
		return
	end

	add_node(targets, pos, pnodeid)
end

local function traverse_network(targets, all_nodes, pos, p_pos, pnodeid, queue)
	local positions = {
		{x=pos.x+1, y=pos.y,   z=pos.z},
		{x=pos.x-1, y=pos.y,   z=pos.z},
		{x=pos.x,   y=pos.y+1, z=pos.z},
		{x=pos.x,   y=pos.y-1, z=pos.z},
		{x=pos.x,   y=pos.y,   z=pos.z+1},
		{x=pos.x,   y=pos.y,   z=pos.z-1}}
	for _, cur_pos in pairs(positions) do
		check_node(targets, all_nodes, cur_pos, p_pos, pnodeid, queue)
	end
end

local function fluid_targets(p_pos, pos)
	local provider = minetest.get_node(p_pos)
	local pnodeid  = minetest.pos_to_string(p_pos)

	local targets   = {}
	local queue     = {}
	local all_nodes = {}

	local node = minetest.get_node(pos)
	local ndef = minetest.registered_nodes[node.name]
	if ndef and minetest.get_item_group(node.name, "fluid_transport") > 0 then
		add_duct_node(all_nodes, pos, pnodeid, queue)
	elseif ndef and ndef['node_io_can_put_liquid'] and ndef['node_io_can_put_liquid'](pos, node, "back") then
		queue = {p_pos}
	end

	while next(queue) do
		local to_visit = {}
		for _, posi in ipairs(queue) do
			traverse_network(targets, all_nodes, posi, p_pos, pnodeid, to_visit)
		end
		queue = to_visit
	end

	targets   = flatten(targets)
	all_nodes = flatten(all_nodes)

	return targets
end

function fluid_lib.transfer_timer_tick(pos, elapsed)
	local refresh = true
	local node    = minetest.get_node_or_nil(pos)
	local status  = S("Fluid Transfer Pump")
	if not node then
		return false
	end

	local meta    = minetest.get_meta(pos)

	local targets = {}

	-- Only allow the node directly behind to be a start of a network
	local tpos  = vector.add(minetest.facedir_to_dir(node.param2), pos)
	local tnode = minetest.get_node(tpos)
	local ndef  = minetest.registered_nodes[tnode.name]
	if minetest.get_item_group(tnode.name, "fluid_transport") == 0 and
		(not ndef or not ndef['node_io_can_put_liquid'] or not ndef['node_io_can_put_liquid'](tpos, tnode, "back")) then
		minetest.forceload_free_block(pos)
		return
	end

	-- Retrieve network
	targets = fluid_targets(pos, tpos)
	-- No targets, don't proceed
	if #targets == 0 then
		meta:set_string("infotext", status.."\n" .. S("No Receiving Tank"))
		return true
	end

	-- Begin transfer
	local srcpos  = face_front(pos, node.param2)
	local srcnode = minetest.get_node(srcpos)

	-- Make sure source node is not air
	if not srcnode or srcnode.name == "air" then
		meta:set_string("infotext", status.."\n" .. S("No Source Tank"))
		return true
	end

	local srcdef = minetest.registered_nodes[srcnode.name]

	-- Make sure source node is a registered fluid container
	if not srcdef or not srcdef['node_io_can_take_liquid'] then
		meta:set_string("infotext", status.." " .. S("Off"))
		return false
	end

	local c = srcdef.node_io_can_take_liquid(srcpos, srcnode, "")
	if not c then
		meta:set_string("infotext", status.." " .. S("Off"))
		return false
	end

	local srcmeta = minetest.get_meta(srcpos)
	local fl_size = srcdef.node_io_get_liquid_size(srcpos, srcnode, "")
	local buffers = {}
	for i = 1, fl_size do
		buffers[i] = srcdef.node_io_get_liquid_name(srcpos, srcnode, "", i)
	end
	if not #buffers then
		meta:set_string("infotext", status.."\n" .. S("No Source Tank"))
		return true
	end

	-- Limit the amount of fluid pumped per cycle
	local pcapability = get_node_property(meta, pos, "fluid_pump_capacity")
	local pumped      = 0

	-- Transfer some fluid here
	for _,pos in pairs(targets) do
		if not vector.equals(pos, srcpos) then

			if pumped >= pcapability then break end

			local destnode = minetest.get_node(pos)
			local destdef  = minetest.registered_nodes[destnode.name]
			local pp = nil

			if destdef and destdef['node_io_can_put_liquid'] then
				if destdef.node_io_can_put_liquid(pos, destnode, "back") then
					pp = {}
					local fl_size = destdef.node_io_get_liquid_size(pos, destnode, "back")
					for i = 1, fl_size do
						pp[i] = destdef.node_io_get_liquid_name(pos, destnode, "back", i)
					end
					if #pp == 0 then pp = nil end
				end
			end

			local changed = false

			if pp ~= nil then
				for bindex,bfluid in pairs(pp) do            -- bfluid = destination fluid name
					for aindex,afluid in pairs(buffers) do   -- afluid = source fluid name

						-- get fluid names for pump status
						local bfluid_des = ""
						local afluid_des = ""

						if bfluid ~= "" then
							bfluid_des = fluid_lib.cleanse_node_description(bfluid)
						end

						if afluid ~= "" then
							afluid_des = fluid_lib.cleanse_node_description(afluid)
						end

						if pumped >= pcapability then
							meta:set_string("infotext", status.."\n".. S("Pumped Max Volume") .." "..bfluid_des)
							break
						end

						if (afluid == bfluid or bfluid == "") then -- bfluid = "", empty destiniation
							local idef = destdef.node_io_can_put_liquid(pos, destnode, "back", afluid, pcapability)

							if idef > 0 then
								local fluidcount = srcdef.node_io_get_liquid_stack(srcpos, srcnode, "back", aindex):get_count()
								local defc = math.min(fluidcount, idef)
								local defi = srcdef.node_io_take_liquid(srcpos, srcnode, "back", nil, afluid, defc)

								if defi and defi.millibuckets > 0 then
									local lo = destdef.node_io_put_liquid(pos, destnode, "back", nil, afluid, defi.millibuckets)
									pumped = pumped + (defi.millibuckets - lo)
									meta:set_string("infotext", status.."\n"..S("Pumping").." "..afluid_des)
									changed = true
								end
							else
								meta:set_string("infotext", status.."\n" .. S("Standby"))
							end
						end
					end
				end
			else
				meta:set_string("infotext", status.."\n" .. S("Standby"))
			end

			if changed then
				minetest.get_node_timer(srcpos):start(1.0)
				minetest.get_node_timer(pos):start(1.0)
			end
		end
	end

	return refresh
end

function fluid_lib.refresh_node(pos)
	local t = minetest.get_node_timer(pos)
	if t and not t:is_started() then
		t:start(1.0)
	end

	if node_io_present then
		node_io.update_neighbors(pos)
	end
end

minetest.register_lbm({
    label = "Fluid Transfer Tick",
    name = "fluid_transfer:fluid_transfer_tick",
    nodenames = {"group:fluid_transport_source", "group:fluid_pump"},
    run_at_every_load = true,
    action = fluid_lib.refresh_node,
})
