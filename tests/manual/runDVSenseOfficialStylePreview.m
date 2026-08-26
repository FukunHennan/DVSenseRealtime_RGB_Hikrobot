function figureHandle=runDVSenseOfficialStylePreview
% Launch the MATLAB-hosted official-style DVS interface prototype.

sourceDirectory=fileparts(mfilename("fullpath"));
htmlSource=fullfile(sourceDirectory,"assets", ...
    "dvsense_official_matlab_preview.html");

figureHandle=uifigure( ...
    "Name","DVSense Realtime - MATLAB 可实现界面原型", ...
    "Position",[80 80 1200 700], ...
    "Color",[0.93 0.94 0.95]);

layout=uigridlayout(figureHandle,[1 1]);
layout.Padding=[0 0 0 0];
browser=uihtml(layout,"HTMLSource",htmlSource);
browser.Layout.Row=1;
browser.Layout.Column=1;

if nargout==0
    assignin("base","dvsenseOfficialStylePreview",figureHandle);
    clear figureHandle
end
end
