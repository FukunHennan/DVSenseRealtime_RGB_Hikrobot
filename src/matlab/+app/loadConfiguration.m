function cfg = loadConfiguration(projectRoot)
arguments
    projectRoot (1,1) string
end

projectRoot = string(projectRoot);
if ~isfolder(projectRoot)
    error("DVSense:ConfigProjectRoot", ...
        "Project root does not exist: %s",projectRoot);
end

configDirectory = fullfile(projectRoot,"config");
defaultFile = fullfile(configDirectory,"default.json");
profileFile = fullfile(configDirectory,"camera-profile.json");
if ~isfile(defaultFile)
    error("DVSense:ConfigFile", ...
        "Default configuration is missing: %s",defaultFile);
end
if ~isfile(profileFile)
    error("DVSense:ConfigFile", ...
        "Camera profile is missing: %s",profileFile);
end

defaults = readJson(defaultFile);
validateVersion(defaults);
cfg = defaults;

cfg = mergeStructs(cfg,readJson(profileFile));
localFile = fullfile(configDirectory,"local.json");
if isfile(localFile)
    cfg = mergeStructs(cfg,readJson(localFile));
end

cfg.paths.projectRoot = projectRoot;
cfg = applyDefaults(cfg,projectRoot);
cfg = expandProjectTokens(cfg,projectRoot);
cfg = normalizeConfiguration(cfg,projectRoot);
validateConfiguration(cfg);
end

function value = readJson(filePath)
try
    value = jsondecode(fileread(filePath));
catch cause
    error("DVSense:ConfigFile", ...
        "Unable to read JSON configuration %s: %s",filePath,cause.message);
end
if ~isstruct(value) || numel(value) ~= 1
    error("DVSense:ConfigFile", ...
        "Configuration root must be one JSON object: %s",filePath);
end
end

function validateVersion(config)
if ~isfield(config,"configVersion") || double(config.configVersion) ~= 1
    error("DVSense:ConfigVersion", ...
        "Unsupported configuration version. Expected version 1.");
end
end

function result = mergeStructs(base,override)
result = base;
fields = fieldnames(override);
for index = 1:numel(fields)
    name = fields{index};
    incoming = override.(name);
    if isfield(result,name) && isstruct(result.(name)) && ...
            isstruct(incoming) && numel(result.(name)) == 1 && numel(incoming) == 1
        result.(name) = mergeStructs(result.(name),incoming);
    else
        result.(name) = incoming;
    end
end
end

function config = applyDefaults(config,projectRoot)
if ~isfield(config,"paths"), config.paths = struct(); end
if ~isfield(config.paths,"runtimeRoot")
    config.paths.runtimeRoot = fullfile(projectRoot,"runtime","bin");
end
if ~isfield(config.paths,"sdkRoot")
    config.paths.sdkRoot = "C:/Program Files (x86)/DvsenseDriver";
end
if ~isfield(config.paths,"mvsRoot")
    config.paths.mvsRoot = "C:/Program Files (x86)/MVS";
end
if ~isfield(config.paths,"mvsRuntimeRoot")
    config.paths.mvsRuntimeRoot = ...
        "C:/Program Files (x86)/Common Files/MVS/Runtime/Win64_x64";
end
if ~isfield(config.paths,"fusionSdkRoot")
    config.paths.fusionSdkRoot = fullfile(projectRoot,"vendor","dvsense-fusion-sdk");
end
if ~isfield(config.paths,"outputRoot")
    config.paths.outputRoot = fullfile(projectRoot,"artifacts","output");
end
if ~isfield(config.paths,"defaultParameterFile")
    config.paths.defaultParameterFile = fullfile(projectRoot,"config", ...
        "dvsense_default_parameters.json");
end
if ~isfield(config.paths,"calibrationFile") && isfield(config,"fusion") && ...
        isfield(config.fusion,"calibrationFile")
    config.paths.calibrationFile = config.fusion.calibrationFile;
end
if ~isfield(config,"fusion"), config.fusion = struct(); end
if ~isfield(config.fusion,"rgbFps"), config.fusion.rgbFps = 30; end
if ~isfield(config.fusion,"outputWidth"), config.fusion.outputWidth = 1280; end
if ~isfield(config.fusion,"outputHeight"), config.fusion.outputHeight = 720; end
if ~isfield(config.fusion,"calibrationEnabled")
    config.fusion.calibrationEnabled = true;
end
if ~isfield(config.fusion,"calibrationFile")
    config.fusion.calibrationFile = fullfile(projectRoot, ...
        "calibration","fusion_result.json");
end
end

function value = expandProjectTokens(value,projectRoot)
if isstruct(value)
    fields = fieldnames(value);
    for index = 1:numel(fields)
        name = fields{index};
        value.(name) = expandProjectTokens(value.(name),projectRoot);
    end
elseif ischar(value) || (isstring(value) && isscalar(value))
    value = string(value);
    value = replace(value,"${PROJECT_ROOT}",projectRoot);
elseif iscell(value)
    for index = 1:numel(value)
        value{index} = expandProjectTokens(value{index},projectRoot);
    end
end
end

function config = normalizeConfiguration(config,projectRoot)
config.paths.projectRoot = string(projectRoot);
config.paths.runtimeRoot = normalizePath(config.paths.runtimeRoot);
config.paths.sdkRoot = normalizePath(config.paths.sdkRoot);
config.paths.mvsRoot = normalizePath(config.paths.mvsRoot);
config.paths.mvsRuntimeRoot = normalizePath(config.paths.mvsRuntimeRoot);
config.paths.fusionSdkRoot = normalizePath(config.paths.fusionSdkRoot);
config.paths.outputRoot = normalizePath(config.paths.outputRoot);
config.paths.defaultParameterFile = normalizePath(config.paths.defaultParameterFile);
config.fusion.calibrationFile = normalizePath(config.fusion.calibrationFile);
config.fusion.outputSize = [ ...
    double(config.fusion.outputWidth),double(config.fusion.outputHeight)];

if ~isfield(config,"source"), config.source = struct(); end
if ~isfield(config.source,"mode"), config.source.mode = "live"; end
if ~isfield(config.source,"resolution")
    config.source.resolution = [720 1280];
end
if ~isfield(config.source,"windowUs"), config.source.windowUs = 1000; end
config.source.mode = string(config.source.mode);
config.source.resolution = double(config.source.resolution);
config.source.windowUs = uint64(config.source.windowUs);

if ~isfield(config,"camera"), config.camera = struct(); end
if isfield(config.camera,"event")
    config.camera.product = string(config.camera.event.product);
    config.camera.serial = string(config.camera.event.serial);
else
    if ~isfield(config.camera,"product"), config.camera.product = "DVSLume"; end
    if ~isfield(config.camera,"serial"), config.camera.serial = ""; end
end
if ~isfield(config.camera,"connection")
    config.camera.connection = struct();
end
if ~isfield(config.camera.connection,"warmupBatches")
    config.camera.connection.warmupBatches = 5;
end

if ~isfield(config,"recording"), config.recording = struct(); end
config.recording.rawDirectory = fullfile(config.paths.outputRoot,"recordings");

if ~isfield(config,"runtime"), config.runtime = struct(); end
if ~isfield(config.runtime,"durationSeconds")
    config.runtime.durationSeconds = Inf;
elseif ischar(config.runtime.durationSeconds) || ...
        (isstring(config.runtime.durationSeconds) && isscalar(config.runtime.durationSeconds))
    durationText = string(config.runtime.durationSeconds);
    if strcmpi(durationText,"Inf")
        config.runtime.durationSeconds = Inf;
    else
        config.runtime.durationSeconds = str2double(durationText);
    end
end
end

function value = normalizePath(value)
value = string(value);
value = replace(value,"/",filesep);
end

function validateConfiguration(config)
if ~isfield(config.fusion,"outputWidth") || ...
        ~isfield(config.fusion,"outputHeight") || ...
        any(~isfinite(config.fusion.outputSize)) || ...
        any(config.fusion.outputSize <= 0) || ...
        any(mod(config.fusion.outputSize,1) ~= 0)
    error("DVSense:ConfigOutputSize", ...
        "Fusion output size must contain positive integer dimensions.");
end
if ~isfolder(config.paths.sdkRoot)
    error("DVSense:ConfigSdkRoot", ...
        "DVSense SDK directory does not exist: %s",config.paths.sdkRoot);
end
if ~isfolder(config.paths.mvsRoot)
    error("DVSense:ConfigMvsRoot", ...
        "MVS directory does not exist: %s",config.paths.mvsRoot);
end
if config.fusion.calibrationEnabled && ~isfile(config.fusion.calibrationFile)
    error("DVSense:Calibration", ...
        "Fusion calibration file does not exist: %s", ...
        config.fusion.calibrationFile);
end
end
