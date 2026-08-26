function buildMex(sdkRoot)
arguments
    sdkRoot (1,1) string = "C:\Program Files (x86)\DvsenseDriver"
end
projectRoot=fileparts(fileparts(fileparts(mfilename("fullpath"))));
headers=dir(fullfile(sdkRoot,"**","DvsCameraManager.hpp"));
assert(~isempty(headers),"DvsCameraManager.hpp not found below %s",sdkRoot);
libs=["DvsenseBase.lib","DvsenseHal.lib","DvsenseDriver.lib"];
libraryFiles=fullfile(sdkRoot,"lib",libs);
assert(all(isfile(libraryFiles)),"DVSense import libraries not found below %s",sdkRoot);
includeDir=headers(1).folder;
sdkIncludeDir=fullfile(sdkRoot,"include");
outDir=fullfile(projectRoot,"artifacts","build","mex");
objDir=fullfile(projectRoot,"artifacts","build","obj");
if ~isfolder(outDir), mkdir(outDir); end
if ~isfolder(objDir), mkdir(objDir); end
fprintf("Include: %s\nInclude root: %s\nLibraries:\n  %s\n", ...
    includeDir,sdkIncludeDir,strjoin(libraryFiles,newline+"  "));

compiler=mex.getCompilerConfigurations("C++","Selected");
shell=compiler.Details.CommandLineShell;
shellArg=compiler.Details.CommandLineShellArg;
helperSource=fullfile(projectRoot,"src","native","src","dvsense_helper.cpp");
helperExe=fullfile(outDir,"dvsense_helper.exe");
helperObject=fullfile(objDir,"dvsense_helper.obj");
helperCommand=sprintf(['call "%s" %s >nul && cl /nologo /EHsc ' ...
    '/std:c++17 /utf-8 /O2 /MD /I"%s" /Fo"%s" "%s" /Fe:"%s" /link ' ...
    '/LIBPATH:"%s" %s'],shell,shellArg,sdkIncludeDir,helperObject,helperSource, ...
    helperExe,fullfile(sdkRoot,"lib"),strjoin(libs," "));
status=system(helperCommand);
assert(status==0,"Failed to build DVSense helper executable.");

runtimeFiles=app.dvsenseRuntimeFiles();
for runtimeIndex=1:numel(runtimeFiles)
    runtimeFile=runtimeFiles(runtimeIndex);
    source=fullfile(sdkRoot,"bin",runtimeFile);
    assert(isfile(source),"Required DVSense runtime DLL not found: %s",source);
    copyfile(source,fullfile(outDir,runtimeFile),"f");
end

args=[ ...
    "-R2018a","-v","COMPFLAGS=$COMPFLAGS /std:c++17 /utf-8 /EHsc", ...
    fullfile(projectRoot,"src","native","src","dvsense_mex.cpp"), ...
    "-output",fullfile(outDir,"dvsense_mex")];
mex(args{:});
intermediateFiles=[fullfile(outDir,"dvsense_helper.lib"), ...
    fullfile(outDir,"dvsense_helper.exp"),fullfile(outDir,"dvsense_mex.pdb")];
for file=intermediateFiles
    if isfile(file), delete(file); end
end
end
