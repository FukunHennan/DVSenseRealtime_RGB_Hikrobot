function tests = testCommandMailbox
tests = functiontests(localfunctions);
end

function testCoalescesDisplayAccumulationAndParameterWrites(testCase)
box = ui.internal.CommandMailbox(4);
box.push(struct("type","setDisplayAccumulationUs","value",20000));
box.push(struct("type","setDisplayAccumulationUs","value",30000));
box.push(struct("type","setToolParameter","tool","Biases", ...
    "name","bias_diff","value",1));
box.push(struct("type","setToolParameter","tool","Biases", ...
    "name","bias_diff","value",2));

commands = box.consume();

verifyEqual(testCase,numel(commands),2);
verifyEqual(testCase,commands{1}.value,30000);
verifyEqual(testCase,commands{2}.value,2);
end

function testProtectedCommandsAreNotDropped(testCase)
box = ui.internal.CommandMailbox(1);
box.push(struct("type","stop"));
verifyError(testCase,@()box.push(struct("type","start")), ...
    "DVSense:CommandMailboxFull");
end

