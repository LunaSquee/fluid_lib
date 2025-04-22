local S = core.get_translator("fluid_lib")

fluid_tanks.register_tank("fluid_tanks:tank", {
	description = S("Fluid Tank"),
	capacity = 8000,
	accepts = true,
})

-- Just some default crafting recipes. No big deal if we cannot craft this, as the mods
-- using fluid_lib currently all have their own tanks.

if core.get_modpath("xcompat") then
	minetest.register_craft({
		output = "fluid_tanks:tank",
		recipe = {
			{xcompat.materials.glass, xcompat.materials.glass, xcompat.materials.glass},
			{xcompat.materials.glass, xcompat.materials.steel_ingot, xcompat.materials.glass},
			{xcompat.materials.glass, xcompat.materials.glass, xcompat.materials.glass},
		}
	})
elseif core.get_modpath("default") then
	minetest.register_craft({
		output = "fluid_tanks:tank",
		recipe = {
			{"default:glass", "default:glass", "default:glass"},
			{"default:glass", "default:steel_ingot", "default:glass"},
			{"default:glass", "default:glass", "default:glass"},
		}
	})
elseif core.get_modpath("mcl_core") then
	minetest.register_craft({
		output = "fluid_tanks:tank",
		recipe = {
			{"mcl_core:glass", "mcl_core:glass", "mcl_core:glass"},
			{"mcl_core:glass", "mcl_core:iron_ingot", "mcl_core:glass"},
			{"mcl_core:glass", "mcl_core:glass", "mcl_core:glass"},
		}
	})
end
