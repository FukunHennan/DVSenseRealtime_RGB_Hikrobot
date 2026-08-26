function packagePath = createDevelopmentPackage(outputRoot)
% Create a source-first development package with runtime dependencies.
if nargin < 1 || strlength(string(outputRoot)) == 0
    projectRoot = localProjectRoot();
    outputRoot = fullfile(projectRoot,"artifacts","packages");
else
    projectRoot = localProjectRoot();
    outputRoot = string(outputRoot);
end

if ~isfolder(outputRoot)
    mkdir(outputRoot);
end

packageName = "DVSenseRealtimeV1-dev";
stagingRoot = tempname;
packageRoot = fullfile(stagingRoot,packageName);
mkdir(packageRoot);
cleanup = onCleanup(@()localRemoveDirectory(stagingRoot)); %#ok<NASGU>

entries = [ ...
    "main.m"
    "startFusionPreview.m"
    "README.md"
    "VERSION"
    "CONTEXT.md"
    "启动开发版.bat"
    "启动运行版.bat"
    "archive"
    "src"
    "runtime"
    "config"
    "docs"
    "tests"
    "tools"];

for index = 1:numel(entries)
    source = fullfile(projectRoot,entries(index));
    if isfile(source) || isfolder(source)
        copyfile(source,fullfile(packageRoot,entries(index)),"f");
    end
end

prunePrototypeBuildArtifacts(packageRoot);
pruneBuildIntermediates(packageRoot);

packagePath = fullfile(outputRoot,packageName + ".zip");
if isfile(packagePath)
    delete(packagePath);
end
zip(packagePath,packageName,stagingRoot);
end

function projectRoot = localProjectRoot()
projectRoot = fileparts(fileparts(fileparts(mfilename("fullpath"))));
end

function localRemoveDirectory(folder)
if isfolder(folder)
    rmdir(folder,"s");
end
end

function prunePrototypeBuildArtifacts(packageRoot)
prototypeDirectory = fullfile(packageRoot,"src","matlab","+camera","+internal");
if ~isfolder(prototypeDirectory)
    return
end
allowed = ["dvsenseBridgePrototype.m";"dvsense_bridge_thunk_pcwin64.dll"];
files = dir(prototypeDirectory);
for index = 1:numel(files)
    if files(index).isdir
        continue
    end
    if ~ismember(string(files(index).name),allowed)
        delete(fullfile(prototypeDirectory,files(index).name));
    end
end
end

function pruneBuildIntermediates(packageRoot)
patterns = ["*.obj","*.lib","*.exp","*.pdb","*.ilk"];
for pattern = patterns
    files = dir(fullfile(packageRoot,"**",pattern));
    for index = 1:numel(files)
        if ~files(index).isdir
            delete(fullfile(files(index).folder,files(index).name));
        end
    end
end
end
