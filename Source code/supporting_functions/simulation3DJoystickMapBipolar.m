function y = simulation3DJoystickMapBipolar(rawValue, uMin, uMax, neutral, deadband, reverseDirection, outMin, outMax)
%SIMULATION3DJOYSTICKMAPBIPOLAR Map a centered joystick axis.
%
% Copyright 2026 The MathWorks, Inc.

    rawValue = localFiniteScalar(rawValue, neutral);
    uMin = localFiniteScalar(uMin, -1);
    uMax = localFiniteScalar(uMax, 1);
    neutral = localFiniteScalar(neutral, mean([uMin uMax]));
    deadband = max(localFiniteScalar(deadband, 0), 0);
    reverseDirection = logical(localFiniteScalar(reverseDirection, 0));
    outMin = localFiniteScalar(outMin, -1);
    outMax = localFiniteScalar(outMax, 1);

    if uMin > uMax
        tmp = uMin;
        uMin = uMax;
        uMax = tmp;
    end
    neutral = min(max(neutral, uMin), uMax);

    negSpan = max(neutral - uMin, 0);
    posSpan = max(uMax - neutral, 0);
    maxDeadband = max(min(negSpan, posSpan), 0);
    deadband = min(deadband, maxDeadband);

    negEdge = neutral - deadband;
    posEdge = neutral + deadband;
    tol = localTolerance([uMin uMax neutral rawValue]);

    if rawValue <= negEdge
        denom = max(negEdge - uMin, tol);
        normalized = -(negEdge - rawValue) / denom;
    elseif rawValue >= posEdge
        denom = max(uMax - posEdge, tol);
        normalized = (rawValue - posEdge) / denom;
    else
        normalized = 0;
    end

    normalized = min(max(normalized, -1), 1);
    if reverseDirection
        normalized = -normalized;
    end

    if normalized >= 0
        y = normalized * outMax;
    else
        y = -normalized * outMin;
    end
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
