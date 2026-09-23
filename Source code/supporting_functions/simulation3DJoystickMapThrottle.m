function y = simulation3DJoystickMapThrottle(rawValue, uMin, uMax, deadband, reverseDirection, outMin, outMax)
%SIMULATION3DJOYSTICKMAPTHROTTLE Map a one-sided joystick axis.
%
% Copyright 2026 The MathWorks, Inc.

    rawValue = localFiniteScalar(rawValue, 0);
    uMin = localFiniteScalar(uMin, -1);
    uMax = localFiniteScalar(uMax, 1);
    deadband = max(localFiniteScalar(deadband, 0), 0);
    reverseDirection = logical(localFiniteScalar(reverseDirection, 0));
    outMin = localFiniteScalar(outMin, 0);
    outMax = localFiniteScalar(outMax, 1);

    lo = min(uMin, uMax);
    hi = max(uMin, uMax);
    span = max(hi - lo, localTolerance([lo hi rawValue]));

    if reverseDirection
        fraction = (hi - rawValue) / span;
    else
        fraction = (rawValue - lo) / span;
    end
    fraction = min(max(fraction, 0), 1);

    deadbandFraction = min(deadband / span, 0.95);
    if fraction <= deadbandFraction
        fraction = 0;
    else
        fraction = (fraction - deadbandFraction) / max(1 - deadbandFraction, eps);
    end

    y = outMin + fraction * (outMax - outMin);
end


function value = localFiniteScalar(value, defaultValue)
    if ~(isnumeric(value) || islogical(value)) || ~isscalar(value) || ~isfinite(double(value))
        value = defaultValue;
    else
        value = double(value);
    end
end


function tol = localTolerance(values)
    scale = max([abs(values(:)); 1]);
    tol = max(eps(scale), 1e-9);
end
