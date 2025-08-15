package input;

Key_State :: enum u32 { Up, Down }

Key_Code :: enum u32 {
	None = 0,
	Left = 1, Right, Up, Down,
	Space = 5,
	A = 65, B, C, D, E, F, G, H, I, J, K, L, M, N, O, P, Q, R, S, T, U, V, W, X, Y, Z,	
}

Key_Event :: struct {
	state: Key_State,
	keycode: Key_Code,
}

Event :: union {
	Key_Event,
}
