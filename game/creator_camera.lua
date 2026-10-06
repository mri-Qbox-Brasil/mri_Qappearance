-- Character creator camera rig: drag to spin the ped (with momentum), drag up/down to crane,
-- wheel or right-drag to dolly toward the cursor. Each step camera is the framing it starts
-- from; offsets reset when a new step camera arrives. See README "Câmera do criador".

local YAW_PER_PX = 0.4          -- degrees of ped heading per dragged pixel
local CRANE_PER_PX = 0.0018     -- metres of height per pixel, scaled by camera distance
local ZOOM_STEP = 0.85          -- distance factor per wheel notch
local ZOOM_PER_PX = 0.012       -- wheel notches per right-dragged pixel
local MIN_DIST, MAX_DIST = 0.35, 3.2
local LOW, HIGH = -0.85, 0.75   -- framing point height limits, relative to the ped origin
local FOLLOW = 18.0             -- damping rate of camera and heading (1/s)
local FRICTION = 3.2            -- spin decay rate after release (1/s)
local MAX_SPIN = 720.0          -- degrees per second
local SETTLE_MS = 140           -- overshoot lingers this long before springing back

local active = false
local base, dist, distTarget, height, heightTarget
local yawTarget, spin = nil, 0.0
local dragging = false
local lastInput = 0
local applied

local function damp(current, target, rate, dt)
    return current + (target - current) * (1.0 - math.exp(-rate * dt))
end

local function wrap(angle)
    return (angle + 180.0) % 360.0 - 180.0
end

local function clamp(value, lo, hi)
    return math.max(lo, math.min(hi, value))
end

local function heightLimits()
    local pedZ = GetEntityCoords(cache.ped).z
    -- the step framing itself is always inside the limits, or arriving would nudge it
    return math.min(pedZ + LOW - base.point.z, 0.0), math.max(pedZ + HIGH - base.point.z, 0.0)
end

-- Past a limit the input meets growing resistance instead of a wall.
local function push(value, delta, lo, hi)
    local nextValue = value + delta
    if (nextValue > hi and delta > 0) or (nextValue < lo and delta < 0) then
        local over = math.max(value - hi, lo - value, 0.0)
        delta = delta * 0.35 / (1.0 + over * 10.0)
    end
    return value + delta
end

local function capture(cam)
    local point = client.currentCamPoint
    if not point then return end
    local coords = GetCamCoord(cam)
    local offset = coords - point
    local length = #offset
    if length < 0.01 then return end
    base = { point = point, dir = offset / length, dist = length }
    dist, distTarget, height, heightTarget = length, length, 0.0, 0.0
    applied = nil
end

local function frame(dt)
    local cam = client.getCameraHandle()
    if not cam or client.isCameraInterpolating() then
        if base then
            -- a new step camera was placed from the current heading: stop turning away from it
            base, yawTarget, spin = nil, nil, 0.0
        end
    else
        if not base then capture(cam) end
        if base then
            if not dragging and GetGameTimer() - lastInput > SETTLE_MS then
                local lo, hi = heightLimits()
                distTarget = clamp(distTarget, MIN_DIST, MAX_DIST)
                heightTarget = clamp(heightTarget, lo, hi)
            end
            dist = damp(dist, distTarget, FOLLOW, dt)
            height = damp(height, heightTarget, FOLLOW, dt)

            if not applied or math.abs(applied.dist - dist) > 0.0005 or math.abs(applied.height - height) > 0.0005 then
                local point = base.point + vector3(0.0, 0.0, height)
                local coords = point + base.dir * dist
                SetCamCoord(cam, coords.x, coords.y, coords.z)
                PointCamAtCoord(cam, point.x, point.y, point.z)
                local dof = Config.DepthOfField
                if dof and dof.enabled then
                    -- equals the config at the step framing, so arriving never pops the focus
                    SetCamNearDof(cam, math.max(0.05, dof.nearDof - math.max(base.dist - dist, 0.0)))
                    SetCamFarDof(cam, dof.farDof + math.max(dist - base.dist, 0.0))
                end
                applied = { dist = dist, height = height }
            end
        end
    end

    if yawTarget then
        if not dragging then
            yawTarget = yawTarget + spin * dt
            spin = spin * math.exp(-FRICTION * dt)
        end
        local heading = GetEntityHeading(cache.ped)
        local diff = wrap(yawTarget - heading)
        SetEntityHeading(cache.ped, heading + diff * (1.0 - math.exp(-FOLLOW * dt)))
        if not dragging and math.abs(spin) < 3.0 and math.abs(diff) < 0.05 then
            yawTarget, spin = nil, 0.0
        end
    end
end

function client.creatorCameraStart()
    if active then return end
    active = true
    base, yawTarget, spin, dragging = nil, nil, 0.0, false
    CreateThread(function()
        local last = GetGameTimer()
        while active and client.isNewCharacter() do
            local now = GetGameTimer()
            frame(math.min((now - last) / 1000.0, 0.05))
            last = now
            Wait(0)
        end
        active = false
    end)
end

function client.creatorCameraStop()
    active = false
    yawTarget, spin, dragging = nil, 0.0, false
end

--- Current rig pose and the step framing it started from, in world coords; nil before the first capture.
function client.creatorCameraPoses()
    if not base then return end
    local point = base.point + vector3(0.0, 0.0, height)
    return { coords = point + base.dir * dist, point = point },
        { coords = base.point + base.dir * base.dist, point = base.point }
end

--- Drops any running spin so an instant heading change is not pulled back.
function client.creatorSpinHalt()
    yawTarget, spin = nil, 0.0
end

--- Smooth turn for A/D and the review half-turn; false when the rig is not running.
function client.creatorTurn(angle)
    if not active then return false end
    yawTarget = (yawTarget or GetEntityHeading(cache.ped)) - angle
    return true
end

local function zoom(notches, relY)
    if not base then return end
    local nextDist = distTarget * ZOOM_STEP ^ notches
    local lo, hi = heightLimits()
    -- keeps the spot under the cursor under the cursor while the camera moves in
    local tanHalf = math.tan(math.rad(GetCamFov(client.getCameraHandle())) / 2.0)
    heightTarget = push(heightTarget, relY * tanHalf * (distTarget - nextDist), lo, hi)
    distTarget = push(distTarget, nextDist - distTarget, MIN_DIST, MAX_DIST)
end

RegisterNUICallback("creator_cam", function(data, cb)
    cb(1)
    if not active or type(data) ~= "table" then return end
    lastInput = GetGameTimer()

    if data.grab then
        dragging = true
        spin = 0.0
        yawTarget = yawTarget or GetEntityHeading(cache.ped)
    elseif data.release then
        dragging = false
        spin = clamp(-(tonumber(data.vx) or 0.0) * YAW_PER_PX, -MAX_SPIN, MAX_SPIN)
    elseif data.reset then
        if base then distTarget, heightTarget = base.dist, 0.0 end
    elseif data.wheel then
        zoom(clamp(tonumber(data.wheel) or 0.0, -3.0, 3.0), clamp(tonumber(data.y) or 0.0, -1.0, 1.0))
    elseif data.mode == "rotate" and yawTarget then
        yawTarget = yawTarget - (tonumber(data.dx) or 0.0) * YAW_PER_PX
    elseif data.mode == "crane" and base then
        local lo, hi = heightLimits()
        heightTarget = push(heightTarget, (tonumber(data.dy) or 0.0) * CRANE_PER_PX * dist, lo, hi)
    elseif data.mode == "zoom" then
        zoom(-(tonumber(data.dy) or 0.0) * ZOOM_PER_PX, clamp(tonumber(data.y) or 0.0, -1.0, 1.0))
    end
end)
