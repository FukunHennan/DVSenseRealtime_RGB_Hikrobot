classdef CameraSourceFactory
    methods (Static)
        function obj = create(cfg)
            if cfg.source.mode ~= "live"
                error("DVSense:数据源","当前版本仅支持真实DVSLume相机。");
            end
            obj = camera.DVSenseCameraSource(cfg);
        end
    end
end
