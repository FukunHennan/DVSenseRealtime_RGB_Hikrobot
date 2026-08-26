function tests=testNativeProtocol
tests=functiontests(localfunctions);
end

function testBridgeDeclaresDisplayWindowCommand(testCase)
projectRoot=fileparts(fileparts(fileparts(mfilename("fullpath"))));
header=string(fileread(fullfile(projectRoot,"src","native","bridge", ...
    "dvsense_bridge.h")));
verifyNotEmpty(testCase,strfind(char(header),"dvsense_set_display_window"));
end

function testReadFrameLayout(testCase)
projectRoot=fileparts(fileparts(fileparts(mfilename("fullpath"))));
validationDir=fullfile(projectRoot,"artifacts","build","validation");
mexFile=fullfile(validationDir,"dvsense_mex_validate."+mexext);
helperFile=fullfile(validationDir,"dvsense_helper.exe");
assumeTrue(testCase,isfile(mexFile) && isfile(helperFile), ...
    "Native validation binaries have not been built.");

addpath(validationDir,"-begin");
pathCleanup=onCleanup(@()rmpath(validationDir)); %#ok<NASGU>
info=dvsense_mex_validate("open","");
mexCleanup=onCleanup(@()dvsense_mex_validate("close")); %#ok<NASGU>
verifyEqual(testCase,[info.height info.width],[720 1280]);
frame=dvsense_mex_validate("readframe");
verifySize(testCase,frame,[720 1280]);
verifyEqual(testCase,frame(1,1),uint8(2));
verifyEqual(testCase,frame(720,1280),uint8(3));
verifyEqual(testCase,frame(360,640),uint8(1));
dvsense_mex_validate("close");
clear mexCleanup
end

