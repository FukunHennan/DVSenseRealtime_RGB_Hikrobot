classdef (Abstract) MeasurementBackend < handle
    properties (Abstract)
        Name string
    end
    properties
        Status string = ""
    end
    methods (Abstract)
        measurement = extractMeasurement(obj,packet,cfg)
        frame = render(obj,packet,cfg)
    end
end
