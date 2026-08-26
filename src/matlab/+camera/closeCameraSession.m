function closeCameraSession(stopAction,closeAction)
arguments
    stopAction (1,1) function_handle
    closeAction (1,1) function_handle
end

try, stopAction(); catch, end
try, closeAction(); catch, end
end
