function tests = testProjectStructure
tests = functiontests(localfunctions);
end

function testRootDirectoryOnlyContainsApprovedEntries(testCase)
projectRoot = fileparts(fileparts(fileparts(mfilename("fullpath"))));
entries = dir(projectRoot);
names = string({entries.name});
names = names(~ismember(names,[".",".."]));

approved = [ ...
    ".gitignore"
    "config"
    "docs"
    "runtime"
    "src"
    "tests"
    "tools"
    "main.m"
    "README.md"
    "VERSION"];

unexpected = setdiff(names,approved);
verifyEmpty(testCase,unexpected, ...
    "根目录只允许放入口、文档和一级功能目录；生成物必须放到 artifacts 或对应子目录。");
end

function testCameraInternalOnlyShipsRuntimePrototype(testCase)
projectRoot = fileparts(fileparts(fileparts(mfilename("fullpath"))));
internalDirectory = fullfile(projectRoot,"src","matlab","+camera","+internal");
entries = dir(internalDirectory);
names = string({entries.name});
names = names(~[entries.isdir]);

approved = ["dvsenseBridgePrototype.m","dvsense_bridge_thunk_pcwin64.dll"];
unexpected = setdiff(names,approved);
verifyEmpty(testCase,unexpected, ...
    "camera.internal 只保留 MATLAB 运行需要的 bridge 原型和 thunk DLL。");
end
