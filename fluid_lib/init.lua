-- Universal Fluid API implementation
-- Copyright (c) 2018 Evert "Diamond" Prants <evert@lunasqu.ee>

local modpath = minetest.get_modpath(minetest.get_current_modname())
local S = core.get_translator("fluid_lib")

fluid_lib = rawget(_G, "fluid_lib") or {}
fluid_lib.modpath = modpath

fluid_lib.unit = S("mB")
fluid_lib.unit_description = S("milli-bucket")

fluid_lib.empty_buffer = S("Empty")

fluid_lib.fluid_name_cache = {}
fluid_lib.fluid_description_cache = {}

function fluid_lib.cleanse_node_name(node)
	if fluid_lib.fluid_name_cache[node] then
		return fluid_lib.fluid_name_cache[node]
	end

	local no_mod    = node:gsub("^([%w_]+:)", "")
	local no_source = no_mod:gsub("(_?source_?)", "")

	fluid_lib.fluid_name_cache[node] = no_source
	return no_source
end

function fluid_lib.cleanse_node_description(node)
	if fluid_lib.fluid_description_cache[node] then
		return fluid_lib.fluid_description_cache[node]
	end

	local ndef = minetest.registered_nodes[node]
	if not ndef then return nil end

	-- Remove translation string
	local desc_no_translation = ndef.description
	if string.match(desc_no_translation, "^\27") ~= nil then
		desc_no_translation = desc_no_translation:match("[)]([%w%s]+)\27")
	end

	local translated_name = ndef._fluid_name or ndef._doc_items_entry_name
	local no_source = translated_name or desc_no_translation:gsub("(%s?Source%s?)", "")

	fluid_lib.fluid_description_cache[node] = no_source
	return no_source
end

function fluid_lib.comma_value(n) -- credit http://richard.warburton.it
	local left,num,right = string.match(n,'^([^%d]*%d)(%d*)(.-)$')
	return left..(num:reverse():gsub('(%d%d%d)','%1,'):reverse())..right
end

dofile(modpath.."/buffer.lua")
dofile(modpath.."/nodeio.lua")
