classdef SessionRecorder < handle
    properties (Access=private)
        Config struct
        SessionDir string
        FileId double = -1
        Buffer double = zeros(256,9)
        BufferCount double = 0
        Opened logical = false
    end
    methods
        function obj=SessionRecorder(cfg), obj.Config=cfg; end
        function open(obj)
            if ~obj.Config.recording.enabled, return; end
            stamp=string(datetime("now","Format","yyyyMMdd_HHmmss"));
            obj.SessionDir=fullfile(obj.Config.paths.outputRoot,"session_"+stamp);
            mkdir(obj.SessionDir);
            if obj.Config.recording.saveTracking
                file=fullfile(obj.SessionDir,"tracking.csv");
                obj.FileId=fopen(file,"wt");
                if obj.FileId<0
                    error("DVSense:记录文件","无法创建跟踪记录文件：%s",file);
                end
                fprintf(obj.FileId, ...
                    "sequence,timestampUs,x,y,vx,vy,confidence,latencyUs,eventCount\n");
            end
            obj.Opened=true;
        end
        function write(obj,packet,track,stats)
            if ~obj.Opened || obj.FileId<0, return; end
            obj.BufferCount=obj.BufferCount+1;
            obj.Buffer(obj.BufferCount,:)=[double(packet.sequence), ...
                double(track.timestampUs),track.position(1),track.position(2), ...
                track.velocity(1),track.velocity(2),track.confidence, ...
                stats.latencyUs,stats.eventCount];
            if obj.BufferCount==size(obj.Buffer,1)
                obj.flushBuffer();
            end
        end
        function close(obj)
            if ~obj.Opened, return; end
            obj.flushBuffer();
            if obj.FileId>=0
                fclose(obj.FileId);
                obj.FileId=-1;
            end
            obj.Opened=false;
        end
        function delete(obj)
            try, obj.close(); catch, end
        end
    end
    methods (Access=private)
        function flushBuffer(obj)
            if obj.FileId<0 || obj.BufferCount==0, return; end
            rows=obj.Buffer(1:obj.BufferCount,:).';
            fprintf(obj.FileId,"%.0f,%.0f,%.9g,%.9g,%.9g,%.9g,%.9g,%.9g,%.0f\n",rows);
            obj.BufferCount=0;
        end
    end
end
