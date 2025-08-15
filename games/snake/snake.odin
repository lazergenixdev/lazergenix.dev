package snake;
import "base:runtime"
import "core:mem"
import "core:math"
import "core:math/rand"
import "core:math/linalg"
import "engine:core"
import "engine:input"
import "engine:window"
import "engine:graphics"

BOARD_WIDTH  :: 21;
BOARD_HEIGHT :: 21;
COOLDOWN     :: 0.15;
START_LENGTH :: 3;

Location :: [2] int;

arena: mem.Arena;
r: graphics.Renderer2D;
game: struct {
	next_direction  : core.Direction2D,
	direction       : core.Direction2D,
	paused          : bool,
	lost            : bool,
	want_reset      : bool,
	spaces_moved    : int,
	snake_memory    : [] Location,
	snake           : [] Location,
	size            : [2] int,
	tile_size       : f32,
	update_cooldown : f32,
	apple           : Location,
	board_offset    : [2] f32,
}

@export
game_init :: proc()
{
	context = window.wasm_context;
	size := core.cast_vector(window.size, f32);
	
	r = graphics.renderer2d_create(size);
	game.size = {BOARD_WIDTH, BOARD_HEIGHT};
	memory := core.allocate(size_of(Location) * BOARD_WIDTH * BOARD_HEIGHT);
	game.snake_memory = mem.slice_data_cast([]Location, memory[:]);
	resize_board();
	reset_game();
}

@export
game_handle_event :: proc(event: input.Event)
{
	switch e in event {
		case input.Key_Event:
			if e.state == .Down {
				new_dir := game.next_direction;
				#partial switch e.keycode {
					case .Up: fallthrough
					case .W: new_dir = .Up;
					case .Left: fallthrough
					case .A: new_dir = .Left;
					case .Down: fallthrough
					case .S: new_dir = .Down;
					case .Right: fallthrough
					case .D: new_dir = .Right;
					case .N:
						snake_grow();
					case .R: game.want_reset = true;
					case .M:
						game.snake = game.snake_memory[:1];
					case .Space:
						game.paused = !game.paused;
				}
				if new_dir != flip(game.direction) {
					game.next_direction = new_dir;
				}
			}
	}
}

@export
game_loop :: proc(dt: f32, flags: core.StateFlags)
{
	context = window.wasm_context;

	// Probably should make this part of the engine somehow?
	size := core.cast_vector(window.size, f32);
	if .Resized in flags {
		graphics.resize(&r, size);
		resize_board();
	}

	if game.want_reset {
		reset_game();
	}

	if !game.lost && !game.paused {
		game.update_cooldown += dt;
		for game.update_cooldown >= COOLDOWN {
			move : [2] int;
			game.direction = game.next_direction;
			switch game.direction {
				case .Left:  move.x += -1.0;
				case .Right: move.x +=  1.0;
				case .Up:    move.y += -1.0;
				case .Down:  move.y +=  1.0;
			}
			snake_move(move);
			game.update_cooldown -= COOLDOWN;
			
			if game.spaces_moved >= START_LENGTH {
				for loc in game.snake[1:] {
					if game.snake[0] == loc {
						game.lost = true;
					}
				}
			}
			if game.snake[0].x < 0 || game.snake[0].x >= game.size.x \
			|| game.snake[0].y < 0 || game.snake[0].y >= game.size.y {
				game.lost = true;
			}
			if game.snake[0] == game.apple {
				snake_grow();
				reset_apple();
			}
		}
		
	}
	
	board_size := core.cast_vector(game.size, f32) * game.tile_size;
	game.board_offset = calculate_board_offset(board_size);

	graphics.add_rect_outline(&r, graphics.rect_from_topleft(game.board_offset, board_size), 1, 3);
	fill_cell(game.apple, {0.8, 0.3, 0.3, 1});
	snake_color: graphics.Color = {0.3, 0.3, 0.3, 1} if game.lost else {0.3, 0.8, 0.3, 1};

	for loc in game.snake[len(game.snake)-1:] {
		rect := graphics.rect_from_topleft(core.to_f32(loc) * game.tile_size + game.board_offset, game.tile_size);
		t := game.update_cooldown / COOLDOWN;
		switch to_direction(game.snake[len(game.snake)-2] - loc) {
			case .Left:  rect.x.max = math.lerp(rect.x.max, rect.x.min, t);
			case .Right: rect.x.min = math.lerp(rect.x.min, rect.x.max, t);
			case .Up:    rect.y.max = math.lerp(rect.y.max, rect.y.min, t);
			case .Down:  rect.y.min = math.lerp(rect.y.min, rect.y.max, t);
		}
		graphics.add_rect(&r, rect, snake_color);
	}
	for loc in game.snake[1:len(game.snake)-1] {
		fill_cell(loc, snake_color);
	}
	for loc in game.snake[:1] {
		rect := graphics.rect_from_topleft(core.to_f32(loc) * game.tile_size + game.board_offset, game.tile_size);
		t := game.update_cooldown / COOLDOWN;
		switch game.direction {
			case .Left:  rect.x.min = math.lerp(rect.x.max, rect.x.min, t);
			case .Right: rect.x.max = math.lerp(rect.x.min, rect.x.max, t);
			case .Up:    rect.y.min = math.lerp(rect.y.max, rect.y.min, t);
			case .Down:  rect.y.max = math.lerp(rect.y.min, rect.y.max, t);
		}
		graphics.add_rect(&r, rect, snake_color);
	}

	graphics.render(&r);
}

calculate_board_offset :: proc(size: [2] f32) -> [2] f32
{
	window_size := core.to_f32(window.size);
	return (window_size - size) * 0.5;
}

fill_cell :: proc(loc: Location, color: graphics.Color, offset := [2] f32 {})
{
	rect := graphics.rect_from_topleft(core.to_f32(loc) * game.tile_size + game.board_offset, game.tile_size);
	graphics.add_rect(&r, graphics.rect_offset(rect, offset), color);
}

snake_move :: proc(offset: [2] int)
{
	for i := len(game.snake)-1; i > 0; i -= 1 {
		game.snake[i] = game.snake[i-1];
	}
	game.snake[0] += offset;
	game.spaces_moved += 1;
}

snake_grow :: proc()
{
	last := len(game.snake);
	game.snake = game.snake_memory[:last+1];
	game.snake[last] = game.snake[last-1];
}

reset_apple :: proc()
{
	loc: Location;
	search: for {
		loc.x = int(rand.uint32() % u32(game.size.x));
		loc.y = int(rand.uint32() % u32(game.size.y));
		
		for l in game.snake {
			if loc == l {
				continue search;
			}
		}
		
		break;
	}
	game.apple = loc;
}

resize_board :: proc()
{
	window_size := core.to_f32(window.size);
	potential_sizes := window_size / core.to_f32(game.size + 1);
	game.tile_size = min(potential_sizes.x, potential_sizes.y);
}

reset_game :: proc()
{
	game.lost = false;
	game.paused = false;
	game.want_reset = false;
	game.spaces_moved = 0;
	game.snake = game.snake_memory[:START_LENGTH];
	for i in 0..<START_LENGTH {
		game.snake[i] = {0, 10};
	}
	game.direction = .Right;
	game.next_direction = .Right;
	reset_apple();
}

flip :: proc(dir: core.Direction2D) -> core.Direction2D
{
	switch dir {
		case .Left:  return .Right;
		case .Right: return .Left;
		case .Up:    return .Down;
		case .Down:  return .Up;
	}
	return {};
}

to_direction :: proc(vector: Location) -> core.Direction2D
{
	switch int(vector.x > vector.y) << 1 | int(vector.x > -vector.y) {
		case 0b00: return .Left;
		case 0b01: return .Down; // Up and Down are swapped because Up is negative
		case 0b10: return .Up;
		case 0b11: return .Right;
	}
	return {};
}
