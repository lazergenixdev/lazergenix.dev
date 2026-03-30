// Header for easier compilation to WASM modules
// Clang Flags: --target=wasm32 -nostdlib -Wl,--no-entry -Wl,--export-dynamic

#ifndef WASM_H
#define WASM_H
#include <stddef.h> // --> NULL, size_t
#include <stdint.h> // --> uint8_t, uint32_t, ...

#define WASM_EXPORT __attribute__((__visibility__("default"))) extern
#define WASM_IMPORT(RET,NAME) __attribute__((import_module("env"), import_name(#NAME))) extern RET __env_ ## NAME
#define WASM_PAGE_SIZE 65536

void *memset(void *dest, int c, size_t n)
{
	for (size_t i = 0; i < n; ++i)
		((uint8_t*)(dest))[i] = c;
	return dest;
}

void *memcpy(void * restrict dest, const void * restrict src, size_t n)
{
	for (size_t i = 0; i < n; ++i)
		((uint8_t*)(dest))[i] = ((uint8_t*)(src))[i];
	return dest;
}

size_t strlen(const char* start)
{
	if (!start) return 0;
    const char* end = start;
    while (*end != '\0') ++end;
    return end - start;
}

// WebAssembly Arena Allocator

typedef struct {
	size_t start_page;
	size_t pages_reserved;
	size_t bytes_allocated;
} WasmArenaAllocator;

static inline uint32_t _ceil_div(uint32_t num, uint32_t den)
{
    return (num + den - 1) / den;
}

static inline void wasm_arena_init(WasmArenaAllocator *arena)
{
    arena->start_page = __builtin_wasm_memory_grow(0, 1);
	arena->bytes_allocated = 0;
	arena->pages_reserved = WASM_PAGE_SIZE;
}

static inline void* wasm_arena_allocate(WasmArenaAllocator *arena, uint32_t size)
{
	size_t bytes_reserved = arena->pages_reserved * WASM_PAGE_SIZE;
	
	if (arena->bytes_allocated + size > bytes_reserved)
	{
		size_t total_pages_required = _ceil_div(arena->bytes_allocated + size, WASM_PAGE_SIZE);
		size_t pages_needed = total_pages_required - arena->pages_reserved;
		__builtin_wasm_memory_grow(0, pages_needed);
	}

	uint8_t *start_address = (uint8_t*)(arena->start_page * WASM_PAGE_SIZE);
	void *pointer = start_address + arena->bytes_allocated;
	arena->bytes_allocated += size;
	return pointer;
}

static inline void wasm_arena_free_all(WasmArenaAllocator *arena)
{
	arena->bytes_allocated = 0;
}

#endif // WASM_H
