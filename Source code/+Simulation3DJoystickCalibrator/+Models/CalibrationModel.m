classdef CalibrationModel < handle
    %CALIBRATIONMODEL Hardware-independent calibration state and operations.
    %
    % Copyright 2026 The MathWorks, Inc.

    properties (SetObservable, SetAccess = private)
        ProfileID char = 'simulation-3d-joystick'
        Profile struct = struct()
        DeviceID char = 'Joystick1'
        NumAxes double = 4
        Signals struct = struct([])
        IsConnected logical = false
        RestCaptured logical = false
        Calibrated logical = false(1, 4)
        Revision double = 0
    end

    properties (Access = private)
        RestMedian double = []
        RestNoise double = []
    end

    methods
        function obj = CalibrationModel(profileID)
            arguments
                profileID {mustBeTextScalar} = "simulation-3d-joystick"
            end
            obj.selectProfile(profileID);
        end

        function selectProfile(obj, profileID)
            arguments
                obj
                profileID {mustBeTextScalar}
            end

            cfg = ...
                Simulation3DJoystickCalibrator.Services.ConfigurationService.default(profileID);
            obj.ProfileID = cfg.profileID;
            obj.Profile = ...
                Simulation3DJoystickCalibrator.Services.ProfileCatalog.get(cfg.profileID);
            obj.Signals = cfg.signals;
            obj.NumAxes = cfg.numAxes;
            obj.RestCaptured = false;
            obj.Calibrated = false(1, numel(cfg.signals));
            obj.RestMedian = [];
            obj.RestNoise = [];
            obj.touch();
        end

        function setDevice(obj, deviceID)
            arguments
                obj
                deviceID {mustBeTextScalar}
            end
            obj.DeviceID = char(string(deviceID));
            obj.IsConnected = false;
            obj.touch();
        end

        function setConnected(obj, connected, numAxes)
            arguments
                obj
                connected (1,1) logical
                numAxes (1,1) double {mustBeInteger, mustBePositive} = obj.NumAxes
            end
            if connected && numAxes < numel(obj.Signals)
                error('Simulation3DJoystickCalibrator:TooFewAxes', ...
                    ['The controller reports %d axes; at least %d distinct ' ...
                     'analog axes are required for Roll, Pitch, Yaw, and Throttle.'], ...
                    numAxes, numel(obj.Signals));
            end
            if numAxes > ...
                    Simulation3DJoystickCalibrator.Services.ConfigurationService.MaxChannels
                error('Simulation3DJoystickCalibrator:TooManyAxes', ...
                    'At most %d input axes are supported; the controller reports %d.', ...
                    Simulation3DJoystickCalibrator.Services.ConfigurationService.MaxChannels, ...
                    numAxes);
            end
            obj.IsConnected = connected;
            obj.NumAxes = numAxes;
            obj.touch();
        end

        function captureRest(obj, samples)
            arguments
                obj
                samples double
            end
            samples = obj.validateSamples(samples);
            obj.NumAxes = size(samples, 2);
            obj.RestMedian = median(samples, 1);
            obj.RestNoise = max(abs(samples - obj.RestMedian), [], 1);

            signals = obj.Signals;
            for index = 1:numel(signals)
                channel = signals(index).channel;
                if channel <= obj.NumAxes
                    signals(index).neutral = obj.RestMedian(channel);
                    signals(index).deadband = max( ...
                        signals(index).deadband, ...
                        min(0.2, 3 * obj.RestNoise(channel)));
                end
            end
            obj.Signals = signals;
            obj.RestCaptured = true;
            obj.Calibrated = false(1, numel(signals));
            obj.touch();
        end

        function channel = captureSignal(obj, signalIndex, samples)
            arguments
                obj
                signalIndex (1,1) double {mustBeInteger, mustBePositive}
                samples double
            end
            if signalIndex > numel(obj.Signals)
                error('Simulation3DJoystickCalibrator:SignalIndex', ...
                    'Signal index %d is outside the calibration contract.', ...
                    signalIndex);
            end
            if ~obj.RestCaptured
                error('Simulation3DJoystickCalibrator:RestRequired', ...
                    'Capture the rest positions before mapping signals.');
            end

            samples = obj.validateSamples(samples);
            movement = max(samples, [], 1) - min(samples, [], 1);
            unavailable = [obj.Signals(obj.Calibrated).channel];
            if obj.Calibrated(signalIndex)
                ownChannel = obj.Signals(signalIndex).channel;
                unavailable(unavailable == ownChannel) = [];
            end
            unavailable = unavailable(unavailable <= numel(movement));
            movement(unavailable) = -Inf;
            [largestMovement, channel] = max(movement);
            if isempty(channel) || ~isfinite(largestMovement) || ...
                    largestMovement < 0.15
                error('Simulation3DJoystickCalibrator:InsufficientMovement', ...
                    ['No unassigned axis moved far enough. Move only the selected ' ...
                     'control through its full travel and try again.']);
            end

            signal = obj.Signals(signalIndex);
            signal.channel = channel;
            signal.rawMin = min(samples(:, channel));
            signal.rawMax = max(samples(:, channel));
            if channel <= numel(obj.RestMedian)
                signal.neutral = obj.RestMedian(channel);
                signal.deadband = max(signal.deadband, ...
                    min(0.2, 3 * obj.RestNoise(channel)));
            elseif strcmp(signal.mapping, 'centered')
                signal.neutral = mean([signal.rawMin signal.rawMax]);
            else
                signal.neutral = signal.rawMin;
            end
            signal.neutral = min(max(signal.neutral, signal.rawMin), signal.rawMax);

            signals = obj.Signals;
            signals(signalIndex) = signal;
            obj.Signals = signals;
            calibrated = obj.Calibrated;
            calibrated(signalIndex) = true;
            obj.Calibrated = calibrated;
            obj.NumAxes = max(obj.NumAxes, channel);
            obj.touch();
        end

        function updateSignal(obj, signalIndex, fieldName, value)
            arguments
                obj
                signalIndex (1,1) double {mustBeInteger, mustBePositive}
                fieldName {mustBeTextScalar}
                value
            end
            if signalIndex > numel(obj.Signals)
                error('Simulation3DJoystickCalibrator:SignalIndex', ...
                    'Signal index %d is outside the calibration contract.', ...
                    signalIndex);
            end

            fieldName = char(string(fieldName));
            editable = {'channel','rawMin','rawMax','neutral','deadband', ...
                'reverse','outputMin','outputMax'};
            if ~ismember(fieldName, editable)
                    error('Simulation3DJoystickCalibrator:ReadOnlyField', ...
                    'Signal field "%s" cannot be edited.', fieldName);
            end

            signal = obj.Signals(signalIndex);
            if strcmp(fieldName, 'reverse')
                if ~(islogical(value) || isnumeric(value)) || ~isscalar(value)
                        error('Simulation3DJoystickCalibrator:InvalidValue', ...
                        'reverse must be scalar true or false.');
                end
                value = logical(value);
            else
                if ~(isnumeric(value) || islogical(value)) || ...
                        ~isscalar(value) || ~isfinite(double(value))
                    if ischar(value) || (isstring(value) && isscalar(value))
                        value = str2double(string(value));
                    end
                end
                if ~isnumeric(value) || ~isscalar(value) || ~isfinite(value)
                        error('Simulation3DJoystickCalibrator:InvalidValue', ...
                        '%s must be a finite numeric scalar.', fieldName);
                end
                value = double(value);
                if strcmp(fieldName, 'channel')
                    if value ~= round(value) || value < 1 || ...
                            value > ...
                            Simulation3DJoystickCalibrator.Services.ConfigurationService.MaxChannels
                        error('Simulation3DJoystickCalibrator:InvalidChannel', ...
                            'channel must be a whole number from 1 through %d.', ...
                            Simulation3DJoystickCalibrator.Services.ConfigurationService.MaxChannels);
                    end
                    obj.NumAxes = max(obj.NumAxes, value);
                elseif strcmp(fieldName, 'deadband') && value < 0
                        error('Simulation3DJoystickCalibrator:InvalidDeadband', ...
                        'deadband must be nonnegative.');
                elseif any(strcmp(fieldName, {'outputMin','outputMax'}))
                    outputMin = signal.outputMin;
                    outputMax = signal.outputMax;
                    if strcmp(fieldName, 'outputMin')
                        outputMin = value;
                    else
                        outputMax = value;
                    end
                    if outputMin >= outputMax
                        error('Simulation3DJoystickCalibrator:InvalidOutputRange', ...
                            'outputMin must be less than outputMax.');
                    end
                    if strcmp(signal.mapping, 'centered') && ...
                            (outputMin > 0 || outputMax < 0)
                        error('Simulation3DJoystickCalibrator:InvalidOutputRange', ...
                            ['A centered control output range must include zero ' ...
                             '(outputMin <= 0 <= outputMax).']);
                    end
                end
            end

            signal.(fieldName) = value;
            signals = obj.Signals;
            signals(signalIndex) = signal;
            obj.Signals = signals;
            obj.touch();
        end

        function loadConfiguration(obj, cfg)
            arguments
                obj
                cfg (1,1) struct
            end
            [cfg, report] = ...
                Simulation3DJoystickCalibrator.Services.ConfigurationService.normalize(cfg);
            if ~report.ok
                error('Simulation3DJoystickCalibrator:InvalidConfiguration', ...
                    '%s', strjoin(report.problems, newline));
            end

            obj.ProfileID = cfg.profileID;
            obj.Profile = ...
                Simulation3DJoystickCalibrator.Services.ProfileCatalog.get(cfg.profileID);
            obj.Signals = cfg.signals;
            obj.NumAxes = cfg.numAxes;
            obj.RestCaptured = true;
            obj.Calibrated = true(1, numel(cfg.signals));
            obj.RestMedian = nan(1, cfg.numAxes);
            obj.RestNoise = zeros(1, cfg.numAxes);
            for index = 1:numel(cfg.signals)
                channel = cfg.signals(index).channel;
                obj.RestMedian(channel) = cfg.signals(index).neutral;
                obj.RestNoise(channel) = cfg.signals(index).deadband / 3;
            end
            obj.touch();
        end

        function cfg = configuration(obj)
            cfg = struct( ...
                'schemaVersion', ...
                    Simulation3DJoystickCalibrator.Services.ProfileCatalog.SchemaVersion, ...
                'profileID', obj.ProfileID, ...
                'profileVersion', obj.Profile.profileVersion, ...
                'numAxes', obj.NumAxes, ...
                'signals', obj.Signals, ...
                'savedAt', char(datetime('now', 'TimeZone', 'UTC', ...
                    'Format', "yyyy-MM-dd'T'HH:mm:ss'Z'")), ...
                'appVersion', ...
                    Simulation3DJoystickCalibrator.Services.ProfileCatalog.AppVersion);
        end

        function [ok, report] = validate(obj)
            [ok, report] = ...
                Simulation3DJoystickCalibrator.Services.ConfigurationService.validate( ...
                obj.configuration());
            if ~all(obj.Calibrated)
                ok = false;
                missing = string({obj.Signals(~obj.Calibrated).label});
                report.problems{end+1} = sprintf( ...
                    'Calibration is incomplete for: %s.', strjoin(missing, ', '));
                report.ok = false;
                report.summary = sprintf( ...
                    '%d problem(s) found; calibration is incomplete.', ...
                    numel(report.problems));
            end
        end

        function values = mapAxes(obj, rawAxes, activeSignalIndex, captureSamples)
            arguments
                obj
                rawAxes (1,:) double
                activeSignalIndex (1,1) double ...
                    {mustBeInteger, mustBeNonnegative} = 0
                captureSamples double = []
            end
            signals = obj.Signals;
            if activeSignalIndex > 0 && ~isempty(captureSamples)
                signals = obj.signalsForActivePreview( ...
                    signals, activeSignalIndex, captureSamples);
            end
            [values, ~] = ...
                Simulation3DJoystickCalibrator.Services.MappingService.mapPreview( ...
                rawAxes, signals);
        end
    end

    methods (Access = private)
        function signals = signalsForActivePreview( ...
                obj, signals, signalIndex, samples)
            if signalIndex > numel(signals)
                error('Simulation3DJoystickCalibrator:SignalIndex', ...
                    'Signal index %d is outside the calibration contract.', ...
                    signalIndex);
            end
            samples = obj.validateSamples(samples);
            movement = max(samples, [], 1) - min(samples, [], 1);
            unavailable = [obj.Signals(obj.Calibrated).channel];
            if obj.Calibrated(signalIndex)
                ownChannel = obj.Signals(signalIndex).channel;
                unavailable(unavailable == ownChannel) = [];
            end
            unavailable = unavailable(unavailable <= numel(movement));
            movement(unavailable) = -Inf;
            [largestMovement, channel] = max(movement);
            if isempty(channel) || ~isfinite(largestMovement) || ...
                    largestMovement < 0.03
                return;
            end

            signal = signals(signalIndex);
            signal.channel = channel;
            observed = samples(:, channel);
            if channel <= numel(obj.RestMedian) && ...
                    isfinite(obj.RestMedian(channel))
                observed(end + 1, 1) = obj.RestMedian(channel);
                signal.neutral = obj.RestMedian(channel);
                signal.deadband = max(signal.deadband, ...
                    min(0.2, 3 * obj.RestNoise(channel)));
            end
            signal.rawMin = min(observed);
            signal.rawMax = max(observed);
            if signal.rawMin >= signal.rawMax
                return;
            end
            if strcmp(signal.mapping, 'centered')
                signal.neutral = min(max(signal.neutral, ...
                    signal.rawMin), signal.rawMax);
            end
            signals(signalIndex) = signal;
        end

        function samples = validateSamples(~, samples)
            if isempty(samples) || ~ismatrix(samples) || ...
                    any(~isfinite(samples), 'all')
                error('Simulation3DJoystickCalibrator:InvalidSamples', ...
                    'Capture samples must be a nonempty finite numeric matrix.');
            end
            if isvector(samples)
                samples = reshape(samples, 1, []);
            end
            if size(samples, 2) > ...
                    Simulation3DJoystickCalibrator.Services.ConfigurationService.MaxChannels
                error('Simulation3DJoystickCalibrator:TooManyAxes', ...
                    'At most %d input axes are supported.', ...
                    Simulation3DJoystickCalibrator.Services.ConfigurationService.MaxChannels);
            end
        end

        function touch(obj)
            obj.Revision = obj.Revision + 1;
        end
    end
end
