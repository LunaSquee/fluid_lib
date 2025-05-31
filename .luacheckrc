read_globals = {
    "DIR_DELIM", "INIT",

    "minetest", "core",
    "dump", "dump2",

    "mcl_util",
    "node_io",
    "xcompat",

    "Raycast",
    "Settings",
    "PseudoRandom",
    "PerlinNoise",
    "VoxelManip",
    "SecureRandom",
    "VoxelArea",
    "PerlinNoiseMap",
    "PcgRandom",
    "ItemStack",
    "AreaStore",

    "vector",


    table = {
        fields = {
            "copy",
            "indexof",
            "insert_all",
            "key_value_swap",
            "shuffle",
        }
    },

    string = {
        fields = {
            "split",
            "trim",
        }
    },

    math = {
        fields = {
            "hypot",
            "sign",
            "factorial"
        }
    },
}
globals = {
  bucket = {
      fields = {
          "register_liquid",
          "liquids",
          "get_liquid_for_bucket",
      }
  },
  mcl_buckets = {
      fields = {
          "register_liquid",
          "buckets",
          "liquids",
          "get_liquid_for_bucket",
      }
  },
  mesecraft_bucket = {
    fields = {
        "register_liquid",
        "liquids",
        "get_liquid_for_bucket",
    }
  },
  fluid_lib = {
      fields = {
          "unit",
          "transfer_timer_tick",
          "refresh_node",
          "register_transfer_node",
          "register_extractor_node",
          "register_node",
          "get_buffer_data",
          "get_node_buffers",
          "insert_into_buffer",
          "can_take_from_buffer",
          "take_from_buffer",
          "can_insert_into_buffer",
          "buffer_accepts_fluid",
          "cleanse_node_description",
          "buffer_to_string",
          "comma_value",
          "cleanse_node_name",
          "register_liquid",
          "empty_buffer",
          "get_empty_bucket",
          "get_liquid_list",
          "get_flowing_for_source",
          "get_source_for_flowing",
          "get_bucket_for_source",
          "get_source_for_bucket"
      },
  },
  fluid_tanks = {
      fields = {
          "register_tank"
      },
  },
}
