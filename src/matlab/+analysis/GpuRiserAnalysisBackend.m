classdef GpuRiserAnalysisBackend < handle
    % GPU seam. The first implementation preserves the CPU algorithm and contract.
    properties (SetAccess=private)
        Name string = "matlab-gpu"
        BackendUsed string = "cpu"
    end
    properties (Access=private)
        CpuBackend
    end
    methods
        function obj = GpuRiserAnalysisBackend(config)
            obj.CpuBackend = analysis.CpuRiserAnalysisBackend(config);
        end
        function result = process(obj,packet)
            % Keep all result fields identical while GPU kernels are introduced.
            result = obj.CpuBackend.process(packet);
        end
        function reset(obj)
            obj.CpuBackend.reset();
        end
        function value=status(obj)
            value=struct("requested",obj.Name,"executed",obj.BackendUsed, ...
                "fallback",true, ...
                "reason","GPU riser kernels are not implemented; CPU fallback is active");
        end
    end
end
