function tests = testConfigurationLoading
tests = functiontests(localfunctions);
end

function testLoadsDefaultsProfileAndExpandedPaths(testCase)
projectRoot = tempname;
cleanup = onCleanup(@()cleanupDirectory(projectRoot)); %#ok<NASGU>
createFixture(projectRoot);

cfg = app.loadConfiguration(projectRoot);

verifyEqual(testCase,string(cfg.paths.projectRoot),string(projectRoot));
verifyEqual(testCase,string(cfg.paths.runtimeRoot), ...
    string(fullfile(projectRoot,"runtime","bin")));
verifyEqual(testCase,string(cfg.paths.mvsRoot), ...
    "C:\Program Files (x86)\MVS");
verifyEqual(testCase,string(cfg.paths.mvsRuntimeRoot), ...
    "C:\Program Files (x86)\Common Files\MVS\Runtime\Win64_x64");
verifyEqual(testCase,string(cfg.fusion.calibrationFile), ...
    string(fullfile(projectRoot,"calibration","fusion_result.json")));
verifyEqual(testCase,string(cfg.camera.event.lens.model), ...
    "3MP-HD CCTV LENS 6MM IR");
verifyEqual(testCase,double(cfg.fusion.outputSize),[1280 720]);
end

function testNormalizesInfiniteRuntimeDurationForApplicationLoop(testCase)
projectRoot = tempname;
cleanup = onCleanup(@()cleanupDirectory(projectRoot)); %#ok<NASGU>
createFixture(projectRoot);
defaults = jsondecode(fileread(fullfile(projectRoot,"config","default.json")));
defaults.runtime = struct("durationSeconds","Inf");
writeJson(fullfile(projectRoot,"config","default.json"),defaults);

cfg = app.loadConfiguration(projectRoot);

verifyClass(testCase,cfg.runtime.durationSeconds,"double");
verifyEqual(testCase,cfg.runtime.durationSeconds,Inf);
end

function testLocalOverridesAreAppliedAfterCameraProfile(testCase)
projectRoot = tempname;
cleanup = onCleanup(@()cleanupDirectory(projectRoot)); %#ok<NASGU>
createFixture(projectRoot);

writeJson(fullfile(projectRoot,"config","local.json"),struct( ...
    "camera",struct( ...
        "event",struct("serial","DVSYNC-LOCAL"), ...
        "rgb",struct("serial","HIK-LOCAL")), ...
    "paths",struct("mvsRuntimeRoot", ...
        "${PROJECT_ROOT}/mvs-runtime")));
mkdir(fullfile(projectRoot,"mvs-runtime"));

cfg = app.loadConfiguration(projectRoot);

verifyEqual(testCase,string(cfg.camera.event.serial),"DVSYNC-LOCAL");
verifyEqual(testCase,string(cfg.camera.rgb.serial),"HIK-LOCAL");
verifyEqual(testCase,string(cfg.paths.mvsRuntimeRoot), ...
    string(fullfile(projectRoot,"mvs-runtime")));
end

function testRejectsUnsupportedConfigurationVersion(testCase)
projectRoot = tempname;
cleanup = onCleanup(@()cleanupDirectory(projectRoot)); %#ok<NASGU>
createFixture(projectRoot);
writeJson(fullfile(projectRoot,"config","default.json"), ...
    struct("configVersion",99));

verifyError(testCase,@()app.loadConfiguration(projectRoot), ...
    "DVSense:ConfigVersion");
end

function testRejectsMissingCalibrationFile(testCase)
projectRoot = tempname;
cleanup = onCleanup(@()cleanupDirectory(projectRoot)); %#ok<NASGU>
createFixture(projectRoot);
writeJson(fullfile(projectRoot,"config","default.json"), ...
    struct("configVersion",1,"fusion", ...
    struct("calibrationFile","${PROJECT_ROOT}/calibration/missing.json")));

verifyError(testCase,@()app.loadConfiguration(projectRoot), ...
    "DVSense:Calibration");
end

function testAllowsMissingCalibrationFileWhenFusionCalibrationIsDisabled(testCase)
projectRoot = tempname;
cleanup = onCleanup(@()cleanupDirectory(projectRoot)); %#ok<NASGU>
createFixture(projectRoot);
writeJson(fullfile(projectRoot,"config","default.json"), ...
    struct("configVersion",1,"fusion",struct( ...
    "calibrationEnabled",false, ...
    "calibrationFile","${PROJECT_ROOT}/calibration/missing.json")));

cfg = app.loadConfiguration(projectRoot);

verifyFalse(testCase,cfg.fusion.calibrationEnabled);
verifyEqual(testCase,string(cfg.fusion.calibrationFile), ...
    string(fullfile(projectRoot,"calibration","missing.json")));
end

function testRejectsInvalidFusionOutputSize(testCase)
projectRoot = tempname;
cleanup = onCleanup(@()cleanupDirectory(projectRoot)); %#ok<NASGU>
createFixture(projectRoot);
writeJson(fullfile(projectRoot,"config","default.json"), ...
    struct("configVersion",1,"fusion", ...
    struct("outputWidth",0,"outputHeight",720)));

verifyError(testCase,@()app.loadConfiguration(projectRoot), ...
    "DVSense:ConfigOutputSize");
end

function createFixture(projectRoot)
mkdir(fullfile(projectRoot,"config"));
mkdir(fullfile(projectRoot,"runtime","bin"));
mkdir(fullfile(projectRoot,"calibration"));
mkdir(fullfile(projectRoot,"sdk"));
mkdir(fullfile(projectRoot,"mvs"));
touch(fullfile(projectRoot,"calibration","fusion_result.json"));

defaultConfig = struct( ...
    "configVersion",1, ...
    "source",struct("mode","live","windowUs",1000), ...
    "paths",struct( ...
        "runtimeRoot","${PROJECT_ROOT}/runtime/bin", ...
        "sdkRoot","${PROJECT_ROOT}/sdk", ...
        "mvsRoot","C:/Program Files (x86)/MVS", ...
        "mvsRuntimeRoot", ...
            "C:/Program Files (x86)/Common Files/MVS/Runtime/Win64_x64", ...
        "calibrationFile","${PROJECT_ROOT}/calibration/fusion_result.json"), ...
    "fusion",struct( ...
        "rgbFps",30, ...
        "outputWidth",1280, ...
        "outputHeight",720, ...
        "calibrationEnabled",true));
writeJson(fullfile(projectRoot,"config","default.json"),defaultConfig);

profile = struct( ...
    "camera",struct( ...
        "event",struct("product","DVSLume","serial","", ...
            "lens",struct("model","3MP-HD CCTV LENS 6MM IR")), ...
        "rgb",struct("model","MV-CU050-90UC","serial","", ...
            "lens",struct("model","HN-1228-CM-C2/3B 12MM 1:2.8 2/3"))), ...
    "trigger",struct("mode","hardware","syncBox",true));
writeJson(fullfile(projectRoot,"config","camera-profile.json"),profile);
end

function writeJson(filePath,value)
fileId = fopen(filePath,"w");
assert(fileId >= 0,"Unable to create fixture: %s",filePath);
cleanup = onCleanup(@()fclose(fileId)); %#ok<NASGU>
fwrite(fileId,jsonencode(value),"char");
end

function touch(filePath)
fileId = fopen(filePath,"w");
assert(fileId >= 0,"Unable to create fixture: %s",filePath);
fclose(fileId);
end

function cleanupDirectory(directory)
if isfolder(directory)
    rmdir(directory,"s");
end
end
