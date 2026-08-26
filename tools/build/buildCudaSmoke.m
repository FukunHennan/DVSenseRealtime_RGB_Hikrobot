function buildCudaSmoke
projectRoot=fileparts(fileparts(fileparts(mfilename("fullpath"))));
outDir=fullfile(projectRoot,"artifacts","build","mex");
if ~isfolder(outDir), mkdir(outDir); end
mexcuda("-v",fullfile(projectRoot,"src","native","cuda","gpu_smoke.cu"), ...
    "-output",fullfile(outDir,"gpu_smoke"));
x=gpuArray(single(1:4));
y=gpu_smoke(x);
assert(isequal(gather(y),single(2:2:8)),"CUDA smoke test returned a wrong result.");
fprintf("CUDA MEX smoke test passed.\n");
end
