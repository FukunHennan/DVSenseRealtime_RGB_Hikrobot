function validateEnvironment(cfg)
arguments
    cfg struct
end

assert(~verLessThan("matlab","24.1"), "MATLAB R2024a or newer is recommended.");

if isfield(cfg.paths,"runtimeRoot")
    runtimeDirectory=cfg.paths.runtimeRoot;
else
    runtimeDirectory=fullfile(cfg.paths.projectRoot,"runtime","bin");
end
bridgeFile=fullfile(runtimeDirectory,"dvsense_bridge.dll");
if ~isfile(bridgeFile)
    error("DVSense:Bridge不存在", ...
        "尚未找到DVSense bridge DLL：%s。请执行tools/buildBridge。",bridgeFile);
end
helperFile = fullfile(runtimeDirectory,"dvsense_helper.exe");
if ~isfile(helperFile)
    error("DVSense:Helper不存在", ...
        "尚未找到DVSense隔离辅助进程：%s。请执行tools/buildBridge。",helperFile);
end
if ~isfolder(cfg.paths.sdkRoot)
    error("DVSense:SDK目录不存在","SDK目录不存在：%s",cfg.paths.sdkRoot);
end
sdkBin = fullfile(cfg.paths.sdkRoot,"bin");
if ~isfolder(sdkBin)
    error("DVSense:SDK运行库不存在","SDK运行库目录不存在：%s",sdkBin);
end
runtimeFiles=app.dvsenseRuntimeFiles();
missingRuntime=runtimeFiles(~isfile(fullfile(runtimeDirectory,runtimeFiles)));
if ~isempty(missingRuntime)
    error("DVSense:运行库不完整", ...
        "runtime旁缺少DVSense运行库：%s。请重新执行tools/buildBridge。", ...
        strjoin(missingRuntime,", "));
end
runtimeDirectoryFiles=dir(fullfile(runtimeDirectory,"*.dll"));
runtimeDirectoryNames=string({runtimeDirectoryFiles.name});
allowedRuntime=["dvsense_bridge.dll"; lower(runtimeFiles(:))];
unexpectedRuntime=runtimeDirectoryNames(~ismember(lower(runtimeDirectoryNames), ...
    allowedRuntime));
if ~isempty(unexpectedRuntime)
    error("DVSense:UnexpectedRuntimeFiles", ...
        "runtime目录包含未列入DVSense闭包的DLL：%s。请清理后重新执行tools/buildBridge。", ...
        strjoin(unexpectedRuntime,", "));
end

if any(cfg.compute.backend == ["matlab-gpu","auto"])
    hasPCT = license("test","Distrib_Computing_Toolbox");
    if ~hasPCT && ~cfg.compute.allowFallback
        error("DVSense:GPU", "Parallel Computing Toolbox is unavailable.");
    end
end

if ~isfolder(cfg.paths.outputRoot)
    mkdir(cfg.paths.outputRoot);
end
end
