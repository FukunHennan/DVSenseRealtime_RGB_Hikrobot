function tests=testToolParameterValidation
tests=functiontests(localfunctions);
end

function testReadbackUpdatesOnlyMatchingCachedParameter(testCase)
parameters=struct( ...
    "tool",{"Bias","Bias"}, ...
    "name",{"bias_diff_on","bias_diff_off"}, ...
    "current",{"20","30"});

updated=camera.applyToolParameterReadback( ...
    parameters,"Bias","bias_diff_on","42");

verifyEqual(testCase,string(updated(1).current),"42");
verifyEqual(testCase,string(updated(2).current),"30");
end

function testReadbackRequiresExactlyOneMatch(testCase)
parameters=struct("tool","Bias","name","bias_diff_on","current","20");

verifyError(testCase,@()camera.applyToolParameterReadback( ...
    parameters,"Bias","missing","1"),"DVSense:ParameterNotFound");
end

function testIntegerParameterRejectsOutOfRangeValue(testCase)
parameter=struct("type","INT","min",0,"max",100);
verifyError(testCase,@()camera.validateToolParameter(parameter,101), ...
    "DVSense:ParameterOutOfRange");
end

function testFloatParameterRejectsOutOfRangeValue(testCase)
parameter=struct("type","FLOAT","min",0.1,"max",1.5);
verifyError(testCase,@()camera.validateToolParameter(parameter,0), ...
    "DVSense:ParameterOutOfRange");
end

function testEnumParameterAcceptsOnlyOfficialOption(testCase)
parameter=struct("type","ENUM","options",["MASTER","SLAVE"]);
verifyEqual(testCase, ...
    camera.validateToolParameter(parameter,"SLAVE"),"SLAVE");
verifyError(testCase, ...
    @()camera.validateToolParameter(parameter,"AUTO"), ...
    "DVSense:InvalidParameterOption");
end

function testBoolParameterRequiresLogicalOrCanonicalText(testCase)
parameter=struct("type","BOOL");
verifyEqual(testCase,camera.validateToolParameter(parameter,true),true);
verifyEqual(testCase,camera.validateToolParameter(parameter,"false"),false);
verifyError(testCase, ...
    @()camera.validateToolParameter(parameter,"yes"), ...
    "DVSense:InvalidParameterValue");
end

function testStringMetadataLimitsAreParsed(testCase)
parameter=struct("type","INT","min","-25","max","23","options",{{}});
verifyEqual(testCase,camera.validateToolParameter(parameter,0),0);
end

function testToolParameterTextConversionReturnsCharVectors(testCase)
verifyEqual(testCase,camera.formatToolParameterValue(true,"BOOL"),'true');
verifyEqual(testCase,camera.formatToolParameterValue(12,"INT"),'12');
verifyEqual(testCase,camera.formatToolParameterValue("SLAVE","ENUM"),'SLAVE');
end

function testBundledDefaultPresetEnablesEventTrailFilter(testCase)
projectRoot=fileparts(fileparts(fileparts(mfilename("fullpath"))));
defaults=jsondecode(fileread(fullfile(projectRoot,"config", ...
    "dvsense_default_parameters.json")));

verifyTrue(testCase,defaults.EventTrailFilter.enable, ...
    "默认预设必须开启硬件事件拖尾过滤，避免识别窗口优先抓到运动残影。");
verifyEqual(testCase,string(defaults.EventTrailFilter.type),"TRAIL");
end
