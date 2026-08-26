classdef MatlabGpuMeasurementBackend < analysis.MeasurementBackend
    % V1 validation backend. Measurement is computed on GPU; rendering is
    % gathered for MATLAB display. Replace with CUDA MEX without changing callers.
    properties
        Name string = "matlab-gpu"
    end
    methods
        function m = extractMeasurement(~,packet,cfg)
            n=numel(packet.x);
            m=struct("valid",false,"position",[NaN;NaN], ...
                "boundingBox",[NaN NaN NaN NaN],"confidence",0);
            if n < cfg.tracking.minimumEvents, return; end
            x=gpuArray(single(packet.x)); y=gpuArray(single(packet.y));
            values=gather([mean(x);mean(y);min(x);min(y);max(x);max(y)]);
            m.valid=true; m.position=double(values(1:2));
            m.boundingBox=double([values(3) values(4) ...
                values(5)-values(3)+1 values(6)-values(4)+1]);
            m.confidence=min(1,n/max(cfg.source.eventsPerWindow,1));
        end
        function frame = render(~,packet,cfg)
            % Display is intentionally outside the real-time path in later versions.
            cpu=analysis.CpuMeasurementBackend; frame=cpu.render(packet,cfg);
        end
    end
end
