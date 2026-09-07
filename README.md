# Simulation 3D Joystick Calibrator 

This app helps users connect a joystick or RC controller, calibrate it once, and reuse the calibrated configuration in Simulink. The intended use includes open-loop simulation or human-in-the-loop simulation, where the user drives the model through calibrated hardware inputs via a connected joystick or RC controller over USB. 

Current scope: the calibrator is built for fixed-wing aircraft pilot controls. It calibrates Roll, Pitch, Yaw, and Throttle, mapped to Aileron, Elevator, Rudder, and Throttle outputs.

Future Scope: This will be extended to control robots, automobiles, machines, etc.

## Workflow

### 1. Install the toolbox

Install the provided `.mltbx` file in MATLAB.

After installation:

- the app is available from the MATLAB Apps tab,
- the `Simulation 3D Joystick Calibrator` Simulink library is available in the Library Browser,
- the overview document is available as `Overview.mlx`.

[Add screenshot here: Toolbox installed and app visible in Apps tab]

### 2. Open the app

Launch the app from the Apps tab, or run:

```matlab
PilotCalibrator
```

The app opens the main calibration window only. Use the `Overview` button when you want to open the overview/help content.

[Add screenshot here: Main app window]

### 3. Calibrate the controller

Inside the app:

1. connect the joystick or RC controller,
2. capture center,
3. sweep Roll, Pitch, Yaw, and Throttle,
4. confirm the detected directions,
5. save the calibration as a `.mat` file.

The saved `.mat` file includes the joystick ID, detected axis count, channel mapping, deadbands, neutral positions, and fixed-wing actuator limits.

[Add screenshot here: Main app window during calibration]

### 4. Test in a new Simulink model

Create a new blank Simulink model and test the calibrated hardware path directly.

1. Open the Simulink Library Browser.
2. Find the `Pilot Input Calibration` library.
3. Drag `Calibrated Pilot Input` into the new model.
4. Attach Display blocks to the calibrated outputs.
5. Double-click `Calibrated Pilot Input` and load the saved `.mat` configuration file.
6. Click Apply or OK, then update the model.
7. Run the model in simulation mode with the hardware connected.
8. Move the controller and confirm the Display blocks show the expected Aileron, Elevator, Rudder, and Throttle responses.

[Add screenshot here: New Simulink model with Calibrated Pilot Input and Display blocks]

### 5. Use in your own simulation

After the new-model test passes, reuse the same `Calibrated Pilot Input` block and `.mat` configuration file in your flight simulation model.

This calibrated configuration can be used in pilot-in-the-loop simulation workflows. Keep the configuration file local to the model folder when possible. If the mask loads a file from another folder, it copies it beside the model; if the file is already local, it reuses the same file without creating a duplicate.

[Add screenshot here: Library Browser and masked subsystem in a user model]

## Practical Use

The intended usage is:

- calibrate once,
- save one configuration file per controller,
- test the configuration in a new Simulink model with Display blocks,
- reuse the same file in open-loop or pilot-in-the-loop fixed-wing simulations,
- recalibrate only when the controller, joystick ID, channel assignment, or hardware axis behavior changes.
