package graphics;
import "core:math/rand"

Color :: [4] f32;

random_color :: proc() -> Color
{
	//return { 1, 0, 1, 1 };
	return { rand.float32(), rand.float32(), rand.float32(), 1 };
}

Camera :: struct {
	transform: matrix [4,4] f32,
}
