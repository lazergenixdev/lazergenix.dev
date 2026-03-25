package reload;

import "core:os"
import "core:fmt"
import "core:time"
import "core:terminal/ansi"
import "core:strings"
import "core:path/slashpath"

import "../print"

DEBUG :: false;

Options :: enum {
    Quit_On_Build_Failed,
}

rebuild_urself :: proc(flags: bit_set[Options] = nil, source_location := #caller_location) -> (ok: bool)
{
    assert(len(os.args) > 0);

    binary_path := os.args[0];
    when DEBUG { fmt.printfln("binary_path = \"{}\"", binary_path) }

    source_path := source_location.file_path;
    when DEBUG { fmt.printfln("source_path = \"{}\"", source_path) }
    
    sources := gather_all_source_paths(source_path);
    when DEBUG { fmt.printfln("sources = {}", sources) }
    is_needed := needs_rebuild(binary_path, sources[:]) or_return;
    when DEBUG { fmt.printfln("is_needed = \"{}\"", is_needed) }

    if !is_needed {
        return true;
    }
    
    old_binary_path := fmt.tprintf("{}.old", binary_path);

    if os.rename(binary_path, old_binary_path) != nil {
        print.error("Could not rename binary path to \"{}\"", old_binary_path);
        return;
    }

    if !run({"odin", "build", ".", fmt.tprintf("-out:{}", os.args[0])}) {
        os.rename(old_binary_path, binary_path);
        if .Quit_On_Build_Failed in flags {
            os.exit(1);
        }
        return true;
    }

    run(os.args);
    os.exit(0);
}

gather_all_source_paths :: proc(source_path: string) -> [dynamic] string
{
    paths := make([dynamic] string, context.temp_allocator);
    dir := slashpath.dir(source_path);

	w := os.walker_create(dir);
	defer os.walker_destroy(&w);

	for info in os.walker_walk(&w) {
		// _ = walker_error(&w) or_break
		if path, err := os.walker_error(&w); err != nil {
			print.error("Failed walking {}: {}", path, err);
			continue
		}

		if strings.has_suffix(info.fullpath, ".odin") {
            append(&paths, fmt.tprint(info.fullpath));
		}
	}

	// Handle error if one happened during iteration at the end:
	if path, err := os.walker_error(&w); err != nil {
        print.error("Failed walking {}: {}", path, err);
	}

    return paths;
}

gather_all_html :: proc(location := #caller_location) -> [dynamic] string
{
    paths := make([dynamic] string, context.temp_allocator);
    dir := slashpath.dir(location.file_path);

	w := os.walker_create(dir);
	defer os.walker_destroy(&w);

	for info in os.walker_walk(&w) {
		// _ = walker_error(&w) or_break
		if path, err := os.walker_error(&w); err != nil {
			print.error("Failed walking {}: {}", path, err);
			continue
		}

		if strings.has_suffix(info.fullpath, ".odin") {
            append(&paths, fmt.tprint(info.fullpath));
		}
		if strings.has_suffix(info.fullpath, ".html") {
            append(&paths, fmt.tprint(info.fullpath));
		}
	}

	// Handle error if one happened during iteration at the end:
	if path, err := os.walker_error(&w); err != nil {
        print.error("Failed walking {}: {}", path, err);
	}

    return paths;
}

needs_rebuild :: proc(output: string, inputs: [] string) -> (out: bool, ok: bool)
{
    output_path_time, err := os.modification_time_by_path(output);
    if err != nil {
        if err == .Not_Exist {
            return true, true;
        }
        print.error("Could not access file time of \"{}\"", output);
        return;
    }
    for path in inputs {
        input_path_time, err := os.modification_time_by_path(path);
        if err != nil {
            print.error("Could not access file time of \"{}\"", path);
            return;
        }
        if time.diff(input_path_time, output_path_time) < 0 {
            return true, true;
        }
    }
    return false, true;
}

run :: proc(command: [] string) -> (ok: bool)
{
    builder := strings.builder_make();
    for arg, i in command {
        strings.write_string(&builder, arg);
        if i+1 < len(command) {
            strings.write_string(&builder, " ");
        }
    }
	print.command(strings.to_string(builder));
    process, err := os.process_start({
        command = command,
        stderr = os.stderr,
        stdout = os.stdout,
        stdin = os.stdin,
    });
    if err != nil {
        print.error("Could not start process: {}", err);
        return false;
    }
    state, wait_err := os.process_wait(process);
    if wait_err != nil {
        print.error("Could not wait process: {}", wait_err);
        return false;
    }
    if  state.exit_code != 0 {
        print.error("Process exited with code {}", state.exit_code);
        return false;
    }
    return true;
}
