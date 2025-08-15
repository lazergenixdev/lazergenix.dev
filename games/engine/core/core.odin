package core;
import "base:runtime"
import "base:intrinsics"
import "core:mem"
import "core:slice"
import "core:math/rand"

State :: enum u32 { Resized };
StateFlags :: bit_set[State; u32];

WASM_PAGE_SIZE :: 1 << 16;

ceil_div :: proc(num, den: $T) -> T
{
	return (num + den - 1) / den;
}

allocate :: proc(size: int) -> [] u8
{
	return allocate_pages(ceil_div(size, WASM_PAGE_SIZE));
}

allocate_pages :: proc(page_count: int) -> [] u8
{
	page_start := cast(uintptr) intrinsics.wasm_memory_grow(0, uintptr(page_count));
	data := page_start * WASM_PAGE_SIZE;
	size := page_count * WASM_PAGE_SIZE;
	return slice.bytes_from_ptr(cast(rawptr) data, size);
}

allocate_slice :: proc($T: typeid, count: int) -> T
{
	return mem.slice_data_cast(T, allocate(size_of(T) * count));
}

arena_create :: proc(size: int) -> mem.Arena
{
	arena: mem.Arena;
	mem.arena_init(&arena, allocate(size));
	return arena;
}

//arena_allocator_create :: proc(size: int) -> mem.Arena
//{
//	arena: mem.Arena;
//	mem.arena_init(&arena, allocate(size));
//	return runtime.allocator;
//}

arena_alloc_slice :: proc(arena: ^mem.Arena, $T: typeid, count: int) -> [] T
{
	ptr, err := mem.arena_alloc(arena, size_of(T) * count);
	return slice.from_ptr(cast([^] T) ptr, count);
}

array_size :: proc(array: [] $T) -> int
{
	return size_of(T) * len(array);
}

cast_vector :: proc(vector: [$N] $F, $T: typeid) -> [N] T
{
	result : [N] T;
	#unroll for i in 0..<len(vector) {
		result[i] = cast(T) vector[i]
	}
	return result;
}

to_f32 :: proc(vector: [$N] $F) -> [N] f32
{
	return cast_vector(vector, f32);
}
