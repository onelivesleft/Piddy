-- Input states
local TOWARD      = 0 -- DO NOT EDIT
local AWAY        = 1 -- DO NOT EDIT
local NEUTRAL     = 2 -- DO NOT EDIT
local NOT_TOWARD  = 3 -- DO NOT EDIT
local NOT_AWAY    = 4 -- DO NOT EDIT
local NOT_NEUTRAL = 5 -- DO NOT EDIT


-- If you set the same input to axis and pid then it will be one long scale.
-- Can be any input, though you likely want to use sliders/pots:
-- 'LS' / 'RS' = Left Slider / Right Slider
-- 'S1' / 'S2' / 'S3' = Pots 1 / 2 / 3
local AXIS_SELECT  = 'LS'--'S1'
local AXIS_INVERT  = false
local PID_SELECT   = 'LS'--'S1'
local PID_INVERT   = false
local VALUE_SELECT = 'RS'
local VALUE_INVERT = false
local VALUE_MAX    = 20


-- When assigning following inputs you may use a bool, string or table:
--
--  bool:   lock input on (true) or off (false)
--           e.g. AUDIO_SELECT = true -- turns audio on
--
--  string: input name, will be true if the input is non-zero
--           (or true for logical switched)
--           e.g. ARMED = 'L04' -- quad armed when logical switch 4 is true
--
--  table:  first entry is input name, second is state in which it will be on
--           e.g. TRIGGER = {'SH', TOWARD} -- trigger pid change when SH is pulled
--                toward you.
local TRIGGER = {'SH', TOWARD}
local REQUIRE_DOUBLE_HIT = true
local DOUBLE_HIT_WINDOW  = 5


-- Two-stage arming:      https://www.youtube.com/watch?v=bv3VJ1jznw8
-- If you are using a two-stage arming mechanism which utilises the same switch
--  to trigger as is used here then set this to true, and READY_TO_ARM
--  to the switch position in which the trigger should arm the quad (so that it
--  does not also trigger a PID change)
-- If you set up two-stage arming exactly as-per the above video then set to:
--  true & {'SF', AWAY}
local TWO_STAGE_ARM = false
local READY_TO_ARM  = {'SF', AWAY}


-- Set to switch state which signifies the quad is armed.  If you're using
--  two-stage arming as per above video then set to 'L04'
local ARMED = {'SF', AWAY}


-- Switch to enable/disable audio
local AUDIO_SELECT = {'SB', NOT_TOWARD}
local AUDIO_BUFFER = 1.5 -- seconds after audio plays in which no new audio will play


-- Following code sets up variables you can use to trigger audio. Don't edit it!
local AXIS_CHANGES         = 0 -- DO NOT EDIT
local PID_CHANGES          = 1 -- DO NOT EDIT
local VALUE_CHANGES        = 2 -- DO NOT EDIT    Use these to designate when audio triggers
local TRIGGER_HIT          = 3 -- DO NOT EDIT
local TRANSMISSION_STARTS  = 4 -- DO NOT EDIT

local PLAY_AXIS  = 0 -- DO NOT EDIT
local PLAY_PID   = 1 -- DO NOT EDIT              Use these to designate what audio plays
local PLAY_VALUE = 2 -- DO NOT EDIT

local WHEN = {} -- DO NOT EDIT
WHEN[AXIS_CHANGES]        = {} -- DO NOT EDIT
WHEN[PID_CHANGES]         = {} -- DO NOT EDIT
WHEN[VALUE_CHANGES]       = {} -- DO NOT EDIT
WHEN[TRIGGER_HIT]         = {} -- DO NOT EDIT
WHEN[TRANSMISSION_STARTS] = {} -- DO NOT EDIT
-- End of audio trigger setup code


-- Add as many audio triggers as you want here.  Each piece of audio will only play once per
--  event.
-- The default settings use SB as a three-state selecter: when TOWARD you audio is disabled,
--  when centered some audio is played, and when AWAY from you verbose audio is played.
WHEN[AXIS_CHANGES][PLAY_AXIS]  = {'SB', NOT_TOWARD}
WHEN[AXIS_CHANGES][PLAY_PID]   = {'SB', AWAY}
WHEN[AXIS_CHANGES][PLAY_VALUE] = {'SB', AWAY}
WHEN[PID_CHANGES][PLAY_AXIS]   = {'SB', AWAY}
WHEN[PID_CHANGES][PLAY_PID]    = {'SB', NOT_TOWARD}
WHEN[PID_CHANGES][PLAY_VALUE]  = {'SB', AWAY}
WHEN[VALUE_CHANGES][PLAY_VALUE] = true

local PLAY_COUNTDOWN    = true
local COUNTDOWN_FROM    = 5    -- Max seconds to countdown from.
local INITIAL_COUNTDOWN = true -- Always read out the countdown when it starts


-------------------------------- MAKE NO CHANGES BELOW THIS POINT! -------------------------------



local THRESHOLD = 100
local function check_input(switch)
    local t = type(switch)
    if t == 'boolean' then
        return switch
    elseif t == 'string' then
        local v = getValue(switch)
        return v >= -THRESHOLD and v <= THRESHOLD
    elseif t == 'table' then
        local state
        local v = getValue(switch[1])
        local condition = switch[2]
        if v >= -THRESHOLD and v <= THRESHOLD then -- NEUTRAL
            return condition == NEUTRAL or condition == NOT_AWAY or condition == NOT_TOWARD
        elseif v < 0 then -- AWAY
            return condition == AWAY or condition == NOT_NEUTRAL or condition == NOT_TOWARD
        else -- TOWARD
            return condition == TOWARD or condition == NOT_AWAY or condition == NOT_NEUTRAL
        end
    end
end

local function convert_input(switch)
    local s
    local t = type(switch)
    if t == 'boolean' then return switch end
    if t == 'table' then s = switch[1] else s = switch end
    s = string.lower(s)
    s = string.gsub(s, "l0", "l")
    if t == 'table' then return {s, switch[2]} else return s end
end


AXIS_SELECT        = convert_input(AXIS_SELECT)
PID_SELECT         = convert_input(PID_SELECT)
VALUE_SELECT       = convert_input(VALUE_SELECT)
TRIGGER            = convert_input(TRIGGER)
REQUIRE_DOUBLE_HIT = convert_input(REQUIRE_DOUBLE_HIT)
TWO_STAGE_ARM      = convert_input(TWO_STAGE_ARM)
READY_TO_ARM       = convert_input(READY_TO_ARM)
ARMED              = convert_input(ARMED)
AUDIO_SELECT       = convert_input(AUDIO_SELECT)
PLAY_COUNTDOWN     = convert_input(PLAY_COUNTDOWN)
INITIAL_COUNTDOWN  = convert_input(INITIAL_COUNTDOWN)

for change, sounds in pairs(WHEN) do
    for sound, switch in pairs(sounds) do
        WHEN[change][sound] = convert_input(switch)
    end
end

DOUBLE_HIT_WINDOW = 100 * DOUBLE_HIT_WINDOW
AUDIO_BUFFER      = 100 * AUDIO_BUFFER

local ROLL  = 10
local PITCH = 40
local YAW   = 70
local P = 0
local I = 10
local D = 20

local AXIS = {ROLL, PITCH, YAW}
local PID = {P, I , D}
local AXIS_LABEL = {}
local PID_LABEL = {}
AXIS_LABEL[ROLL]='ROLL'; AXIS_LABEL[PITCH]='PITCH'; AXIS_LABEL[YAW]='YAW'
PID_LABEL[P]='P'; PID_LABEL[I]='I'; PID_LABEL[D]='D'

local function round(num, decimals)
    local mult = 10^(decimals or 0)
    return math.floor(num * mult + 0.5) / mult
end

local function approx(a, b, e)
    return math.abs(a-b) <= e
end

local function sfx(name)
    playFile('/SCRIPTS/TELEMETRY/PIDDY/'..string.lower(name)..'.wav')
end

local function bmp(x, y, name)
    lcd.drawPixmap(x, y, '/SCRIPTS/TELEMETRY/PIDDY/'..string.lower(name)..'.bmp')
end

local function make_get_function()
    if AXIS_SELECT == PID_SELECT then
        return function()
            local v = getValue(AXIS_SELECT)
            v = math.floor(9 * (v + 1024) / 2049 + 1) * 10
            if AXIS_INVERT then
                return 90 - v
            else
                return v
            end
        end
    else
        return function()
            local axis = getValue(AXIS_SELECT)
            axis = math.floor(3 * (axis + 1024) / 2049) + 1
            if AXIS_INVERT then axis = 3 - axis end
            axis = AXIS[axis]

            local pid  = getValue(PID_SELECT)
            pid = math.floor(3 * (pid + 1024) / 2049) + 1
            if PID_INVERT then pid = 3 - pid end
            pid = PID[pid]

            return axis + pid
        end
    end
end
local get_function  = make_get_function()
local curr_function = get_function()
local prev_function = curr_function

local function get_value()
    local v = getValue(VALUE_SELECT)
    v = round(VALUE_MAX * v / 1024, 0)
    if VALUE_INVERT then
        return VALUE_MAX - v
    else
        return v
    end
end
local curr_value = get_value()
local prev_value = curr_value
local last_played_value = curr_value

local function get_axis(f)
    if f <= 30 then
        return ROLL
    elseif f <= 60 then
        return PITCH
    else
        return YAW
    end
end
local curr_axis = get_axis(curr_function)
local prev_axis = curr_axis
local last_played_axis = curr_axis

local function get_pid(f)
    if f <= 30 then
        return f - ROLL
    elseif f <= 60 then
        return f - PITCH
    else
        return f - YAW
    end
end
local curr_pid = get_pid(curr_function)
local prev_pid = curr_pid
local last_played_pid = curr_pid

local last_played = 0
local curr_time   = 0
local prev_time   = 0
local delta_time  = 0

local play_axis  = false
local play_pid   = false
local play_value = false

local armed         = false
local to_play       = {}
local value_changed = false


local function draw()
    lcd.clear()
    lcd.drawText(80, 0, "PID Tuning")
    lcd.drawFilledRectangle(0, 0, 210, 8, INVERT)
    local x = 0
    local axis_step_x = 2
    local pid_step_x  = 23
    local axis_y  = 9
    local pid_y   = 19
    local total_y = 28
    local value_y = 37
    local armed_x = 0
    local armed_y = 47
    for i, axis in ipairs(AXIS) do
        lcd.drawText(x + 1, axis_y + 1, tostring(AXIS_LABEL[axis]))
        if axis == curr_axis then
            lcd.drawFilledRectangle(x, axis_y, pid_step_x * 3 - 1, pid_y - axis_y - 1, INVERT)
        end
        for j, pid in ipairs(PID) do
            lcd.drawText(x + 1, pid_y + 1, tostring(PID_LABEL[pid]))
            if axis + pid == curr_function then
                local s = tostring(curr_value)
                if curr_value >= 0 then s = "+" .. s end
                lcd.drawText(x + 1, value_y, s)
                lcd.drawFilledRectangle(x, pid_y, pid_step_x - 1, armed_y - pid_y - 1, INVERT)
            end
            x = x + pid_step_x
        end
        x = x + axis_step_x
    end
    if armed then
        bmp(armed_x, armed_y, 'armed')
    else
        bmp(armed_x, armed_y, 'disarmed')
    end
end


local function audio()
    to_play = {}
    value_changed = false
    if curr_axis ~= last_played_axis then
        for sound, switch in pairs(WHEN[AXIS_CHANGES]) do
            if check_input(switch) then to_play[sound] = true end
        end
        last_played_axis = curr_axis
    end
    if curr_pid ~= last_played_pid then
        for sound, switch in pairs(WHEN[PID_CHANGES]) do
            if check_input(switch) then to_play[sound] = true end
        end
        last_played_pid = curr_pid
    end
    if curr_value ~= last_played_value then
        for sound, switch in pairs(WHEN[VALUE_CHANGES]) do
            if check_input(switch) then to_play[sound] = true end
        end
        last_played_value = curr_value
        value_changed = true
    end
    if to_play[PLAY_AXIS]  then sfx(AXIS_LABEL[curr_axis]) end
    if to_play[PLAY_PID]   then sfx(PID_LABEL[curr_pid]) end
    if to_play[PLAY_VALUE] and (curr_value ~= 0 or value_changed) then
        if curr_value < 0 then
            sfx('minus')
            playNumber(-curr_value, 0)
        else
            if curr_value > 0 then
                sfx('plus')
            end
            playNumber(curr_value, 0)
        end
    end
    last_played = curr_time
end


local function run(event)
    prev_time  = curr_time
    prev_function = curr_function
    prev_value    = curr_value
    prev_axis     = curr_axis
    prev_pid      = curr_pid

    curr_function = get_function()
    curr_value    = get_value()
    curr_axis     = get_axis(curr_function)
    curr_pid      = get_pid(curr_function)
    curr_time     = getTime()
    delta_time    = curr_time - prev_time

    armed = check_input(ARMED)
    ready_to_arm = check_input(READY_TO_ARM)

    draw()
    if check_input(AUDIO_SELECT) and curr_time >= last_played + AUDIO_BUFFER then
        audio()
    end
end

return{run=run}
