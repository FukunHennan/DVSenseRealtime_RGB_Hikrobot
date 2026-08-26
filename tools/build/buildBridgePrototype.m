function buildBridgePrototype
% Generate the MATLAB loadlibrary prototype during development builds.
projectRoot = fileparts(fileparts(fileparts(mfilename("fullpath"))));
runtimeLibrary = fullfile(projectRoot,"runtime","bin","dvsense_bridge.dll");
header = fullfile(projectRoot,"src","native","bridge","dvsense_bridge.h");
outputDirectory = fullfile(projectRoot,"src","matlab","+camera","+internal");
stagingDirectory = tempname;

assert(isfile(runtimeLibrary),"DVSense bridge DLL not found: %s",runtimeLibrary);
assert(isfile(header),"DVSense bridge header not found: %s",header);
if ~isfolder(outputDirectory)
    mkdir(outputDirectory);
end
mkdir(stagingDirectory);
oldDirectory = pwd;
cleanup = onCleanup(@()cd(oldDirectory)); %#ok<NASGU>

addpath(stagingDirectory,"-begin");
cd(stagingDirectory);
loadlibrary(runtimeLibrary,header, ...
    "mfilename","dvsenseBridgePrototype","alias","dvsense_bridge");
unloadlibrary("dvsense_bridge");

prototype = fullfile(stagingDirectory,"dvsenseBridgePrototype.m");
thunk = fullfile(stagingDirectory,"dvsense_bridge_thunk_pcwin64.dll");
assert(isfile(prototype),"MATLAB bridge prototype was not generated.");
assert(isfile(thunk),"MATLAB bridge thunk was not generated.");
copyfile(prototype,fullfile(outputDirectory,"dvsenseBridgePrototype.m"),"f");
copyfile(thunk,fullfile(outputDirectory,"dvsense_bridge_thunk_pcwin64.dll"),"f");
end
