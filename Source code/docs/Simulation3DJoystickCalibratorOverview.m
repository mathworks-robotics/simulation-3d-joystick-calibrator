%[text] # Simulation 3D Joystick Calibrator
%[text] Create one reusable four-axis calibration for a USB joystick or RC controller, then use the saved configuration with the Fixed-Wing, Multirotor, and Helicopter Input blocks.
%%
%[text] ## Install the Toolbox
%[text] Install `Simulation_3D_Joystick_Calibrator.mltbx` from the MATLAB Add-On Manager or by double-clicking the file.
%[text] After installation, confirm that **Simulation 3D Joystick Calibrator** appears in both the MATLAB Apps tab and the Simulink Library Browser.
%%
%[text] ## Requirements
%[text] - MATLAB R2025b or later
%[text] - Simulink
%[text] - Simulink 3D Animation
%[text] - A controller recognized by `sim3d.io.Joystick` \
%%
%[text] ## Launch the App
%[text] Open **Simulation 3D Joystick Calibrator** from the MATLAB Apps tab or run `Simulation3DJoystickCalibrator` in the Command Window.
%%
%[text] ## Calibration Workflow
%[text] 1. Select the runtime Device ID and click **Connect**.
%[text] 2. Center Roll, Pitch, and Yaw, place Throttle at its minimum or rest position, and click **Center & hold**.
%[text] 3. Sweep one control through its full travel.
%[text] 4. Check the detected channel and calibrated-output preview, set **Reverse** when required, and confirm the control.
%[text] 5. Repeat the sweep for Roll, Pitch, Yaw, and Throttle.
%[text] 6. For Fixed-Wing use, set **Output Min** and **Output Max** to the required control-surface and throttle ranges.
%[text] 7. Review the calibrated preview and click **Save**. \
%[text] **Edit existing calibration** loads a saved configuration without discarding its calibrated values when a controller is connected.
%[text] During an incomplete calibration, an unswept control can temporarily share the channel identified for another control. Sweep the remaining controls to assign their actual channels; saving requires four unique channel assignments.
%%
%[text] ## Live Previews
%[text] **Raw channels** shows every analog axis reported by the connected device and highlights the channel detected during a sweep.
%[text] **Calibrated output preview** shows Roll, Pitch, Yaw, and Throttle after applying calibration and configured output limits.
%%
%[text] ## Supported Controllers
%[text] Controllers may expose between 4 and 64 analog axes. Roll, Pitch, Yaw, and Throttle can use any four distinct channels. Additional axes remain visible in the raw preview but are ignored unless assigned.
%[text] Buttons, switches, POV hats, and controllers with fewer than four analog axes are not supported.
%%
%[text] ## Saved Configuration
%[text] A saved MAT-file contains one scalar struct named `cfg` with:
%[text] - `schemaVersion` equal to 2
%[text] - `profileID` equal to `simulation-3d-joystick`
%[text] - `profileVersion` and `numAxes`
%[text] - Four ordered `signals`: Roll, Pitch, Yaw, and Throttle
%[text] - `savedAt` and `appVersion` \
%[text] Each signal stores its assigned channel, raw minimum and maximum, neutral value, deadband, reverse flag, mapping type, and output range. The runtime Device ID is not saved.
%%
%[text] ## Simulink Blocks
%[text] - **Calibrated Fixed-Wing Input** uses the saved Output Min and Output Max values. Its defaults are Aileron \[-15, 15\] degrees, Elevator \[-25, 25\] degrees, Rudder \[-20, 20\] degrees, and Throttle \[0, 1\].
%[text] - **Calibrated Multirotor Input** outputs RollCmd, PitchCmd, and YawCmd in \[-1, 1\], with ThrottleCmd in \[0, 1\].
%[text] - **Calibrated Helicopter Input** outputs LateralCyclic, LongitudinalCyclic, and Pedals in \[-1, 1\], with Collective in \[0, 1\]. \
%%
%[text] ## Use the Simulink Library
%[text] 1. Open the Simulink Library Browser.
%[text] 2. Find **Simulation 3D Joystick Calibrator**.
%[text] 3. Add the required aircraft-input block.
%[text] 4. Open its mask and select the saved calibration MAT-file.
%[text] 5. Select the runtime Device ID, apply the mask, and update the model.
%[text] 6. Connect the output bus to the flight-control model. \
%[text] When an external calibration is selected, the block copies it into the model's local calibration folder so the model does not depend on an absolute path.
%%
%[text] ## Included Example
%[text] `Simulation3DJoystickExample.mat` demonstrates the shared configuration schema and can be loaded by all three blocks.
%%
%[text] ## When to Recalibrate
%[text] Recalibrate when the physical controller, assigned channels, measured travel, center behavior, deadband, direction, or Fixed-Wing output limits change. Changing the aircraft-specific block or runtime Device ID does not require a new physical-axis calibration.
%%
%[text] ## Scope
%[text] Version 1.0 supports Fixed-Wing, Multirotor, and Helicopter axis inputs. Ground vehicles, arbitrary customer-defined signals, buttons, POV hats, and optional controls are outside this release.
% Copyright 2026 The MathWorks, Inc.

%[appendix]{"version":"1.0"}
%---
%[metadata:view]
%   data: {"layout":"inline"}
%---
