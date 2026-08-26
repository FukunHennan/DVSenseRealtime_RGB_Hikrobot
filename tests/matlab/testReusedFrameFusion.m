function tests = testReusedFrameFusion
tests = functiontests(localfunctions);
end

function testWaitingStates(testCase)
cfg = testConfig();
renderer = fusion.FusionRenderer(cfg);
rgb = zeros(4,6,3,"uint8");
dvs = ones(4,6,"uint8");
result = renderer.render([],rgb);
verifyFalse(testCase,result.valid);
verifyEqual(testCase,string(result.status),"waiting-dvs");
result = renderer.render(dvs,[]);
verifyFalse(testCase,result.valid);
verifyEqual(testCase,string(result.status),"waiting-rgb");
end

function testIndexedEventsOverlayRgb(testCase)
cfg = testConfig();
renderer = fusion.FusionRenderer(cfg);
rgb = repmat(reshape(uint8([10 20 30]),1,1,3),4,6,1);
dvs = ones(4,6,"uint8");
dvs(2,3) = 2;
dvs(3,4) = 3;
result = renderer.render(dvs,rgb);
verifyTrue(testCase,result.valid);
verifyEqual(testCase,string(result.status),"ready");
verifyEqual(testCase,size(result.frame),[4 6 3]);
verifyEqual(testCase,squeeze(result.frame(2,3,:)),uint8([0;255;0]));
verifyEqual(testCase,squeeze(result.frame(3,4,:)),uint8([255;0;255]));
verifyEqual(testCase,squeeze(result.frame(1,1,:)),uint8([10;20;30]));
end

function testFusionRendererOwnsNoCameraSdk(testCase)
root = projectRoot();
source = fileread(fullfile(root,"src","matlab","+fusion","FusionRenderer.m"));
for forbidden = ["hikrobot_mex","DVSenseSession","HikrobotCameraSource", ...
        "readDisplayFrame","discover(","MV_CC_"]
    verifyEmpty(testCase,strfind(source,char(forbidden)), ...
        "FusionRenderer must not own or read camera resources.");
end
end

function testAppReadsEachPreviewSourceOnce(testCase)
root = projectRoot();
source = fileread(fullfile(root,"src","matlab","+app","run.m"));
verifyEqual(testCase,count(string(source),"rgbSrc.readDisplayFrame()"),1);
verifyEqual(testCase,count(string(source),"src.readDisplayFrame()"),1);
verifyNotEmpty(testCase,strfind(source,"latestRgbFrame = rgbFrame"));
verifyNotEmpty(testCase,strfind(source,"latestDvsFrame = frame"));
verifyNotEmpty(testCase,strfind(source,"fusionRenderer.render(latestDvsFrame,latestRgbFrame)"));
end

function testThirdFrameSurfaceExists(testCase)
root = projectRoot();
source = fileread(fullfile(root,"src","matlab","+ui","WorkbenchViewer.m"));
verifyNotEmpty(testCase,strfind(source,"FusionFramePanel"));
verifyNotEmpty(testCase,strfind(source,"FusionFrameSurface"));
verifyNotEmpty(testCase,strfind(source,"obj.FusionFrameSurface.update"));
end

function cfg = testConfig()
cfg = struct("fusion",struct("outputWidth",6,"outputHeight",4,"eventAlpha",1));
end

function root = projectRoot()
root = fileparts(fileparts(fileparts(mfilename("fullpath"))));
end
