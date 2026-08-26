# Development Package Layout Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Create a developer-focused project package that keeps source, runtime binaries, build scripts, and required MATLAB bridge assets together on a new machine.

**Architecture:** Keep the current source tree as the working tree, but define a second package shape for development handoff. The development package includes editable source, private runtime binaries, MATLAB bridge prototype files, and build/test tooling; it excludes generated build junk so the package can be moved without carrying transient objects.

**Tech Stack:** MATLAB R2024b, existing C++ bridge/helper binaries, MATLAB `loadlibrary` prototype files, ZIP packaging, MATLAB unit tests.

**Contract:** `tests/matlab/testDevelopmentPackaging.m` and
`tools/package/createDevelopmentPackage.m`

## Global Constraints

- Repository root stays limited to human entry points and first-level directories.
- `runtime/bin/` remains the only runtime DLL/EXE location.
- `src/matlab/+camera/+internal/` may keep only `dvsenseBridgePrototype.m` and `dvsense_bridge_thunk_pcwin64.dll`.
- Generated `.obj`, `.lib`, `.exp`, logs, recordings, and previews stay out of the development package root.
- Development packaging must work from MATLAB R2024b on Windows.

---

### Task 1: Lock the development package contract in tests

**Files:**
- Create: `tests/matlab/testDevelopmentPackaging.m`

**Interfaces:**
- Consumes: `tools/package/createDevelopmentPackage.m`
- Produces: an unzip-and-inspect test that verifies the development package contains source, runtime, tools, tests, and MATLAB bridge assets, while excluding transient build outputs

- [ ] **Step 1: Write the failing test**

```matlab
function tests = testDevelopmentPackaging
tests = functiontests(localfunctions);
end

function testDevelopmentPackageContainsSourceRuntimeAndTooling(testCase)
projectRoot = fileparts(fileparts(fileparts(mfilename("fullpath"))));
run(fullfile(projectRoot,"tools","dev","setupPath.m"));
outputRoot = tempname;
extractRoot = tempname;
mkdir(outputRoot);
mkdir(extractRoot);
cleanup = onCleanup(@()cleanupDirectories(outputRoot,extractRoot)); %#ok<NASGU>

packagePath = createDevelopmentPackage(outputRoot);
unzip(packagePath,extractRoot);
packageRoot = fullfile(extractRoot,"DVSenseRealtimeV1-dev");

verifyTrue(testCase,isfile(fullfile(packageRoot,"main.m")));
verifyTrue(testCase,isfile(fullfile(packageRoot,"README.md")));
verifyTrue(testCase,isfile(fullfile(packageRoot,"CONTEXT.md")));
verifyTrue(testCase,isfile(fullfile(packageRoot,"VERSION")));
verifyTrue(testCase,isfolder(fullfile(packageRoot,"src","matlab","+camera")));
verifyTrue(testCase,isfile(fullfile(packageRoot,"src","matlab","+camera","+internal","dvsenseBridgePrototype.m")));
verifyTrue(testCase,isfile(fullfile(packageRoot,"src","matlab","+camera","+internal","dvsense_bridge_thunk_pcwin64.dll")));
verifyTrue(testCase,isfile(fullfile(packageRoot,"runtime","bin","dvsense_bridge.dll")));
verifyTrue(testCase,isfile(fullfile(packageRoot,"runtime","bin","dvsense_helper.exe")));
verifyTrue(testCase,isfolder(fullfile(packageRoot,"tools","build")));
verifyTrue(testCase,isfolder(fullfile(packageRoot,"tests","matlab")));
verifyFalse(testCase,isfolder(fullfile(packageRoot,"artifacts","build")));
verifyFalse(testCase,isfile(fullfile(packageRoot,"dvsenseBridgePrototype.m")));
verifyFalse(testCase,isfile(fullfile(packageRoot,"frame_batch_test.obj")));
end
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `matlab -batch "run(fullfile(pwd,'tools','dev','setupPath.m')); results=runtests(fullfile(pwd,'tests','matlab','testDevelopmentPackaging.m'));"`
Expected: FAIL because `createDevelopmentPackage` does not exist yet

- [ ] **Step 3: Keep only the assertions that reflect the package contract**

If a path in the test looks optional, remove it now. The package contract should be strict enough that a stray generated file fails the test.

- [ ] **Step 4: Re-run the test and keep it red**

Run the same `runtests` command again.
Expected: still FAIL for the missing package builder, not for a typo in the test

- [ ] **Step 5: Commit**

```bash
git add tests/matlab/testDevelopmentPackaging.m
git commit -m "test: lock development package layout"
```

### Task 2: Build the development package generator

**Files:**
- Create: `tools/package/createDevelopmentPackage.m`
- Modify: `tools/build/buildBridgePrototype.m` if its output naming needs to feed the package contract

**Interfaces:**
- Consumes: project root discovery, runtime file list, and the bridge prototype file in `src/matlab/+camera/+internal`
- Produces: `createDevelopmentPackage(outputRoot)` returning a ZIP path that contains the complete developer handoff layout

- [ ] **Step 1: Write the failing implementation-driving test**

Use the test from Task 1 as the driver. Do not add a second package test until the first one is green.

- [ ] **Step 2: Implement the package entry list**

```matlab
entries = [ ...
    "main.m"
    "README.md"
    "VERSION"
    "CONTEXT.md"
    "启动开发版.bat"
    "src"
    "runtime"
    "config"
    "docs"
    "tests"
    "tools"];
```

Copy the listed entries into a temporary `DVSenseRealtimeV1-dev` staging root, then delete transient files from `src/matlab/+camera/+internal` and from the package root before zipping.

- [ ] **Step 3: Make the package self-contained**

Ensure the package keeps:

```matlab
runtime/bin/dvsense_bridge.dll
runtime/bin/dvsense_helper.exe
runtime/bin/*.dll vendor dependencies
src/matlab/+camera/+internal/dvsenseBridgePrototype.m
src/matlab/+camera/+internal/dvsense_bridge_thunk_pcwin64.dll
tools/build/*
tools/dev/*
tests/*
```

and removes:

```matlab
artifacts/*
*.obj
*.lib
*.exp
root-level bridge prototype leftovers
```

- [ ] **Step 4: Re-run the development package test**

Run: `matlab -batch "run(fullfile(pwd,'tools','dev','setupPath.m')); results=runtests(fullfile(pwd,'tests','matlab','testDevelopmentPackaging.m'));"`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add tools/package/createDevelopmentPackage.m
git commit -m "feat: add development package builder"
```

### Task 3: Document the split between development and runtime packages

**Files:**
- Modify: `docs/architecture/structure.md`
- Modify: `README.md`
- Modify: `runtime/README.md`

**Interfaces:**
- Consumes: the new development package contract and the existing runtime package contract
- Produces: clear documentation that tells future work where development assets live and what the runtime package excludes

- [ ] **Step 1: Add the development package rule to the structure doc**

State that the development package is the source handoff shape, while `runtime/` is the runtime-only shape.

- [ ] **Step 2: Update the top-level README**

Add one short section that tells a new maintainer to use the development package when moving the repo to another computer for continued work.

- [ ] **Step 3: Re-run the full MATLAB test suite**

Run: `matlab -batch "run(fullfile(pwd,'tools','dev','setupPath.m')); results=runtests(fullfile(pwd,'tests','matlab'),'IncludeSubfolders',true);"`
Expected: `0` failures and `0` incomplete tests

- [ ] **Step 4: Verify the generated ZIP contents**

Unzip the development package and confirm the root contains only the intended source, tooling, and runtime folders.

- [ ] **Step 5: Commit**

```bash
git add docs/architecture/structure.md README.md runtime/README.md
git commit -m "docs: define development package layout"
```
