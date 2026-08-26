classdef MotionTracker < handle
    properties (SetAccess=private)
        Initialized logical = false
        State double = zeros(4,1)
        Covariance double = eye(4)
        LastTimestampUs uint64 = uint64(0)
    end
    properties (Access=private)
        Config struct
    end
    methods
        function obj=MotionTracker(cfg)
            obj.Config=cfg; obj.Covariance=eye(4)*cfg.initialCovariance;
        end
        function reset(obj)
            obj.Initialized=false;
            obj.State=zeros(4,1);
            obj.Covariance=eye(4)*obj.Config.initialCovariance;
            obj.LastTimestampUs=uint64(0);
        end
        function track=step(obj,m,timestampUs)
            if ~obj.Initialized
                if m.valid
                    obj.State=[m.position;0;0]; obj.Initialized=true;
                    obj.LastTimestampUs=timestampUs;
                end
                track=obj.output(m,timestampUs); return
            end
            dt=max(double(timestampUs-obj.LastTimestampUs)*1e-6,1e-6);
            F=[1 0 dt 0;0 1 0 dt;0 0 1 0;0 0 0 1];
            q=obj.Config.processNoise;
            G=[0.5*dt^2 0;0 0.5*dt^2;dt 0;0 dt];
            Q=G*(q*eye(2))*G';
            obj.State=F*obj.State; obj.Covariance=F*obj.Covariance*F'+Q;
            if m.valid
                H=[1 0 0 0;0 1 0 0]; R=obj.Config.measurementNoise*eye(2);
                innovation=m.position-H*obj.State;
                S=H*obj.Covariance*H'+R;
                K=(obj.Covariance*H')/S;
                obj.State=obj.State+K*innovation;
                obj.Covariance=(eye(4)-K*H)*obj.Covariance;
            end
            obj.LastTimestampUs=timestampUs;
            track=obj.output(m,timestampUs);
        end
    end
    methods (Access=private)
        function track=output(obj,m,timestampUs)
            track=struct("valid",obj.Initialized,"timestampUs",timestampUs, ...
                "position",obj.State(1:2),"velocity",obj.State(3:4), ...
                "boundingBox",m.boundingBox,"confidence",m.confidence);
        end
    end
end
