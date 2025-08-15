package graphics;

Range     :: struct { min, max: f32 };
Point     :: distinct [2] f32;
Triangle  :: distinct [3] Point;
Rectangle :: distinct [2] Range;

rect_from_center :: proc(center, size: [2] f32) -> Rectangle
{
	half_size := size * 0.5;
	return {
		{min = center.x - half_size.x, max = center.x + half_size.x},
		{min = center.y - half_size.y, max = center.y + half_size.y},
	};
}

rect_from_topleft :: proc(topleft, size: [2] f32) -> Rectangle
{
	return {
		{min = topleft.x, max = topleft.x + size.x},
		{min = topleft.y, max = topleft.y + size.y},
	};
}

rect_size :: proc(rect: Rectangle) -> [2] f32
{
	return {
		rect.x.max - rect.x.min,
		rect.y.max - rect.y.min,
	};
}

rect_offset :: proc(rect: Rectangle, offset: [2] f32) -> Rectangle
{
	return {
		transmute(Range) (transmute([2] f32) rect.x + offset.x),
		transmute(Range) (transmute([2] f32) rect.y + offset.y),
	};
}

rect_centered :: proc(parent: Rectangle, size: [2] f32) -> Rectangle
{
	return rect_from_topleft((rect_size(parent) - size) * 0.5, size);
}
