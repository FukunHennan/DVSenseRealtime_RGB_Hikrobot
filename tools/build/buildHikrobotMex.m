function outputFile = buildHikrobotMex(mvsRoot)
arguments
    mvsRoot (1,1) string = "C:\Program Files (x86)\MVS"
end
projectRoot = fileparts(fileparts(fileparts(mfilename("fullpath"))));
includeDir = fullfile(mvsRoot,"Development","Includes");
libraryDir = fullfile(mvsRoot,"Development","Libraries","win64");
header = fullfile(includeDir,"MvCameraControl.h");
library = fullfile(libraryDir,"MvCameraControl.lib");
assert(isfile(header),"MVS header not found: %s",header);
assert(isfile(library),"MVS import library not found: %s",library);
outDir = fullfile(projectRoot,"runtime","bin");
if ~isfolder(outDir), mkdir(outDir); end
source = fullfile(projectRoot,"src","native","src","hikrobot_mex.cpp");
args = ["-R2018a","-v", ...
    "COMPFLAGS=$COMPFLAGS /std:c++17 /utf-8 /EHsc", ...
    "-I"+includeDir, source, library, ...
    "-output",fullfile(outDir,"hikrobot_mex")];
mex(args{:});
outputFile = fullfile(outDir,"hikrobot_mex."+mexext);
fprintf("Built Hikrobot MEX: %s\n",outputFile);
end
