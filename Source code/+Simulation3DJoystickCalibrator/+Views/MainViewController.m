classdef MainViewController < handle
    %MAINVIEWCONTROLLER Bind the App Designer view to the shared ViewModel.
    %
    % Copyright 2026 The MathWorks, Inc.

    properties (Constant, Access = private)
        Blue = [0 0.4470 0.7410]
        Green = [0.4660 0.6740 0.1880]
        Orange = [0.8500 0.3250 0.0980]
        Gray = [0.46 0.46 0.46]
        BarGray = [0.45 0.45 0.45]
        TextColor = [0.91 0.91 0.91]
        PanelBase = [0.16 0.16 0.16]
        PanelTint = [0.22 0.17 0.13]
    end

    properties (Access = private)
        App
        ViewModel
        Listeners cell = {}

        SignalLamps = gobjects(1, 4)
        SweepButtons = gobjects(1, 4)
        StepPanels = gobjects(1, 3)
        StepAccents = gobjects(1, 3)
        StepBadges = gobjects(1, 3)

        RawBars
        RawLabels = gobjects(1, 0)
        NormalizedBars
        NormalizedLabels = gobjects(1, 4)
        ProgressFill
        OverviewFigure

        LastAxisCount double = 0
        LastActiveRow double = NaN
        RawDisplayLimits double = [-1 1]
    end

    methods
        function obj = MainViewController(app, viewModel)
            arguments
                app
                viewModel ...
                    Simulation3DJoystickCalibrator.ViewModels.MainViewModel
            end

            obj.App = app;
            obj.ViewModel = viewModel;
            obj.captureComponentGroups();
            obj.configureDeviceItems();
            obj.initializeGraphics();
            obj.bindToViewModel();
            obj.syncState();
            obj.syncPreview();
        end

        function delete(obj)
            for index = 1:numel(obj.Listeners)
                try
                    delete(obj.Listeners{index});
                catch
                end
            end
            obj.Listeners = {};
            obj.closeOverviewFigure();
            obj.App = [];
            obj.ViewModel = [];
        end

        function connectCommand(obj)
            obj.ViewModel.setDeviceCommand(obj.App.DeviceDropDown.Value);
            obj.ViewModel.connectCommand();
        end

        function centerCommand(obj)
            obj.ViewModel.startRestCaptureCommand();
        end

        function signalActionCommand(obj, signalIndex)
            arguments
                obj
                signalIndex (1,1) double {mustBeInteger, mustBePositive}
            end
            obj.ViewModel.signalActionCommand(signalIndex);
        end

        function tableEditCommand(obj, event)
            if numel(event.Indices) ~= 2
                return;
            end
            fieldNames = {'', 'channel', 'rawMin', 'rawMax', ...
                'deadband', 'reverse', 'outputMin', 'outputMax', ''};
            fieldName = fieldNames{event.Indices(2)};
            if isempty(fieldName)
                obj.syncState();
                return;
            end
            obj.ViewModel.updateSignalCommand( ...
                event.Indices(1), fieldName, event.NewData);
        end

        function loadCommand(obj)
            [fileName, folder] = uigetfile('*.mat', ...
                'Edit existing calibration', ...
                fullfile(pwd, '*.mat'));
            if isequal(fileName, 0)
                return;
            end
            [success, report] = ...
                obj.ViewModel.loadCommand(fullfile(folder, fileName));
            if ~success
                uialert(obj.App.UIFigure, ...
                    strjoin(report.problems, newline), ...
                    'Not a valid calibration file', ...
                    'Icon', 'error');
                return;
            end
            obj.rebuildRawPlot();
            if ~isempty(report.warnings)
                uialert(obj.App.UIFigure, ...
                    strjoin(report.warnings, newline), ...
                    'Loaded with warnings', ...
                    'Icon', 'warning');
            end
        end

        function saveCommand(obj)
            if ~obj.ViewModel.CanSave
                obj.App.InstructionLabel.Text = ...
                    'Capture center and verify all four controls before saving.';
                return;
            end
            deviceName = regexprep(obj.ViewModel.DeviceID, '\W', '');
            if isempty(deviceName)
                deviceName = 'Controller';
            end
            defaultName = sprintf( ...
                '%s_simulation_3d_joystick.mat', deviceName);
            [fileName, folder] = uiputfile('*.mat', ...
                'Save calibration', fullfile(pwd, defaultName));
            if isequal(fileName, 0)
                return;
            end
            try
                obj.ViewModel.saveCommand(fullfile(folder, fileName));
            catch exception
                uialert(obj.App.UIFigure, exception.message, ...
                    'Save failed', 'Icon', 'error');
            end
        end

        function showOverview(obj)
            obj.showStartupOverview();
        end
    end

    methods (Access = private)
        function captureComponentGroups(obj)
            obj.SignalLamps(1) = obj.App.RollSignalLamp;
            obj.SignalLamps(2) = obj.App.PitchSignalLamp;
            obj.SignalLamps(3) = obj.App.YawSignalLamp;
            obj.SignalLamps(4) = obj.App.ThrottleSignalLamp;

            obj.SweepButtons(1) = obj.App.RollSweepButton;
            obj.SweepButtons(2) = obj.App.PitchSweepButton;
            obj.SweepButtons(3) = obj.App.YawSweepButton;
            obj.SweepButtons(4) = obj.App.ThrottleSweepButton;

            obj.StepPanels(1) = obj.App.ConnectPanel;
            obj.StepPanels(2) = obj.App.CenterPanel;
            obj.StepPanels(3) = obj.App.SweepPanel;

            obj.StepAccents(1) = obj.App.ConnectAccent;
            obj.StepAccents(2) = obj.App.CenterAccent;
            obj.StepAccents(3) = obj.App.SweepAccent;

            obj.StepBadges(1) = obj.App.ConnectBadge;
            obj.StepBadges(2) = obj.App.CenterBadge;
            obj.StepBadges(3) = obj.App.SweepBadge;
        end

        function configureDeviceItems(obj)
            ids = arrayfun(@(index) sprintf('Joystick%d', index), ...
                1:12, 'UniformOutput', false);
            if strcmp(obj.ViewModel.DeviceID, 'Demo')
                ids = [{'Demo'}, ids];
            end
            obj.App.DeviceDropDown.Items = ids;
            obj.App.DeviceDropDown.Value = obj.ViewModel.DeviceID;
        end

        function initializeGraphics(obj)
            obj.trimAxes(obj.App.ProgressAxes);
            xlim(obj.App.ProgressAxes, [0 4]);
            ylim(obj.App.ProgressAxes, [0 1]);
            patch(obj.App.ProgressAxes, [0 4 4 0], [0 0 1 1], ...
                obj.PanelBase + 0.08, 'EdgeColor', 'none');
            obj.ProgressFill = patch(obj.App.ProgressAxes, ...
                [0 0 0 0], [0 0 1 1], obj.Green, ...
                'EdgeColor', 'none');

            obj.rebuildRawPlot();

            cla(obj.App.NormalizedAxes);
            title(obj.App.NormalizedAxes, 'Calibrated output preview');
            obj.NormalizedBars = bar(obj.App.NormalizedAxes, ...
                1:4, zeros(1, 4), ...
                'FaceColor', obj.Blue, ...
                'Tag', 'NormalizedOutputBars');
            obj.App.NormalizedAxes.XTick = 1:4;
            obj.App.NormalizedAxes.XTickLabel = ...
                cellstr(obj.ViewModel.SignalNames);
            ylim(obj.App.NormalizedAxes, [-1.25 1.25]);
            for index = 1:4
                obj.NormalizedLabels(index) = text( ...
                    obj.App.NormalizedAxes, index, 0, '', ...
                    'HorizontalAlignment', 'center', ...
                    'FontWeight', 'bold', ...
                    'FontSize', 10, ...
                    'Color', obj.TextColor, ...
                    'Clipping', 'off');
            end
            obj.cleanPlotAxes(obj.App.NormalizedAxes);
        end

        function bindToViewModel(obj)
            obj.Listeners{end+1} = addlistener( ...
                obj.ViewModel, 'UiRevision', 'PostSet', ...
                @(~,~) obj.syncState());
            obj.Listeners{end+1} = addlistener( ...
                obj.ViewModel, 'PreviewRevision', 'PostSet', ...
                @(~,~) obj.syncPreview());
        end

        function syncState(obj)
            if ~obj.isViewAlive()
                return;
            end
            vm = obj.ViewModel;
            if obj.LastAxisCount ~= vm.NumAxes
                obj.rebuildRawPlot();
            end
            if any(strcmp(obj.App.DeviceDropDown.Items, vm.DeviceID))
                obj.App.DeviceDropDown.Value = vm.DeviceID;
            end
            if vm.IsConnected
                obj.App.ConnectionLamp.Color = obj.Green;
                obj.App.ConnectionLabel.Text = sprintf( ...
                    'Connected - %d axes', vm.NumAxes);
            else
                obj.App.ConnectionLamp.Color = obj.Gray;
                obj.App.ConnectionLabel.Text = 'Not connected';
            end

            obj.App.CenterButton.Text = obj.chooseText(vm.RestCaptured, ...
                'Re-capture center', 'Center & hold');
            obj.App.InstructionLabel.Text = vm.StatusMessage;
            if ~isequaln(obj.App.CalibrationTable.Data, vm.TableData)
                obj.App.CalibrationTable.Data = vm.TableData;
                obj.centerTable();
                obj.LastActiveRow = NaN;
            end

            for index = 1:4
                label = char(vm.SignalNames(index));
                if vm.IsCapturing && vm.ActiveSignalIndex == index
                    obj.SignalLamps(index).Color = obj.Orange;
                    obj.SweepButtons(index).Text = 'Sweeping...';
                    obj.SweepButtons(index).FontColor = obj.Orange;
                elseif vm.SignalVerified(index)
                    obj.SignalLamps(index).Color = obj.Green;
                    obj.SweepButtons(index).Text = [label ' OK'];
                    obj.SweepButtons(index).FontColor = obj.Green;
                elseif vm.SignalCaptured(index) && ...
                        vm.ActiveSignalIndex == index
                    obj.SignalLamps(index).Color = obj.Orange;
                    obj.SweepButtons(index).Text = ['Confirm ' label];
                    obj.SweepButtons(index).FontColor = obj.Orange;
                else
                    obj.SignalLamps(index).Color = obj.Gray;
                    obj.SweepButtons(index).Text = ['Sweep ' label];
                    obj.SweepButtons(index).FontColor = obj.TextColor;
                end
            end

            obj.updateProgress();
            obj.updateSteps();
            obj.updateEnabledState();
            if ~isequal(obj.LastActiveRow, vm.ActiveSignalIndex)
                obj.setActiveRow(vm.ActiveSignalIndex);
            end
        end

        function syncPreview(obj)
            if ~obj.isViewAlive()
                return;
            end
            vm = obj.ViewModel;
            if obj.LastAxisCount ~= vm.NumAxes
                obj.rebuildRawPlot();
            end

            raw = vm.RawValues;
            rawData = zeros(1, obj.LastAxisCount);
            count = min(numel(rawData), numel(raw));
            rawData(1:count) = raw(1:count);
            if ~isempty(obj.RawBars) && isvalid(obj.RawBars)
                obj.RawBars.YData = rawData;
                colors = repmat(obj.BarGray, obj.LastAxisCount, 1);
                active = vm.ActiveSignalIndex;
                if active >= 1 && active <= height(vm.TableData)
                    channel = vm.TableData.Channel(active);
                    if channel >= 1 && channel <= obj.LastAxisCount
                        colors(channel, :) = obj.Blue;
                    end
                end
                obj.RawBars.CData = colors;
                obj.updateRawLimits(rawData);
                for index = 1:numel(obj.RawLabels)
                    obj.RawLabels(index).Position = [index, ...
                        obj.labelY(rawData(index), obj.App.RawAxes.YLim), 0];
                    obj.RawLabels(index).String = ...
                        sprintf('%.2f', rawData(index));
                end
            end

            normalized = vm.PreviewValues;
            if numel(normalized) < 4
                normalized(end+1:4) = 0;
            end
            normalized = normalized(1:4);
            obj.NormalizedBars.YData = normalized;
            obj.updateOutputLimits(normalized);
            for index = 1:4
                obj.NormalizedLabels(index).Position = [index, ...
                    obj.labelY(normalized(index), ...
                    obj.App.NormalizedAxes.YLim), 0];
                obj.NormalizedLabels(index).String = ...
                    sprintf('%.2f', normalized(index));
            end
            drawnow limitrate nocallbacks;
        end

        function rebuildRawPlot(obj)
            if ~obj.isViewAlive()
                return;
            end
            count = max(1, obj.ViewModel.NumAxes);
            cla(obj.App.RawAxes);
            title(obj.App.RawAxes, 'Raw channels');
            obj.RawBars = bar(obj.App.RawAxes, ...
                1:count, zeros(1, count), ...
                'FaceColor', 'flat', ...
                'Tag', 'RawChannelBars');
            obj.RawBars.CData = repmat(obj.BarGray, count, 1);
            obj.App.RawAxes.XTick = 1:count;
            obj.RawLabels = gobjects(1, count);
            for index = 1:count
                obj.RawLabels(index) = text(obj.App.RawAxes, ...
                    index, 0, '', ...
                    'HorizontalAlignment', 'center', ...
                    'FontWeight', 'bold', ...
                    'FontSize', 10, ...
                    'Color', obj.TextColor, ...
                    'Clipping', 'off');
            end
            obj.RawDisplayLimits = [-1 1];
            ylim(obj.App.RawAxes, obj.RawDisplayLimits);
            obj.cleanPlotAxes(obj.App.RawAxes);
            obj.LastAxisCount = count;
        end

        function updateRawLimits(obj, values)
            low = min([values(:); 0; -1]);
            high = max([values(:); 0; 1]);
            span = max(high - low, 1);
            padding = 0.08 * span + 0.02;
            target = [low - padding, high + padding];
            relaxation = 0.12;
            limits = obj.RawDisplayLimits;
            if target(1) < limits(1)
                limits(1) = target(1);
            else
                limits(1) = ...
                    (1 - relaxation) * limits(1) + relaxation * target(1);
            end
            if target(2) > limits(2)
                limits(2) = target(2);
            else
                limits(2) = ...
                    (1 - relaxation) * limits(2) + relaxation * target(2);
            end
            limits(1) = min(limits(1), -1);
            limits(2) = max(limits(2), 1);
            obj.RawDisplayLimits = limits;
            ylim(obj.App.RawAxes, limits);
        end

        function updateOutputLimits(obj, values)
            configured = [];
            data = obj.ViewModel.TableData;
            if ~isempty(data) && all(ismember( ...
                    {'OutputMin','OutputMax'}, ...
                    data.Properties.VariableNames))
                configured = [data.OutputMin; data.OutputMax];
            end
            candidates = [reshape(values, [], 1); configured(:); 0];
            candidates = candidates(isfinite(candidates));
            if isempty(candidates)
                candidates = [-1; 1];
            end
            low = min(candidates);
            high = max(candidates);
            if low == high
                reference = max(abs(low), 1);
                low = low - 0.5 * reference;
                high = high + 0.5 * reference;
            end
            span = high - low;
            padding = max(0.08 * span, 0.05);
            ylim(obj.App.NormalizedAxes, ...
                [low - padding, high + padding]);
        end

        function updateProgress(obj)
            count = sum(obj.ViewModel.SignalVerified);
            obj.App.ProgressLabel.Text = ...
                sprintf('%d of 4 verified', count);
            obj.ProgressFill.XData = [0 count count 0];
        end

        function updateSteps(obj)
            if obj.ViewModel.IsConnected
                obj.setStepVisual(1, 'complete');
            else
                obj.setStepVisual(1, 'active');
            end
            if ~obj.ViewModel.IsConnected
                obj.setStepVisual(2, 'pending');
            elseif obj.ViewModel.RestCaptured
                obj.setStepVisual(2, 'complete');
            else
                obj.setStepVisual(2, 'active');
            end
            if ~obj.ViewModel.RestCaptured
                obj.setStepVisual(3, 'pending');
            elseif all(obj.ViewModel.SignalVerified)
                obj.setStepVisual(3, 'complete');
            else
                obj.setStepVisual(3, 'active');
            end
        end

        function setStepVisual(obj, index, state)
            switch state
                case 'pending'
                    color = obj.Gray;
                    panelColor = obj.PanelBase;
                    badgeText = num2str(index);
                case 'active'
                    color = obj.Orange;
                    panelColor = obj.PanelTint;
                    badgeText = num2str(index);
                otherwise
                    color = obj.Green;
                    panelColor = obj.PanelBase;
                    badgeText = 'OK';
            end
            obj.StepAccents(index).BackgroundColor = color;
            obj.StepBadges(index).BackgroundColor = color;
            obj.StepBadges(index).Text = badgeText;
            obj.StepPanels(index).BackgroundColor = panelColor;
        end

        function updateEnabledState(obj)
            vm = obj.ViewModel;
            idle = ~vm.IsCapturing;
            obj.App.DeviceDropDown.Enable = obj.onOff(idle);
            obj.App.ConnectButton.Enable = obj.onOff(idle);
            obj.App.CenterButton.Enable = ...
                obj.onOff(idle && vm.IsConnected);
            for index = 1:4
                obj.SweepButtons(index).Enable = ...
                    obj.onOff(idle && vm.IsConnected && vm.RestCaptured);
            end
            obj.App.EditButton.Enable = obj.onOff(idle);
            obj.App.OverviewButton.Enable = obj.onOff(idle);
            obj.App.SaveButton.Enable = ...
                obj.onOff(idle && vm.CanSave);
        end

        function centerTable(obj)
            removeStyle(obj.App.CalibrationTable);
            addStyle(obj.App.CalibrationTable, ...
                uistyle('HorizontalAlignment', 'center'));
        end

        function setActiveRow(obj, index)
            obj.centerTable();
            if index >= 1 && index <= height(obj.ViewModel.TableData)
                addStyle(obj.App.CalibrationTable, ...
                    uistyle('BackgroundColor', [0.12 0.20 0.28]), ...
                    'row', index);
            end
            obj.LastActiveRow = index;
        end

        function showStartupOverview(obj)
            if ~isempty(obj.OverviewFigure) && isvalid(obj.OverviewFigure)
                obj.OverviewFigure.Visible = 'on';
                return;
            end
            if ~obj.isViewAlive()
                return;
            end

            dialogSize = [640 440];
            mainPosition = obj.App.UIFigure.Position;
            left = mainPosition(1) + ...
                max((mainPosition(3) - dialogSize(1)) / 2, 20);
            bottom = mainPosition(2) + ...
                max((mainPosition(4) - dialogSize(2)) / 2, 20);
            obj.OverviewFigure = uifigure( ...
                'Name', 'Simulation 3D Joystick Calibration Overview', ...
                'Position', [round(left) round(bottom) dialogSize], ...
                'Resize', 'off', ...
                'WindowStyle', 'modal', ...
                'CloseRequestFcn', @(~,~) obj.closeOverviewFigure());
            if isprop(obj.OverviewFigure, 'Theme')
                obj.OverviewFigure.Theme = 'dark';
            end

            grid = uigridlayout(obj.OverviewFigure, [4 1]);
            grid.RowHeight = {28, 76, '1x', 84};
            grid.Padding = [16 16 16 16];
            grid.RowSpacing = 10;
            uilabel(grid, ...
                'Text', 'Simulation 3D Joystick Calibration', ...
                'FontSize', 18, ...
                'FontWeight', 'bold', ...
                'FontColor', obj.TextColor);
            uilabel(grid, ...
                'Text', ['Calibrate Roll, Pitch, Yaw, and Throttle once. ' ...
                 'The same file works with the Fixed-Wing, Multirotor, and ' ...
                 'Helicopter Input blocks.'], ...
                'WordWrap', 'on', ...
                'FontColor', [0.80 0.80 0.80]);

            workflowPanel = uipanel(grid, ...
                'BorderType', 'none', ...
                'BackgroundColor', obj.PanelBase);
            workflow = uigridlayout(workflowPanel, [3 1]);
            workflow.RowHeight = {22, '1x', 28};
            workflow.Padding = [12 10 12 10];
            workflow.RowSpacing = 6;
            uilabel(workflow, ...
                'Text', 'Recommended workflow', ...
                'FontWeight', 'bold', ...
                'FontColor', obj.TextColor);
            uilabel(workflow, ...
                'Text', sprintf([ ...
                    '1. Connect the controller and capture center/rest.\n' ...
                    '2. Sweep and confirm Roll, Pitch, Yaw, and Throttle.\n' ...
                    '3. Save the common calibration file.\n' ...
                    '4. Add the aircraft-specific block to a Simulink model.\n' ...
                    '5. Load the same file in that block and verify its outputs.']), ...
                'WordWrap', 'on', ...
                'FontColor', [0.82 0.82 0.82]);
            uilabel(workflow, ...
                'Text', ...
                    ['Fixed-Wing uses the saved output limits; Multirotor and ' ...
                     'Helicopter stay normalized.'], ...
                'FontAngle', 'italic', ...
                'FontColor', [0.72 0.72 0.72]);

            actions = uigridlayout(grid, [2 2]);
            actions.RowHeight = {36, 36};
            actions.ColumnWidth = {'1x', '1x'};
            actions.Padding = [0 0 0 0];
            actions.RowSpacing = 8;
            actions.ColumnSpacing = 10;
            uibutton(actions, 'push', ...
                'Text', 'Start Calibration', ...
                'ButtonPushedFcn', @(~,~) obj.closeOverviewFigure());
            uibutton(actions, 'push', ...
                'Text', 'New Simulink Model', ...
                'ButtonPushedFcn', @(~,~) obj.openNewModel());
            uibutton(actions, 'push', ...
                'Text', 'Library Browser', ...
                'ButtonPushedFcn', @(~,~) obj.openLibraryBrowser());
            uibutton(actions, 'push', ...
                'Text', 'Open Overview File', ...
                'ButtonPushedFcn', @(~,~) obj.openOverviewFile());
        end

        function closeOverviewFigure(obj)
            if ~isempty(obj.OverviewFigure) && ...
                    isvalid(obj.OverviewFigure)
                obj.OverviewFigure.CloseRequestFcn = [];
                delete(obj.OverviewFigure);
            end
            obj.OverviewFigure = [];
        end

        function openNewModel(obj)
            obj.closeOverviewFigure();
            try
                modelName = sprintf('Simulation3DJoystickTest_%s', ...
                    datestr(now, 'HHMMSSFFF')); %#ok<TNOW1,DATST>
                new_system(modelName);
                open_system(modelName);
            catch exception
                uialert(obj.App.UIFigure, exception.message, ...
                    'New model failed', 'Icon', 'error');
            end
        end

        function openLibraryBrowser(obj)
            obj.closeOverviewFigure();
            try
                slLibraryBrowser;
            catch
                try
                    open_system(obj.libraryModelFile());
                catch exception
                    uialert(obj.App.UIFigure, exception.message, ...
                        'Open library failed', 'Icon', 'error');
                end
            end
        end

        function openOverviewFile(obj)
            obj.closeOverviewFigure();
            try
                open(obj.overviewFile());
            catch exception
                uialert(obj.App.UIFigure, exception.message, ...
                    'Open overview failed', 'Icon', 'error');
            end
        end

        function tf = isViewAlive(obj)
            tf = ~isempty(obj.App) && isvalid(obj.App) && ...
                ~isempty(obj.App.UIFigure) && isvalid(obj.App.UIFigure);
        end
    end

    methods (Static, Access = private)
        function trimAxes(axesObject)
            axesObject.XTick = [];
            axesObject.YTick = [];
            axesObject.Box = 'off';
            axesObject.XColor = 'none';
            axesObject.YColor = 'none';
            if isprop(axesObject, 'Toolbar')
                axesObject.Toolbar.Visible = 'off';
            end
            if exist('disableDefaultInteractivity', 'file') == 2
                disableDefaultInteractivity(axesObject);
            end
        end

        function cleanPlotAxes(axesObject)
            axesObject.XGrid = 'off';
            axesObject.YGrid = 'off';
            axesObject.Box = 'off';
            axesObject.YTick = [];
            axesObject.YColor = 'none';
            if isprop(axesObject, 'Toolbar')
                axesObject.Toolbar.Visible = 'off';
            end
            if exist('disableDefaultInteractivity', 'file') == 2
                disableDefaultInteractivity(axesObject);
            end
        end

        function value = labelY(sample, limits)
            range = max(diff(limits), eps);
            padding = 0.06 * range;
            value = sample + 0.04 * range * sign(sample + eps);
            value = min(max(value, limits(1) + padding), ...
                limits(2) - padding);
        end

        function value = onOff(condition)
            if condition
                value = 'on';
            else
                value = 'off';
            end
        end

        function value = chooseText(condition, trueText, falseText)
            if condition
                value = trueText;
            else
                value = falseText;
            end
        end

        function root = toolboxRoot()
            packageFolder = fileparts(fileparts(mfilename('fullpath')));
            root = fileparts(packageFolder);
        end

        function filePath = libraryModelFile()
            filePath = fullfile( ...
                Simulation3DJoystickCalibrator.Views.MainViewController.toolboxRoot(), ...
                'library', 'Simulation3DJoystickCalibratorLibrary.slx');
        end

        function filePath = overviewFile()
            filePath = fullfile( ...
                Simulation3DJoystickCalibrator.Views.MainViewController.toolboxRoot(), ...
                'docs', 'Simulation3DJoystickCalibratorOverview.m');
        end
    end
end
