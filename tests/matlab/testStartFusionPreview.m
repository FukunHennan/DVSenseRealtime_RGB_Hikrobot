function tests = testStartFusionPreview
tests = functiontests(localfunctions);
end

function testBuildsNativeFusionLaunchCommandWithoutStartingProcess(testCase)
projectRoot = fileparts(fileparts(fileparts(mfilename("fullpath"))));
addpath(projectRoot);
cleanup = onCleanup(@()rmpath(projectRoot)); %#ok<NASGU>

launch = startFusionPreview("", false);
expectedDirectory = fullfile(projectRoot, ...
    "artifacts", "build", "native-fusion-smoke", "bin", "Release");
expectedExecutable = fullfile(expectedDirectory, ...
    "three_view_fusion_preview.exe");
expectedCalibration = fullfile(expectedDirectory, "calibration_result.json");

verifyEqual(testCase, string(launch.workingDirectory), string(expectedDirectory));
verifyEqual(testCase, string(launch.executable), string(expectedExecutable));
verifyEqual(testCase, string(launch.calibrationFile), string(expectedCalibration));
verifyTrue(testCase, contains(string(launch.command), ...
    "three_view_fusion_preview.exe"));
verifyTrue(testCase, contains(string(launch.command), ...
    "calibration_result.json"));
end
