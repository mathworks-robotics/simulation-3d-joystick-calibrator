classdef DemoJoystickAdapter < handle
    %DEMOJOYSTICKADAPTER Deterministic hardware-free app demonstration source.
    %
    % Copyright 2026 The MathWorks, Inc.

    properties (SetAccess = private)
        DeviceID char = 'Demo'
        NumAxes double = 8
        IsConnected logical = false
    end

    properties (Access = private)
        Mode char = 'preview'
        ActiveChannel double = 1
        StartToken
        SampleIndex double = 0
    end

    methods
        function obj = DemoJoystickAdapter(numAxes)
            arguments
                numAxes (1,1) double {mustBeInteger, mustBePositive} = 8
            end
            obj.NumAxes = numAxes;
            obj.StartToken = tic;
        end

        function numAxes = connect(obj, ~)
            obj.IsConnected = true;
            obj.Mode = 'preview';
            obj.StartToken = tic;
            obj.SampleIndex = 0;
            numAxes = obj.NumAxes;
        end

        function axes = readAxes(obj)
            if ~obj.IsConnected
                error('Simulation3DJoystickCalibrator:JoystickDisconnected', ...
                    'Connect the demo input before reading it.');
            end

            obj.SampleIndex = obj.SampleIndex + 1;
            elapsed = toc(obj.StartToken);
            phase = 2 * pi * elapsed;
            axes = zeros(1, obj.NumAxes);
            switch obj.Mode
                case 'rest'
                    axisIndex = 1:obj.NumAxes;
                    axes = 0.002 * sin(0.37 * obj.SampleIndex + axisIndex);
                case 'sweep'
                    axes(obj.ActiveChannel) = sin(phase);
                otherwise
                    count = min(4, obj.NumAxes);
                    for index = 1:count
                        axes(index) = sin(phase * (0.3 + 0.08 * index) + index);
                    end
            end
        end

        function beginRestCapture(obj)
            obj.Mode = 'rest';
            obj.StartToken = tic;
            obj.SampleIndex = 0;
        end

        function beginSignalCapture(obj, signalIndex)
            arguments
                obj
                signalIndex (1,1) double {mustBeInteger, mustBePositive}
            end
            obj.Mode = 'sweep';
            obj.ActiveChannel = min(signalIndex, obj.NumAxes);
            obj.StartToken = tic;
            obj.SampleIndex = 0;
        end

        function beginPreview(obj)
            obj.Mode = 'preview';
            obj.StartToken = tic;
            obj.SampleIndex = 0;
        end

        function disconnect(obj)
            obj.IsConnected = false;
        end

        function delete(obj)
            obj.disconnect();
        end
    end
end
