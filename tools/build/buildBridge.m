function buildBridge(sdkRoot)
arguments
    sdkRoot (1,1) string = "C:\Program Files (x86)\DvsenseDriver"
end

projectRoot=fileparts(fileparts(fileparts(mfilename("fullpath"))));
runtimeDir=fullfile(projectRoot,"runtime","bin");
objDir=fullfile(projectRoot,"artifacts","build","obj");
if ~isfolder(runtimeDir), mkdir(runtimeDir); end
if ~isfolder(objDir), mkdir(objDir); end

compiler=mex.getCompilerConfigurations("C++","Selected");
shell=compiler.Details.CommandLineShell;
shellArg=compiler.Details.CommandLineShellArg;
source=fullfile(projectRoot,"src","native","bridge","dvsense_bridge.cpp");
output=fullfile(runtimeDir,"dvsense_bridge.dll");
object=fullfile(objDir,"dvsense_bridge.obj");
command=sprintf(['call "%s" %s >nul && cl /nologo /LD /EHsc /std:c++17 ' ...
    '/utf-8 /O2 /MD /Fo"%s" "%s" /Fe:"%s"'],shell,shellArg,object,source,output);
status=system(command);
assert(status==0,"Failed to build DVSense bridge DLL.");
for artifact=["dvsense_bridge.exp","dvsense_bridge.lib"]
    artifactPath=fullfile(runtimeDir,artifact);
    if isfile(artifactPath), delete(artifactPath); end
end

helperSource=fullfile(projectRoot,"artifacts","build","mex","dvsense_helper.exe");
buildMex(sdkRoot);
copyfile(helperSource,fullfile(runtimeDir,"dvsense_helper.exe"),"f");
runtimeFiles=app.dvsenseRuntimeFiles();
for index=1:numel(runtimeFiles)
    sourceFile=fullfile(sdkRoot,"bin",runtimeFiles(index));
    assert(isfile(sourceFile),"Required runtime DLL missing: %s",sourceFile);
    copyfile(sourceFile,fullfile(runtimeDir,runtimeFiles(index)),"f");
end

buildBridgePrototype();
end
