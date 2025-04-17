-- Universal Fluid API implementation
-- This hack overrides the Minetest Game buckets to work with the Node IO API
-- Also translates fluid registrations to games other than MTG
-- Copyright (c) 2025 Evert "Diamond" Prants <evert@lunasqu.ee>
fluid_lib = rawget(_G, "fluid_lib") or {}

local napi = minetest.get_modpath("node_io")
local mtg = minetest.get_modpath("default")
local mcl = minetest.get_modpath("mcl_core")
local bucketmod = minetest.get_modpath("bucket")

function fluid_lib.get_empty_bucket()
    if mcl ~= nil then return "mcl_buckets:bucket_empty" end

    return "bucket:bucket_empty"
end

function fluid_lib.get_liquid_list()
    local list = {}
    if bucketmod ~= nil then
        for source in pairs(bucket.liquids) do list[source] = 1 end
    elseif mcl ~= nil then
        for source in pairs(mcl_buckets.liquids) do list[source] = 1 end
    end
    return list
end

function fluid_lib.get_flowing_for_source(source)
    if bucketmod ~= nil then return bucket.liquids[source].flowing end

    local hack = source .. "_flowing"
    if core.registered_nodes[hack] ~= nil then return hack end

    return nil
end

function fluid_lib.get_bucket_for_source(source)
    if bucketmod ~= nil and bucket.liquids[source] ~= nil then
        return bucket.liquids[source].itemname
    elseif mcl ~= nil and mcl_buckets.liquids[source] ~= nil then
        return mcl_buckets.liquids[source].bucketname
    end

    return nil
end

function fluid_lib.get_source_for_bucket(itemname)
    local found = nil

    if bucketmod ~= nil then
        for _, b in pairs(bucket.liquids) do
            if b.itemname and b.itemname == itemname then
                found = b.source
                break
            end
        end
    elseif mcl ~= nil then
        for source, b in pairs(mcl_buckets.liquids) do
            if b.bucketname and b.bucketname == itemname then
                found = source
                break
            end
        end
    end

    return found
end

-- function taken straight from mcl_buckets :P
local function mcl_bucket_get_pointed_thing(user)
    local start = user:get_pos()
    start.y = start.y + user:get_properties().eye_height
    local look_dir = user:get_look_dir()
    local _end = vector.add(start, vector.multiply(look_dir, 5))

    local ray = core.raycast(start, _end, false, true)
    for pointed_thing in ray do
        local name = core.get_node(pointed_thing.under).name
        local def = core.registered_nodes[name]
        if not def or def.drawtype ~= "flowingliquid" then
            return pointed_thing
        end
    end
end

local function mcl_extra_check(pos, placer, source)
    -- Fill any fluid buffers if present
    local place = true
    local ppos = vector.subtract(pos, vector.new(0, 1, 0))
    local pointed_thing = nil
    if placer then
        pointed_thing = mcl_bucket_get_pointed_thing(placer)
        if pointed_thing and pointed_thing.type == "node" then
            ppos = pointed_thing.under
        end
    end
    local buffer_node = minetest.get_node(ppos)
    local ndef = buffer_node and core.registered_nodes[buffer_node.name]

    -- Node IO Support
    local usedef = ndef
    local defpref = "node_io_"
    local lookat = "U"

    if napi then
        usedef = node_io
        lookat = pointed_thing and
                     node_io.get_pointed_side(placer, pointed_thing) or lookat
        defpref = ""
    end

    if usedef[defpref .. 'can_put_liquid'] and
        usedef[defpref .. 'can_put_liquid'](ppos, buffer_node, lookat) then
        if usedef[defpref .. 'room_for_liquid'](ppos, buffer_node, lookat,
                                                source, 1000) >= 1000 then
            usedef[defpref .. 'put_liquid'](ppos, buffer_node, lookat, placer,
                                            source, 1000)
            if ndef.on_timer then
                minetest.get_node_timer(ppos):start(
                    ndef.node_timer_seconds or 1.0)
            end
            place = false
        end
    end

    return place, true
end

if mtg ~= nil and bucketmod ~= nil then
    -- For compatibility with previous fluid_lib version
    bucket.get_liquid_for_bucket = fluid_lib.get_source_for_bucket

    local function check_protection(pos, name, text)
        if minetest.is_protected(pos, name) then
            minetest.log("action",
                         (name ~= "" and name or "A mod") .. " tried to " ..
                             text .. " at protected position " ..
                             minetest.pos_to_string(pos) .. " with a bucket")
            minetest.record_protection_violation(pos, name)
            return true
        end
        return false
    end

    local function override_bucket(itemname, source)
        core.override_item(itemname, {
            on_place = function(itemstack, user, pointed_thing)
                -- Must be pointing to node
                if pointed_thing.type ~= "node" then return end

                local node = minetest.get_node_or_nil(pointed_thing.under)
                local ndef = node and minetest.registered_nodes[node.name]

                -- Call on_rightclick if the pointed node defines it
                if ndef and ndef.on_rightclick and
                    not (user and user:is_player() and
                        user:get_player_control().sneak) then
                    return ndef.on_rightclick(pointed_thing.under, node, user,
                                              itemstack)
                end

                local lpos

                -- Check if pointing to a buildable node
                if ndef and ndef.buildable_to then
                    -- buildable; replace the node
                    lpos = pointed_thing.under
                else
                    -- not buildable to; place the liquid above
                    -- check if the node above can be replaced

                    lpos = pointed_thing.above
                    node = minetest.get_node_or_nil(lpos)
                    local above_ndef = node and
                                           minetest.registered_nodes[node.name]

                    if not above_ndef or not above_ndef.buildable_to then
                        -- do not remove the bucket with the liquid
                        return itemstack
                    end
                end

                if check_protection(lpos, user and user:get_player_name() or "",
                                    "place " .. source) then
                    return
                end

                -- Fill any fluid buffers if present
                local place = true
                local ppos = pointed_thing.under
                local buffer_node = minetest.get_node(ppos)

                -- Node IO Support
                local usedef = ndef
                local defpref = "node_io_"
                local lookat = "N"

                if napi then
                    usedef = node_io
                    lookat = node_io.get_pointed_side(user, pointed_thing)
                    defpref = ""
                end

                if usedef[defpref .. 'can_put_liquid'] and
                    usedef[defpref .. 'can_put_liquid'](ppos, buffer_node,
                                                        lookat) then
                    if usedef[defpref .. 'room_for_liquid'](ppos, buffer_node,
                                                            lookat, source, 1000) >=
                        1000 then
                        usedef[defpref .. 'put_liquid'](ppos, buffer_node,
                                                        lookat, user, source,
                                                        1000)
                        if ndef.on_timer then
                            minetest.get_node_timer(ppos):start(
                                ndef.node_timer_seconds or 1.0)
                        end
                        place = false
                    end
                end

                if place then
                    minetest.set_node(lpos, {name = source})
                end

                return ItemStack("bucket:bucket_empty")
            end
        })
    end

    local original_register = bucket.register_liquid
    function bucket.register_liquid(source, flowing, itemname, inventory_image,
                                    name, groups, force_renew)
        original_register(source, flowing, itemname, inventory_image, name,
                          groups, force_renew)
        override_bucket(itemname, source)
    end

    core.override_item("bucket:bucket_empty", {
        on_use = function(_, user, pointed_thing)
            if pointed_thing.type == "object" then
                pointed_thing.ref:punch(user, 1.0, {full_punch_interval = 1.0},
                                        nil)
                return user:get_wielded_item()
            elseif pointed_thing.type ~= "node" then
                -- do nothing if it's neither object nor node
                return
            end
            -- Check if pointing to a liquid source
            local node = minetest.get_node(pointed_thing.under)
            local liquiddef = bucket.liquids[node.name]
            local item_count = user:get_wielded_item():get_count()

            if liquiddef ~= nil and liquiddef.itemname ~= nil and node.name ==
                liquiddef.source then
                if check_protection(pointed_thing.under, user:get_player_name(),
                                    "take " .. node.name) then
                    return
                end

                -- default set to return filled bucket
                local giving_back = liquiddef.itemname

                -- check if holding more than 1 empty bucket
                if item_count > 1 then

                    -- if space in inventory add filled bucked, otherwise drop as item
                    local inv = user:get_inventory()
                    if inv:room_for_item("main", {name = liquiddef.itemname}) then
                        inv:add_item("main", liquiddef.itemname)
                    else
                        local pos = user:getpos()
                        pos.y = math.floor(pos.y + 0.5)
                        minetest.add_item(pos, liquiddef.itemname)
                    end

                    -- set to return empty buckets minus 1
                    giving_back = "bucket:bucket_empty " ..
                                      tostring(item_count - 1)

                end

                -- force_renew requires a source neighbour
                local source_neighbor = false
                if liquiddef.force_renew then
                    source_neighbor = minetest.find_node_near(
                                          pointed_thing.under, 1,
                                          liquiddef.source)
                end
                if not (source_neighbor and liquiddef.force_renew) then
                    minetest.add_node(pointed_thing.under, {name = "air"})
                end

                return ItemStack(giving_back)
            else
                -- non-liquid nodes will have their on_punch triggered
                local node_def = minetest.registered_nodes[node.name]
                if node_def then
                    node_def.on_punch(pointed_thing.under, node, user,
                                      pointed_thing)
                end
                return user:get_wielded_item()
            end
        end,
        on_place = function(itemstack, user, pointed_thing)
            -- Must be pointing to node
            if pointed_thing.type ~= "node" then return end

            local lpos = pointed_thing.under
            local node = minetest.get_node_or_nil(lpos)
            local ndef = node and minetest.registered_nodes[node.name]

            -- Call on_rightclick if the pointed node defines it
            if ndef and ndef.on_rightclick and
                not (user and user:is_player() and
                    user:get_player_control().sneak) then
                return ndef.on_rightclick(lpos, node, user, itemstack)
            end

            if check_protection(lpos, user and user:get_player_name() or "",
                                "take " .. node.name) then return end

            -- Node IO Support
            local usedef = ndef
            local defpref = "node_io_"
            local lookat = "N"

            if napi then
                usedef = node_io
                lookat = node_io.get_pointed_side(user, pointed_thing)
                defpref = ""
            end

            -- Remove fluid from buffers if present
            if usedef[defpref .. 'can_take_liquid'] and
                usedef[defpref .. 'can_take_liquid'](lpos, node, lookat) then
                local bfc = usedef[defpref .. 'get_liquid_size'](lpos, node,
                                                                 lookat)
                local buffers = {}
                for i = 1, bfc do
                    buffers[i] = usedef[defpref .. 'get_liquid_name'](lpos,
                                                                      node,
                                                                      lookat, i)
                end

                if #buffers > 0 then
                    for _, fluid in pairs(buffers) do
                        if fluid ~= "" then
                            local took =
                                usedef[defpref .. 'take_liquid'](lpos, node,
                                                                 lookat, user,
                                                                 fluid, 1000)
                            if took.millibuckets == 1000 and took.name == fluid then
                                if bucket.liquids[fluid] then
                                    itemstack = ItemStack(
                                                    bucket.liquids[fluid]
                                                        .itemname)
                                    if ndef.on_timer then
                                        minetest.get_node_timer(lpos):start(
                                            ndef.node_timer_seconds or 1.0)
                                    end
                                    break
                                end
                            end
                        end
                    end
                end
            end

            return itemstack
        end
    })

    override_bucket("bucket:bucket_water", "default:water_source")
    override_bucket("bucket:bucket_river_water", "default:river_water_source")
    override_bucket("bucket:bucket_lava", "default:lava_source")
end

if mcl ~= nil then
    local function override_bucket(item, source)
        local original = mcl_buckets.buckets[item]
        if not original then return end
        local source_place = original.source_place
        local original_extra_check = original.extra_check
        original.extra_check = function(pos, placer)
            local use_source = source
            if source_place then
                use_source = (type(source_place) == "function") and
                                 source_place(pos) or source_place
            end
            local place, empty = mcl_extra_check(pos, placer, use_source)
            if original_extra_check and place then
                return original_extra_check(pos, placer)
            end

            return place, empty
        end
    end

    override_bucket("mcl_buckets:bucket_lava", "mcl_core:lava_source")
    override_bucket("mcl_buckets:bucket_water", "mcl_core:water_source")
    override_bucket("mcl_buckets:bucket_river_water",
                    "mclx_core:river_water_source")
end

function fluid_lib.register_liquid(source, flowing, itemname, inventory_image,
                                   name, groups, force_renew)
    if inventory_image:match("^#") then
        if mcl ~= nil then
            inventory_image =
                "mcl_buckets_bucket.png^(mcl_buckets_mask.png^[multiply:" ..
                    inventory_image .. ")"
        else
            inventory_image = "bucket.png^(bucket_mask.png^[multiply:" ..
                                  inventory_image .. ")"
        end
    end

    if bucketmod ~= nil then
        bucket.register_liquid(source, flowing, itemname, inventory_image, name,
                               groups, force_renew)
    elseif mcl ~= nil then
        mcl_buckets.register_liquid({
            source_place = source,
            source_take = {source},
            bucketname = itemname,
            inventory_image = inventory_image,
            name = name,
            extra_check = function(pos, placer)
                return mcl_extra_check(pos, placer, source)
            end,
            groups = groups,
            -- TODO: descriptions
            longdesc = "",
            usagehelp = "",
            tt_help = ""
        })
    end
end

