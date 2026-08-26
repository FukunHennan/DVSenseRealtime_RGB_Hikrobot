classdef (Abstract) CameraSource < handle
    methods (Abstract)
        open(obj)
        tf = hasData(obj)
        packet = read(obj)
        frame = readDisplayFrame(obj)
        close(obj)
    end
end
