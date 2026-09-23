function app = runApp(mode, visible)
%RUNAPP Launch the App Designer UI and return its runtime object graph.
%
% Copyright 2026 The MathWorks, Inc.

    arguments
        mode (1,1) string {mustBeMember(mode, ...
            ["hardware", "test", "headless"])} = "hardware"
        visible (1,1) logical = true
    end

    mode = lower(string(mode));
    packageFolder = fileparts(mfilename('fullpath'));
    toolboxRoot = fileparts(packageFolder);
    appFile = locateAppFile(toolboxRoot);
    appFolder = fileparts(appFile);

    if ~contains(string(path), string(appFolder))
        addpath(appFolder, '-begin');
    end

    optionsKey = 'Simulation3DJoystickCalibratorLaunchOptions';
    setappdata(groot, optionsKey, ...
        struct('mode', char(mode), 'visible', visible));
    optionsCleanup = onCleanup(@() clearLaunchOptions(optionsKey));
    view = Simulation3DJoystickCalibratorDesignerApp();
    app = view.getRuntimeStack();
    clear optionsCleanup;
end

function clearLaunchOptions(optionsKey)
    if isappdata(groot, optionsKey)
        rmappdata(groot, optionsKey);
    end
end

function appFile = locateAppFile(toolboxRoot)
    appName = 'Simulation 3D Joystick Calibrator';
    appFileName = 'Simulation3DJoystickCalibratorDesignerApp.mlapp';
    appFile = fullfile(toolboxRoot, 'apps', appFileName);
    if isfile(appFile)
        return;
    end

    installedApps = matlab.apputil.getInstalledAppInfo;
    for index = 1:numel(installedApps)
        if strcmp(installedApps(index).name, appName) && ...
                strcmp(installedApps(index).status, 'installed')
            matches = dir(fullfile( ...
                installedApps(index).location, '**', appFileName));
            matches = matches(~[matches.isdir]);
            if ~isempty(matches)
                appFile = fullfile(matches(1).folder, matches(1).name);
                return;
            end
        end
    end

    error('Simulation3DJoystickCalibrator:MissingApp', ...
        ['The "%s" App Designer file is missing. Reinstall the toolbox ' ...
         'before launching the calibrator from the command line.'], appName);
end
