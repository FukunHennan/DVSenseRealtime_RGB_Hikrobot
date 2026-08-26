function tests = testDevelopmentPackaging
tests = functiontests(localfunctions);
end

function testDevelopmentPackageContainsSourceRuntimeAndTooling(testCase)
projectRoot = fileparts(fileparts(fileparts(mfilename("fullpath"))));
run(fullfile(projectRoot,"tools","dev","setupPath.m"));
outputRoot = tempname;
extractRoot = tempname;
mkdir(outputRoot);
mkdir(extractRoot);
cleanup = onCleanup(@()cleanupDirectories(outputRoot,extractRoot)); %#ok<NASGU>

packagePath = createDevelopmentPackage(outputRoot);
unzip(packagePath,extractRoot);
packageRoot = fullfile(extractRoot,"DVSenseRealtimeV1-dev");

verifyTrue(testCase,isfile(fullfile(packageRoot,"main.m")));
verifyTrue(testCase,isfile(fullfile(packageRoot,"startFusionPreview.m")));
verifyTrue(testCase,isfile(fullfile(packageRoot,"README.md")));
verifyTrue(testCase,isfile(fullfile(packageRoot,"CONTEXT.md")));
verifyTrue(testCase,isfile(fullfile(packageRoot,"VERSION")));
verifyTrue(testCase,isfile(fullfile(packageRoot,"启动开发版.bat")));
verifyTrue(testCase,isfile(fullfile(packageRoot,"启动运行版.bat")));
verifyTrue(testCase,isfolder(fullfile(packageRoot,"archive","versions", ...
    "2026-08-22_fusion-preview","legacy-event-workbench")));
verifyTrue(testCase,isfolder(fullfile(packageRoot,"src","matlab","+camera")));
verifyTrue(testCase,isfolder(fullfile(packageRoot,"src","native","bridge")));
verifyTrue(testCase,isfile(fullfile(packageRoot,"src","matlab","+camera", ...
    "+internal","dvsenseBridgePrototype.m")));
verifyTrue(testCase,isfile(fullfile(packageRoot,"src","matlab","+camera", ...
    "+internal","dvsense_bridge_thunk_pcwin64.dll")));
verifyTrue(testCase,isfile(fullfile(packageRoot,"runtime","bin", ...
    "dvsense_bridge.dll")));
verifyTrue(testCase,isfile(fullfile(packageRoot,"runtime","bin", ...
    "dvsense_helper.exe")));
verifyTrue(testCase,isfolder(fullfile(packageRoot,"tools","build")));
verifyTrue(testCase,isfolder(fullfile(packageRoot,"tools","package")));
verifyTrue(testCase,isfolder(fullfile(packageRoot,"tests","matlab")));
verifyTrue(testCase,isfolder(fullfile(packageRoot,"docs","architecture")));
verifyFalse(testCase,isfolder(fullfile(packageRoot,"artifacts")));
verifyFalse(testCase,isfile(fullfile(packageRoot,"dvsenseBridgePrototype.m")));
verifyFalse(testCase,isfile(fullfile(packageRoot,"frame_batch_test.obj")));
verifyEmpty(testCase,findBuildIntermediates(packageRoot), ...
    "开发包不能携带 .obj/.lib/.exp 编译中间文件。");
end

function files = findBuildIntermediates(packageRoot)
patterns = ["*.obj","*.lib","*.exp","*.pdb","*.ilk"];
files = strings(0,1);
for index = 1:numel(patterns)
    matches = dir(fullfile(packageRoot,"**",patterns(index)));
    files = [files; fullfile(string({matches.folder}),string({matches.name})).']; %#ok<AGROW>
end
end

function cleanupDirectories(varargin)
for index = 1:nargin
    folder = varargin{index};
    if isfolder(folder)
        rmdir(folder,"s");
    end
end
end
