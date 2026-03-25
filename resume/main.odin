// Generate Resume
// build :: odin build . -out:gen.exe
// run   :: ./gen.exe
package main;

import "core:os"
import "core:fmt"
import "core:time"
import "core:strings"
import "projects"
import "reload"
import "print"

resumes :: [] Resume {
    {
        name = "index",
        projects = {
            { projects.llvm, true },
            { projects.kai, true },
            { projects.ooo, true },
            { projects.voxel, true },
            { projects.fission, true },
            //{ projects.shirt, true },
            { projects.ytmm, true },
            { projects.optix, false },
            { projects.fluid, false },
            { projects.cloth, false },
        },
        skills = {
            {
                category = "Programming",
                items = {"C++", "C", "Python", "x86", "ARM", "CUDA", "MATLAB", "bash", "HTML", "Javascript", "CSS"},
            },
            {
                category = "Programming Tools",
                items = {"git", "lldb/gdb", "Makefiles", "CMake", "Linux"},
            },
            {
                category = "Graphics Tools",
                items = {"Vulkan", "DirectX", "OpenGL", "WebGPU", "Slang", "Unreal Engine 5", "Blender"},
            }
        }
    },
    {
        name = "qualcomm",
        projects = {
            { projects.llvm, true },
            { projects.kai, true },
            { projects.ooo, true },
            { projects.voxel, true },
            { projects.fission, true },
            //{ projects.shirt, true },
            { projects.ytmm, true },
            { projects.optix, false },
            { projects.fluid, false },
            { projects.cloth, false },
        },
        skills = {
            {
                category = "Programming",
                items = {"C++", "C", "Python", "x86", "ARM", "CUDA", "MATLAB", "bash", "HTML", "Javascript", "CSS"},
            },
            {
                category = "Programming Tools",
                items = {"git", "lldb/gdb", "Makefiles", "CMake", "Linux"},
            },
            {
                category = "Graphics Tools",
                items = {"Vulkan", "DirectX", "OpenGL", "WebGPU", "Slang", "Unreal Engine 5", "Blender"},
            }
        }
    }
}

Resume :: struct {
    name: string,
    projects: [] projects.Project_Reference,
    skills: [] Skill,
}

Skill :: struct {
    category: string,
    items: [] string,
}

main :: proc()
{
    if !reload.rebuild_urself({.Quit_On_Build_Failed}) { return }

    err := os.make_directory("generated");
    if err != nil && err != .Exist {
        print.error("Failed to created directory " + print.STRING + " ({})", err);
        return;
    }

    resume := resumes[0];
    resume_map := make(map[string] Resume);
    for resume in resumes {
        resume_map[resume.name] = resume;
    }

    if len(os.args) >= 2 {
        name := os.args[1];
        ok: bool;
        resume, ok = resume_map[name];
        if !ok {
            print.error("No resume with name " + print.STRING, name);
            valid_names := make([] string, len(resumes));
            for resume, i in resumes {
                valid_names[i] = resume.name;
            }
            fmt.print("Valid names: ");
            for name, i in valid_names {
                fmt.printf(print.STRING, name);
                if i + 1 < len(valid_names) {
                    fmt.print(", ");
                }
            }
            fmt.println();
            return;
        }
    }

    output := fmt.aprintf("{}.html", resume.name);
    if resume.name != "index" {
        output = strings.concatenate({"generated/", output});
    }

    for {
        inputs := reload.gather_all_html();
        is_needed, ok := reload.needs_rebuild(output, inputs[:]);
        if !ok {
            return
        }
        if is_needed {
            build_resume_html(output, resume);
        }
        free_all(context.temp_allocator);
        time.sleep(time.Second);

        if !reload.rebuild_urself() {
            return
        }
    }
}

build_resume_html :: proc(output: string, resume: Resume) -> (ok: bool)
{
    template :: "template.html";

    start := time.tick_now();

    // Generate HTML for all resume parts

    projects := projects.build_html(resume.projects);
    skills := build_skills_html(resume.skills);
    
    // Load template

    data, err := os.read_entire_file(template, context.allocator);
    if err != nil {
        print.error("Failed to read file " + print.STRING + " ({})", template, err);
        return;
    }

    // Build resume HTML

    builder := strings.builder_make(0, 2 * len(data));
    strings.write_bytes(&builder, data);
    strings.builder_replace_all(&builder, "<!-- Projects -->", projects);
    strings.builder_replace_all(&builder, "<!-- Skills -->", skills);
    str := strings.to_string(builder);

    // Write resume to file

    err = os.write_entire_file(output, str);
    if err != nil {
        print.error("Failed to write file " + print.STRING + " ({})", output, err);
        return;
    }
    
    // Print time elapsed
    
    duration := time.tick_since(start);
    print.generated("HTML " + print.STRING + " in " + print.DURATION, output, duration);
    return true;
}

build_skills_html :: proc(skills: [] Skill) -> string
{
    builder := strings.builder_make();

    for skill in skills
    {
        strings.write_string(&builder, "<div class=\"columns\">");
        strings.write_string(&builder, "<div><b>");
        strings.write_string(&builder, skill.category);
        strings.write_string(&builder, "</b></div>");
        strings.write_string(&builder, "<div>");
        for item, i in skill.items {
            strings.write_string(&builder, item);
            if i + 1 < len(skill.items) {
                strings.write_string(&builder, ", ");
            }
        }
        strings.write_string(&builder, "</div>");
        strings.write_string(&builder, "</div>");
    }

    return strings.to_string(builder);
}
