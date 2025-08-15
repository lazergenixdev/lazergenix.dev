package window;
import "base:runtime"
import "core:fmt"
import "core:math/rand"
import "../graphics"

@(default_calling_convention="contextless")
foreign {
	window_size :: proc() -> u32 ---
	log :: proc(message: string) ---
}

size: [2] u32;
mouse_pos: [2] u32;

logf :: proc(format: string, args: .. any)
{
	buf : [1024] u8;
	log(fmt.bprintf(buf[:], format, ..args));
}

rect :: #force_inline proc() -> graphics.Rectangle
{
	return {{0, cast(f32) size.x}, {0, cast(f32) size.y}};
}


@(default_calling_convention="contextless")
foreign {
	__link :: proc(index: int, address: rawptr) ---
	__rand :: proc(array: [] u32) ---
}

random_state : runtime.Default_Random_State;
wasm_context : runtime.Context;

@export
__engine_setup :: proc()
{
	__link(0, &size);
	__link(1, &mouse_pos);

	random_values : [2] u32;
	__rand(random_values[:])
	ptr_seed := transmute(^u64) raw_data(random_values[:])
	random_state = rand.create(ptr_seed^);
	
	wasm_context = context;
	wasm_context.random_generator = runtime.default_random_generator(&random_state);
	//default_context.allocator = runtime.default_wasm_allocator();
}