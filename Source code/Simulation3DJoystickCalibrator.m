function app = Simulation3DJoystickCalibrator()
%SIMULATION3DJOYSTICKCALIBRATOR Launch the joystick calibration app.
%   One saved calibration works with the Fixed-Wing, Multirotor, and
%   Helicopter Input blocks.
%
% Copyright 2026 The MathWorks, Inc.

    toolboxRoot = fileparts(mfilename('fullpath'));
    addpath(toolboxRoot, ...
        fullfile(toolboxRoot, 'supporting_functions'), ...
        fullfile(toolboxRoot, 'library'), ...
        fullfile(toolboxRoot, 'examples'), ...
        fullfile(toolboxRoot, 'images'));

    stack = Simulation3DJoystickCalibrator.runApp("hardware", true);
    app = stack.view;
    if nargout == 0
        clear app stack
    end
end
