struct Vertex
{
    float2 position;
    float4 color;
}

struct Camera
{
    float4x4 mvp;
}

ParameterBlock<Camera> camera;

struct VOut
{
    float4 position : SV_Position;
    float4 color;
}

[shader("vertex")]
VOut vs_main(Vertex input)
{
    VOut output;
    output.position = mul(camera.mvp, float4(input.position, 1.0));
    output.color = input.color;
    return output;
}

[shader("fragment")]
float4 fs_main(VOut input) : SV_Target
{
    return input.color;
}
