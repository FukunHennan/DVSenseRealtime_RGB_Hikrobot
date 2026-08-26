classdef RiserBackendFactory
    methods (Static)
        function backend=create(cfg)
            requested=string(cfg.compute.backend);
            gpuOK=analysis.riser.gpuAvailable();
            if requested=="matlab-gpu" && ~gpuOK && ~cfg.compute.allowFallback
                error("DVSense:GPU","GPU识别后端不可用，且未允许CPU回退。");
            end
            if requested=="matlab-gpu" && gpuOK
                backend=analysis.GpuRiserAnalysisBackend(cfg);
                return
            end
            backend=analysis.CpuRiserAnalysisBackend(cfg);
        end
    end
end
