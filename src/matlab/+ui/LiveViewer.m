classdef LiveViewer < handle
    properties (SetAccess = private)
        AdapterName string
    end
    properties (Access = private)
        Adapter
    end

    methods
        function obj = LiveViewer(cfg)
            obj.Adapter = ui.WorkbenchViewer(cfg);
            obj.AdapterName = "workbench";
        end

        function tf = isRunning(obj)
            tf = obj.Adapter.isRunning();
        end

        function varargout = selectCamera(obj,varargin)
            [varargout{1:nargout}] = obj.Adapter.selectCamera(varargin{:});
        end

        function varargout = resolveConnectionFailure(obj,varargin)
            [varargout{1:nargout}] = obj.Adapter.resolveConnectionFailure(varargin{:});
        end

        function setConnectionStatus(obj,varargin), obj.Adapter.setConnectionStatus(varargin{:}); end
        function setRgbConnectionStatus(obj,varargin), obj.Adapter.setRgbConnectionStatus(varargin{:}); end
        function setRgbCameraInfo(obj,varargin), obj.Adapter.setRgbCameraInfo(varargin{:}); end
        function setRgbRunningState(obj,varargin), obj.Adapter.setRgbRunningState(varargin{:}); end
        function setRgbExposureState(obj,varargin), obj.Adapter.setRgbExposureState(varargin{:}); end
        function updateRgb(obj,varargin), obj.Adapter.updateRgb(varargin{:}); end
        function varargout = selectRgbCamera(obj,varargin)
            [varargout{1:nargout}] = obj.Adapter.selectRgbCamera(varargin{:});
        end
        function setCameraInfo(obj,varargin), obj.Adapter.setCameraInfo(varargin{:}); end
        function update(obj,varargin), obj.Adapter.update(varargin{:}); end
        function setAnalysisResult(obj,varargin), obj.Adapter.setAnalysisResult(varargin{:}); end
        function setRecognitionStatus(obj,varargin), obj.Adapter.setRecognitionStatus(varargin{:}); end
        function resetProcessingView(obj,varargin), obj.Adapter.resetProcessingView(varargin{:}); end
        function setCommandError(obj,varargin), obj.Adapter.setCommandError(varargin{:}); end
        function pumpEvents(obj,varargin), obj.Adapter.pumpEvents(varargin{:}); end
        function setRecordingState(obj,varargin), obj.Adapter.setRecordingState(varargin{:}); end
        function setRunningState(obj,varargin), obj.Adapter.setRunningState(varargin{:}); end
        function setDisplayAccumulationUs(obj,varargin), obj.Adapter.setDisplayAccumulationUs(varargin{:}); end
        function setToolParameters(obj,varargin), obj.Adapter.setToolParameters(varargin{:}); end
        function setToolParameterState(obj,varargin), obj.Adapter.setToolParameterState(varargin{:}); end
        function beginROISelection(obj,varargin), obj.Adapter.beginROISelection(varargin{:}); end
        function showROI(obj,varargin), obj.Adapter.showROI(varargin{:}); end
        function clearROI(obj,varargin), obj.Adapter.clearROI(varargin{:}); end

        function handle = getImageHandle(obj)
            handle = obj.Adapter.getImageHandle();
        end

        function commands = consumeCommands(obj)
            commands = obj.Adapter.consumeCommands();
        end

        function delete(obj)
            if ~isempty(obj.Adapter)
                delete(obj.Adapter);
            end
        end
    end
end
