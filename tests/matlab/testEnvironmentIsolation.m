function tests=testEnvironmentIsolation
tests=functiontests(localfunctions);
end

function testValidationDoesNotModifyMatlabPath(testCase)
projectRoot=tempname;
sdkRoot=tempname;
mkdir(fullfile(projectRoot,"runtime","bin"));
mkdir(fullfile(sdkRoot,"bin"));
createRuntimeFixture(projectRoot);

directoryCleanup=onCleanup(@()cleanupDirectories(projectRoot,sdkRoot)); %#ok<NASGU>
originalPath=getenv("PATH");
pathCleanup=onCleanup(@()setenv("PATH",originalPath)); %#ok<NASGU>
setenv("PATH","C:\Windows\System32");

cfg=localConfig(projectRoot,sdkRoot);
app.validateEnvironment(cfg);

verifyEqual(testCase,string(getenv("PATH")),"C:\Windows\System32", ...
    "Validation must not inject vendor DLLs into the MATLAB process PATH.");
end

function testValidationRejectsUnexpectedVendorDll(testCase)
projectRoot=tempname;
sdkRoot=tempname;
mkdir(fullfile(projectRoot,"runtime","bin"));
mkdir(fullfile(sdkRoot,"bin"));
createRuntimeFixture(projectRoot);
touch(fullfile(projectRoot,"runtime","bin","Qt6Core.dll"));
directoryCleanup=onCleanup(@()cleanupDirectories(projectRoot,sdkRoot)); %#ok<NASGU>

cfg=localConfig(projectRoot,sdkRoot);
verifyError(testCase,@()app.validateEnvironment(cfg), ...
    "DVSense:UnexpectedRuntimeFiles");
end

function cfg=localConfig(projectRoot,sdkRoot)
cfg.paths.projectRoot=projectRoot;
cfg.paths.sdkRoot=sdkRoot;
cfg.paths.outputRoot=fullfile(projectRoot,"artifacts","output");
cfg.compute.backend="cpu";
cfg.compute.allowFallback=true;
end

function createRuntimeFixture(projectRoot)
runtimeRoot = fullfile(projectRoot,"runtime","bin");
touch(fullfile(runtimeRoot,"dvsense_bridge.dll"));
touch(fullfile(runtimeRoot,"dvsense_helper.exe"));
runtimeFiles=app.dvsenseRuntimeFiles();
for runtimeIndex=1:numel(runtimeFiles)
    touch(fullfile(runtimeRoot,runtimeFiles(runtimeIndex)));
end
end

function touch(path)
file=fopen(char(path),"w");
assert(file>=0,"Unable to create test file: %s",path);
fclose(file);
end

function cleanupDirectories(projectRoot,sdkRoot)
if isfolder(projectRoot), rmdir(projectRoot,"s"); end
if isfolder(sdkRoot), rmdir(sdkRoot,"s"); end
end

