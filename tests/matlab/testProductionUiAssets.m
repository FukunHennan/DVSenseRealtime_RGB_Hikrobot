function tests = testProductionUiAssets
tests = functiontests(localfunctions);
end

function testSettingsUsesDataChangedInsteadOfPolling(testCase)
source = string(fileread(assetPath()));

verifyNotSubstring(testCase,source,"setInterval");
verifySubstring(testCase,source,"DataChanged");
verifySubstring(testCase,source,"parameterJson");
verifySubstring(testCase,source,"parameterSignature");
end

function testSettingsKeepsDomStableAndAnimatesCollapse(testCase)
source = string(fileread(assetPath()));

verifySubstring(testCase,source,"structureSignature");
verifySubstring(testCase,source,"maxHeight");
verifySubstring(testCase,source,"scrollHeight");
verifySubstring(testCase,source,"dataset.open");
verifyNotSubstring(testCase,source,'groups.innerHTML=""');
end

function testSettingsDebouncesNumericWrites(testCase)
source = string(fileread(assetPath()));

verifySubstring(testCase,source,"scheduleNumericCommit");
verifySubstring(testCase,source,"setTimeout");
verifySubstring(testCase,source,"onchange");
verifySubstring(testCase,source,"step");
end

function testSettingsExposesChineseDisplayAccumulationControl(testCase)
source = string(fileread(assetPath()));

verifySubstring(testCase,source,"显示与刷新");
verifySubstring(testCase,source,"事件累计时间");
verifySubstring(testCase,source,"setDisplayAccumulationUs");
verifySubstring(testCase,source,"displayAccumulationUs");
verifyNotSubstring(testCase,source,"画面刷新率");
verifyNotSubstring(testCase,source,"setRefreshHz");
verifyNotSubstring(testCase,source,"setBatchTimeUs");
verifyNotSubstring(testCase,source,"displayRefreshHz");
verifyNotSubstring(testCase,source,"batchTimeUs");
verifySubstring(testCase,source,"ms");
end

function testSettingsUsesChineseParameterDisplayNames(testCase)
source = string(fileread(assetPath()));

verifySubstring(testCase,source,"偏置参数");
verifySubstring(testCase,source,"事件拖尾过滤");
verifySubstring(testCase,source,"事件率控制");
verifySubstring(testCase,source,"ON事件阈值");
verifySubstring(testCase,source,"OFF事件阈值");
verifySubstring(testCase,source,"displayParameterName");
verifySubstring(testCase,source,"displayToolName");
end

function verifySubstring(testCase,source,needle)
verifyNotEmpty(testCase,strfind(char(source),char(needle)), ...
    "Expected settings asset to contain: "+string(needle));
end

function verifyNotSubstring(testCase,source,needle)
verifyEmpty(testCase,strfind(char(source),char(needle)), ...
    "Expected settings asset not to contain: "+string(needle));
end

function path = assetPath()
projectRoot = fileparts(fileparts(fileparts(mfilename("fullpath"))));
path = fullfile(projectRoot,"src","matlab","+ui","assets","settings.html");
end

