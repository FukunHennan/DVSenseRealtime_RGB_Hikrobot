function tests = testRuntimeLayout
tests = functiontests(localfunctions);
end

function testResolvesPrivateRuntimeFiles(testCase)
projectRoot = tempname;
runtimeRoot = fullfile(projectRoot, "runtime", "bin");
mkdir(runtimeRoot);
cleanup = onCleanup(@()cleanupDirectory(projectRoot)); %#ok<NASGU>

touch(fullfile(runtimeRoot, "dvsense_bridge.dll"));
touch(fullfile(runtimeRoot, "DVSenseCamera.dll"));

layout = camera.RuntimeLayout(projectRoot);

verifyEqual(testCase, layout.Root, string(runtimeRoot));
verifyEqual(testCase, layout.BridgeLibrary, string(fullfile(runtimeRoot, "dvsense_bridge.dll")));
verifyTrue(testCase, any(layout.VendorLibraries == ...
    string(fullfile(runtimeRoot, "DVSenseCamera.dll"))));
end

function testAddsRuntimePathAndRestoresIt(testCase)
projectRoot = tempname;
runtimeRoot = fullfile(projectRoot, "runtime", "bin");
mkdir(runtimeRoot);
cleanup = onCleanup(@()cleanupDirectory(projectRoot)); %#ok<NASGU>

layout = camera.RuntimeLayout(projectRoot);
originalPath = path;
pathCleanup = layout.addToPath();

verifyTrue(testCase, contains(string(path), string(runtimeRoot)));
clear pathCleanup
verifyEqual(testCase, string(path), string(originalPath));
end

function testBridgeBuildScriptRefreshesHelperFromSource(testCase)
root=fileparts(fileparts(fileparts(mfilename("fullpath"))));
source=fileread(fullfile(root,"tools","build","buildBridge.m"));
verifyTrue(testCase,contains(source,"buildMex(sdkRoot);"));
verifyFalse(testCase,contains(source,"if ~isfile(helperSource)"));
end

function touch(filePath)
fileId = fopen(filePath, "w");
assert(fileId >= 0, "Unable to create test fixture: %s", filePath);
fclose(fileId);
end

function cleanupDirectory(directory)
if isfolder(directory)
    rmdir(directory, "s");
end
end

