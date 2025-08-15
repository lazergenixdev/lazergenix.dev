#! odin run .
package build;
import "core:os"
import "core:fmt";
import "core:c/libc"
import "core:strings"
import "core:sys/windows"
import "core:path/filepath"
import "core:unicode/utf16"
import "core:encoding/json"
import "core:encoding/base64"
MINIFY_WASM :: #config(MINIFY_WASM, true)

FileSize :: struct { name: string, size: uint };

statistics : struct {
	template: uint,
	engine: uint,
	shaders: [dynamic] FileSize,
	wasm: FileSize,
	total_size: i64,
}

options :: [] string {
	"-file",
	"-target:freestanding_wasm32",
	"-o:aggressive",
	"-collection:engine=engine",
}
all_options: string;
engine_code: string;
html_template :: #load("index.template.html", string);
shader_strings : map [string] string;

Game :: struct {
	name    : string,
	title   : string,
	icon    : string,
	shaders : [] string,
}

Substitution :: struct {
	old, new: string,
}

main :: proc()
{
	list_dependencies();
	setup()
	build({"snake",       "Snake Game",  "🐍", {"tri_col.slang"}})
	build({"minesweeper", "Minesweeper", "💣", {"tri_col.slang", "tri_tex.slang"}})
}

list_dependencies :: proc()
{
	// slangc
	// wgsl-minifier
	// wasm-opt
	// terser
	// html-minifier-terser
}

setup :: proc()
{
	all_options = strings.join(options, " ");
	
	{
		fmt.println(":: \e[33mMinimizing Javascript ...\e[0m");
		run_shell("terser Engine.js -o Engine.min.js --mangle --module -c -m");
		data, _ := os.read_entire_file("Engine.min.js");
		engine_code = string(data);
		fmt.println(" . ", "Engine.min.js");
		statistics.engine = len(engine_code);
	}

	shader_directory, _ := os.open(filepath.join({"engine", "shaders"}));
	shader_files, err := os.read_dir(shader_directory, -1);

	if err != nil {
		fmt.println("Failed to read directory", err);
		os.exit(1);
	}

	builder: strings.Builder;
	strings.builder_init(&builder);
	fmt.println(":: \e[33mBuilding Shaders ...\e[0m");
	for file in shader_files {
		if !strings.has_suffix(file.name, ".slang") {
			continue;
		}
		path, _ := strings.substring_to(file.fullpath, len(file.fullpath)-len(".slang"));
		output_wgsl := strings.concatenate({path, ".wgsl"});
		output_json := strings.concatenate({path, ".json"});
		runf("slangc {} -target wgsl -o {} -reflection-json {} -O2", file.fullpath, output_wgsl, output_json);
		fmt.println(" . ", filepath.base(output_json));
		
		min_wgsl, _ := strings.replace(output_wgsl, ".wgsl", ".min.wgsl", 1);
		runf("wgsl-minifier -f {} {}", output_wgsl, min_wgsl)
		fmt.println(" . ", filepath.base(min_wgsl));
		
		shader_json, _ := os.read_entire_file(output_json);
		shader_wgsl, _ := os.read_entire_file(min_wgsl);
		temp, _ := strings.replace(file.name, ".slang", "_json", 1);
		fmt.sbprintf(&builder, "{}:", temp);
		tokenizer := json.make_tokenizer(cast(string) shader_json);
		token, err := json.get_token(&tokenizer);
		for err == .None {
			strings.write_string(&builder, token.text);
			token, err = json.get_token(&tokenizer);
		}
		strings.write_string(&builder, ",");
		temp, _ = strings.replace(file.name, ".slang", "_wgsl", 1);
		fmt.sbprintf(&builder, "{}:`", temp);
		strings.write_string(&builder, cast(string) shader_wgsl);
		strings.write_string(&builder, "`,");

		shader_strings[file.name] = strings.to_string(builder);
	}
	statistics.template = len(html_template);
}

build :: proc(using game: Game)
{
	fmt.println(":: \e[35mBuilding", name, "...\e[0m")
	
	shader_builder: strings.Builder;
	strings.builder_init(&shader_builder);
	clear(&statistics.shaders);
	for name in shaders {
		strings.write_string(&shader_builder, shader_strings[name]);
		append(&statistics.shaders, FileSize {name, len(shader_strings[name])});
	}
	
	// Compile Game
	output_wasm := filepath.join({name, strings.concatenate({name, ".wasm"})});
	runf("odin build {0}/{0}.odin {2} -out:{1}", name, output_wasm, all_options)
	fmt.println(" . ", output_wasm)
	
	when MINIFY_WASM {
		min_wasm, _ := strings.replace(output_wasm, ".wasm", ".min.wasm", 1);
		runf("wasm-opt {} -Oz -o {}", output_wasm, min_wasm)
		fmt.println(" . ", min_wasm);
	}
	else {
		min_wasm := output_wasm;
	}

	//runf("gzip -9 -f {}", min_wasm);
	//fmt.print(" . ", output_wasm); fmt.println(".gz");

	wasm_data, _ := os.read_entire_file(min_wasm);
	encoded, _ := base64.encode(wasm_data);
	statistics.wasm = { min_wasm, len(encoded) };

	// Create Page (NOTE: this can be automated with reflection)
	substitutions := [] Substitution {
		{"@@icon@@", game.icon}, 
		{"@@name@@", game.name}, 
		{"@@title@@", game.title},
		{"@@code@@", engine_code},
		{"@@shaders@@", strings.to_string(shader_builder)},
		{"@@wasm@@", string(encoded)},
	};
	temp_html := filepath.join({name, "index.temp.html"});
	template(html_template, temp_html, substitutions)
	fmt.println(" . ", temp_html)
	
	output_html := filepath.join({name, "index.html"});
	cmd := strings.join({
		"html-minifier-terser",
		temp_html,
		"-o",
		output_html,
		"--collapse-whitespace --remove-comments --minify-css true",
	}, " ");
	run_shell(cmd);
	fmt.println(" . ", output_html)

	statistics.total_size = os.file_size_from_path(output_html);
	print_statistics();
}

template :: proc(source, output: string, substitutions: [] Substitution)
{
	result := strings.clone(source);
	for sub in substitutions {
		result, _ = strings.replace_all(result, sub.old, sub.new);
	}
	err := os.write_entire_file_or_err(output, transmute([] u8) result);
	if err != nil {
		os.exit(1);
	}
}

run_shell :: proc(command: string)
{
	if libc.system(strings.clone_to_cstring(command)) != 0 {
		os.exit(1);
	}
}

runf :: proc(format: string, args: ..any)
{
	run(fmt.tprintf(format, ..args));
}

run :: proc(command: string)
{
	if !run_command(command) {
		os.exit(1);
	}
}

run_command :: proc(command: string) -> (success: bool)
{
	using windows;
    si: STARTUPINFOW;
    pi: PROCESS_INFORMATION;
    exit_code: DWORD;

    si.cb = size_of(si);
    si.dwFlags = STARTF_USESTDHANDLES;

    // Inherit current stdout/stderr/stdin
    si.hStdOutput = GetStdHandle(STD_OUTPUT_HANDLE);
    si.hStdError  = GetStdHandle(STD_ERROR_HANDLE);
    si.hStdInput  = GetStdHandle(STD_INPUT_HANDLE);

    // Command to run (must be writable string for CreateProcessA)
    cmd := to_cstring16(command);

    if !CreateProcessW(nil, cmd, nil, nil, TRUE, 0, nil, nil, &si, &pi) {
        fmt.printf("CreateProcess failed ({}) {}\n", GetLastError(), command);
        return false;
    }

    // Wait until process finishes
    WaitForSingleObject(pi.hProcess, INFINITE);

    // Get its exit code
    if !GetExitCodeProcess(pi.hProcess, &exit_code) {
		fmt.printf(":: Failed to get exit code ({})\n", GetLastError());
    }
	
    // Close handles
    CloseHandle(pi.hProcess);
    CloseHandle(pi.hThread);

	return exit_code == 0;
}

to_cstring16 :: proc(str: string) -> [^] u16
{
	string_slice := make([] u16, len(str)+100, context.temp_allocator);
	string_slice[utf16.encode_string(string_slice, str)] = 0;
	return raw_data(string_slice);
}

print_statistics :: proc()
{
	kB :: proc(bytes: $T) -> string {
		return fmt.aprintf("{:.2f} kB", f64(bytes) / 1000);
	}
	fmt.printfln("\e[32m=== {:12s}  -  \"index.template.html\"\e[0m", kB(statistics.template))
	fmt.printfln("\e[32m=== {:12s}  -  \"Engine.min.js\"\e[0m", kB(statistics.engine))
	for s in statistics.shaders {
		fmt.printfln("\e[32m=== {:12s}  -  \"{}\"\e[0m", kB(s.size), s.name)
	}
	fmt.printfln("\e[32m=== {:12s}  -  \"{}\"\e[0m", kB(statistics.wasm.size), statistics.wasm.name)
	fmt.printfln("\e[32m=== {:12s}  -  \"index.html\"\e[0m", kB(statistics.total_size))
}
