package graphics;
import "core:fmt"
import "core:mem"
import "core:slice"
import "core:math/linalg"
import "../core"

Renderer2D :: struct {
	pipeline         : RenderPipeline,
	camera_group     : BindGroup,
	camera_buffer    : Buffer,
	index_buffer     : Buffer,
	vertex_buffer    : Buffer,
	camera           : Camera,
	vertex_data      : [] TriColVertex,
	index_data       : [] u32,
	vertex_count     : u32,
	index_count      : u32,
}

TriColVertex :: struct {
	position : [2] f32,
	color    : [4] f32,
}

Renderer2D_Config :: struct {
	max_vertex_count : int,
	max_index_count  : int,
}

DEFAULT_RENDERER2D_CONFIG :: Renderer2D_Config {
	max_vertex_count = 1024,
	max_index_count  = 1024,
}

renderer2d_create :: proc(screen_size: [2] f32, config := DEFAULT_RENDERER2D_CONFIG) -> Renderer2D
{
	using renderer: Renderer2D;

	required_size := config.max_vertex_count * size_of(TriColVertex) \
	               + config.max_index_count  * size_of(u32);

	//arena := core.arena_create(required_size);
	//vertex_data = core.arena_alloc_slice(&arena, TriColVertex, config.max_vertex_count);
	//index_data  = core.arena_alloc_slice(&arena, u32,          config.max_index_count);

	//memory := core.allocate(required_size);
	//vertex_data = slice.from_ptr(cast(^TriColVertex) raw_data(memory), config.max_vertex_count);
	//index_data = slice.from_ptr(cast(^u32) raw_data(memory[size_of(TriColVertex)*config.max_vertex_count:]), config.max_index_count);
	vertex_data = core.allocate_slice([]TriColVertex, config.max_vertex_count);
	index_data = core.allocate_slice([]u32, config.max_index_count);

	pipeline = wgpu_pipeline_create("tri_col");
	vertex_buffer = wgpu_buffer_create(core.array_size(vertex_data), {.Vertex, .CopyDst});
	index_buffer = wgpu_buffer_create(core.array_size(index_data), {.Index, .CopyDst});
	camera_buffer = wgpu_buffer_create(size_of(Camera), {.Uniform, .CopyDst});
	camera_group = wgpu_bind_group_create(pipeline, 0, {{0, camera_buffer}});
	
	resize(&renderer, screen_size);
	
	return renderer;
}

resize :: proc(using renderer: ^Renderer2D, screen_size: [2] f32)
{
	camera.transform = linalg.matrix_ortho3d_f32(0, screen_size.x, screen_size.y, 0, -1, 1, false);
	wgpu_buffer_write(camera_buffer, mem.ptr_to_bytes(&camera));
}

add_rect :: proc(using renderer: ^Renderer2D, rect: Rectangle, color: Color)
{
	index_data[index_count+0] = vertex_count + 0;
	index_data[index_count+1] = vertex_count + 1;
	index_data[index_count+2] = vertex_count + 2;
	index_data[index_count+3] = vertex_count + 2;
	index_data[index_count+4] = vertex_count + 3;
	index_data[index_count+5] = vertex_count + 0;
	
	vertex_data[vertex_count+0] = {{rect.x.min, rect.y.min}, color};
	vertex_data[vertex_count+1] = {{rect.x.min, rect.y.max}, color};
	vertex_data[vertex_count+2] = {{rect.x.max, rect.y.max}, color};
	vertex_data[vertex_count+3] = {{rect.x.max, rect.y.min}, color};

	index_count += 6;
	vertex_count += 4;
}

add_rect_outline :: proc(using renderer: ^Renderer2D, rect: Rectangle, color: Color, stroke_width: f32 = 1)
{
	for i := 0; i < 8; i += 1 {
		if i & 1 == 1 {
			index_data[index_count+0] = vertex_count + u32(i);
			index_data[index_count+1] = vertex_count + u32((i + 1) % 8);
			index_data[index_count+2] = vertex_count + u32((i + 2) % 8);
		} else {
			index_data[index_count+0] = vertex_count + u32(i);
			index_data[index_count+1] = vertex_count + u32((i + 2) % 8);
			index_data[index_count+2] = vertex_count + u32((i + 1) % 8);
		}
		index_count += 3;
	}
	in_l := rect.x.min; out_l := in_l;
	in_r := rect.x.max; out_r := in_r;
	in_t := rect.y.min; out_t := in_t;
	in_b := rect.y.max; out_b := in_b;

	out_l -= stroke_width; out_t -= stroke_width;
	out_r += stroke_width; out_b += stroke_width;

	vertex_data[vertex_count+0] = {{out_l, out_b}, color};
	vertex_data[vertex_count+1] = {{ in_l,  in_b}, color};
	vertex_data[vertex_count+2] = {{out_l, out_t}, color};
	vertex_data[vertex_count+3] = {{ in_l,  in_t}, color};
	vertex_data[vertex_count+4] = {{out_r, out_t}, color};
	vertex_data[vertex_count+5] = {{ in_r,  in_t}, color};
	vertex_data[vertex_count+6] = {{out_r, out_b}, color};
	vertex_data[vertex_count+7] = {{ in_r,  in_b}, color};

	vertex_count += 8;
}

push_vertex :: proc(using renderer: ^Renderer2D, vertex: TriColVertex)
{
	index_data[index_count] = vertex_count;
	index_count += 1;
	vertex_data[vertex_count] = vertex;
	vertex_count += 1;
}

render :: proc(using renderer: ^Renderer2D)
{
	wgpu_buffer_write(index_buffer, index_data[:index_count]);
	wgpu_buffer_write(vertex_buffer, vertex_data[:vertex_count]);
	wgpu_bind_pipeline(pipeline);
	wgpu_bind_bind_group(0, camera_group);
	wgpu_bind_index_buffer(index_buffer);
	wgpu_bind_vertex_buffer(vertex_buffer);
	wgpu_draw_indexed(index_count);
	vertex_count = 0;
	index_count = 0;
}
