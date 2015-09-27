-- Solidworks Controls Myo script written by Fan Zhang, Rahul Mehta, Ayodeji Ige, Oswin Rodriguez
-- Written at and for Hack the North 2014 hack-a-thon competition, September 19th to 21st, 2014
-- Special thanks to Thalmic Labs for providing Myo hardware used in development

scriptId = 'com.example.SolidworksControls'
ir = 0 -- variable to set counter for right rotation
il = 0 -- Variable to set counter for left rotation
unlocked = false -- Lock and unlock status of the Myo, unlocked by thumbToPinky pose and locked by inactivity timeout
rotateLeft = 0 -- Variable used to signal actuation of left rotation
rotateRight = 0 -- Variable used to signal actuation of right rotation
fingersSpreadGesture = 0 -- Variable used to signal being in process of a fingersSpread starting gesture
fistHoldGesture = 0 -- Variable used to signal that a fist hold is in progress
zoomActive = 0 -- Variable used to signal the process of zooming
PITCH_MOTION_THRESHOLD = 10 -- Variable used to set tolerance for change in pitch
YAW_MOTION_THRESHOLD = 50 -- Variable used to set tolerance for change in pitch
ROLL_MOTION_THRESHOLD = 20 -- Variable used to set tolerance for change in pitch
SLOW_MOVE_PERIOD = 50 -- Variable used to set tolerance for change in pitch

function activeAppName() 
	return "Solidworks Controls"
end

function conditionallySwapWave(pose) -- Left/right arm support
    if myo.getArm() == "left" then
        if pose == "waveIn" then
            pose = "waveOut"
        elseif pose == "waveOut" then
            pose = "waveIn"
        end
    end
    return pose
end

function onForegroundWindowChange(app, title)

	local wantActive = false
	activeApp = ""
	-- Only activates when active window is Solidworks, "SolidWorks Education Edition" should be replaced by
	-- title of local version of Solidworks if different. 
	if platform == "Windows" then
		wantActive = string.match(title, "^SolidWorks Student Edition %- ")
		activeApp = "Solidworks"
	end
	
	return wantActive
end

function onActiveChange(isActive) 
	if isActive == true then
		myo.debug("!WINDOW! Script active.")
	elseif isActive == false then
		myo.debug("!WINDOW! Script inactive.")
		-- Disable all input and interface methods when target window becomes out of focus
		unlocked = false
		myo.controlMouse(false)
		myo.mouse("center", "up")
		myo.keyboard("left_control", "up")
	end
end

function onPoseEdge(pose, edge) 
	if edge == "on" then 
		if fingersSpreadGesture == 1 and unlocked then -- Only triggered if a fingersSpread gesture has been initiated
			if pose == "fingersSpread" then -- Another fingerSpread signals end of gesture
				fingersSpreadGesture = 0
				myo.controlMouse(false)
				myo.mouse("center", "up")
				myo.keyboard("left_control", "up")
			elseif pose == "fist" then -- Fist pose signals rotation by grabbing, replacing inputs by previous rest pose
				myo.mouse("center", "up")
				myo.keyboard("left_control", "up")
				myo.mouse("center", "down")
			elseif pose == "rest" then -- Rest pose signals panning
				myo.keyboard("left_control", "down")
				myo.mouse("center", "down")
			end	
		else
			if pose == "thumbToPinky" and unlocked == false then --Unlocking pose, requires to be held for at least 0.5s
				confirm = myo.getTimeMilliseconds()	
			elseif pose == "fingersSpread" and unlocked then -- Signals the initiation of a fingersSpread gesture, enables mouse
				myo.controlMouse(true)
				fingersSpreadGesture = 1
			elseif pose == "fist" and unlocked then -- Fist pose not part of gesture signals zooming gesture
				pitchReference = getMyoPitchDegrees()
				yawReference = getMyoYawDegrees()
				zoomActive = 1
			elseif pose == conditionallySwapWave("waveIn") and unlocked then -- Signals the initiation of left rotation
				myo.debug("Turn left.")
				rotateLeft = 1
			elseif pose == conditionallySwapWave("waveOut") and unlocked then -- Signals the initiation of right rotation
				myo.debug("Turn right.")
				rotateRight = 1
			end
		end
	elseif edge == "off" then
		if pose == "thumbToPinky" and not unlocked then -- Unlock by thumbToPinky gesture
			myo.debug("Unlocked.")
			unlocked = true
			lastActivity = myo.getTimeMilliseconds()
		end
		
		-- Resets a bunch of variables and inputs which should be cleared upon any change in input
		myo.mouse("center", "up")
		myo.keyboard("left_control", "up")
		fistHoldGesture = 0
		rotateLeft = 0
		rotateRight = 0
		
		zoomActive = 0
	end
end

function onPeriodic()
	
	if unlocked then -- Timeout after 5000 seconds of inactivity. Keep-alive timer called after every action
		if myo.getTimeMilliseconds() - lastActivity > 5000 then
			myo.debug("Locked.")
			unlocked = false
			myo.vibrate("short")
			
			myo.controlMouse(false)
			myo.mouse("center", "up")
			myo.keyboard("left_control", "up")
		end
	end	
	
	if rotateLeft == 1 then -- Action for rotating left
		il = il + 1
		if(il%10 == 0) then
			myo.keyboard("left_arrow", "press") --runs once every 10 times i.e every 100ms
		end
		lastActivity = myo.getTimeMilliseconds()
	end
	if rotateRight == 1 then -- Action for rotating right
		ir = ir + 1
		if(ir%10 == 0) then
			myo.keyboard("right_arrow", "press") --runs once every 10 times i.e every 100ms
		end
		lastActivity = myo.getTimeMilliseconds()
	end
	
	if fingersSpreadGesture == 1 then -- Used to transition into rotation by grabbing with fist gesture after fingersSpread gesture
		if pose == "fist" then
			fistHoldGesture = 1
		else
			fistHoldGesture = 0
		end
		lastActivity = myo.getTimeMilliseconds()
	end
	
	if (zoomActive == 1) then -- Used when fist gesture used to activate zoom
		-- if sectionActive == 1 then -- Buggy: checks if section view is on 
		--	local relativeRoll = degreeDiff(getMyoRollDegrees(), rollReference)
		--	relativeRoll = conditionalRoll(relativeRoll)
		--	if math.abs(relativeRoll) > ROLL_MOTION_THRESHOLD then --checks if change in roll is greater than defined threshold
		--		rollReference = getMyoPitchDegrees()
		--		if relativeRoll > 0 then
		--			myo.keyboard("return", "press") --
		--			sectionActive = 0
		--			lastActivity = myo.getTimeMilliseconds()
		--		end  
		--	end
		--end

		local relativePitch = degreeDiff(getMyoPitchDegrees(), pitchReference) 
		local relativeYaw = degreeDiff(getMyoYawDegrees(), yawReference)
		relativePitch = conditionalPitch(relativePitch)
		
		if math.abs(relativePitch) > PITCH_MOTION_THRESHOLD then -- Buggy --checks if change in pitch is greater than the defined threshold 
			pitchReference = getMyoPitchDegrees()
            if relativePitch > 0 then
                myo.keyboard("z", "press")	--zoom out
            elseif relativePitch < 0 then
                myo.keyboard("z", "press", "shift") --zoom in
            end
			lastActivity = myo.getTimeMilliseconds()			
        end
		
		--if math.abs(relativeYaw) > YAW_MOTION_THRESHOLD then --checks if change in yaw is greater than the defined threshold and activates section mode if true
        --	yawReference = getMyoYawDegrees()
		--	rollReference = getMyoRollDegrees()
		--	if relativeYaw > 0 then
		--		myo.keyboard("t", "press", "control")
		--		sectionActive = 1
		--	end
		--	lastActivity = myo.getTimeMilliseconds()
       -- end
	end
end
--returns the current yaw value in degrees
function getMyoYawDegrees()
    local yawValue = math.deg(myo.getYaw())
    return yawValue
end

--returns the current pitch value in degrees
function getMyoPitchDegrees()
    local PitchValue = math.deg(myo.getPitch())
    return PitchValue
end

--returns the current roll value in degrees
function getMyoRollDegrees()
    local RollValue = math.deg(myo.getRoll())
    return RollValue
end

--calculates the change in angle between two positions for either pitch, yaw or roll
function degreeDiff(value, base)
    local diff = value - base
    if diff > 180 then
        diff = diff - 360
    elseif diff < -180 then
        diff = diff + 360
    end
    return diff
end

--corrects the pitch based on MYO orientation
function conditionalPitch(pitch)
    if myo.getXDirection()== "towardElbow" then
        pitch=-pitch;
    end
    return pitch
end

--corrects the roll based on myo orientation
function conditionalRoll(roll)
    if myo.getXDirection()== "towardElbow" then
        roll=-roll;
    end
    return roll
end