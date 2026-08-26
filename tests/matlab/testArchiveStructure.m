function tests = testArchiveStructure
tests = functiontests(localfunctions);
end

function testArchiveVersionSnapshotContainsLegacyWorkbench(testCase)
projectRoot = fileparts(fileparts(fileparts(mfilename("fullpath"))));
versionRoot = fullfile(projectRoot,"archive","versions","2026-08-22_fusion-preview");
legacyRoot = fullfile(versionRoot,"legacy-event-workbench");

verifyTrue(testCase,isfile(fullfile(versionRoot,"README.md")));
verifyTrue(testCase,isfile(fullfile(legacyRoot,"README.md")));
verifyTrue(testCase,isfile(fullfile(legacyRoot,"DVSenseWorkbenchPreview.m")));
verifyTrue(testCase,isfile(fullfile(legacyRoot,"runDVSenseWorkbenchPreview.m")));
verifyTrue(testCase,isfile(fullfile(legacyRoot,"testManualWorkbenchPreview.m")));
end
