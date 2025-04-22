local S = core.get_translator("fluid_lib")

-- Nodes for transferring fluids
-- All units are in millibuckets (1 bucket)

-- This is the node that takes fluid from another node.
function fluid_lib.register_extractor_node(nodename, nodedef)
	if not nodedef.groups then
		nodedef.groups = {}
	end

	nodedef.groups["fluid_transport_source"] = 1
	nodedef.paramtype2 = "facedir"
	nodedef.legacy_facedir_simple = true

	nodedef._mcl_blast_resistance = nodedef._mcl_blast_resistance or 1
	nodedef._mcl_hardness = nodedef._mcl_hardness or 2

	nodedef.on_timer = fluid_lib.transfer_timer_tick
	nodedef.node_io_on_neighbor_update = function (pos, node, side)
		local t = minetest.get_node_timer(pos)
		if not t:is_started() then
			t:start(1.0)
		end
	end

	local orig_construct = nodedef.on_construct
	nodedef.on_construct = function (pos)
		local meta = minetest.get_meta(pos)
		meta:set_int("fluid_store", 0)
		meta:set_string("fluid", "")

		fluid_lib.refresh_node(pos)

		if orig_construct then
			orig_construct(pos)
		end
	end

	nodedef.on_punch = function (pos, node, puncher, pointed_thing)
		minetest.get_node_timer(pos):start(1.0)
		minetest.chat_send_player(puncher:get_player_name(), S("Pump Started"))
		minetest.node_punch(pos, node, puncher, pointed_thing)
	end

	-- Default transfer capacity
	if not nodedef.fluid_pump_capacity then
		nodedef.fluid_pump_capacity = 1000
	end

	minetest.register_node(nodename, nodedef)
end

-- This is the node that allows for fluid transfer.
function fluid_lib.register_transfer_node(nodename, nodedef)
	if not nodedef.groups then
		nodedef.groups = {}
	end

	nodedef.groups["fluid_transport"] = 1
	nodedef._mcl_blast_resistance = nodedef._mcl_blast_resistance or 1
	nodedef._mcl_hardness = nodedef._mcl_hardness or 2

	-- Duct node density
	local cd = 1/7

	if nodedef.duct_density then
		cd = math.abs(nodedef.duct_density)
		nodedef.duct_density = nil
	end

	-- Default values, including the nodebox
	local defaults = {
		drawtype = "nodebox",
		node_box = {
			type = "connected",
			fixed = {
				{-cd, -cd, -cd, cd, cd, cd}
			},
			connect_front = {
				{-cd, -cd, -1/2, cd, cd, -cd}
			},
			connect_back = {
				{-cd, -cd, cd, cd, cd, 1/2}
			},
			connect_top = {
				{-cd, cd, -cd, cd, 1/2, cd}
			},
			connect_bottom = {
				{-cd, -1/2, -cd, cd, -cd, cd}
			},
			connect_left = {
				{-1/2, -cd, -cd, cd, cd, cd}
			},
			connect_right = {
				{cd, -cd, -cd, 1/2, cd, cd}
			},
		},
		paramtype = "light",
		connect_sides = { "top", "bottom", "front", "left", "back", "right" },
		is_ground_content = false,
		connects_to = {
			"group:fluid_transport",
			"group:fluid_transport_source",
			"group:fluid_container"
		},
	}

	for k,v in pairs(defaults) do
		if not nodedef[k] then
			nodedef[k] = v
		end
	end

	nodedef.on_construct = fluid_lib.refresh_node
	nodedef.after_destruct = fluid_lib.refresh_node

	minetest.register_node(nodename, nodedef)
end
