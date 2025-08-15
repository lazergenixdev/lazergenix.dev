const canvas = document.getElementById("main");

function report(error) {
	alert(error);
	throw error;
}

if (!navigator.gpu) {
	report(Error("WebGPU not supported."));
}

const adapter = await navigator.gpu.requestAdapter();
if (!adapter) {
	report(Error("Couldn't request WebGPU adapter."));
}

const device = await adapter.requestDevice();
const context = canvas.getContext("webgpu");
if (!context) {
	report(Error("Not able to create WebGPU context."));
}
context.configure({
	device,
	format: navigator.gpu.getPreferredCanvasFormat(),
	alphaMode: "premultiplied",
});

class BindingManager {
	constructor() {
		this.pools = {};
	}

	push(type, value) {
		let pool = this.pools[type];
		if (!pool) pool = this.pools[type] = [];
		const index = pool.length;
		pool.push(value);
		return index;
	}

	get(type, index) {
		return this.pools[type][index];
	}
}

const linked = {
	0: -1, // window size
	1: -1, // mouse position
};

const bindingManager = new BindingManager();
let state = 0;
let c = null; // Exported WASM Functions
let scratch_page = 0;

function resizeToParent() {
	const parent = canvas.parentElement;
	if (!parent) return;
	canvas.width = parent.clientWidth;
	canvas.height = parent.clientHeight;
	state |= 1;
}

resizeToParent();
window.addEventListener("resize", () => resizeToParent());

function setEventHandlers(handlers) {
	for (const [key, callback] of Object.entries(handlers)) {
		window.addEventListener(key, callback);
	}
}

/*initEventListeners() {
	this.canvas.addEventListener("mousemove", e => {
		const rect = this.canvas.getBoundingClientRect();
		this.mouse.x = e.clientX - rect.left;
		this.mouse.y = e.clientY - rect.top;
	});

	this.canvas.addEventListener("mousedown", e => this.mouse.buttons[e.button] = true);
	this.canvas.addEventListener("mouseup", e => this.mouse.buttons[e.button] = false);
}*/

function stringFromWASM(offset, length) {
	const bytes = new Uint8Array(c.memory.buffer, offset, length);
	return new TextDecoder().decode(bytes);
}

async function resolveAll(promises) {
	return await Promise.all(promises.map(async (p, i) => {
		promises[i] = await p;
	}));
}

function setVector2_u32(memory, offset, x, y) {
	const dv = new DataView(memory.buffer, offset);
	dv.setUint32(0, x, true);
	dv.setUint32(4, y, true);
}

function vertexLayoutFromReflection(reflect) {
	let stride = 0;
	const attributes = [];
	const sizeMap = {
		float32: 4,
	}
	function addAttribute(info) {
		if (info.binding.kind != "varyingInput") return;
		if (info.type.kind == "struct") {
			for (const field of info.type.fields) {
				addAttribute(field);
			}
		}
		else if (info.type.kind == "vector") {
			const format = info.type.elementType.scalarType + "x" + info.type.elementCount.toString();
			attributes.push({shaderLocation: info.binding.index, offset: stride, format: format});
			stride += info.type.elementCount * sizeMap[info.type.elementType.scalarType];
		}
		else if (info.type.kind == "scalar") {
			attributes.push({shaderLocation: info.binding.index, offset: stride, format: info.type.scalarType});
			stride += sizeMap[info.type.scalarType];
		}
		else {
			console.error("Unknown Type:", info.type.kind);
		}
	}
	for (const entry of reflect.entryPoints) {
		if (entry.name != "vs_main") continue;
		for (const param of entry.parameters) {
			addAttribute(param);
		}
	}
	return {
		arrayStride: stride,
		attributes: attributes,
	};
}

let encoder = null;
let renderPass = null;

WebAssembly.instantiate(Uint8Array.from(atob(`@@wasm@@`), c => c.charCodeAt(0)), {
	env: {
		__link: (index, address) => linked[index] = address,
		__rand: (ptr, len) => crypto.getRandomValues(new Uint32Array(c.memory.buffer, ptr, len)),
		wgpu_buffer_create: (size, usage) => {
			return bindingManager.push(GPUBuffer, device.createBuffer({size: size, usage: usage}))
		},
		wgpu_buffer_write_raw: (buffer, ptr, len, offset) => {
			device.queue.writeBuffer(bindingManager.get(GPUBuffer, buffer), offset, new DataView(c.memory.buffer, ptr, len))
		},
		wgpu_pipeline_create: (ptr, len) => {
			const id = stringFromWASM(ptr, len);
			const shaderModule = device.createShaderModule({code: shaders[id+"_wgsl"]});
			const format = navigator.gpu.getPreferredCanvasFormat();

			return bindingManager.push(GPURenderPipeline, device.createRenderPipeline({
				layout: "auto",
				vertex: {
					module: shaderModule,
					entryPoint: "vs_main",
					buffers: [vertexLayoutFromReflection(shaders[id+"_json"])]
				},
				fragment: {
					module: shaderModule,
					entryPoint: "fs_main",
					targets: [{ format }]
				},
				primitive: {
					topology: "triangle-list"
				}
			}));
		},
		wgpu_bind_group_create: (pipeline, set, ptr, count) => {
			const dv = new DataView(c.memory.buffer, ptr);
			const entries = [];

			for (let i = 0; i < count; ++i) {
				const index          = dv.getUint32(i*12,   true);
				const resource_index = dv.getUint32(i*12+4, true);
				const resource_type  = dv.getUint32(i*12+8, true);
				const entry = {binding: index};
				switch (resource_type) {
					case 1: // GPUBuffer
						entry.resource = {buffer: bindingManager.get(GPUBuffer, resource_index)};
						break;
					case 2: // GPUTextureView
					case 3: // GPUSampler
						break;
					default:
						console.error("Unknown reource type", resource_type);
				}
				entries.push(entry);
			}

			const _pipeline = bindingManager.get(GPURenderPipeline, pipeline);
			if (_pipeline instanceof Promise) {
				return bindingManager.push(GPUBindGroup, _pipeline.then((pipeline) => {
					return device.createBindGroup({
						layout: pipeline.getBindGroupLayout(set),
						entries: entries,
					});
				}));
			}
			return bindingManager.push(GPUBindGroup, device.createBindGroup({
				layout: _pipeline.getBindGroupLayout(set),
				entries: entries,
			}));
		},
		wgpu_bind_pipeline: (pipeline) => renderPass.setPipeline(bindingManager.get(GPURenderPipeline, pipeline)),
		wgpu_bind_bind_group: (index, bindGroup) => renderPass.setBindGroup(index, bindingManager.get(GPUBindGroup, bindGroup)),
		wgpu_bind_vertex_buffer: (buffer) => renderPass.setVertexBuffer(0, bindingManager.get(GPUBuffer, buffer)),
		wgpu_bind_index_buffer: (buffer) => renderPass.setIndexBuffer(bindingManager.get(GPUBuffer, buffer), "uint32"),
		wgpu_draw: (vertexCount, instanceCount, firstVertex, firstInstance) => renderPass.draw(vertexCount, instanceCount, firstVertex, firstInstance),
		wgpu_draw_indexed: (indexCount, instanceCount, firstIndex, baseVertex, firstInstance) => renderPass.drawIndexed(indexCount, instanceCount, firstIndex, baseVertex, firstInstance),
		log: (ptr, len) => console.log(stringFromWASM(ptr, len)),
		cosf: Math.cos,
		sinf: Math.sin,
		debug1: (msgptr, msglen, x, digits) => {},
		debug2: (msgptr, msglen, x, y, digits) => {},
		debug3: (msgptr, msglen, x, y, z, digits) => {},
		debug4: (msgptr, msglen, x, y, z, w, digits) => {},
	}
}).then(async (wasm) => {
	c = wasm.instance.exports;
	//scratch_page = c.memory.grow(1) << 16;
	c.__engine_setup();
	setVector2_u32(c.memory, linked[0], canvas.width, canvas.height);
	c.game_init();

	function onKeyEvent(state, code) {
		let keycode = undefined;
		if (code.startsWith("Key")) {
			keycode = code.charCodeAt(3);
		}
		if (keycode == undefined) {
			keycode = {
				ArrowLeft:  1,
				ArrowRight: 2,
				ArrowUp:    3,
				ArrowDown:  4,
				Space:      5,
			}[code];
		}
		const dv = new DataView(c.memory.buffer, scratch_page << 16);
		dv.setUint32(0, state, true);
		dv.setUint32(4, keycode, true);
		dv.setUint32(8, 1, true); // Key_Event
		c.game_handle_event(scratch_page << 16);
	}

	setEventHandlers({
		mousemove: (e) => {
			const rect = canvas.getBoundingClientRect();
			setVector2_u32(c.memory, linked[1], e.clientX - rect.left, e.clientY - rect.top);
		},
		keydown: (e) => { if (!e.repeat) onKeyEvent(1, e.code) },
		keyup:   (e) => onKeyEvent(0, e.code),
	})

	await resolveAll(bindingManager.pools[GPUBindGroup]);
	state = 0;

	let lastTime = performance.now();
	function main_loop(currTime) {
		const dt = (currTime - lastTime) / 1000;
		lastTime = currTime;
		encoder = device.createCommandEncoder();
		renderPass = encoder.beginRenderPass({
			colorAttachments: [{
				view: context.getCurrentTexture().createView(),
				clearValue: { r: 0, g: 0, b: 0, a: 1.0 },
				loadOp: "clear",
				storeOp: "store"
			}]
		});
		if (state & 1) {
			const dv = new DataView(c.memory.buffer, linked[0]);
			dv.setUint32(0, canvas.width, true);
			dv.setUint32(4, canvas.height, true);
		}
		c.game_loop(dt, state);
		renderPass.end();
		device.queue.submit([encoder.finish()]);
		state = 0;
		requestAnimationFrame(main_loop);
	}
	requestAnimationFrame(main_loop);
});