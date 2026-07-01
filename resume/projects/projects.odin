package projects;

import "core:fmt"
import "core:strings"

Project_Reference :: struct {
    project: Project,
    show_desc: bool,
}

Project :: struct {
    name: string,
    link: string,
    lang: [] string,
    desc: [] string,
}

kai: Project : {
    name = "Kai Scripting Language",
    link = "https://github.com/lazergenixdev/kai-compiler",
    lang = {"C"},
    desc = {
        "Designed an open-source performance-oriented AOT scripting language in C with zero dependencies to target real-time systems.",
        "Built a custom bytecode interpreter to support compile-time code execution and enable advanced metaprogramming features.",
        "Utilized arena allocation strategy to decrease total compilation speed, resulting in a 2x speed up in parsing.",
    },
}

ooo: Project : {
    name = "Pipelined Out-of-Order Processor",
    lang = {"SystemVerilog"},
    desc = {
        "Worked in a team of 2 to design, test, and implement a modern MIPS processor using SystemVerilog in a Linux environment with Verilator.",
        "Implemented out-of-order execution with register renaming to increase IPC by up to 50%.",
        "Designed a custom non-blocking data cache to increase memory throughput.",
    },
}

fluid: Project : {
    name = "SPH Fluid Simulation",
    link = "https://mbizzigotti.github.io/wi25-cse169-proj5",
    lang = {"Javascript", "WebGPU"},
    desc = {
        "Implemented particle-based physics models with neighbor searching, force calculation, and semi-implicit euler integration to estimate real fluid behavior.",
        "Leveraged modern GPU compute capabilities through WebGPU compute shaders to simulate and render thousands of fluid particles interactively.",
        "Optimized simulation performance by minimizing memory transfers to enable real-time performance.",
    },
}

voxel: Project : {
    name = "Voxel Rendering Engine",
    link = "https://github.com/lazergenixdev/First-Voxel-Engine",
    lang = {"C++"},
    desc = {
        "Developed a dynamic multi-threaded chunk remeshing system to optimize terrain updates without blocking the render thread using the Vulkan graphics API.",
        "Implemented level-of-detail voxel streaming to allow more than 100x the draw distances.",
        "Integrated greedy meshing algorithm to decrease cost of CPU to GPU data transfer.",
    },
}

fission: Project : {
    name = "Fission: Cross-Platform Game Framework",
    link = "https://github.com/lazergenixdev/Fission",
    lang = {"C++"},
    desc = {
        "Developed a cross-platform Vulkan game framework over 4+ years, to enable efficient application creation.",
        "Maintained a custom \"in-house\" build pipeline to support compilation across varied platforms (Windows, MacOS, Android) and toolchains (MSVC, Clang, GCC).",
    },
}

shirt: Project : {
    name = "Automatic T-Shirt Folder",
    lang = {"C"},
    desc = {
        "Worked on a team of 4 students to create a design, test, and build an automated T-shirt folder.",
        "Programmed the software to work with our hardware setup to control each motor.",
    },
}

ytmm: Project : {
    name = "YT Music Manager",
//  link = "https://github.com/lazergenixdev/ytmm",
    lang = {"Python"},
    desc = {
        "Designed a user database system in Python for efficient music organization/synchronization.",
        "Implemented continuous integration workflows on GitHub to automatically build and deploy binaries on each push.",
    },
}

optix: Project : {
    name = "OptiX Path Tracer",
    link = "https://mbizzigotti.github.io/cse168-showcase/final-project",
    lang = {"CUDA", "C++"},
    desc = {
        "Developed Multiple Importance Sampling path tracer using NVIDIA OptiX to enable real-time rendering.",
        "Implemented BVH acceleration structures to optimize ray-scene intersection performance.",
        "Used stratified sampling and quasi-random sequences to improve convergence.",
    },
}

cloth: Project : {
    name = "Cloth Simulation",
    link = "https://mbizzigotti.github.io/wi25-cse169-proj4",
    lang = {"Odin"},
    desc = {
        "Implemented a software physics system using symplectic euler integration with WebGL as the rendering backend to create a real-time cloth physics simulation.",
    },
}

llvm: Project : {
    name = "LLVM: Custom RISC-V Backend",
    lang = {"C++"},
    desc = {
        "Successfully modified LLVM RISC-V backend to generate code for a new experimental branching technique.",
        "Learned how to effectively apply LLVM tools and test programs to debug a variety of compiler issues.",
    },
}

build_html :: proc(projects: [] Project_Reference) -> string
{
    builder := strings.builder_make();

    for ref in projects
    {
        project := ref.project;
        has_link := len(ref.project.link) > 0;

        strings.write_string(&builder, "<div class=\"columns\">");
        strings.write_string(&builder, "<div>");
        if has_link {
            strings.write_string(&builder, fmt.tprint("<a class=\"proj\" href=\"", ref.project.link, "\">", sep=""))
        }
        else {
            strings.write_string(&builder, "<b>")
        }
        strings.write_string(&builder, ref.project.name);
        strings.write_string(&builder, has_link ? "</a>" : "</b>");
        if len(project.lang) > 0 {
            strings.write_string(&builder, ", ");
            strings.write_string(&builder, "<i>");
            for lang, i in project.lang {
                strings.write_string(&builder, lang);
                if i + 1 < len(project.lang) {
                    strings.write_string(&builder, ", ");
                }
            }
            strings.write_string(&builder, "</i>");
        }
        strings.write_string(&builder, "</div>");
        strings.write_string(&builder, "</div>");
        
        // Write description
        strings.write_string(&builder, ref.show_desc ? "<p>" : "<p class=\"empty\">");
        if ref.show_desc {
            for line in project.desc {
                strings.write_string(&builder, line);
                strings.write_string(&builder, " ");
            }
        }
        strings.write_string(&builder, "</p>");

        free_all(context.temp_allocator);
    }

    return strings.to_string(builder);
}
