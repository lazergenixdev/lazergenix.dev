#define OPTIONAL_ARGS \
    OPTIONAL_UINT_ARG(method, 0, "-m", "method", "Method: Fan(0) Strip(1) Max Area(2)") \
    OPTIONAL_UINT_ARG(lod, 4, "-l", "lod", "Level of detail")
#define BOOLEAN_ARGS \
    BOOLEAN_ARG(help, "-h", "Show help")
#include "easyargs.h"
#include "triangulate_circle.h"
#include "stdio.h"
#include "stdlib.h"

int main(int argc, char* argv[])
{
    args_t args = make_default_args();
    if (!parse_args(argc, argv, &args) || args.help) {
        print_help(argv[0]);
        return 1;
    }

    tric_Buffers buffers = {};
    tric_memory_requirements(args.method, args.lod, &buffers);

    buffers.Vertices = malloc(buffers.VertexCount * buffers.VertexStride);
    buffers.Indices = malloc(buffers.IndexCount * sizeof(uint32_t));
    tric_triangulate(args.method, args.lod, &buffers);

    tric_Point *positions = (tric_Point*)(buffers.Vertices);
    uint32_t triangle_count = buffers.IndexCount / 3;

    printf("<svg xmlns=\"http://www.w3.org/2000/svg\" viewBox=\"-1 -1 2 2\">\n");

    for (uint32_t i = 0; i < triangle_count; ++i)
    {
        uint32_t i0 = buffers.Indices[i*3 + 0];
        uint32_t i1 = buffers.Indices[i*3 + 1];
        uint32_t i2 = buffers.Indices[i*3 + 2];
        printf("<polygon points=\"%f,%f %f,%f %f,%f\"/>\n",
            positions[i0].x, positions[i0].y,
            positions[i1].x, positions[i1].y,
            positions[i2].x, positions[i2].y
        );
    }

    printf("</svg>\n");
}
