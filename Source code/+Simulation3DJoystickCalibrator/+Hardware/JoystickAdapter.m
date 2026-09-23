classdef JoystickAdapter < handle
    %JOYSTICKADAPTER Runtime adapter around sim3d.io.Joystick.
    %
    % Copyright 2026 The MathWorks, Inc.

    properties (SetAccess = private)
        DeviceID char = 'Joystick1'
        NumAxes double = 0
        IsConnected logical = false
    end

    properties (Access = private)
        Device = []
    end

    methods
        function numAxes = connect(obj, deviceID)
            arguments
                obj
                deviceID {mustBeTextScalar}
            end

            obj.disconnect();
            numericID = obj.parseDeviceID(deviceID);
            try
                obj.Device = sim3d.io.Joystick(ID=numericID);
                axes = read(obj.Device);
            catch exception
                obj.disconnect();
                error('Simulation3DJoystickCalibrator:JoystickConnection', ...
                    'Could not open joystick %d: %s', numericID, ...
                    exception.message);
            end
            obj.DeviceID = sprintf('Joystick%d', numericID);
            obj.NumAxes = numel(axes);
            obj.IsConnected = true;
            numAxes = obj.NumAxes;
        end

        function axes = readAxes(obj)
            if ~obj.IsConnected || isempty(obj.Device)
                error('Simulation3DJoystickCalibrator:JoystickDisconnected', ...
                    'Connect a joystick before reading inputs.');
            end
            try
                axes = double(read(obj.Device));
                axes = reshape(axes, 1, []);
            catch exception
                error('Simulation3DJoystickCalibrator:JoystickRead', ...
                    'Could not read %s: %s', obj.DeviceID, exception.message);
            end
        end

        function beginRestCapture(~)
        end

        function beginSignalCapture(~, ~)
        end

        function beginPreview(~)
        end

        function disconnect(obj)
            device = obj.Device;
            obj.Device = [];
            obj.IsConnected = false;
            obj.NumAxes = 0;
            if isempty(device)
                return;
            end
            try
                close(device);
            catch
            end
            try
                delete(device);
            catch
            end
        end

        function delete(obj)
            obj.disconnect();
        end
    end

    methods (Static, Access = private)
        function numericID = parseDeviceID(deviceID)
            value = string(deviceID);
            token = regexp(value, '\d+', 'match', 'once');
            if isempty(token)
                numericID = str2double(value);
            else
                numericID = str2double(token);
            end
            if ~isfinite(numericID) || numericID < 1 || numericID ~= round(numericID)
                error('Simulation3DJoystickCalibrator:InvalidDeviceID', ...
                    'Device ID must identify Joystick1 through Joystick12.');
            end
        end
    end
end
