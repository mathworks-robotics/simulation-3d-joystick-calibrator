classdef MappingService
    %MAPPINGSERVICE Shared mapping implementation for app previews and tests.
    %
    % Copyright 2026 The MathWorks, Inc.

    methods (Static)
        function value = mapSignal(rawValue, signal)
            arguments
                rawValue {mustBeNumeric}
                signal (1,1) struct
            end

            required = {'mapping','rawMin','rawMax','neutral','deadband', ...
                'reverse','outputMin','outputMax'};
            missing = required(~isfield(signal, required));
            if ~isempty(missing)
                error('Simulation3DJoystickCalibrator:InvalidSignal', ...
                    'Signal is missing field(s): %s.', strjoin(missing, ', '));
            end

            switch lower(string(signal.mapping))
                case "centered"
                    value = arrayfun(@(x) simulation3DJoystickMapBipolar(x, ...
                        signal.rawMin, signal.rawMax, signal.neutral, ...
                        signal.deadband, signal.reverse, ...
                        signal.outputMin, signal.outputMax), rawValue);
                case "unipolar"
                    value = arrayfun(@(x) simulation3DJoystickMapThrottle(x, ...
                        signal.rawMin, signal.rawMax, signal.deadband, ...
                        signal.reverse, signal.outputMin, signal.outputMax), ...
                        rawValue);
                otherwise
                    error('Simulation3DJoystickCalibrator:UnsupportedMapping', ...
                        'Unsupported mapping kind "%s".', signal.mapping);
            end
        end

        function [values, names] = mapConfiguration(rawAxes, cfg)
            arguments
                rawAxes (1,:) double
                cfg (1,1) struct
            end

            [cfg, report] = ...
                Simulation3DJoystickCalibrator.Services.ConfigurationService.normalize(cfg);
            if ~report.ok
                error('Simulation3DJoystickCalibrator:InvalidConfiguration', ...
                    '%s', strjoin(report.problems, newline));
            end

            values = zeros(1, numel(cfg.signals));
            names = string({cfg.signals.outputName});
            for index = 1:numel(cfg.signals)
                signal = cfg.signals(index);
                if signal.channel > numel(rawAxes)
                    error('Simulation3DJoystickCalibrator:MissingAxis', ...
                        'Input contains %d axes, but %s uses channel %d.', ...
                        numel(rawAxes), signal.label, signal.channel);
                end
                values(index) = ...
                    Simulation3DJoystickCalibrator.Services.MappingService.mapSignal( ...
                        rawAxes(signal.channel), signal);
            end
        end

        function [values, names] = mapPreview(rawAxes, signals)
            %MAPPREVIEW Map each row independently during partial calibration.
            arguments
                rawAxes (1,:) double
                signals struct
            end

            signals = reshape(signals, 1, []);
            values = zeros(1, numel(signals));
            names = string({signals.outputName});
            for index = 1:numel(signals)
                signal = signals(index);
                channel = signal.channel;
                if ~(isnumeric(channel) && isscalar(channel) && ...
                        isfinite(channel) && channel == round(channel) && ...
                        channel >= 1 && channel <= numel(rawAxes))
                    continue;
                end
                values(index) = ...
                    Simulation3DJoystickCalibrator.Services.MappingService.mapSignal( ...
                        rawAxes(channel), signal);
            end
        end

        function [values, names] = mapForProfile(rawAxes, cfg, profileID)
            %MAPFORPROFILE Apply one shared calibration to a block contract.
            arguments
                rawAxes (1,:) double
                cfg (1,1) struct
                profileID {mustBeTextScalar}
            end

            [cfg, report] = ...
                Simulation3DJoystickCalibrator.Services.ConfigurationService.normalize(cfg);
            if ~report.ok
                error('Simulation3DJoystickCalibrator:InvalidConfiguration', ...
                    '%s', strjoin(report.problems, newline));
            end
            profile = ...
                Simulation3DJoystickCalibrator.Services.ProfileCatalog.get(profileID);

            values = zeros(1, numel(cfg.signals));
            names = string({profile.signals.outputName});
            for index = 1:numel(cfg.signals)
                signal = cfg.signals(index);
                if signal.channel > numel(rawAxes)
                    error('Simulation3DJoystickCalibrator:MissingAxis', ...
                        'Input contains %d axes, but %s uses channel %d.', ...
                        numel(rawAxes), signal.label, signal.channel);
                end
                if ~strcmp(profile.id, 'fixed-wing')
                    signal.outputMin = profile.signals(index).outputMin;
                    signal.outputMax = profile.signals(index).outputMax;
                end
                values(index) = ...
                    Simulation3DJoystickCalibrator.Services.MappingService.mapSignal( ...
                        rawAxes(signal.channel), signal);
            end
        end
    end
end
