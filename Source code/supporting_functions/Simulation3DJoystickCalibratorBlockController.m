classdef Simulation3DJoystickCalibratorBlockController
    %SIMULATION3DJOYSTICKCALIBRATORBLOCKCONTROLLER Runtime callbacks for joystick calibration blocks.
    %
    % Copyright 2026 The MathWorks, Inc.

    properties (Constant, Access = private)
        DEFAULT_NUM_AXES = 8
        MAX_NUM_AXES = 64
    end

    methods (Static)

        function MaskInitialization(maskInitContext)
            if nargin < 1
                return;
            end

            maskObj = maskInitContext.MaskObject;
            blockPath = getfullname(maskInitContext.BlockHandle);
            mws = maskInitContext.MaskWorkspace;
            Simulation3DJoystickCalibratorBlockController.initializeFromMask(maskObj, blockPath, mws);
            Simulation3DJoystickCalibratorBlockController.refreshCalibrationAppButton(maskObj);
        end


        function initializeFromMask(maskObj, blockPath, mws)
            Simulation3DJoystickCalibratorBlockController.ensureContractSupportPath();
            expectedProfile = Simulation3DJoystickCalibratorBlockController.expectedProfile(blockPath, maskObj);
            try
                configFileName = strtrim(maskObj.getParameter('configName').Value);
                resolvedConfigFile = Simulation3DJoystickCalibratorBlockController.resolveConfigPath(configFileName);

                if isempty(configFileName) || strcmp(configFileName, '0')
                    cfg = Simulation3DJoystickCalibratorBlockController.defaultConfig(expectedProfile);
                    cfg.joystickID = Simulation3DJoystickCalibratorBlockController.getMaskJoystickID(maskObj, cfg.joystickID);
                    Simulation3DJoystickCalibratorBlockController.applyConfiguration(maskObj, blockPath, mws, cfg, true);
                    return;
                end

                if isempty(resolvedConfigFile) || ~isfile(resolvedConfigFile)
                    warning('CalibratedInput:fileNotFound', ...
                        'CalibratedInput: Config file "%s" not found. Using defaults.', ...
                        configFileName);
                    cfg = Simulation3DJoystickCalibratorBlockController.defaultConfig(expectedProfile);
                    cfg.joystickID = Simulation3DJoystickCalibratorBlockController.getMaskJoystickID(maskObj, cfg.joystickID);
                    Simulation3DJoystickCalibratorBlockController.applyConfiguration(maskObj, blockPath, mws, cfg, true);
                    return;
                end

                [cfg, ok, detail] = Simulation3DJoystickCalibratorBlockController.loadCanonicalConfig(resolvedConfigFile);
                if ~ok
                    warning('CalibratedInput:readError', ...
                        'CalibratedInput: Could not load "%s". %s Using defaults.', ...
                        configFileName, detail);
                    cfg = Simulation3DJoystickCalibratorBlockController.defaultConfig(expectedProfile);
                    cfg.joystickID = Simulation3DJoystickCalibratorBlockController.getMaskJoystickID(maskObj, cfg.joystickID);
                    Simulation3DJoystickCalibratorBlockController.applyConfiguration(maskObj, blockPath, mws, cfg, true);
                    return;
                end

                Simulation3DJoystickCalibratorBlockController.applyConfiguration(maskObj, blockPath, mws, cfg, true);
            catch ME
                warning('CalibratedInput:initFailed', ...
                    'CalibratedInput: Initialization failed (%s). Using defaults.', ME.message);
                cfg = Simulation3DJoystickCalibratorBlockController.defaultConfig(expectedProfile);
                cfg.joystickID = Simulation3DJoystickCalibratorBlockController.getMaskJoystickID(maskObj, cfg.joystickID);
                Simulation3DJoystickCalibratorBlockController.applyConfiguration(maskObj, blockPath, mws, cfg, true);
            end
        end


        function cfg = loadConfigForMask(maskObj)
            Simulation3DJoystickCalibratorBlockController.ensureContractSupportPath();
            blockPath = '';
            try
                blockPath = getfullname(maskObj.BlockHandle);
            catch
            end
            expectedProfile = Simulation3DJoystickCalibratorBlockController.expectedProfile(blockPath, maskObj);
            cfg = Simulation3DJoystickCalibratorBlockController.defaultConfig(expectedProfile);
            cfg.joystickID = Simulation3DJoystickCalibratorBlockController.getMaskJoystickID(maskObj, cfg.joystickID);

            try
                configFileName = strtrim(maskObj.getParameter('configName').Value);
            catch
                configFileName = '';
            end

            if isempty(configFileName) || strcmp(configFileName, '0')
                return;
            end

            resolvedConfigFile = Simulation3DJoystickCalibratorBlockController.resolveConfigPath(configFileName);
            if isempty(resolvedConfigFile) || ~isfile(resolvedConfigFile)
                warning('CalibratedInput:fileNotFound', ...
                    'CalibratedInput: Config file "%s" not found. Using defaults.', ...
                    configFileName);
                return;
            end

            [loadedCfg, ok, detail] = Simulation3DJoystickCalibratorBlockController.loadCanonicalConfig(resolvedConfigFile);
            if ~ok
                warning('CalibratedInput:readError', ...
                    'CalibratedInput: Could not load "%s". %s Using defaults.', ...
                    configFileName, detail);
                return;
            end

            cfg = Simulation3DJoystickCalibratorBlockController.ensureModernFields( ...
                loadedCfg, expectedProfile);
            cfg.joystickID = Simulation3DJoystickCalibratorBlockController.getMaskJoystickID(maskObj, cfg.joystickID);
        end


        function applyConfiguration(maskObj, blockPath, mws, cfg, preferMaskJoystick)
            if nargin < 5
                preferMaskJoystick = false;
            end
            expectedProfile = ...
                Simulation3DJoystickCalibratorBlockController.expectedProfile(blockPath, maskObj);
            cfg = Simulation3DJoystickCalibratorBlockController.ensureModernFields(cfg, expectedProfile);
            if preferMaskJoystick
                cfg.joystickID = Simulation3DJoystickCalibratorBlockController.getMaskJoystickID(maskObj, cfg.joystickID);
            end
            cfg = Simulation3DJoystickCalibratorBlockController.applyResolvedAxisCount(cfg, blockPath);
            Simulation3DJoystickCalibratorBlockController.flattenToMaskWorkspace(mws, cfg, expectedProfile);
            Simulation3DJoystickCalibratorBlockController.pushJoystick(maskObj, blockPath, cfg);
        end


        function pushJoystick(maskObj, blockPath, cfg)
            try
                joyParam = maskObj.getParameter('joystickID');
                if ismember(cfg.joystickID, joyParam.TypeOptions)
                    joyParam.Value = cfg.joystickID;
                end
            catch
            end
            Simulation3DJoystickCalibratorBlockController.applyJoystickID(blockPath, cfg.joystickID);
            if isfield(cfg, 'numAxes')
                Simulation3DJoystickCalibratorBlockController.applyAxisConfiguration(blockPath, cfg.numAxes);
            end
        end


        function joystickID(callbackContextOrBlock)
            if nargin < 1 || isempty(callbackContextOrBlock)
                return;
            end

            try
                if isnumeric(callbackContextOrBlock) || ischar(callbackContextOrBlock) || ...
                        (isstring(callbackContextOrBlock) && isscalar(callbackContextOrBlock))
                    blockPath = char(string(callbackContextOrBlock));
                    if isnumeric(callbackContextOrBlock)
                        blockPath = getfullname(callbackContextOrBlock);
                    end
                    maskObj = Simulink.Mask.get(blockPath);
                    if isempty(maskObj)
                        return;
                    end
                    joyID = maskObj.getParameter('joystickID').Value;
                else
                    joyID = callbackContextOrBlock.ParameterObject.Value;
                    blockPath = getfullname(callbackContextOrBlock.BlockHandle);
                end
                Simulation3DJoystickCalibratorBlockController.applyJoystickID(blockPath, joyID);
                numAxes = Simulation3DJoystickCalibratorBlockController.detectJoystickAxes(joyID);
                if isempty(numAxes)
                    currentWidth = Simulation3DJoystickCalibratorBlockController.currentSelectorWidth(blockPath);
                    numAxes = Simulation3DJoystickCalibratorBlockController.DEFAULT_NUM_AXES;
                    if ~isempty(currentWidth)
                        numAxes = max(numAxes, currentWidth);
                    end
                end
                Simulation3DJoystickCalibratorBlockController.applyAxisConfiguration(blockPath, numAxes);
            catch
            end
        end


        function configName(callbackContextOrBlock)
            if nargin < 1 || isempty(callbackContextOrBlock)
                return;
            end

            try
                if isnumeric(callbackContextOrBlock) || ...
                        ischar(callbackContextOrBlock) || ...
                        (isstring(callbackContextOrBlock) && ...
                        isscalar(callbackContextOrBlock))
                    blockPath = char(string(callbackContextOrBlock));
                    if isnumeric(callbackContextOrBlock)
                        blockPath = getfullname(callbackContextOrBlock);
                    end
                    maskObj = Simulink.Mask.get(blockPath);
                else
                    maskObj = Simulink.Mask.get( ...
                        callbackContextOrBlock.BlockHandle);
                end
                if isempty(maskObj)
                    return;
                end
                Simulation3DJoystickCalibratorBlockController. ...
                    refreshCalibrationAppButton(maskObj);
            catch
            end
        end


        function openCalibrationApp(~)
            Simulation3DJoystickCalibratorBlockController.ensureContractSupportPath();
            try
                Simulation3DJoystickCalibrator();
            catch ME
                errordlg(sprintf( ...
                    'Could not open Simulation 3D Joystick Calibrator.\n\n%s', ...
                    ME.message), ...
                    'Calibration App Error');
            end
        end


        function loaded = refreshCalibrationAppButton(maskObj)
            loaded = ...
                Simulation3DJoystickCalibratorBlockController. ...
                hasLoadedCalibration(maskObj);
            try
                button = maskObj.getDialogControl('openCalibrationApp');
                if isempty(button)
                    return;
                end
                if loaded
                    desiredState = 'off';
                else
                    desiredState = 'on';
                end
                if ~strcmp(button.Enabled, desiredState)
                    button.Enabled = desiredState;
                end
            catch
            end
        end


        function loaded = hasLoadedCalibration(maskObj)
            loaded = false;
            try
                configFileName = ...
                    strtrim(maskObj.getParameter('configName').Value);
            catch
                return;
            end
            if isempty(configFileName) || strcmp(configFileName, '0')
                return;
            end

            resolvedConfigFile = ...
                Simulation3DJoystickCalibratorBlockController. ...
                resolveConfigPath(configFileName);
            if isempty(resolvedConfigFile) || ~isfile(resolvedConfigFile)
                return;
            end

            [~, loaded] = ...
                Simulation3DJoystickCalibratorBlockController. ...
                loadCanonicalConfig(resolvedConfigFile);
        end


        function success = loadFromFile(maskObj, blockPath, fullPath)
            success = false;
            Simulation3DJoystickCalibratorBlockController.ensureContractSupportPath();

            [cfg, ok, detail] = Simulation3DJoystickCalibratorBlockController.loadCanonicalConfig(fullPath);
            if ~ok
                    errordlg(sprintf('Could not load joystick calibration:\n%s\n\n%s', ...
                    fullPath, detail), 'Load Error');
                return;
            end

            expectedProfile = ...
                Simulation3DJoystickCalibratorBlockController.expectedProfile(blockPath, maskObj);

            [storedPath, copiedFile] = Simulation3DJoystickCalibratorBlockController.storeInProject(fullPath, blockPath);
            maskObj.getParameter('configName').Value = storedPath;
            selectedJoyID = Simulation3DJoystickCalibratorBlockController.getMaskJoystickID(maskObj, ...
                Simulation3DJoystickCalibratorBlockController.defaultConfig().joystickID);

            % Mask workspace writes are only supported during mask initialization.
            % Queue the selected file in mask parameters now, then let
            % MaskInitialization apply the calibration on Apply/OK.

            success = true;
            Simulation3DJoystickCalibratorBlockController. ...
                refreshCalibrationAppButton(maskObj);
            if copiedFile
                storageLine = sprintf('Copied to local folder: %s', storedPath);
            else
                storageLine = sprintf('Using local file: %s', storedPath);
            end
            summary = Simulation3DJoystickCalibratorBlockController.configurationSummary( ...
                cfg, selectedJoyID, expectedProfile);
            msgbox(sprintf([ ...
                'Loaded from: %s\n' ...
                '%s\n\n' ...
                'Configuration file staged in the mask dialog.\n' ...
                'Click Apply or OK to refresh the subsystem from this file.\n\n%s'], ...
                fullPath, storageLine, summary), ...
                'Configuration Selected');
        end


        function loadConfig(callbackContext)
            maskObj = Simulink.Mask.get(callbackContext.BlockHandle);
            blockPath = getfullname(callbackContext.BlockHandle);

            startFolder = ...
                Simulation3DJoystickCalibratorBlockController. ...
                getLoadStartFolder();

            [fileName, filePath] = uigetfile('*.mat', ...
                'Select Simulation 3D Joystick Configuration File', ...
                fullfile(startFolder, '*.mat'));
            if isequal(fileName, 0)
                return;
            end

            Simulation3DJoystickCalibratorBlockController.loadFromFile(maskObj, blockPath, ...
                fullfile(filePath, fileName));
        end


        function cfg = defaultConfig(profileID)
            if nargin < 1 || isempty(profileID)
                profileID = 'fixed-wing';
            end
            canonical = ...
                Simulation3DJoystickCalibrator.Services.ConfigurationService.default( ...
                'simulation-3d-joystick', 4);
            if strcmp( ...
                    Simulation3DJoystickCalibrator.Services.ProfileCatalog.normalizeID( ...
                    profileID), 'fixed-wing')
                profile = ...
                    Simulation3DJoystickCalibrator.Services.ProfileCatalog.get( ...
                    'fixed-wing');
                for index = 1:numel(canonical.signals)
                    canonical.signals(index).outputMin = ...
                        profile.signals(index).outputMin;
                    canonical.signals(index).outputMax = ...
                        profile.signals(index).outputMax;
                end
            end
            cfg = canonical;
            cfg.joystickID = 'Joystick1';
            runtime = ...
                Simulation3DJoystickCalibrator.Services.ConfigurationService.toRuntimeVariables( ...
                canonical, profileID);
            cfg = Simulation3DJoystickCalibratorBlockController.mergeStructs(cfg, runtime);
        end


        function flattenToMaskWorkspace(mws, cfg, outputProfileID)
            if nargin < 3 || isempty(outputProfileID)
                outputProfileID = 'fixed-wing';
                if isfield(cfg, 'profileID') && any(strcmp( ...
                        Simulation3DJoystickCalibrator.Services.ProfileCatalog.ids(), ...
                        cfg.profileID))
                    outputProfileID = cfg.profileID;
                end
            end
            cfg = Simulation3DJoystickCalibratorBlockController.ensureModernFields(cfg, outputProfileID);

            vars = Simulation3DJoystickCalibratorBlockController.configVariables(cfg);
            names = fieldnames(vars);
            for idx = 1:numel(names)
                mws.set(names{idx}, vars.(names{idx}));
            end

            if isfield(cfg, 'savedAt')
                mws.set('savedAt', cfg.savedAt);
            end
        end


        function cfg = ensureModernFields(cfg, outputProfileID)
            if nargin < 2 || isempty(outputProfileID)
                outputProfileID = 'fixed-wing';
                if isfield(cfg, 'profileID') && any(strcmp( ...
                        Simulation3DJoystickCalibrator.Services.ProfileCatalog.ids(), ...
                        cfg.profileID))
                    outputProfileID = cfg.profileID;
                end
            end
            joystickID = 'Joystick1';
            if isfield(cfg, 'joystickID')
                joystickID = cfg.joystickID;
            end
            canonicalCandidate = cfg;
            if isfield(canonicalCandidate, 'calibrationProfileID')
                canonicalCandidate.profileID = ...
                    canonicalCandidate.calibrationProfileID;
            end
            [canonical, report] = ...
                Simulation3DJoystickCalibrator.Services.ConfigurationService.normalize( ...
                    canonicalCandidate);
            if ~report.ok
                error('CalibratedInput:invalidConfig', ...
                    '%s', strjoin(report.problems, newline));
            end
            runtime = ...
                Simulation3DJoystickCalibrator.Services.ConfigurationService.toRuntimeVariables( ...
                canonical, outputProfileID);
            cfg = Simulation3DJoystickCalibratorBlockController.mergeStructs(canonical, runtime);
            if ~(ischar(joystickID) || ...
                    (isstring(joystickID) && isscalar(joystickID))) || ...
                    strlength(string(joystickID)) == 0
                joystickID = 'Joystick1';
            end
            cfg.joystickID = char(string(joystickID));
        end


        function [cfg, ok, detail] = loadCanonicalConfig(filePath)
            cfg = struct();
            ok = false;
            detail = '';
            Simulation3DJoystickCalibratorBlockController.ensureContractSupportPath();

            try
                [canonical, report] = ...
                    Simulation3DJoystickCalibrator.Services.ConfigurationService.load(filePath);
            catch ME
                detail = ME.message;
                return;
            end
            if ~report.ok
                detail = strjoin(report.problems, newline);
                return;
            end
            cfg = canonical;
            ok = true;
        end


        function resolvedPath = resolveConfigPath(configFileName)
            resolvedPath = '';

            if isempty(configFileName) || strcmp(configFileName, '0')
                return;
            end

            if Simulation3DJoystickCalibratorBlockController.isAbsolutePath(configFileName)
                if isfile(configFileName)
                    resolvedPath = configFileName;
                end
                return;
            end

            searchRoots = { ...
                Simulation3DJoystickCalibratorBlockController.getCurrentProjectRoot(), ...
                Simulation3DJoystickCalibratorBlockController.getExampleConfigFolder(), ...
                Simulation3DJoystickCalibratorBlockController.locateWorkspaceRoot(), ...
                Simulation3DJoystickCalibratorBlockController.getProjectConfigFolder()};

            for idx = 1:numel(searchRoots)
                root = searchRoots{idx};
                if isempty(root)
                    continue;
                end
                candidate = fullfile(root, configFileName);
                if isfile(candidate)
                    resolvedPath = candidate;
                    return;
                end
            end

            if isfile(configFileName)
                resolvedPath = configFileName;
            end
        end


        function [storedPath, copiedFile] = storeInProject(sourcePath, blockPath)
            copiedFile = false;
            sourcePath = char(sourcePath);
            if nargin < 2
                blockPath = '';
            end

            targetFolder = Simulation3DJoystickCalibratorBlockController.getLocalConfigFolder(blockPath);
            if ~exist(targetFolder, 'dir')
                mkdir(targetFolder);
            end

            [~, name, ext] = fileparts(sourcePath);
            localFile = fullfile(targetFolder, [name ext]);
            if ~strcmpi(sourcePath, localFile)
                copyfile(sourcePath, localFile, 'f');
                copiedFile = true;
            end
            storedPath = localFile;
        end


        function folder = getLoadStartFolder()
            folder = pwd;
        end


        function localFolder = getLocalConfigFolder(blockPath)
            if nargin >= 1 && ~isempty(blockPath)
                try
                    modelFile = get_param(bdroot(blockPath), 'FileName');
                    if ~isempty(modelFile)
                        modelFolder = fileparts(modelFile);
                        if ~Simulation3DJoystickCalibratorBlockController.isWithinToolbox(modelFolder)
                            localFolder = modelFolder;
                            return;
                        end
                    end
                catch
                end
            end

            currentFolder = pwd;
            if ~Simulation3DJoystickCalibratorBlockController.isWithinToolbox(currentFolder)
                localFolder = currentFolder;
                return;
            end

            localFolder = Simulation3DJoystickCalibratorBlockController.firstUserPathFolder();
            if isempty(localFolder)
                localFolder = currentFolder;
            end
        end


        function tf = isWithinToolbox(pathValue)
            tf = false;
            toolboxRoot = Simulation3DJoystickCalibratorBlockController.locateWorkspaceRoot();
            if isempty(toolboxRoot) || isempty(pathValue)
                return;
            end

            pathValue = char(pathValue);
            toolboxRoot = char(toolboxRoot);
            if strcmpi(pathValue, toolboxRoot)
                tf = true;
                return;
            end
            tf = startsWith(lower(pathValue), lower([toolboxRoot filesep]));
        end


        function folder = firstUserPathFolder()
            folder = '';
            try
                candidates = regexp(userpath, pathsep, 'split');
                for idx = 1:numel(candidates)
                    candidate = strtrim(candidates{idx});
                    if isempty(candidate)
                        continue;
                    end
                    if ~isfolder(candidate)
                        continue;
                    end
                    if ~Simulation3DJoystickCalibratorBlockController.isWithinToolbox(candidate)
                        folder = candidate;
                        return;
                    end
                end
            catch
            end
        end


        function projectRoot = getCurrentProjectRoot()
            projectRoot = '';
            try
                proj = currentProject;
                projectRoot = char(proj.RootFolder);
            catch
            end
        end


        function configFolder = getProjectConfigFolder()
            projectRoot = Simulation3DJoystickCalibratorBlockController.getCurrentProjectRoot();
            if ~isempty(projectRoot)
                storageRoot = projectRoot;
            else
                storageRoot = prefdir;
            end

            configFolder = fullfile(storageRoot, ...
                'Simulation3DJoystickCalibration', 'Configs');
        end


        function configFolder = getExampleConfigFolder()
            configFolder = fullfile(Simulation3DJoystickCalibratorBlockController.locateWorkspaceRoot(), ...
                'examples');
        end


        function tf = isAbsolutePath(pathValue)
            tf = ~isempty(regexp(pathValue, '^[A-Za-z]:[\\/]|^\\\\|^/', 'once'));
        end


        function ensureContractSupportPath()
            workspaceRoot = Simulation3DJoystickCalibratorBlockController.locateWorkspaceRoot();
            if ~isempty(workspaceRoot)
                addpath(workspaceRoot, ...
                    fullfile(workspaceRoot, 'supporting_functions'), ...
                    fullfile(workspaceRoot, 'library'), ...
                    fullfile(workspaceRoot, 'examples'), ...
                    fullfile(workspaceRoot, 'images'));
            end
        end


        function cfg = applyResolvedAxisCount(cfg, blockPath)
            if nargin < 2
                blockPath = '';
            end
            cfg = Simulation3DJoystickCalibratorBlockController.ensureModernFields(cfg);
            liveAxes = Simulation3DJoystickCalibratorBlockController.detectJoystickAxes(cfg.joystickID);
            if ~isempty(liveAxes)
                cfg.numAxes = liveAxes;
                return;
            end

            configuredWidth = Simulation3DJoystickCalibratorBlockController.configuredChannelCount(cfg);
            currentWidth = Simulation3DJoystickCalibratorBlockController.currentSelectorWidth(blockPath);
            fallbackAxes = Simulation3DJoystickCalibratorBlockController.DEFAULT_NUM_AXES;
            if ~isempty(currentWidth)
                fallbackAxes = max(fallbackAxes, currentWidth);
            end
            savedAxes = Simulation3DJoystickCalibratorBlockController.normalizeNumAxes(cfg.numAxes);
            if ~isempty(savedAxes)
                fallbackAxes = max(fallbackAxes, savedAxes);
            end
            if ~isempty(configuredWidth)
                fallbackAxes = max(fallbackAxes, configuredWidth);
            end

            cfg.numAxes = fallbackAxes;
        end


        function vars = configVariables(cfg)
            cfg = Simulation3DJoystickCalibratorBlockController.ensureModernFields(cfg);
            vars = struct();
            vars.joystickID = cfg.joystickID;
            vars.numAxes = cfg.numAxes;
            if isfield(cfg, 'profileID')
                vars.profileID = cfg.profileID;
            end
            if isfield(cfg, 'schemaVersion')
                vars.schemaVersion = cfg.schemaVersion;
            end

            vars.rollCh = cfg.rollCh;
            vars.rollDB = cfg.rollDB;
            vars.uRollMin = cfg.uRollMin;
            vars.uRollMax = cfg.uRollMax;
            vars.rollNeutral = cfg.rollNeutral;
            vars.dirRoll = cfg.dirRoll;

            vars.pitchCh = cfg.pitchCh;
            vars.pitchDB = cfg.pitchDB;
            vars.uPitchMin = cfg.uPitchMin;
            vars.uPitchMax = cfg.uPitchMax;
            vars.pitchNeutral = cfg.pitchNeutral;
            vars.dirPitch = cfg.dirPitch;

            vars.yawCh = cfg.yawCh;
            vars.yawDB = cfg.yawDB;
            vars.uYawMin = cfg.uYawMin;
            vars.uYawMax = cfg.uYawMax;
            vars.yawNeutral = cfg.yawNeutral;
            vars.dirYaw = cfg.dirYaw;

            vars.throttleCh = cfg.throttleCh;
            vars.throttleDB = cfg.throttleDB;
            vars.uThrottleMin = cfg.uThrottleMin;
            vars.uThrottleMax = cfg.uThrottleMax;
            vars.throttleNeutral = cfg.throttleNeutral;
            vars.dirThrottle = cfg.dirThrottle;

            vars.aileronMin = cfg.aileronMin;
            vars.aileronMax = cfg.aileronMax;
            vars.elevatorMin = cfg.elevatorMin;
            vars.elevatorMax = cfg.elevatorMax;
            vars.rudderMin = cfg.rudderMin;
            vars.rudderMax = cfg.rudderMax;
            vars.throttleMin = cfg.throttleMin;
            vars.throttleMax = cfg.throttleMax;
        end


        function joyID = getMaskJoystickID(maskObj, defaultJoyID)
            joyID = defaultJoyID;
            try
                value = maskObj.getParameter('joystickID').Value;
                if ischar(value) || isstring(value)
                    joyID = char(string(value));
                end
            catch
            end
        end


        function numAxes = detectJoystickAxes(joyID)
            numericID = Simulation3DJoystickCalibratorBlockController.parseJoystickNumericID(joyID);
            if isempty(numericID)
                numericID = 1;
            end

            joy = [];
            try
                joy = sim3d.io.Joystick(ID=numericID);
                axesValue = read(joy);
                numAxes = Simulation3DJoystickCalibratorBlockController.normalizeNumAxes(numel(axesValue));
            catch
                numAxes = [];
            end
            Simulation3DJoystickCalibratorBlockController.releaseJoystickObject(joy);
        end


        function releaseJoystickObject(joy)
            if isempty(joy)
                return;
            end
            try
                close(joy);
            catch
            end
            try
                delete(joy);
            catch
            end
        end


        function numAxes = normalizeNumAxes(value)
            numAxes = [];
            if ischar(value) || (isstring(value) && isscalar(value))
                value = str2double(char(string(value)));
            end
            if (isnumeric(value) || islogical(value)) && isscalar(value) && isfinite(double(value))
                numAxes = max(1, min(Simulation3DJoystickCalibratorBlockController.MAX_NUM_AXES, round(double(value))));
            end
        end


        function width = configuredChannelCount(cfg)
            width = [];
            channelFields = {'rollCh','pitchCh','yawCh','throttleCh'};
            for idx = 1:numel(channelFields)
                fieldName = channelFields{idx};
                if isfield(cfg, fieldName)
                    ch = Simulation3DJoystickCalibratorBlockController.normalizeNumAxes(cfg.(fieldName));
                    if ~isempty(ch)
                        if isempty(width)
                            width = ch;
                        else
                            width = max(width, ch);
                        end
                    end
                end
            end
        end


        function applyAxisConfiguration(blockPath, numAxes)
            numAxes = Simulation3DJoystickCalibratorBlockController.normalizeNumAxes(numAxes);
            if isempty(numAxes)
                return;
            end

            joystickBlock = Simulation3DJoystickCalibratorBlockController.findJoystickBlock(blockPath);
            if ~isempty(joystickBlock)
                Simulation3DJoystickCalibratorBlockController.enableAdjustPorts(joystickBlock);
            end

            selectorBlock = Simulation3DJoystickCalibratorBlockController.findSelectorBlock(blockPath);
            if isempty(selectorBlock)
                return;
            end

            try
                dialogParams = get_param(selectorBlock, 'DialogParameters');
                if isfield(dialogParams, 'InputPortWidth')
                    set_param(selectorBlock, 'InputPortWidth', num2str(numAxes));
                end
            catch ME
                warning('CalibratedInput:selectorWidth', ...
                    'CalibratedInput: Could not set Selector InputPortWidth to %d (%s).', ...
                    numAxes, ME.message);
            end
        end


        function enableAdjustPorts(joystickBlock)
            try
                dialogParams = get_param(joystickBlock, 'DialogParameters');
                if isfield(dialogParams, 'adjustports')
                    set_param(joystickBlock, 'adjustports', 'on');
                end
            catch
            end
        end


        function selectorBlock = findSelectorBlock(blockPath)
            selectorBlock = '';
            candidates = { ...
                fullfile(blockPath, 'Actuator scaling', 'Selector'), ...
                fullfile(blockPath, 'Selector')};
            for idx = 1:numel(candidates)
                candidate = strrep(candidates{idx}, '\', '/');
                if ishandle(getSimulinkBlockHandle(candidate))
                    selectorBlock = candidate;
                    return;
                end
            end
        end


        function width = currentSelectorWidth(blockPath)
            width = [];
            selectorBlock = Simulation3DJoystickCalibratorBlockController.findSelectorBlock(blockPath);
            if isempty(selectorBlock)
                return;
            end
            try
                width = Simulation3DJoystickCalibratorBlockController.normalizeNumAxes(get_param(selectorBlock, 'InputPortWidth'));
            catch
                width = [];
            end
        end


        function applyJoystickID(blockPath, joyID)
            joystickBlock = Simulation3DJoystickCalibratorBlockController.findJoystickBlock(blockPath);
            if isempty(joystickBlock)
                return;
            end

            paramName = Simulation3DJoystickCalibratorBlockController.findJoystickParamName(joystickBlock);
            if isempty(paramName)
                return;
            end

            paramValue = char(string(joyID));
            if strcmp(paramName, 'joyid')
                numericID = Simulation3DJoystickCalibratorBlockController.parseJoystickNumericID(joyID);
                if isempty(numericID)
                    numericID = 1;
                end
                paramValue = num2str(numericID);
            end

            set_param(joystickBlock, paramName, paramValue);
            Simulation3DJoystickCalibratorBlockController.enableAdjustPorts(joystickBlock);
        end


        function joystickBlock = findJoystickBlock(blockPath)
            joystickBlock = '';
            candidates = {fullfile(blockPath, 'Simulation 3D Joystick')};
            for idx = 1:numel(candidates)
                candidate = strrep(candidates{idx}, '\', '/');
                if ishandle(getSimulinkBlockHandle(candidate))
                    joystickBlock = candidate;
                    return;
                end
            end
        end


        function paramName = findJoystickParamName(joystickBlock)
            paramName = '';
            try
                dialogParams = get_param(joystickBlock, 'DialogParameters');
                if isfield(dialogParams, 'JoystickID')
                    paramName = 'JoystickID';
                elseif isfield(dialogParams, 'joyid')
                    paramName = 'joyid';
                end
            catch
            end
        end


        function numericID = parseJoystickNumericID(joyID)
            numericID = [];
            if isnumeric(joyID) || islogical(joyID)
                if isscalar(joyID) && isfinite(double(joyID))
                    numericID = max(1, round(double(joyID)));
                end
                return;
            end

            joyText = char(string(joyID));
            tokens = regexp(joyText, '(\d+)$', 'tokens', 'once');
            if ~isempty(tokens)
                numericID = str2double(tokens{1});
            end
        end


        function profileID = expectedProfile(blockPath, maskObj)
            profileID = '';
            if nargin >= 2 && ~isempty(maskObj)
                try
                    parameter = maskObj.getParameter('profileID');
                    if ~isempty(parameter) && ~isempty(strtrim(parameter.Value))
                        profileID = ...
                            Simulation3DJoystickCalibrator.Services.ProfileCatalog.normalizeID( ...
                            parameter.Value);
                    end
                catch
                end
            end
            if isempty(profileID) && nargin >= 1 && ~isempty(blockPath)
                sourceName = blockPath;
                try
                    referenceBlock = get_param(blockPath, 'ReferenceBlock');
                    if ~isempty(referenceBlock)
                        sourceName = referenceBlock;
                    end
                catch
                end
                profileID = ...
                    Simulation3DJoystickCalibrator.Services.ConfigurationService. ...
                    expectedProfileForBlock(sourceName);
            end
            if isempty(profileID)
                profileID = 'fixed-wing';
            end
        end


        function summary = configurationSummary(cfg, joystickID, outputProfileID)
            if nargin < 3 || isempty(outputProfileID)
                outputProfileID = 'fixed-wing';
            end
            try
                [canonical, report] = ...
                    Simulation3DJoystickCalibrator.Services.ConfigurationService.normalize(cfg);
                if ~report.ok
                    error('Invalid configuration.');
                end
                profile = ...
                    Simulation3DJoystickCalibrator.Services.ProfileCatalog.get( ...
                    outputProfileID);
                lines = cell(1, 2 + numel(canonical.signals));
                lines{1} = sprintf('Block output: %s', profile.displayName);
                lines{2} = sprintf( ...
                    'Joystick   : %s (selected in mask)', joystickID);
                for index = 1:numel(canonical.signals)
                    lines{index + 2} = sprintf('%-11s: ch %d', ...
                        canonical.signals(index).label, ...
                        canonical.signals(index).channel);
                end
                summary = strjoin(lines, newline);
            catch ME
                summary = sprintf( ...
                    'Configuration unavailable for joystick %s: %s', ...
                    joystickID, ME.message);
            end
        end


        function output = mergeStructs(output, additions)
            names = fieldnames(additions);
            for index = 1:numel(names)
                output.(names{index}) = additions.(names{index});
            end
        end


        function workspaceRoot = locateWorkspaceRoot()
            workspaceRoot = fileparts(mfilename('fullpath'));
            for idx = 1:4
                hasRootMarkers = isfile(fullfile(workspaceRoot, ...
                    'Simulation3DJoystickCalibrator.m')) && ...
                    isfolder(fullfile(workspaceRoot, ...
                    '+Simulation3DJoystickCalibrator')) && ...
                    isfolder(fullfile(workspaceRoot, 'supporting_functions')) && ...
                    isfolder(fullfile(workspaceRoot, 'library')) && ...
                    isfolder(fullfile(workspaceRoot, 'examples'));
                if hasRootMarkers
                    return;
                end

                parentFolder = fileparts(workspaceRoot);
                if strcmp(parentFolder, workspaceRoot)
                    break;
                end
                workspaceRoot = parentFolder;
            end
        end

    end
end
