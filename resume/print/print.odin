package print;

import "core:fmt"
import "core:terminal/ansi"

STRING   :: ansi.CSI + ansi.FG_YELLOW + ansi.SGR + "\"{}\"" + ansi.CSI + ansi.RESET + ansi.SGR;
DURATION :: ansi.CSI + ansi.FG_GREEN + ansi.SGR + "{}" + ansi.CSI + ansi.RESET + ansi.SGR;

error :: proc(format: string, args: ..any) {
    fmt.eprint(ansi.CSI + ansi.FG_RED + ansi.SGR \
        + "Error" + ansi.CSI + ansi.RESET + ansi.SGR \
        + ": ");
    fmt.eprintfln(format, ..args);
}

command :: proc(format: string, args: ..any) {
    fmt.eprint("- " + ansi.CSI + ansi.BOLD + ";" + ansi.FG_BLUE + ansi.SGR \
        + "Command" + ansi.CSI + ansi.RESET + ansi.SGR \
        + " ");
    fmt.eprintfln(format, ..args);
}

generated :: proc(format: string, args: ..any) {
    fmt.eprint("- " + ansi.CSI + ansi.BOLD + ";" + ansi.FG_BLUE + ansi.SGR \
        + "Generated" + ansi.CSI + ansi.RESET + ansi.SGR \
        + " ");
    fmt.eprintfln(format, ..args);
}
