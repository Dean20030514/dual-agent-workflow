> This file extends [common/coding-style.md](../common/coding-style.md) and [cpp/coding-style.md](../cpp/coding-style.md) with CUDA-specific guidance.

# CUDA Coding Style

## Build System

- **Project varies**: check for `CMakeLists.txt`, `Makefile`, `setup.py` (with `nvcc` invocation), or direct `nvcc` shell scripts. Do not assume one over another.
- **CMake projects**: prefer `find_package(CUDAToolkit)` (modern, ≥ CMake 3.17) over the legacy `find_package(CUDA)`.
- **C++ standard**: follow the project's choice (`-std=c++17` is common; `-std=c++20` if the project enables it). Match the host compiler's standard with `nvcc -std=` exactly — mismatch causes ABI / template instantiation issues.
- **Architecture flags**: do not silently change `-arch=sm_XX` / `-gencode arch=...,code=...`. The project pins these for hardware compatibility; ask before adding or dropping a target.

## Memory & Resource Management

- **Prefer RAII over manual `cudaMalloc` / `cudaFree`**: wrap device pointers in a class with a destructor calling `cudaFree`, or use `thrust::device_vector` / `cuda::std::unique_ptr` (CUDA ≥ 11.7) when the project allows.
- **Always pair `cudaMalloc` with `cudaFree`** in the same scope or RAII owner. Leaks on the device are silent.
- **Pinned host memory**: use `cudaMallocHost` / `cudaFreeHost` for buffers transferred to/from device frequently; never `malloc` for that role.
- **Streams**: prefer non-default streams for any concurrency work; the default stream synchronizes globally with all other streams in legacy mode.

## Error Checking — Mandatory

- **Every CUDA API call must be checked.** Silent failure on the device is the #1 source of "works on my machine, fails in CI" CUDA bugs.
- Use a `CUDA_CHECK(call)` macro that captures `cudaGetLastError()` + `cudaGetErrorString(err)` + file + line. If the project has one, use it; if not, propose adding one before writing new CUDA code.
- After a kernel launch, **always** call `CUDA_CHECK(cudaGetLastError())` (catches launch-config errors) and — if the kernel's correctness is being asserted right after — `CUDA_CHECK(cudaDeviceSynchronize())`.

## Kernel Code

- **`__global__` functions**: name them as `kernelXxxx` or `xxxx_kernel` to make grep'ing kernels easy.
- **Launch config**: never hard-code `<<<1, 1024>>>` for production code. Compute grid / block from problem size; consider `cudaOccupancyMaxPotentialBlockSize` for adaptive sizing.
- **`__device__` helpers**: keep them small and `__forceinline__` only when measurably faster — over-inlining bloats register pressure.
- **Atomics**: avoid in inner loops; prefer warp-level primitives (`__shfl_*_sync`, `__ballot_sync`) where possible.
- **Shared memory**: declare with explicit size (`__shared__ float buf[BLOCK_SIZE]`) or via the dynamic third launch arg — never both.

## Helper Utilities — Check Before Writing Raw API

Before writing raw CUDA driver / runtime API calls, search the project for:

- Existing `cuda_utils.h` / `cuda_helpers.cuh` / similar
- `CUDA_CHECK` / `CUDA_TRY` / `CHECK_CUDA_ERROR` macros
- Wrapper classes for streams, events, device buffers
- Memory pool / allocator utilities

Reuse what exists. Adding a parallel helper system is a refactor that requires explicit approval.

## Performance Conventions

- **Profile, don't guess**: use Nsight Compute (`ncu`) for kernel-level analysis and Nsight Systems (`nsys`) for end-to-end timeline. Don't claim a speedup without before/after numbers from one of these.
- **Async by default**: prefer `cudaMemcpyAsync` + streams over synchronous `cudaMemcpy` once the host-side timing is non-trivial.
- **Avoid `cudaDeviceSynchronize` in hot paths** — it serializes all streams. Use stream-specific events instead.

## Testing

- **Unit tests for kernels**: launch with small known inputs, copy back, compare against CPU reference. CTest + GoogleTest is a common project pattern.
- **Determinism caveats**: floating-point reductions are not guaranteed deterministic across launches; use bit-exact comparison only when the kernel uses ordered reductions or `cub::DeviceReduce` with deterministic policy.
- **Multi-GPU**: if the project supports it, every test must explicitly set `cudaSetDevice` — never assume device 0.

## Anti-patterns

- ❌ Calling CUDA API without checking the return value
- ❌ Allocating device memory without an RAII owner
- ❌ Hard-coded `<<<1, 1024>>>` launch config in production
- ❌ `cudaDeviceSynchronize` sprinkled "to be safe"
- ❌ Mixing host pointers and device pointers in the same `void*` parameter without a clear convention
- ❌ Adding a new CUDA helper utility without first checking what the project already provides
