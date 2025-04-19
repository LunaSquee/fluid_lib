-- Universal Fluid API implementation
-- This hack overrides the Minetest Game buckets to work with the Node IO API
-- Also translates fluid registrations to games other than MTG
-- Copyright (c) 2025 Evert "Diamond" Prants <evert@lunasqu.ee>
fluid_lib = rawget(_G, "fluid_lib") or {}

local napi = minetest.get_modpath("node_io")
local mtg = minetest.get_modpath("default")
local mcl = minetest.get_modpath("mcl_core")
local bucketmod = minetest.get_modpath("bucket")
local mesecraft = minetest.get_modpath("mesecraft_bucket")

local local_registry = {}

local function get_bucket_global()
    if bucketmod ~= nil then
        return bucket
    elseif mesecraft ~= nil then
        return mesecraft_bucket
    elseif mcl ~= nil then
        return mcl_buckets
    end
end

function fluid_lib.get_empty_bucket()
    if mcl ~= nil then return "mcl_buckets:bucket_empty" end
    if mesecraft ~= nil then return "mesecraft_bucket:bucket_empty" end

    return "bucket:bucket_empty"
end

function fluid_lib.get_liquid_list()
    local list = {}
    if bucketmod ~= nil or mesecraft ~= nil then
        local global_bucket = get_bucket_global()
        for source in pairs(global_bucket.liquids) do list[source] = 1 end
    elseif mcl ~= nil then
        for source in pairs(mcl_buckets.liquids) do list[source] = 1 end
    else
        for source in pairs(local_registry) do list[source] = 1 end
    end
    return list
end

function fluid_lib.get_flowing_for_source(source)
    if bucketmod ~= nil or mesecraft ~= nil then
        local global_bucket = get_bucket_global()
        if global_bucket.liquids[source] ~= nil then
            return global_bucket.liquids[source].flowing
        end
    end

    local hack = source .. "_flowing"
    if core.registered_nodes[hack] ~= nil then return hack end

    return nil
end

function fluid_lib.get_bucket_for_source(source)
    if bucketmod ~= nil or mesecraft ~= nil then
        local global_bucket = get_bucket_global()
        if global_bucket.liquids[source] ~= nil then
            return global_bucket.liquids[source].bucketname
        end
    elseif mcl ~= nil and mcl_buckets.liquids[source] ~= nil then
        return mcl_buckets.liquids[source].bucketname
    end

    return nil
end

function fluid_lib.get_source_for_bucket(itemname)
    local found = nil

    if bucketmod ~= nil or mesecraft ~= nil then
        local global_bucket = get_bucket_global()
        for _, b in pairs(global_bucket.liquids) do
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

-- function taken straight from mcl_buckets because it is not exposed
-- https://git.minetest.land/VoxeLibre/VoxeLibre/src/branch/master/mods/ITEMS/mcl_buckets/init.lua
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

-- function taken straight from mcl_buckets because it is not exposed
-- https://git.minetest.land/VoxeLibre/VoxeLibre/src/branch/master/mods/ITEMS/mcl_buckets/init.lua
local function mcl_give_bucket(new_bucket, itemstack, user)
    local inv = user:get_inventory()
    if core.is_creative_enabled(user:get_player_name()) then
        -- TODO: is a full bucket added if inv doesn't contain one?
        return itemstack
    else
        if itemstack:get_count() == 1 then
            return new_bucket
        else
            if inv:room_for_item("main", new_bucket) then
                inv:add_item("main", new_bucket)
            else
                core.add_item(user:get_pos(), new_bucket)
            end
            itemstack:take_item()
            return itemstack
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

local function pick_inventory_image(inventory_image)
    if inventory_image:match("^#") then
        if mcl ~= nil then
            inventory_image =
                "mcl_buckets_bucket_compat.png^(mcl_buckets_mask.png^[multiply:" ..
                    inventory_image .. ")"
        elseif mesecraft ~= nil then
            inventory_image =
                "mesecraft_bucket.png^(bucket_mask.png^[multiply:" ..
                    inventory_image .. ")"
        else
            inventory_image = "bucket.png^(bucket_mask.png^[multiply:" ..
                                  inventory_image .. ")"
        end
    end
    return inventory_image
end

if bucketmod ~= nil or mesecraft ~= nil then
    -- For compatibility with previous fluid_lib version
    local global_bucket = get_bucket_global()
    global_bucket.get_liquid_for_bucket = fluid_lib.get_source_for_bucket

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

    -- OVERRIDE DEFAULT MTG BUCKETS --

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

                return ItemStack(fluid_lib.get_empty_bucket())
            end
        })
    end

    local original_register = global_bucket.register_liquid
    function global_bucket.register_liquid(source, flowing, itemname,
                                           inventory_image, name, groups,
                                           force_renew)
        inventory_image = pick_inventory_image(inventory_image)
        original_register(source, flowing, itemname, inventory_image, name,
                          groups, force_renew)
        override_bucket(itemname, source)
    end

    core.override_item(fluid_lib.get_empty_bucket(), {
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
                                if global_bucket.liquids[fluid] then
                                    itemstack = ItemStack(
                                                    global_bucket.liquids[fluid]
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

    if mesecraft ~= nil then
        override_bucket("mesecraft_bucket:bucket_water", "default:water_source")
        override_bucket("mesecraft_bucket:bucket_river_water",
                        "default:river_water_source")
        override_bucket("mesecraft_bucket:bucket_lava", "default:lava_source")
    elseif mtg ~= nil then
        override_bucket("bucket:bucket_water", "default:water_source")
        override_bucket("bucket:bucket_river_water",
                        "default:river_water_source")
        override_bucket("bucket:bucket_lava", "default:lava_source")
    end
end

if mcl ~= nil then
    -- OVERRIDE DEFAULT VOXELIBRE BUCKETS --

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

    -- OVERRIDE EMPTY BUCKET --

    local original_def = core.registered_items["mcl_buckets:bucket_empty"]
    local original_on_place = original_def.on_place
    local original_on_secondary_use = original_def.on_secondary_use
    local function run_bucket_pickup(itemstack, user, pointed_thing,
                                     original_function)
        -- Must be pointing to node
        if not pointed_thing or pointed_thing.type ~= "node" then
            return itemstack
        end

        local lpos = pointed_thing.under
        local node = minetest.get_node_or_nil(lpos)
        local ndef = node and minetest.registered_nodes[node.name]

        local new_stack = mcl_util.call_on_rightclick(itemstack, user,
                                                      pointed_thing)
        if new_stack then return new_stack end

        local player_name = user and user:get_name() or ""
        if core.is_protected(lpos, player_name) then
            core.record_protection_violation(lpos, player_name)
            return itemstack
        end

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
        local new_bucket = nil
        if usedef[defpref .. 'can_take_liquid'] and
            usedef[defpref .. 'can_take_liquid'](lpos, node, lookat) then
            local bfc = usedef[defpref .. 'get_liquid_size'](lpos, node, lookat)
            local buffers = {}
            for i = 1, bfc do
                buffers[i] = usedef[defpref .. 'get_liquid_name'](lpos, node,
                                                                  lookat, i)
            end

            if #buffers > 0 then
                for _, fluid in pairs(buffers) do
                    if fluid ~= "" then
                        local took = usedef[defpref .. 'take_liquid'](lpos,
                                                                      node,
                                                                      lookat,
                                                                      user,
                                                                      fluid,
                                                                      1000)
                        if took.millibuckets == 1000 and took.name == fluid then
                            if mcl_buckets.liquids[fluid] then
                                new_bucket = ItemStack(
                                                 mcl_buckets.liquids[fluid]
                                                     .bucketname)
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

        if new_bucket then
            return mcl_give_bucket(new_bucket, itemstack, user)
        end

        return original_function(itemstack, user, pointed_thing)
    end

    core.override_item("mcl_buckets:bucket_empty", {
        on_place = function(itemstack, user, pointed_thing)
            return run_bucket_pickup(itemstack, user, pointed_thing,
                                     original_on_place)
        end,
        on_secondary_use = function(itemstack, user, pointed_thing)
            return run_bucket_pickup(itemstack, user, pointed_thing,
                                     original_on_secondary_use)
        end
    })
end

function fluid_lib.register_liquid(source, flowing, itemname, inventory_image,
                                   name, groups, force_renew)

    inventory_image = pick_inventory_image(inventory_image)

    if bucketmod ~= nil or mesecraft ~= nil then
        local global_bucket = get_bucket_global()
        global_bucket.register_liquid(source, flowing, itemname,
                                      inventory_image, name, groups, force_renew)
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
    else
        local_registry[source] = {
            source = source,
            flowing = flowing,
            name = name
        }
    end
end
