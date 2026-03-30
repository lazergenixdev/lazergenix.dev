all: tric-svg tric.wasm

tric-svg: tric_generate_svg.c
	clang $^ -o $@

tric.wasm: tric_web.c
	clang --target=wasm32 -nostdlib -Wl,--no-entry -Wl,--export-dynamic $^ -o $@

