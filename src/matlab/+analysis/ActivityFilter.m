classdef ActivityFilter < handle
    properties (Access=private)
        EventStamp uint32 = zeros(0,0,"uint32")
        Resolution double = [0 0]
        Generation uint32 = uint32(0)
    end
    methods
        function output=apply(obj,packet,cfg)
            output=packet;
            if ~isfield(cfg,"processing") || ...
                    ~isfield(cfg.processing,"activityFilterEnabled") || ...
                    ~cfg.processing.activityFilterEnabled || isempty(packet.x)
                return
            end

            h=packet.resolution(1);
            w=packet.resolution(2);
            if any(obj.Resolution~=[h w])
                obj.EventStamp=zeros(h,w,"uint32");
                obj.Resolution=[h w];
            end
            obj.Generation=obj.Generation+1;
            if obj.Generation==0
                obj.EventStamp(:)=uint32(0);
                obj.Generation=uint32(1);
            end

            x=double(packet.x);
            y=double(packet.y);
            valid=x>=1 & x<=w & y>=1 & y<=h;
            validIndices=find(valid);
            if isempty(validIndices)
                output=obj.select(packet,false(size(packet.x)));
                return
            end

            pixelIndices=sub2ind([h w],y(valid),x(valid));
            obj.EventStamp(pixelIndices)=obj.Generation;
            xv=x(valid);
            yv=y(valid);
            support=zeros(size(pixelIndices),"uint8");
            for dx=-1:1
                for dy=-1:1
                    if dx==0 && dy==0, continue; end
                    neighborX=xv+dx;
                    neighborY=yv+dy;
                    neighborValid=neighborX>=1 & neighborX<=w & ...
                        neighborY>=1 & neighborY<=h;
                    if any(neighborValid)
                        neighborIndices=sub2ind([h w], ...
                            neighborY(neighborValid),neighborX(neighborValid));
                        support(neighborValid)=support(neighborValid)+ ...
                            uint8(obj.EventStamp(neighborIndices)==obj.Generation);
                    end
                end
            end

            minimumSupport=1;
            if isfield(cfg.processing,"minimumNeighborSupport")
                minimumSupport=max(1,min(8,round(cfg.processing.minimumNeighborSupport)));
            end
            keep=false(size(packet.x));
            keep(validIndices)=support>=minimumSupport;
            output=obj.select(packet,keep);
        end
    end
    methods (Static, Access=private)
        function output=select(packet,keep)
            output=packet;
            output.x=packet.x(keep);
            output.y=packet.y(keep);
            output.polarity=packet.polarity(keep);
            if numel(packet.timestamp)==numel(keep)
                output.timestamp=packet.timestamp(keep);
                if ~isempty(output.timestamp)
                    output.timeStartUs=min(output.timestamp);
                    output.timeEndUs=max(output.timestamp);
                end
            end
        end
    end
end
