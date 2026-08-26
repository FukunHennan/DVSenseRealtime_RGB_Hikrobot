@echo off
setlocal
cd /d "%~dp0"
matlab -r "run(fullfile(pwd,'tools','dev','setupPath.m')); main"
