classdef RecognitionWindow < handle
    properties (Access=private)
        TargetUs uint64
        MaxEvents double
        MinReadyEvents double
        X uint16
        Y uint16
        Polarity logical
        Timestamp uint64
        Count double = 0
        StartUs uint64 = uint64(0)
        EndUs uint64 = uint64(0)
        Resolution double = [NaN NaN]
        RoiOffset double = [0 0]
        Ready logical = false
    end
    methods
        function obj=RecognitionWindow(targetUs,maxEvents,minReadyEvents)
            arguments
                targetUs (1,1) {mustBeNumeric}
                maxEvents (1,1) {mustBeNumeric} = 250000
                minReadyEvents (1,1) {mustBeNumeric} = Inf
            end
            obj.TargetUs=uint64(targetUs);
            obj.MaxEvents=max(1,floor(double(maxEvents)));
            obj.MinReadyEvents=max(1,floor(double(minReadyEvents)));
            obj.X=zeros(obj.MaxEvents,1,"uint16");
            obj.Y=zeros(obj.MaxEvents,1,"uint16");
            obj.Polarity=false(obj.MaxEvents,1);
            obj.Timestamp=zeros(obj.MaxEvents,1,"uint64");
        end
        function add(obj,packet)
            if obj.Count==0
                obj.StartUs=packet.timeStartUs;
                obj.Resolution=packet.resolution;
                obj.RoiOffset=packet.roiOffset;
            end
            obj.EndUs=packet.timeEndUs;
            n=numel(packet.x);
            if n>0
                if obj.Count+n>obj.MaxEvents
                    % Keep the newest packet and bound display memory.
                    obj.Count=0;
                    obj.StartUs=packet.timeStartUs;
                end
                copyCount=min(n,obj.MaxEvents);
                sourceStart=n-copyCount+1;
                targetEnd=obj.Count+copyCount;
                targetStart=obj.Count+1;
                obj.X(targetStart:targetEnd)=packet.x(sourceStart:n);
                obj.Y(targetStart:targetEnd)=packet.y(sourceStart:n);
                obj.Polarity(targetStart:targetEnd)=packet.polarity(sourceStart:n);
                if numel(packet.timestamp)==n
                    obj.Timestamp(targetStart:targetEnd)=packet.timestamp(sourceStart:n);
                else
                    obj.Timestamp(targetStart:targetEnd)=packet.timeEndUs;
                end
                obj.Count=targetEnd;
            end
            durationReady = obj.EndUs>=obj.StartUs && ...
                (obj.EndUs-obj.StartUs>=obj.TargetUs);
            countReady = obj.Count>=obj.MinReadyEvents;
            obj.Ready=obj.Count>0 && (durationReady || countReady);
        end
        function tf=ready(obj), tf=obj.Ready; end
        function reset(obj)
            obj.Count=0;
            obj.StartUs=uint64(0);
            obj.EndUs=uint64(0);
            obj.Ready=false;
            obj.Resolution=[NaN NaN];
            obj.RoiOffset=[0 0];
        end
        function packet=take(obj)
            if obj.Count<=0
                error("DVSense:EmptyRecognitionWindow","没有可用于识别的事件。");
            end
            packet=struct("x",obj.X(1:obj.Count), ...
                "y",obj.Y(1:obj.Count), ...
                "polarity",obj.Polarity(1:obj.Count), ...
                "timestamp",obj.Timestamp(1:obj.Count), ...
                "resolution",obj.Resolution, ...
                "roiOffset",obj.RoiOffset, ...
                "timeStartUs",obj.StartUs, ...
                "timeEndUs",obj.EndUs);
            obj.reset();
        end
    end
end
