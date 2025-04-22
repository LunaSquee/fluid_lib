local xcp = core.get_modpath("xcompat")
local mtg = core.get_modpath("default")
local mcl = core.get_modpath("mcl_core")

if xcp then
    local materials = xcompat.materials
    -- Duct
    minetest.register_craft({
        output = "fluid_transfer:fluid_duct 8",
        recipe = {
            {materials.glass, materials.glass, materials.glass}, {"", "", ""},
            {materials.glass, materials.glass, materials.glass}
        }
    })

    -- Pump
    minetest.register_craft({
        output = "fluid_transfer:fluid_transfer_pump",
        recipe = {
            {"", "fluid_transfer:fluid_duct", ""},
            {materials.glass, materials.mese_crystal, materials.glass},
            {materials.stone, materials.stone, materials.stone}
        }
    })

    -- Trash
    minetest.register_craft({
        output = "fluid_transfer:fluid_trash",
        recipe = {
            {materials.cobble, materials.cobble, materials.cobble},
            {materials.stone, fluid_lib.get_empty_bucket(), materials.stone},
            {materials.stone, "fluid_transfer:fluid_duct", materials.stone}
        }
    })
elseif mtg then
    -- Duct
    minetest.register_craft({
        output = "fluid_transfer:fluid_duct 8",
        recipe = {
            {"default:glass", "default:glass", "default:glass"}, {"", "", ""},
            {"default:glass", "default:glass", "default:glass"}
        }
    })

    -- Pump
    minetest.register_craft({
        output = "fluid_transfer:fluid_transfer_pump",
        recipe = {
            {"", "fluid_transfer:fluid_duct", ""},
            {"default:glass", "default:mese_crystal", "default:glass"},
            {"default:stone", "default:stone", "default:stone"}
        }
    })

    -- Trash
    minetest.register_craft({
        output = "fluid_transfer:fluid_trash",
        recipe = {
            {"default:cobble", "default:cobble", "default:cobble"},
            {"default:stone", fluid_lib.get_empty_bucket(), "default:stone"},
            {"default:stone", "fluid_transfer:fluid_duct", "default:stone"}
        }
    })
elseif mcl then
    local redstone = core.get_modpath("mcl_redstone") and
                         "mcl_redstone:redstone" or "mesecons:redstone"

    -- Duct
    minetest.register_craft({
        output = "fluid_transfer:fluid_duct 8",
        recipe = {
            {"mcl_core:glass", "mcl_core:glass", "mcl_core:glass"},
            {"", "", ""}, {"mcl_core:glass", "mcl_core:glass", "mcl_core:glass"}
        }
    })

    -- Pump
    minetest.register_craft({
        output = "fluid_transfer:fluid_transfer_pump",
        recipe = {
            {"", "fluid_transfer:fluid_duct", ""},
            {"mcl_core:glass", redstone, "mcl_core:glass"},
            {"mcl_core:stone", "mcl_core:stone", "mcl_core:stone"}
        }
    })

    -- Trash
    minetest.register_craft({
        output = "fluid_transfer:fluid_trash",
        recipe = {
            {"mcl_core:cobble", "mcl_core:cobble", "mcl_core:cobble"},
            {"mcl_core:stone", fluid_lib.get_empty_bucket(), "mcl_core:stone"},
            {"mcl_core:stone", "fluid_transfer:fluid_duct", "mcl_core:stone"}
        }
    })
end
