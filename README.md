# Universal Fluid API
This API adds support for `fluid_buffers` inside nodes. This means that nodes can contain fluid. Simple fluid transfer is also implemented in `fluid_transfer`.
This mod implements [node_io](https://github.com/auouymous/node_io). Note that while it is recommended that you install this mod also, it is not required in order to function. **Enable ALL the mods provided by this "modpack"!**

This mod also provides an attempt to unify bucket mods from different games, currently focused on Minetest Game and VoxeLibre.

## How to Use
1. Add the node to the `fluid_container` group.
2. Add the following to the node defintion:
```
    fluid_buffers = {
        buffer_name = {
            capacity = 2000,
            accepts = {"default:water_source", "group:water_source"}, -- you can also set this to true to accept any fluid!
            drainable = true,
        },
    }
```
3. Set the appropriate metadata.

* **buffer_name_fluid** = `string` 		- Source node of the fluid.
* **buffer_name_fluid_storage** = `int` 	- How much fluid there is in this buffer.

4. Register your node **(DO NOT MISS THIS STEP! TRANSFER WILL NOT WORK OTHERWISE!)**.

Just call `fluid_lib.register_node(nodename)`.

## API
All numbers are in **milli-buckets** (1 bucket = 1000 mB).

* `fluid_lib.get_node_buffers(pos)`
	* Returns all the fluid buffers present inside a node.

* `fluid_lib.get_buffer_data(pos, buffer)`
	* Returns all the information about this buffer.
```
    {
        fluid     = fluid source block,
        amount    = amount of fluid,
        accepts   = list of accepted fluids,
        capacity  = capacity of the buffer,
        drainable = is this buffer drainable,
    }
```

* `fluid_lib.buffer_accepts_fluid(pos, buffer, fluid)`
	* Returns `true` if `fluid` can go inside the `buffer` at `pos`.

* `fluid_lib.can_insert_into_buffer(pos, buffer, fluid, count)`
	* Returns the amount of `fluid` that can go inside the `buffer` at `pos`. If all of it fits, it returns `count`.

* `fluid_lib.insert_into_buffer(pos, buffer, fluid, count)`
	* Actually does the inserting.

* `fluid_lib.can_take_from_buffer(pos, buffer, count)`
	* Returns the amount of `fluid` that can be taken from the `buffer` at `pos`.

* `fluid_lib.take_from_buffer(pos, buffer, count)`
	* Actually takes the fluid. On success, returns the source block that was taken and how much was actually taken.

* `fluid_lib.register_node(nodename)`
	* Registers a node that has fluid buffers. This is IMPORTANT!

* `fluid_lib.register_extractor_node(nodename, nodedef)`
	* Registers a node that can extract fluid from another node (in front of self) and put it into ducts.
	* `fluid_pump_capacity` variable in nodedef determines how much fluid (in mB) this node can "pump" every second.

* `fluid_lib.register_transfer_node(nodename, nodedef)`
	* Registers a node that can transfer fluids. This is effectively a fluid duct.
	* `duct_density` variable in nodedef determines the diameter of the duct (custom node_box is created).

* `fluid_lib.register_liquid(source, flowing, itemname, inventory_image, name, groups, force_renew)`
	* Works exactly the same as the default `bucket` mod, except it adds callbacks to insert/take fluid from nodes.
	* `inventory_image` can be a **ColorString**.
	* (WIP) supports additional games: Minetest Game (default bucket mod), VoxeLibre (mcl_buckets)

* `fluid_lib.get_empty_bucket()`
  * Get the item name of an empty bucket

* `fluid_lib.get_liquid_list()`
  * Get the list of registered source nodes

* `fluid_lib.get_flowing_for_source(source)`
  * Get the flowing variant of a liquid

* `fluid_lib.get_bucket_for_source(source)`
  * Get the bucket item name for a source node

* `fluid_lib.get_source_for_bucket(bucket)`
  * Get the source node of a bucket

## License
### fluid_lib
See [LICENSE](LICENSE)

### bucket_compat
Contains assets and code snippets from [Minetest Game](https://github.com/luanti-org/minetest_game/tree/master/mods/bucket) and [VoxeLibre](https://git.minetest.land/VoxeLibre/VoxeLibre/src/branch/master/mods/ITEMS/mcl_buckets) to provide maximum compatibility with the fluid APIs.
