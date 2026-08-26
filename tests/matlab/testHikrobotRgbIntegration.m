function tests = testHikrobotRgbIntegration
tests = functiontests(localfunctions);
end

function testRgbBackendSourceExists(testCase)
root = projectRoot();
verifyTrue(testCase,isfile(fullfile(root,"src","matlab","+camera", ...
    "HikrobotCameraSource.m")));
verifyTrue(testCase,isfile(fullfile(root,"src","native","src", ...
    "hikrobot_mex.cpp")));
verifyTrue(testCase,isfile(fullfile(root,"tools","build", ...
    "buildHikrobotMex.m")));
end

function testUiProtocolMapsRgbCommands(testCase)
connect = struct("version",1,"sequence",1,"type","connectRgb","payload",struct);
disconnect = struct("version",1,"sequence",2,"type","disconnectRgb","payload",struct);
exposure = struct("version",1,"sequence",3,"type","setRgbExposureUs", ...
    "payload",struct("value",2800));
verifyEqual(testCase,string(ui.internal.mapControlEvent(connect,struct([])).type),"connectRgb");
verifyEqual(testCase,string(ui.internal.mapControlEvent(disconnect,struct([])).type),"disconnectRgb");
command = ui.internal.mapControlEvent(exposure,struct([]));
verifyEqual(testCase,string(command.type),"setRgbExposureUs");
verifyEqual(testCase,command.value,2800);
end

function testProductionUiEnablesRealRgbControls(testCase)
source = string(fileread(fullfile(projectRoot(),"src","matlab","+ui","assets","workbench.html")));
verifyNotEmpty(testCase,strfind(char(source),'id="connectRgb"'));
verifyNotEmpty(testCase,strfind(char(source),'id="disconnectRgb"'));
verifyNotEmpty(testCase,strfind(char(source),'id="rgbExposure"'));
verifyNotEmpty(testCase,strfind(char(source),"真实 MVS SDK 枚举"));
verifyEmpty(testCase,strfind(char(source),"RGB 后端未接入"));
end

function root = projectRoot()
root = fileparts(fileparts(fileparts(mfilename("fullpath"))));
end
