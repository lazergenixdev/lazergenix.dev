#include "wasm.h"

WASM_IMPORT(float, sin)(float x);
WASM_IMPORT(float, cos)(float x);

#define TRIC_ASSERT(...)
#define TRIC_SINCOS _sincos
inline static void _sincos(float x, float *sin, float *cos)
{
    *cos = __env_cos(x);
    *sin = __env_sin(x);
}

#include "triangulate_circle.h"

static WasmArenaAllocator allocator;
static tric_Buffers buffers;

WASM_EXPORT
void init()
{
    wasm_arena_init(&allocator);
}

WASM_EXPORT
void* vertex_buffer_data()
{
    return buffers.Vertices;
}

WASM_EXPORT
int vertex_buffer_size()
{
    return buffers.VertexCount * buffers.VertexStride;
}

WASM_EXPORT
void* index_buffer_data()
{
    return buffers.Indices;
}

WASM_EXPORT
int index_buffer_size()
{
    return buffers.IndexCount * sizeof(uint32_t);
}

WASM_EXPORT
void generate(tric_Method method, int lod)
{
    tric_memory_requirements(method, lod, &buffers);
    wasm_arena_free_all(&allocator);
    buffers.Vertices = wasm_arena_allocate(&allocator, vertex_buffer_size());
    buffers.Indices = wasm_arena_allocate(&allocator, index_buffer_size());
    tric_triangulate(method, lod, &buffers);
}
