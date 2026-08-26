function motion = estimateMotionState(centerline,timestampUs,previous,config)
% Estimate centroid motion from the previous valid frame.
arguments
    centerline (:,2) double
    timestampUs (1,1) uint64
    previous struct
    config struct
end
motion = struct("position",[NaN;NaN],"velocity",[NaN;NaN],"acceleration",[NaN;NaN],"state","invalid");
if isempty(centerline), return; end
position = mean(centerline,1).'; motion.position = position;
if ~isfield(previous,"valid") || ~previous.valid
    motion.velocity = [0;0]; motion.acceleration = [0;0]; motion.state = "stable"; return;
end
dt = double(timestampUs - previous.timestampUs) * 1e-6;
if dt <= 0, return; end
velocity = (position - previous.position) ./ dt;
acceleration = (velocity - previous.velocity) ./ dt;
motion.velocity = velocity; motion.acceleration = acceleration;
threshold = 0.05;
if isfield(config,"motionThresholdPxPerS"), threshold = max(0,double(config.motionThresholdPxPerS)); end
if norm(velocity) > threshold, motion.state = "moving"; else, motion.state = "stable"; end
end
