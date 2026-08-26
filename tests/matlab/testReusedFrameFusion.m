function tests = testReusedFrameFusion
tests = functiontests(localfunctions);
end

function testThresholdZeroIsIdentity(testCase)
frame = uint8(randi([0 255],[8 9 3]));
verifyEqual(testCase,fusion.applyRgbThreshold(frame,0),frame);
end

function testThresholdUsesDefinedLuminance(testCase)
frame = zeros(1,2,3,"uint8");
frame(1,1,:) = uint8([100 100 100]);
frame(1,2,:) = uint8([200 0 0]);
result = fusion.applyRgbThreshold(frame,80);
verifyEqual(testCase,squeeze(result(1,1,:)),uint8([100;100;100]));
verifyEqual(testCase,squeeze(result(1,2,:)),uint8([0;0;0]));
end

function testThresholdClampsToByteRange(testCase)
frame = uint8(ones(2,2,3)*255);
verifyEqual(testCase,fusion.applyRgbThreshold(frame,-1),frame);
result = fusion.applyRgbThreshold(uint8(zeros(2,2,3)),300);
verifyEqual(testCase,result,uint8(zeros(2,2,3)));
end

function testRendererReportsMissingInputsTruthfully(testCase)
cfg = baseConfig(false,"");
renderer = fusion.FusionRenderer(cfg);
result = renderer.render([],uint8(zeros(720,1280,3)),struct());
verifyFalse(testCase,result.valid);
verifyEqual(testCase,string(result.status),"waiting-dvs");
result = renderer.render(ones(720,1280,"uint8"),[],struct());
verifyEqual(testCase,string(result.status),"waiting-rgb");
end

function testDisabledCalibrationDoesNotFakeFusion(testCase)
cfg = baseConfig(false,"");
renderer = fusion.FusionRenderer(cfg);
result = renderer.render(ones(720,1280,"uint8"), ...
    uint8(zeros(720,1280,3)),struct());
verifyFalse(testCase,result.valid);
verifyEqual(testCase,string(result.status),"calibration-error");
verifyFalse(testCase,result.calibrationValid);
end

function testIdentityCalibrationAndOverlay(testCase)
assumeTrue(testCase,exist("projective2d","class") == 8);
assumeTrue(testCase,exist("imwarp","file") == 2);
file = tempname + ".json";
cleanup = onCleanup(@()deleteIfExists(file)); %#ok<NASGU>
writelines('{"rgbToDvs":[[1,0,0],[0,1,0],[0,0,1]]}',file);
cfg = baseConfig(true,file);
renderer = fusion.FusionRenderer(cfg);
rgb = uint8(ones(720,1280,3)*40);
dvs = ones(720,1280,"uint8");
dvs(10,20) = 2;
dvs(11,21) = 3;
result = renderer.render(dvs,rgb,struct());
verifyTrue(testCase,result.valid);
verifyEqual(testCase,size(result.frame),[720 1280 3]);
verifyEqual(testCase,squeeze(result.frame(10,20,:)),uint8([0;255;0]));
verifyEqual(testCase,squeeze(result.frame(11,21,:)),uint8([255;0;255]));
end

function testUiThresholdCommands(testCase)
event = struct("version",1,"sequence",1,"type","setRgbThreshold", ...
    "payload",struct("value",123));
command = ui.internal.mapControlEvent(event,struct([]));
verifyEqual(testCase,string(command.type),"setRgbThreshold");
verifyEqual(testCase,command.value,123);
reset = struct("version",1,"sequence",2,"type","resetRgbThreshold", ...
    "payload",struct());
verifyEqual(testCase,string(ui.internal.mapControlEvent(reset,struct([])).type), ...
    "resetRgbThreshold");
end

function cfg = baseConfig(enabled,file)
cfg = struct();
cfg.fusion = struct("outputWidth",1280,"outputHeight",720, ...
    "calibrationEnabled",logical(enabled),"calibrationFile",string(file), ...
    "rgbThreshold",0);
end

function deleteIfExists(file)
if isfile(file), delete(file); end
end
