classdef MainViewModel < handle
    %MAINVIEWMODEL State and commands for the shared calibration dashboard.
    %
    % Copyright 2026 The MathWorks, Inc.

    properties (SetObservable, SetAccess = private)
        DeviceID char = 'Joystick1'
        NumAxes double = 4
        IsConnected logical = false
        RestCaptured logical = false
        SignalCaptured logical = false(1, 4)
        SignalVerified logical = false(1, 4)
        SignalNames string = ["Roll", "Pitch", "Yaw", "Throttle"]
        ActiveSignalIndex double = 0
        TableData table = table()
        RawValues double = zeros(1, 4)
        PreviewValues double = zeros(1, 4)
        StatusMessage char = 'Select a device and connect.'
        CanSave logical = false
        IsCapturing logical = false
        CaptureProgress double = 0
        UiRevision double = 0
        PreviewRevision double = 0
    end

    properties (Access = private)
        Model
        Adapter
        ModelListeners cell = {}
        CaptureTimer = []
        PreviewTimer = []
        CaptureSamples double = []
        CaptureKind char = ''
        CaptureSignalIndex double = 0
        CaptureFailure = []
        CaptureCancelled logical = false
    end

    methods
        function obj = MainViewModel(model, adapter)
            arguments
                model Simulation3DJoystickCalibrator.Models.CalibrationModel
                adapter
            end
            requiredMethods = {'connect','readAxes','disconnect', ...
                'beginRestCapture','beginSignalCapture'};
            for index = 1:numel(requiredMethods)
                if ~ismethod(adapter, requiredMethods{index})
                error('Simulation3DJoystickCalibrator:InvalidAdapter', ...
                        'Hardware adapter must implement %s().', ...
                        requiredMethods{index});
                end
            end

            obj.Model = model;
            obj.Adapter = adapter;
            if isa(adapter, ...
                    'Simulation3DJoystickCalibrator.Hardware.DemoJoystickAdapter')
                obj.Model.setDevice('Demo');
            end
            obj.ModelListeners{end+1} = addlistener( ...
                model, 'Revision', 'PostSet', @(~,~) obj.syncFromModel());
            obj.syncFromModel();
        end

        function delete(obj)
            obj.cancelCapture();
            obj.stopPreview();
            for index = 1:numel(obj.ModelListeners)
                try
                    delete(obj.ModelListeners{index});
                catch
                end
            end
            obj.ModelListeners = {};
            try
                obj.Adapter.disconnect();
            catch
            end
        end

        function setDeviceCommand(obj, deviceID)
            arguments
                obj
                deviceID {mustBeTextScalar}
            end
            obj.stopPreview();
            obj.Model.setDevice(deviceID);
            obj.ActiveSignalIndex = 0;
            obj.RawValues = zeros(1, obj.NumAxes);
            obj.PreviewValues = zeros(1, 4);
            obj.setStatus(sprintf('Ready to connect to %s.', string(deviceID)));
            obj.touchPreview();
        end

        function success = connectCommand(obj)
            success = false;
            if obj.IsCapturing
                return;
            end
            obj.stopPreview();
            obj.setStatus(sprintf('Connecting to %s...', obj.Model.DeviceID));
            try
                numAxes = obj.Adapter.connect(obj.Model.DeviceID);
                obj.Model.setConnected(true, numAxes);
                obj.ActiveSignalIndex = 0;
                obj.RawValues = zeros(1, numAxes);
                obj.PreviewValues = zeros(1, 4);
                unavailable = [obj.Model.Signals.channel] > numAxes;
                if any(unavailable)
                    obj.SignalVerified(unavailable) = false;
                    obj.setStatus(sprintf( ...
                        ['Connected to %s (%d axes), but the loaded calibration ' ...
                         'uses unavailable channel(s): %s. Edit or re-capture them.'], ...
                        obj.Model.DeviceID, numAxes, ...
                        strjoin(string(find(unavailable)), ', ')));
                elseif all(obj.SignalCaptured)
                    obj.setStatus(sprintf( ...
                        ['Connected to %s (%d axes). Loaded calibration is ready; ' ...
                         'verify the live preview or edit values.'], ...
                        obj.Model.DeviceID, numAxes));
                else
                    obj.setStatus(sprintf( ...
                        'Connected to %s (%d axes). Capture center next.', ...
                        obj.Model.DeviceID, numAxes));
                end
                obj.startPreview();
                obj.touchPreview();
                success = true;
            catch exception
                try
                    obj.Adapter.disconnect();
                catch
                end
                obj.Model.setConnected(false, obj.Model.NumAxes);
                obj.setStatus(sprintf( ...
                    'Connection failed: %s', exception.message));
            end
        end

        function startRestCaptureCommand(obj, duration)
            arguments
                obj
                duration (1,1) double {mustBePositive} = 1.5
            end
            obj.SignalCaptured(:) = false;
            obj.SignalVerified(:) = false;
            obj.ActiveSignalIndex = 0;
            obj.startCapture('rest', 0, duration);
        end

        function startSignalCaptureCommand(obj, signalIndex, duration)
            arguments
                obj
                signalIndex (1,1) double {mustBeInteger, mustBePositive}
                duration (1,1) double {mustBePositive} = 3
            end
            if signalIndex > numel(obj.SignalNames)
                error('Simulation3DJoystickCalibrator:SignalIndex', ...
                    'Signal index %d is outside the calibration contract.', ...
                    signalIndex);
            end
            obj.SignalCaptured(signalIndex) = false;
            obj.SignalVerified(signalIndex) = false;
            obj.ActiveSignalIndex = signalIndex;
            obj.startCapture('signal', signalIndex, duration);
        end

        function signalActionCommand(obj, signalIndex, duration)
            arguments
                obj
                signalIndex (1,1) double {mustBeInteger, mustBePositive}
                duration (1,1) double {mustBePositive} = 3
            end
            if obj.IsCapturing
                return;
            end
            if obj.SignalCaptured(signalIndex) && ...
                    ~obj.SignalVerified(signalIndex) && ...
                    obj.ActiveSignalIndex == signalIndex
                obj.confirmSignalCommand(signalIndex);
            else
                obj.startSignalCaptureCommand(signalIndex, duration);
            end
        end

        function confirmSignalCommand(obj, signalIndex)
            arguments
                obj
                signalIndex (1,1) double {mustBeInteger, mustBePositive}
            end
            if signalIndex > numel(obj.SignalCaptured) || ...
                    ~obj.SignalCaptured(signalIndex)
                obj.setStatus('Capture this control before confirming it.');
                return;
            end
            obj.SignalVerified(signalIndex) = true;
            obj.ActiveSignalIndex = 0;
            obj.updateCanSave();
            if all(obj.SignalVerified)
                obj.setStatus( ...
                    'All four controls are verified. Review the table and save.');
            else
                obj.setStatus( ...
                    'Direction confirmed. Sweep the next control.');
            end
            obj.touch();
        end

        function applyRestSamples(obj, samples)
            arguments
                obj
                samples double
            end
            obj.Model.captureRest(samples);
            obj.SignalCaptured(:) = false;
            obj.SignalVerified(:) = false;
            obj.ActiveSignalIndex = 0;
            obj.CaptureProgress = 1;
            obj.setStatus('Center captured. Sweep and verify each control.');
        end

        function channel = applySignalSamples(obj, signalIndex, samples)
            arguments
                obj
                signalIndex (1,1) double {mustBeInteger, mustBePositive}
                samples double
            end
            channel = obj.Model.captureSignal(signalIndex, samples);
            obj.SignalCaptured = obj.Model.Calibrated;
            obj.SignalVerified(signalIndex) = false;
            obj.ActiveSignalIndex = signalIndex;
            obj.CaptureProgress = 1;
            assignedChannels = [obj.Model.Signals.channel];
            sharedRows = find(assignedChannels == channel);
            sharedRows(sharedRows == signalIndex) = [];
            if isempty(sharedRows)
                obj.setStatus(sprintf( ...
                    ['%s mapped to channel %d. Check the calibrated preview, ' ...
                     'set Reverse if needed, then click Confirm %s.'], ...
                    obj.SignalNames(signalIndex), channel, ...
                    obj.SignalNames(signalIndex)));
            else
                sharedNames = strjoin(obj.SignalNames(sharedRows), ', ');
                obj.setStatus(sprintf([ ...
                    '%s mapped to channel %d. Unswept control(s) %s temporarily ' ...
                    'share this channel, so their preview bars move too. Sweep ' ...
                    'them next to assign their actual channels.'], ...
                    obj.SignalNames(signalIndex), channel, sharedNames));
            end
        end

        function updateSignalCommand(obj, signalIndex, fieldName, value)
            arguments
                obj
                signalIndex (1,1) double {mustBeInteger, mustBePositive}
                fieldName {mustBeTextScalar}
                value
            end
            isOutputRangeEdit = any(strcmp(char(string(fieldName)), ...
                {'outputMin','outputMax'}));
            try
                obj.Model.updateSignal(signalIndex, fieldName, value);
                obj.SignalCaptured = obj.Model.Calibrated;
                if obj.SignalCaptured(signalIndex) && ~isOutputRangeEdit
                    obj.SignalVerified(signalIndex) = false;
                    obj.ActiveSignalIndex = signalIndex;
                end
                obj.updateCanSave();
                if isOutputRangeEdit
                    obj.updatePreview(obj.RawValues);
                    obj.setStatus(sprintf([ ...
                        '%s Fixed-Wing output range updated. Multirotor and ' ...
                        'Helicopter outputs remain normalized.'], ...
                        obj.SignalNames(signalIndex)));
                elseif obj.SignalCaptured(signalIndex)
                    obj.setStatus(sprintf( ...
                        '%s updated; confirm its direction again.', ...
                        obj.SignalNames(signalIndex)));
                else
                    obj.setStatus(sprintf( ...
                        '%s updated. Sweep it before confirmation.', ...
                        obj.SignalNames(signalIndex)));
                end
            catch exception
                obj.syncFromModel();
                obj.setStatus(sprintf( ...
                    'Value not accepted: %s', exception.message));
            end
        end

        function setReverseCommand(obj, signalIndex, reverse)
            arguments
                obj
                signalIndex (1,1) double {mustBeInteger, mustBePositive}
                reverse (1,1) logical
            end
            obj.updateSignalCommand(signalIndex, 'reverse', reverse);
        end

        function [rawValues, mappedValues] = previewCommand(obj)
            rawValues = obj.RawValues;
            mappedValues = obj.PreviewValues;
            if ~obj.Model.IsConnected
                obj.setStatus( ...
                    'Connect the selected input before previewing it.');
                return;
            end
            try
                rawValues = obj.Adapter.readAxes();
                obj.updatePreview(rawValues);
                mappedValues = obj.PreviewValues;
            catch exception
                obj.setStatus(sprintf( ...
                    'Preview failed: %s', exception.message));
            end
        end

        function [success, report] = loadCommand(obj, filePath)
            arguments
                obj
                filePath {mustBeTextScalar}
            end
            [cfg, report] = ...
                Simulation3DJoystickCalibrator.Services.ConfigurationService.load(filePath);
            success = report.ok;
            if ~success
                obj.setStatus(sprintf( ...
                    'Load failed: %s', strjoin(report.problems, ' ')));
                return;
            end
            obj.Model.loadConfiguration(cfg);
            obj.SignalCaptured(:) = true;
            obj.SignalVerified(:) = true;
            obj.ActiveSignalIndex = 0;
            obj.RawValues = zeros(1, obj.Model.NumAxes);
            obj.PreviewValues = zeros(1, 4);
            obj.updateCanSave();
            obj.setStatus('Calibration loaded. Adjust values or save a copy.');
            obj.touch();
            obj.touchPreview();
        end

        function cfg = saveCommand(obj, filePath)
            arguments
                obj
                filePath {mustBeTextScalar}
            end
            [ok, report] = obj.Model.validate();
            if ~ok || ~all(obj.SignalVerified)
                if isempty(report.problems)
                    detail = 'Verify all four controls before saving.';
                else
                    detail = strjoin(report.problems, newline);
                end
                error('Simulation3DJoystickCalibrator:IncompleteCalibration', ...
                    '%s', detail);
            end
            filePath = char(string(filePath));
            [folder, name, extension] = fileparts(filePath);
            if isempty(extension)
                filePath = fullfile(folder, [name '.mat']);
            end
            cfg = Simulation3DJoystickCalibrator.Services.ConfigurationService.save( ...
                obj.Model.configuration(), filePath);
            obj.setStatus(sprintf('Calibration saved to %s.', filePath));
        end

        function cfg = configuration(obj)
            cfg = obj.Model.configuration();
        end

        function cancelCapture(obj)
            timerObject = obj.CaptureTimer;
            if isempty(timerObject)
                return;
            end
            obj.CaptureCancelled = true;
            try
                stop(timerObject);
            catch
            end
            try
                delete(timerObject);
            catch
            end
            obj.CaptureTimer = [];
            obj.IsCapturing = false;
            obj.CaptureProgress = 0;
            if obj.IsConnected
                obj.startPreview();
            end
            obj.updateCanSave();
            obj.touch();
        end
    end

    methods (Access = private)
        function startCapture(obj, kind, signalIndex, duration)
            if ~obj.Model.IsConnected
                obj.setStatus('Connect the selected input device first.');
                return;
            end
            if obj.IsCapturing
                obj.setStatus('A capture is already in progress.');
                return;
            end
            if strcmp(kind, 'signal') && ~obj.Model.RestCaptured
                obj.setStatus('Capture center before sweeping controls.');
                return;
            end

            if strcmp(kind, 'rest')
                obj.Adapter.beginRestCapture();
                prompt = ...
                    'Center Roll, Pitch, and Yaw; place Throttle at rest; hold still.';
            else
                obj.Adapter.beginSignalCapture(signalIndex);
                prompt = sprintf( ...
                    'Move only %s through its full travel.', ...
                    obj.SignalNames(signalIndex));
            end

            obj.stopPreview();
            period = 0.03;
            obj.CaptureKind = kind;
            obj.CaptureSignalIndex = signalIndex;
            obj.CaptureSamples = [];
            obj.CaptureFailure = [];
            obj.CaptureCancelled = false;
            obj.CaptureProgress = 0;
            obj.IsCapturing = true;
            obj.setStatus(prompt);

            obj.CaptureTimer = timer( ...
                'ExecutionMode', 'fixedRate', ...
                'BusyMode', 'drop', ...
                'Period', period, ...
                'TasksToExecute', max(3, ceil(duration / period)), ...
                'TimerFcn', @(timerObject, ~) ...
                    obj.onCaptureTick(timerObject), ...
                'StopFcn', @(timerObject, ~) ...
                    obj.onCaptureStopped(timerObject));
            start(obj.CaptureTimer);
        end

        function onCaptureTick(obj, timerObject)
            try
                sample = double(obj.Adapter.readAxes());
                sample = reshape(sample, 1, []);
                if isempty(obj.CaptureSamples)
                    obj.CaptureSamples = sample;
                elseif size(obj.CaptureSamples, 2) == numel(sample)
                    obj.CaptureSamples(end + 1, :) = sample;
                else
                error('Simulation3DJoystickCalibrator:AxisCountChanged', ...
                        'The input axis count changed during capture.');
                end
                obj.updatePreview(sample);
                obj.CaptureProgress = min(1, ...
                    timerObject.TasksExecuted / timerObject.TasksToExecute);
                obj.touch();
            catch exception
                obj.CaptureFailure = exception;
                stop(timerObject);
            end
        end

        function onCaptureStopped(obj, timerObject)
            samples = obj.CaptureSamples;
            kind = obj.CaptureKind;
            signalIndex = obj.CaptureSignalIndex;
            failure = obj.CaptureFailure;
            cancelled = obj.CaptureCancelled;

            try
                delete(timerObject);
            catch
            end
            obj.CaptureTimer = [];
            obj.IsCapturing = false;

            if cancelled
                obj.CaptureProgress = 0;
            elseif ~isempty(failure)
                obj.CaptureProgress = 0;
                obj.setStatus(sprintf( ...
                    'Capture failed: %s', failure.message));
            else
                try
                    if strcmp(kind, 'rest')
                        obj.applyRestSamples(samples);
                    else
                        obj.applySignalSamples(signalIndex, samples);
                    end
                catch exception
                    obj.CaptureProgress = 0;
                    obj.setStatus(sprintf( ...
                        'Capture failed: %s', exception.message));
                end
            end
            if obj.IsConnected
                obj.startPreview();
            end
            obj.updateCanSave();
            obj.touch();
        end

        function startPreview(obj)
            obj.stopPreview();
            if ~obj.Model.IsConnected
                return;
            end
            if ismethod(obj.Adapter, 'beginPreview')
                obj.Adapter.beginPreview();
            end
            obj.PreviewTimer = timer( ...
                'ExecutionMode', 'fixedRate', ...
                'BusyMode', 'drop', ...
                'Period', 0.04, ...
                'TimerFcn', @(~,~) obj.onPreviewTick());
            start(obj.PreviewTimer);
        end

        function stopPreview(obj)
            timerObject = obj.PreviewTimer;
            obj.PreviewTimer = [];
            if isempty(timerObject)
                return;
            end
            try
                stop(timerObject);
            catch
            end
            try
                delete(timerObject);
            catch
            end
        end

        function onPreviewTick(obj)
            try
                obj.updatePreview(obj.Adapter.readAxes());
            catch exception
                obj.stopPreview();
                obj.setStatus(sprintf( ...
                    'Preview stopped: %s', exception.message));
            end
        end

        function updatePreview(obj, rawValues)
            rawValues = reshape(double(rawValues), 1, []);
            obj.RawValues = rawValues;
            try
                if obj.IsCapturing && strcmp(obj.CaptureKind, 'signal')
                    obj.PreviewValues = obj.Model.mapAxes( ...
                        rawValues, obj.CaptureSignalIndex, obj.CaptureSamples);
                else
                    obj.PreviewValues = obj.Model.mapAxes(rawValues);
                end
            catch
                obj.PreviewValues = zeros(1, numel(obj.SignalNames));
            end
            obj.touchPreview();
        end

        function syncFromModel(obj)
            model = obj.Model;
            obj.DeviceID = model.DeviceID;
            obj.NumAxes = model.NumAxes;
            obj.IsConnected = model.IsConnected;
            obj.RestCaptured = model.RestCaptured;
            obj.SignalNames = string({model.Signals.label});
            captured = reshape(logical(model.Calibrated), 1, []);
            if numel(obj.SignalVerified) ~= numel(captured)
                obj.SignalVerified = false(size(captured));
            else
                obj.SignalVerified = obj.SignalVerified & captured;
            end
            obj.SignalCaptured = captured;
            obj.TableData = obj.makeTable(model.Signals);
            obj.updateCanSave();
            obj.touch();
        end

        function updateCanSave(obj)
            [ok, ~] = obj.Model.validate();
            obj.CanSave = ok && all(obj.SignalVerified);
        end

        function setStatus(obj, message)
            obj.StatusMessage = char(string(message));
            obj.updateCanSave();
            obj.touch();
        end

        function touch(obj)
            obj.UiRevision = obj.UiRevision + 1;
        end

        function touchPreview(obj)
            obj.PreviewRevision = obj.PreviewRevision + 1;
        end
    end

    methods (Static, Access = private)
        function data = makeTable(signals)
            count = numel(signals);
            data = table( ...
                string({signals.label}).', ...
                reshape([signals.channel], count, 1), ...
                reshape([signals.rawMin], count, 1), ...
                reshape([signals.rawMax], count, 1), ...
                reshape([signals.deadband], count, 1), ...
                reshape(logical([signals.reverse]), count, 1), ...
                reshape([signals.outputMin], count, 1), ...
                reshape([signals.outputMax], count, 1), ...
                string({signals.unit}).', ...
                'VariableNames', {'Control','Channel','RawMin','RawMax', ...
                'Deadband','Reverse','OutputMin','OutputMax','Unit'});
        end
    end
end
