classdef MeasurementBackendFactory
    methods (Static)
        function obj = create(cfg)
            requested = cfg.compute.backend;
            gpuOK = false;
            hasFallback = isfield(cfg.compute, "allowFallback") && cfg.compute.allowFallback;
            hasPCT = license("test", "Distrib_Computing_Toolbox");
            if any(requested == ["matlab-gpu", "auto"]) && hasPCT
                try, gpuOK = canUseGPU; catch, gpuOK = false; end
            end

            if requested == "matlab-gpu" && ~gpuOK && ~hasFallback
                error("DVSense:GPU", "GPU backend requested but unavailable.");
            end

            if any(requested == ["matlab-gpu", "auto"]) && gpuOK
                obj = analysis.MatlabGpuMeasurementBackend;
                obj.Status = "GPU backend active";
                return;
            end

            obj = analysis.CpuMeasurementBackend;
            if requested == "matlab-gpu"
                if ~hasPCT
                    reason = "Parallel Computing Toolbox unavailable";
                else
                    reason = "no usable GPU detected";
                end
                obj.Status = "CPU fallback: " + reason;
            elseif requested == "auto" && ~gpuOK
                obj.Status = "CPU fallback: GPU unavailable in auto mode";
            else
                obj.Status = "CPU backend active";
            end
        end
    end
end
