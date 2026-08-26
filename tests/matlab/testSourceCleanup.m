function tests=testSourceCleanup
tests=functiontests(localfunctions);
end

function testCloseAttemptsVendorCloseAfterStopFails(testCase)
stopCalled=false;
closeCalled=false;
stopAction=@stopWithFailure;
closeAction=@markClosed;

camera.closeCameraSession(stopAction,closeAction);

verifyTrue(testCase,stopCalled);
verifyTrue(testCase,closeCalled, ...
    "Vendor close must still run when vendor stop fails.");

    function stopWithFailure
        stopCalled=true;
        error("DVSense:testStopFailure","synthetic stop failure");
    end
    function markClosed
        closeCalled=true;
    end
end

