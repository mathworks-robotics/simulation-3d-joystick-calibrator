function blkStruct = slblocks
%SLBLOCKS Register the Simulation 3D Joystick Calibrator library.
%
% Copyright 2026 The MathWorks, Inc.

    libraryName = 'Simulation3DJoystickCalibratorLibrary';
    libraryLabel = 'Simulation 3D Joystick Calibrator';

    blkStruct.Name = sprintf('Simulation 3D\nJoystick Calibrator');
    blkStruct.OpenFcn = libraryName;
    blkStruct.MaskInitialization = '';
    blkStruct.MaskDisplay = ...
        'disp(''Simulation 3D Joystick Calibrator'')';

    Browser(1).Library = libraryName;
    Browser(1).Name = libraryLabel;
    Browser(1).IsFlat = 0;
    blkStruct.Browser = Browser;
end
