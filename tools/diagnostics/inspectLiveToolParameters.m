function inspectLiveToolParameters
projectRoot = fileparts(fileparts(fileparts(mfilename("fullpath"))));
run(fullfile(projectRoot,"tools","dev","setupPath.m"));
layout = camera.RuntimeLayout(projectRoot);
cleanupPath = layout.addToPath(); %#ok<NASGU>

cfg.paths.runtimeRoot = layout.Root;
cfg.paths.sdkRoot = "C:\Program Files (x86)\DvsenseDriver";
cfg.source.live.batchEvents = 2500;
cfg.camera.serial = "";
cfg.camera.product = "DVSLume";
cfg.source.windowUs = uint64(1000);
cfg.roi.enabled = false;
cfg.roi.mode = "hardware";
cfg.roi.rectangle = [1 1 1280 720];
cfg.camera.connection.warmupBatches = 1;

source = camera.DVSenseCameraSource(cfg);
cleanupSource = onCleanup(@()delete(source)); %#ok<NASGU>
devices = source.discover();
serial = string(devices(1).serial);
fprintf("device=%s serial=%s\n",string(devices(1).product),serial);
source.open(serial);
parameters = source.getToolParameters();
for index = 1:numel(parameters)
    parameter = parameters(index);
    fprintf("%02d tool=%s name=%s type=%s current=%s class=%s\n", ...
        index,string(parameter.tool),string(parameter.name), ...
        string(parameter.type),string(parameter.current), ...
        class(parameter.current));
end
source.close();
end
