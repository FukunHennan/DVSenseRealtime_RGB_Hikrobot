projectRoot = fileparts(fileparts(fileparts(mfilename("fullpath"))));
matlabSourceRoot = fullfile(projectRoot,"src","matlab");
if isfolder(matlabSourceRoot)
    addpath(matlabSourceRoot,"-begin");
elseif isfolder(fullfile(projectRoot,"+app"))
    addpath(projectRoot,"-begin");
end

for toolFolder = ["build","dev","diagnostics","package"]
    folder = fullfile(projectRoot,"tools",toolFolder);
    if isfolder(folder)
        addpath(folder,"-end");
    end
end

runtimeBin = fullfile(projectRoot,"runtime","bin");
if isfolder(runtimeBin)
    addpath(runtimeBin,"-begin");
elseif isfolder(fullfile(projectRoot,"runtime"))
    addpath(fullfile(projectRoot,"runtime"),"-begin");
end
