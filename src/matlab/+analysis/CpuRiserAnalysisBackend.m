classdef CpuRiserAnalysisBackend < handle
    properties (SetAccess=private)
        Name string = "cpu"
    end
    properties (Access=private)
        Pipeline
    end
    methods
        function obj = CpuRiserAnalysisBackend(config)
            obj.Pipeline = analysis.RiserAnalysisPipeline(config);
        end
        function result = process(obj,packet)
            result = obj.Pipeline.process(packet);
        end
        function reset(obj)
            obj.Pipeline.reset();
        end
        function value=status(~)
            value=struct("requested","cpu","executed","cpu", ...
                "fallback",false,"reason","");
        end
    end
end
