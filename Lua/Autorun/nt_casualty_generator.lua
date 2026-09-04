print("[NTCCG] Autorun loaded.")

if NT == nil or HF == nil then
    print("[NTCCG] Neurotrauma was not found. This mod requires Neurotrauma.")
    return
end

local debugEnabled = true

local CASUALTY_COUNT = 5
local TRIGGER_COOLDOWN = 0.75
local nextTriggerTime = 0

-- Fixed casualty mode has its own cooldown.
local nextFixedTriggerTime = 0

--------------------------------------------------
-- General configuration
--------------------------------------------------

-- NPC horizontal spacing.
-- Approximately 1.5 character heights.
local SPAWN_SPACING = 150

local ROLE_ORDER = {
    "captain",
    "securityofficer",
    "assistant",
    "mechanic",
    "engineer"
}

local LIMB_POOL = {
    LimbType.LeftArm,
    LimbType.RightArm,
    LimbType.LeftLeg,
    LimbType.RightLeg,
    LimbType.Head,
    LimbType.Torso
}

--------------------------------------------------
-- Fixed casualty configuration
--------------------------------------------------

local FIXED_INFECTED_CAVITY = 5

--------------------------------------------------
-- Fixed trauma profile support
--------------------------------------------------

local AMPUTATION_AFFLICTIONS = {
    [LimbType.LeftArm] = "tla_amputation",
    [LimbType.RightArm] = "tra_amputation",
    [LimbType.LeftLeg] = "tll_amputation",
    [LimbType.RightLeg] = "trl_amputation"
}

--------------------------------------------------
-- Captain trauma profile
--------------------------------------------------

local CAPTAIN_TRAUMA_PROFILE = {

    limbs = {

        [LimbType.LeftArm] = {
            gunshot = 20,
            bleeding = 30
        },

        [LimbType.RightArm] = {
            gunshot = 20,
            bleeding = 30
        },

        [LimbType.LeftLeg] = {
            gunshot = 20,
            bleeding = 30,
            foreignbody = 30,
            artery = 30,
            fracture = "ll_fracture",
            fractureStrength = 100,
            amputation = 100
        },

        [LimbType.RightLeg] = {
            gunshot = 20,
            bleeding = 30,
            fracture = "rl_fracture",
            fractureStrength = 100,
            artery = 30
        }
    },

    torso = {
        gunshot = 30,
        bleeding = 50,
        foreignbody = 30
    },

    afflictions = {
        {
            identifier = "t_fracture",
            strength = 100,
            limb = LimbType.Torso
        },

        {
            identifier = "hypoxemia",
            strength = 0
        },

        {
            identifier = "cardiacarrest",
            strength = 0
        },

        {
            identifier = "aorticrupture",
            strength = 0,
            limb = LimbType.Torso
        }
    }
}

--------------------------------------------------
-- Security Officer trauma profile
--------------------------------------------------

local SECURITY_OFFICER_TRAUMA_PROFILE = {

    limbs = {

        [LimbType.LeftArm] = {
            gunshot = 20,
            bleeding = 30
        },

        [LimbType.RightArm] = {
            gunshot = 20,
            bleeding = 30
        },

        [LimbType.LeftLeg] = {
            gunshot = 20,
            bleeding = 30,
            foreignbody = 20,
            artery = 30,
            fracture = "ll_fracture",
            fractureStrength = 100,
            amputation = 100
        },

        [LimbType.RightLeg] = {
            gunshot = 20,
            bleeding = 30,
            fracture = "rl_fracture",
            fractureStrength = 100,
            artery = 30
        }
    },

    torso = {
        gunshot = 30,
        bleeding = 50,
        foreignbody = 20
    },

    afflictions = {
        {
            identifier = "t_fracture",
            strength = 100,
            limb = LimbType.Torso
        },

        {
            identifier = "hypoxemia",
            strength = 0
        },

        {
            identifier = "cardiacarrest",
            strength = 0
        },

        {
            identifier = "h_fracture",
            strength = 100
        }
    }
}

--------------------------------------------------
-- Assistant trauma profile
--------------------------------------------------

local ASSISTANT_TRAUMA_PROFILE = {

    limbs = {

        [LimbType.LeftArm] = {
            gunshot = 10,
            bleeding = 15
        },

        [LimbType.RightArm] = {
            gunshot = 10,
            bleeding = 15
        },

        [LimbType.LeftLeg] = {
            gunshot = 10,
            bleeding = 15
        },

        [LimbType.RightLeg] = {
            gunshot = 10,
            bleeding = 15
        }
    },

    torso = {
        gunshot = 30,
        bleeding = 40
        -- No torso foreign body.
    },

    afflictions = {
        {
            identifier = "t_fracture",
            strength = 30,
            limb = LimbType.Torso
        }
    }
}

--------------------------------------------------
-- Mechanic trauma profile
--------------------------------------------------

local MECHANIC_TRAUMA_PROFILE = {

    limbs = {

        [LimbType.LeftArm] = {
            gunshot = 20,
            bleeding = 30
        },

        [LimbType.RightArm] = {
            gunshot = 20,
            bleeding = 30
        },

        [LimbType.LeftLeg] = {
            gunshot = 20,
            bleeding = 30,
            foreignbody = 20,
            artery = 30,
            fracture = "ll_fracture",
            fractureStrength = 100,
            amputation = 100
        },

        [LimbType.RightLeg] = {
            gunshot = 20,
            bleeding = 30
        }
    },

    torso = {
        gunshot = 30,
        bleeding = 40,
        foreignbody = 20
    },

    afflictions = {
        {
            identifier = "t_fracture",
            strength = 100,
            limb = LimbType.Torso
        }
    }
}

--------------------------------------------------
-- Engineer trauma profile
--------------------------------------------------

local ENGINEER_TRAUMA_PROFILE = {

    limbs = {

        [LimbType.LeftArm] = {
            gunshot = 20,
            bleeding = 30
        },

        [LimbType.RightArm] = {
            gunshot = 20,
            bleeding = 30
        },

        [LimbType.LeftLeg] = {
            gunshot = 20,
            bleeding = 30,
            foreignbody = 20,
            artery = 30,
            fracture = "ll_fracture",
            fractureStrength = 100,
            amputation = 100
        },

        [LimbType.RightLeg] = {
            gunshot = 20,
            bleeding = 30
        }
    },

    torso = {
        gunshot = 30,
        bleeding = 40,
        foreignbody = 20
    },

    afflictions = {
        {
            identifier = "t_fracture",
            strength = 100,
            limb = LimbType.Torso
        }
    }
}

--------------------------------------------------
-- Profession -> fixed trauma profile
--------------------------------------------------

local FIXED_TRAUMA_PROFILES = {

    captain = CAPTAIN_TRAUMA_PROFILE,

    securityofficer = SECURITY_OFFICER_TRAUMA_PROFILE,

    assistant = ASSISTANT_TRAUMA_PROFILE,

    mechanic = MECHANIC_TRAUMA_PROFILE,

    engineer = ENGINEER_TRAUMA_PROFILE
}

--------------------------------------------------
-- Random bullet configuration
--------------------------------------------------

local BULLET_PROFILES = {

    {
        name = "hmg_light",
        base = 0.75,
        internal = 0.55,
        limb = 0.55,
        artery = 0.30,
        fragment = 0.20
    },

    {
        name = "hmg_standard",
        base = 1.00,
        internal = 0.90,
        limb = 0.75,
        artery = 0.45,
        fragment = 0.35
    },

    {
        name = "hmg_heavy",
        base = 1.25,
        internal = 1.10,
        limb = 0.95,
        artery = 0.60,
        fragment = 0.55
    }
}

--------------------------------------------------
-- General utility functions
--------------------------------------------------

local function debug(msg)
    if debugEnabled then
        print("[NTCCG][DEBUG] " .. msg)
    end
end

local function now()

    if Timing ~= nil
        and Timing.TotalTime ~= nil then

        return Timing.TotalTime
    end

    return os.clock()
end

local function authoritative()

    -- Multiplayer:
    -- only the server is allowed to generate casualties.

    if Game ~= nil
        and Game.IsMultiplayer then

        return SERVER == true
    end

    return true
end

local function randf(a, b)
    return a + (b - a) * math.random()
end

local function randi(a, b)
    return math.random(a, b)
end

local function chance(p)
    return math.random() < p
end

local function pick(list)
    return list[randi(1, #list)]
end

--------------------------------------------------
-- Affliction utilities
--------------------------------------------------

local function hasAffliction(identifier)

    if AfflictionPrefab == nil
        or AfflictionPrefab.Prefabs == nil then

        return false
    end

    local ok, prefab = pcall(
        function()
            return AfflictionPrefab.Prefabs[identifier]
        end
    )

    return ok and prefab ~= nil
end

local function add(
    c,
    identifier,
    strength,
    limb
)

    if c == nil
        or strength == nil
        or strength <= 0 then

        return
    end

    if not hasAffliction(identifier) then

        debug(
            "missing affliction: "
            .. tostring(identifier)
        )

        return
    end

    if limb ~= nil then

        HF.AddAfflictionLimb(
            c,
            identifier,
            limb,
            strength
        )

    else

        HF.AddAffliction(
            c,
            identifier,
            strength
        )
    end
end

--------------------------------------------------
-- Extremity utilities
--------------------------------------------------

local EXTREMITIES = {
    LimbType.LeftArm,
    LimbType.RightArm,
    LimbType.LeftLeg,
    LimbType.RightLeg
}

local function is_extremity(limb)

    return limb == LimbType.LeftArm
        or limb == LimbType.RightArm
        or limb == LimbType.LeftLeg
        or limb == LimbType.RightLeg
end

--------------------------------------------------
-- Amputation state
--------------------------------------------------

local LIMB_CUT_FIX = 2

local function new_amputation_state()

    return {

        count = 0,

        limbs = {
            [LimbType.LeftArm] = false,
            [LimbType.RightArm] = false,
            [LimbType.LeftLeg] = false,
            [LimbType.RightLeg] = false
        }
    }
end

--------------------------------------------------
-- Amputation
--------------------------------------------------

local function amputate_limb(
    c,
    limb,
    state
)

    if c == nil
        or state == nil then

        return false
    end

    if not is_extremity(limb) then
        return false
    end

    if state.count >= LIMB_CUT_FIX then
        return false
    end

    if state.limbs[limb] then
        return false
    end

    local affliction =
        AMPUTATION_AFFLICTIONS[limb]

    if affliction == nil then

        debug(
            "missing amputation affliction for limb: "
            .. tostring(limb)
        )

        return false
    end

    --------------------------------------------------
    -- Traumatic amputation
    --------------------------------------------------

    add(
        c,
        affliction,
        100,
        limb
    )

    --------------------------------------------------
    -- Fracture caused by amputation
    --------------------------------------------------

    if NT.BreakLimb ~= nil then

        NT.BreakLimb(
            c,
            limb
        )
    end

    --------------------------------------------------
    -- Update state
    --------------------------------------------------

    state.limbs[limb] = true
    state.count = state.count + 1

    debug(
        string.format(
            "amputation limb=%s count=%d/%d",
            tostring(limb),
            state.count,
            LIMB_CUT_FIX
        )
    )

    return true
end

--------------------------------------------------
-- Random external wound
--------------------------------------------------

local function external_wound(
    c,
    limb,
    severity
)

    add(
        c,
        "gunshotwound",
        randf(4.0, 10.0) * severity,
        limb
    )

    add(
        c,
        "bleeding",
        randf(6.0, 18.0) * severity,
        limb
    )

    add(
        c,
        "foreignbody",
        randf(20.0, 50.0) * severity,
        limb
    )
end

--------------------------------------------------
-- Random extremity wound
--------------------------------------------------

local function extremity_wound(
    c,
    limb,
    severity,
    arterial
)

    external_wound(
        c,
        limb,
        severity
    )

    --------------------------------------------------
    -- Limb internal damage
    --------------------------------------------------

    add(
        c,
        "internaldamage",
        randf(10.0, 28.0) * severity,
        limb
    )

    --------------------------------------------------
    -- Arterial damage
    --------------------------------------------------

    if arterial
        and NT.ArteryCutLimb ~= nil then

        NT.ArteryCutLimb(
            c,
            limb,
            randf(4.5, 9.0) * severity
        )
    end
end

--------------------------------------------------
-- Random torso wound
--------------------------------------------------

local function torso_wound(
    c,
    severity,
    isCaptain
)

    external_wound(
        c,
        LimbType.Torso,
        severity
    )

    --------------------------------------------------
    -- Internal bleeding
    -- Captain only
    --------------------------------------------------

    if isCaptain then

        add(
            c,
            "internalbleeding",
            randf(18.0, 42.0) * severity
        )
    end

    --------------------------------------------------
    -- Lung damage
    --------------------------------------------------

    add(
        c,
        "lungdamage",
        randf(10.0, 28.0) * severity,
        LimbType.Torso
    )
end

--------------------------------------------------
-- Get health
--------------------------------------------------

local function get_health_fraction(c)

    if c.Health ~= nil then
        return c.Health / 100.0
    end

    return 1.0
end

--------------------------------------------------
-- Random ballistic simulation
--------------------------------------------------

local function apply_random_ballistic(
    c,
    profile,
    impactLimb,
    amputationState,
    isCaptain
)

    local hits = 1

    for _ = 1, hits do

        local severity =
            profile.base
            * randf(0.85, 1.35)

        local limb =
            impactLimb
            or pick(LIMB_POOL)

        debug(
            string.format(
                "ballistics %s limb=%s sev=%.2f",
                profile.name,
                tostring(limb),
                severity
            )
        )

        --------------------------------------------------
        -- Torso
        --------------------------------------------------

        if limb == LimbType.Torso then

            torso_wound(
                c,
                severity,
                isCaptain
            )

        --------------------------------------------------
        -- Extremities / head
        --------------------------------------------------

        else

            local arterial =
                chance(profile.artery)

            if is_extremity(limb) then

                extremity_wound(
                    c,
                    limb,
                    severity,
                    arterial
                )

            else

                --------------------------------------------------
                -- Head
                --------------------------------------------------

                external_wound(
                    c,
                    LimbType.Head,
                    severity
                )

                add(
                    c,
                    "internaldamage",
                    randf(10.0, 28.0) * severity,
                    LimbType.Head
                )
            end

            --------------------------------------------------
            -- Fragment
            --------------------------------------------------

            if chance(profile.fragment) then

                add(
                    c,
                    "foreignbody",
                    randf(3.0, 10.0) * severity,
                    limb
                )

                add(
                    c,
                    "internaldamage",
                    randf(6.0, 16.0) * severity,
                    limb
                )
            end
        end

        --------------------------------------------------
        -- Generic internal bleeding
        -- Captain only
        --------------------------------------------------

        if isCaptain
            and chance(0.25 * profile.internal) then

            add(
                c,
                "internalbleeding",
                randf(8.0, 20.0) * severity
            )
        end

        --------------------------------------------------
        -- Random traumatic amputation
        --------------------------------------------------

        if is_extremity(limb)
            and amputationState ~= nil
            and amputationState.count < LIMB_CUT_FIX
            and not amputationState.limbs[limb] then

            local severChance =
                math.min(
                    0.08
                    + severity * 0.18
                    + profile.fragment * 0.10,
                    0.78
                )

            if chance(severChance) then

                debug(
                    string.format(
                        "sever limb=%s profile=%s sev=%.2f",
                        tostring(limb),
                        profile.name,
                        severity
                    )
                )

                if NT.ArteryCutLimb ~= nil then

                    NT.ArteryCutLimb(
                        c,
                        limb,
                        randf(18.0, 30.0) * severity
                    )
                end

                add(
                    c,
                    "internaldamage",
                    randf(12.0, 24.0) * severity,
                    limb
                )

                amputate_limb(
                    c,
                    limb,
                    amputationState
                )
            end
        end
    end
end

--------------------------------------------------
-- Random mode:
-- continue adding gunshot wounds until vitality
-- reaches zero
--------------------------------------------------

local function amplify_until_death(
    c,
    profileName,
    profile,
    amputationState,
    isCaptain
)

    local safety = 0

    while c ~= nil
        and c.Removed ~= true
        and safety < 100 do

        safety = safety + 1

        local healthFrac =
            get_health_fraction(c)

        if healthFrac <= 0 then
            break
        end

        debug(
            string.format(
                "amplify %s health=%.4f",
                profileName,
                healthFrac
            )
        )

        local impactLimb =
            pick(LIMB_POOL)

        apply_random_ballistic(
            c,
            profile,
            impactLimb,
            amputationState,
            isCaptain
        )
    end
end

--------------------------------------------------
-- Force minimum amputation count for random mode
--------------------------------------------------

local function force_amputation_to_target(
    c,
    state
)

    if c == nil
        or state == nil then

        return
    end

    while state.count < LIMB_CUT_FIX do

        local available = {}

        for _, limb in ipairs(EXTREMITIES) do

            if not state.limbs[limb] then

                table.insert(
                    available,
                    limb
                )
            end
        end

        if #available == 0 then

            debug(
                "no available limb for forced amputation"
            )

            break
        end

        local limb =
            pick(available)

        amputate_limb(
            c,
            limb,
            state
        )
    end
end

--------------------------------------------------
-- Spawn position
--------------------------------------------------

local function get_spawn_position(
    origin,
    index
)

    local centerIndex =
        (CASUALTY_COUNT + 1) / 2

    local offsetX =
        (index - centerIndex)
        * SPAWN_SPACING

    return Vector2(
        origin.X + offsetX,
        origin.Y
    )
end

--------------------------------------------------
-- Get random bullet profile
--------------------------------------------------

local function get_bullet_profile(
    profileName
)

    for _, profile in ipairs(BULLET_PROFILES) do

        if profile.name == profileName then
            return profile
        end
    end

    return BULLET_PROFILES[2]
end

--------------------------------------------------
-- Spawn random casualty
--------------------------------------------------

local function spawn_casualty(
    origin,
    index,
    profileName,
    sourceItem
)

    local nameSeed =
        string.format(
            "NTCCG-%d-%d-%d",
            math.floor(now() * 1000),
            index,
            randi(100000, 999999)
        )

    local info =
        CharacterInfo(
            "human",
            nameSeed
        )

    local jobName =
        ROLE_ORDER[
            ((index - 1) % #ROLE_ORDER) + 1
        ]

    local jobPrefab =
        JobPrefab.Get(jobName)

    if jobPrefab == nil then

        debug(
            "missing job prefab: "
            .. tostring(jobName)
        )

        jobPrefab =
            JobPrefab.Get("assistant")
    end

    info.Job =
        Job(
            jobPrefab,
            false
        )

    local position =
        get_spawn_position(
            origin,
            index
        )

    local c =
        Character.Create(
            info,
            position,
            info.Name
        )

    if c == nil then

        debug(
            "Character.Create returned nil"
        )

        return nil
    end

    c.Enabled = false

    c.GiveJobItems(false)

    if CharacterTeamType ~= nil
        and CharacterTeamType.Team1 ~= nil then

        c.TeamID =
            CharacterTeamType.Team1
    end

    local profile =
        get_bullet_profile(profileName)

    local amputationState =
        new_amputation_state()

    local isCaptain =
        jobName == "captain"

    --------------------------------------------------
    -- Simulate gunshot trauma
    --------------------------------------------------

    amplify_until_death(
        c,
        profile.name,
        profile,
        amputationState,
        isCaptain
    )

    --------------------------------------------------
    -- Ensure target amputation count
    --------------------------------------------------

    force_amputation_to_target(
        c,
        amputationState
    )

    --------------------------------------------------
    -- Rib fracture
    --------------------------------------------------

    if jobName ~= "assistant" then

        add(
            c,
            "t_fracture",
            100,
            LimbType.Torso
        )
    end

    debug(
        string.format(
            "spawned %s role=%s profile=%s amputations=%d/%d",
            tostring(c.Name),
            tostring(jobName),
            tostring(profile.name),
            amputationState.count,
            LIMB_CUT_FIX
        )
    )

    c.Enabled = true

    return c
end

--------------------------------------------------
-- Fixed trauma profile:
-- Apply limb trauma
--------------------------------------------------

local function apply_fixed_limb_trauma(
    c,
    limb,
    trauma
)

    if c == nil
        or trauma == nil then

        return
    end

    --------------------------------------------------
    -- Gunshot wound
    --------------------------------------------------

    if trauma.gunshot ~= nil then

        add(
            c,
            "gunshotwound",
            trauma.gunshot,
            limb
        )
    end

    --------------------------------------------------
    -- Bleeding
    --------------------------------------------------

    if trauma.bleeding ~= nil then

        add(
            c,
            "bleeding",
            trauma.bleeding,
            limb
        )
    end

    --------------------------------------------------
    -- Foreign body
    --------------------------------------------------

    if trauma.foreignbody ~= nil then

        add(
            c,
            "foreignbody",
            trauma.foreignbody,
            limb
        )
    end

    --------------------------------------------------
    -- Fracture
    --------------------------------------------------

    if trauma.fracture ~= nil
        and trauma.fractureStrength ~= nil then

        add(
            c,
            trauma.fracture,
            trauma.fractureStrength,
            limb
        )
    end

    --------------------------------------------------
    -- Arterial damage
    --------------------------------------------------

    if trauma.artery ~= nil
        and trauma.artery > 0 then

        if NT.ArteryCutLimb ~= nil then

            NT.ArteryCutLimb(
                c,
                limb,
                trauma.artery
            )
        end
    end

    --------------------------------------------------
    -- Traumatic amputation
    --------------------------------------------------

    if trauma.amputation ~= nil
        and trauma.amputation > 0 then

        local amputationAffliction =
            AMPUTATION_AFFLICTIONS[limb]

        if amputationAffliction ~= nil then

            add(
                c,
                amputationAffliction,
                trauma.amputation,
                limb
            )

            if NT.BreakLimb ~= nil then

                NT.BreakLimb(
                    c,
                    limb
                )
            end

            debug(
                "fixed traumatic amputation limb="
                .. tostring(limb)
            )
        end
    end
end

--------------------------------------------------
-- Fixed trauma profile:
-- Apply torso trauma
--------------------------------------------------

local function apply_fixed_torso_trauma(
    c,
    trauma
)

    if c == nil
        or trauma == nil then

        return
    end

    if trauma.gunshot ~= nil then

        add(
            c,
            "gunshotwound",
            trauma.gunshot,
            LimbType.Torso
        )
    end

    if trauma.bleeding ~= nil then

        add(
            c,
            "bleeding",
            trauma.bleeding,
            LimbType.Torso
        )
    end

    if trauma.foreignbody ~= nil then

        add(
            c,
            "foreignbody",
            trauma.foreignbody,
            LimbType.Torso
        )
    end
end

--------------------------------------------------
-- Fixed trauma profile:
-- Apply special / whole-body trauma
--------------------------------------------------

local function apply_fixed_profile_afflictions(
    c,
    afflictions
)

    if c == nil
        or afflictions == nil then

        return
    end

    for _, trauma in ipairs(afflictions) do

        if trauma ~= nil
            and trauma.identifier ~= nil
            and trauma.strength ~= nil
            and trauma.strength > 0 then

            add(
                c,
                trauma.identifier,
                trauma.strength,
                trauma.limb
            )
        end
    end
end

--------------------------------------------------
-- Fixed trauma profile:
-- Apply complete profile
--------------------------------------------------

local function apply_fixed_trauma_profile(
    c,
    profile
)

    if c == nil
        or profile == nil then

        return
    end

    --------------------------------------------------
    -- Limbs
    --------------------------------------------------

    if profile.limbs ~= nil then

        for limb, trauma in pairs(profile.limbs) do

            apply_fixed_limb_trauma(
                c,
                limb,
                trauma
            )
        end
    end

    --------------------------------------------------
    -- Torso
    --------------------------------------------------

    if profile.torso ~= nil then

        apply_fixed_torso_trauma(
            c,
            profile.torso
        )
    end

    --------------------------------------------------
    -- Additional afflictions
    --------------------------------------------------

    apply_fixed_profile_afflictions(
        c,
        profile.afflictions
    )

    --------------------------------------------------
    -- Fixed infection
    --------------------------------------------------

    add(
        c,
        "infectedcavity",
        FIXED_INFECTED_CAVITY
    )
end

--------------------------------------------------
-- Get fixed trauma profile
--------------------------------------------------

local function get_fixed_trauma_profile(
    jobName
)

    return FIXED_TRAUMA_PROFILES[jobName]
end

--------------------------------------------------
-- Fixed mode:
-- Increase existing gunshot wounds and bleeding
-- until Character.Health / Vitality reaches zero.
--
-- Character.Health is read-only, so this does NOT
-- attempt to assign c.Health.
--------------------------------------------------

local FIXED_FINISH_LIMBS = {

    LimbType.LeftArm,
    LimbType.RightArm,
    LimbType.LeftLeg,
    LimbType.RightLeg,
    LimbType.Torso
}

local FIXED_FINISH_MAX_ITERATIONS = 32

local function fixed_finish_health(c)

    if c == nil then
        return
    end

    --------------------------------------------------
    -- Record existing gunshot / bleeding values
    --------------------------------------------------

    local wounds = {}

    for _, limb in ipairs(FIXED_FINISH_LIMBS) do

        local amputated = false

        if NT.LimbIsAmputated ~= nil then

            amputated =
                NT.LimbIsAmputated(
                    c,
                    limb
                )
        end

        if not amputated then

            local gunshot =
                HF.GetAfflictionStrengthLimb(
                    c,
                    limb,
                    "gunshotwound",
                    0
                )

            local bleeding =
                HF.GetAfflictionStrengthLimb(
                    c,
                    limb,
                    "bleeding",
                    0
                )

            if gunshot > 0
                or bleeding > 0 then

                table.insert(
                    wounds,
                    {
                        limb = limb,
                        gunshot = gunshot,
                        bleeding = bleeding
                    }
                )
            end
        end
    end

    if #wounds == 0 then

        debug(
            "fixed_finish_health: no existing gunshot/bleeding wounds"
        )

        return
    end

    --------------------------------------------------
    -- Apply extra damage to all existing wounds
    --------------------------------------------------

    local function apply_extra(
        extra
    )

        for _, wound in ipairs(wounds) do

            local newGunshot =
                math.min(
                    wound.gunshot + extra,
                    100
                )

            local newBleeding =
                math.min(
                    wound.bleeding + extra,
                    100
                )

            HF.SetAfflictionLimb(
                c,
                "gunshotwound",
                wound.limb,
                newGunshot
            )

            HF.SetAfflictionLimb(
                c,
                "bleeding",
                wound.limb,
                newBleeding
            )
        end
    end

    --------------------------------------------------
    -- Already dead
    --------------------------------------------------

    local initialHealth = c.Health

    if initialHealth <= 0 then

        debug(
            string.format(
                "fixed_finish_health: already empty health=%.6f",
                initialHealth
            )
        )

        return
    end

    --------------------------------------------------
    -- Find an upper bound
    --------------------------------------------------

    local low = 0
    local high = 1

    apply_extra(high)

    local safety = 0

    while c.Health > 0
        and high < 100
        and safety < 20 do

        high =
            math.min(
                high * 2,
                100
            )

        apply_extra(high)

        safety = safety + 1
    end

    --------------------------------------------------
    -- Could not reach zero
    --------------------------------------------------

    if c.Health > 0 then

        debug(
            string.format(
                "fixed_finish_health: failed to reach zero health=%.6f extra=%.2f",
                c.Health,
                high
            )
        )

        return
    end

    --------------------------------------------------
    -- Binary search the death boundary
    --
    -- low:
    --     Health > 0
    --
    -- high:
    --     Health <= 0
    --------------------------------------------------

    for _ = 1, FIXED_FINISH_MAX_ITERATIONS do

        local mid =
            (low + high) / 2

        apply_extra(mid)

        if c.Health > 0 then

            low = mid

        else

            high = mid
        end
    end

    --------------------------------------------------
    -- Choose the value closest to zero
    --------------------------------------------------

    apply_extra(low)

    local lowHealth =
        c.Health

    apply_extra(high)

    local highHealth =
        c.Health

    if math.abs(lowHealth)
        <= math.abs(highHealth) then

        apply_extra(low)

        debug(
            string.format(
                "fixed_finish_health: final health=%.8f extra=%.8f",
                c.Health,
                low
            )
        )

    else

        apply_extra(high)

        debug(
            string.format(
                "fixed_finish_health: final health=%.8f extra=%.8f",
                c.Health,
                high
            )
        )
    end
end

--------------------------------------------------
-- Spawn fixed casualty
--------------------------------------------------

local function spawn_fixed_casualty(
    origin,
    index,
    sourceItem
)

    local nameSeed =
        string.format(
            "NTCCG-Fixed-%d-%d-%d",
            math.floor(now() * 1000),
            index,
            randi(100000, 999999)
        )

    --------------------------------------------------
    -- Character info
    --------------------------------------------------

    local info =
        CharacterInfo(
            "human",
            nameSeed
        )

    local jobName =
        ROLE_ORDER[
            ((index - 1) % #ROLE_ORDER) + 1
        ]

    --------------------------------------------------
    -- Job
    --------------------------------------------------

    local jobPrefab =
        JobPrefab.Get(jobName)

    if jobPrefab == nil then

        debug(
            "missing job prefab: "
            .. tostring(jobName)
        )

        jobPrefab =
            JobPrefab.Get("assistant")
    end

    info.Job =
        Job(
            jobPrefab,
            false
        )

    --------------------------------------------------
    -- Spawn position
    --------------------------------------------------

    local position =
        get_spawn_position(
            origin,
            index
        )

    --------------------------------------------------
    -- Create character
    --------------------------------------------------

    local c =
        Character.Create(
            info,
            position,
            info.Name
        )

    if c == nil then

        debug(
            "Character.Create returned nil (fixed)"
        )

        return nil
    end

    --------------------------------------------------
    -- Keep disabled while injuries are applied
    --------------------------------------------------

    c.Enabled = false

    c.GiveJobItems(false)

    if CharacterTeamType ~= nil
        and CharacterTeamType.Team1 ~= nil then

        c.TeamID =
            CharacterTeamType.Team1
    end

    --------------------------------------------------
    -- Get independent profession trauma profile
    --------------------------------------------------

    local traumaProfile =
        get_fixed_trauma_profile(
            jobName
        )

    if traumaProfile == nil then

        debug(
            "missing fixed trauma profile for role="
            .. tostring(jobName)
        )

    else

        apply_fixed_trauma_profile(
            c,
            traumaProfile
        )
    end

    --------------------------------------------------
    -- Bring vitality to zero by increasing the
    -- existing gunshot wounds and bleeding.
    --------------------------------------------------

    fixed_finish_health(c)

    --------------------------------------------------
    -- Debug final state
    --------------------------------------------------

    debug(
        string.format(
            "fixed spawned %s role=%s health=%.8f",
            tostring(c.Name),
            tostring(jobName),
            c.Health
        )
    )

    --------------------------------------------------
    -- Enable NPC
    --------------------------------------------------

    c.Enabled = true

    return c
end

--------------------------------------------------
-- Generate fixed casualties
--------------------------------------------------

local function generate_fixed(
    origin,
    sourceItem
)

    if not authoritative() then

        debug(
            "skip fixed generate: not authoritative"
        )

        return
    end

    if now() < nextFixedTriggerTime then

        debug(
            string.format(
                "skip fixed generate: cooldown %.2f < %.2f",
                now(),
                nextFixedTriggerTime
            )
        )

        return
    end

    nextFixedTriggerTime =
        now() + TRIGGER_COOLDOWN

    debug(
        string.format(
            "fixed generate item=%s pos=(%.1f, %.1f) id=%s",
            sourceItem ~= nil
                and sourceItem.Prefab ~= nil
                and sourceItem.Prefab.Identifier ~= nil
                and tostring(
                    sourceItem.Prefab.Identifier.Value
                )
                or "nil",

            origin.X,
            origin.Y,

            sourceItem ~= nil
                and tostring(sourceItem.ID)
                or "nil"
        )
    )

    local spawned = 0

    for i = 1, CASUALTY_COUNT do

        if spawn_fixed_casualty(
            origin,
            i,
            sourceItem
        ) ~= nil then

            spawned =
                spawned + 1
        end
    end

    print(
        string.format(
            "[NTCCG] Fixed generated %d/%d casualties at (%.0f, %.0f).",
            spawned,
            CASUALTY_COUNT,
            origin.X,
            origin.Y
        )
    )
end

--------------------------------------------------
-- Generate random casualties
--------------------------------------------------

local function generate(
    origin,
    sourceItem
)

    if not authoritative() then

        debug(
            "skip generate: not authoritative"
        )

        return
    end

    if now() < nextTriggerTime then

        debug(
            string.format(
                "skip generate: cooldown %.2f < %.2f",
                now(),
                nextTriggerTime
            )
        )

        return
    end

    nextTriggerTime =
        now() + TRIGGER_COOLDOWN

    debug(
        string.format(
            "generate item=%s pos=(%.1f, %.1f) id=%s",
            sourceItem ~= nil
                and sourceItem.Prefab ~= nil
                and sourceItem.Prefab.Identifier ~= nil
                and tostring(
                    sourceItem.Prefab.Identifier.Value
                )
                or "nil",

            origin.X,
            origin.Y,

            sourceItem ~= nil
                and tostring(sourceItem.ID)
                or "nil"
        )
    )

    local spawned = 0

    for i = 1, CASUALTY_COUNT do

        local profile =
            pick(BULLET_PROFILES)

        if spawn_casualty(
            origin,
            i,
            profile.name,
            sourceItem
        ) ~= nil then

            spawned =
                spawned + 1
        end
    end

    print(
        string.format(
            "[NTCCG] Generated %d/%d casualties at (%.0f, %.0f).",
            spawned,
            CASUALTY_COUNT,
            origin.X,
            origin.Y
        )
    )
end

--------------------------------------------------
-- Revolver Hook
--------------------------------------------------

Hook.Add(
    "ntccg.revolver.onUse",
    "NTCCG.RevolverOnUse",
    function(
        statusEffect,
        deltaTime,
        item
    )

        if item == nil
            or item.Prefab == nil
            or item.Prefab.Identifier == nil then

            debug(
                "lua hook fired with nil item"
            )

            return
        end

        debug(
            string.format(
                "lua hook item=%s delta=%.3f",
                tostring(
                    item.Prefab.Identifier.Value
                ),
                deltaTime or -1
            )
        )

        if item.WorldPosition == nil then

            debug(
                "lua hook aborted: item.WorldPosition is nil"
            )

            return
        end

        if not authoritative() then

            debug(
                "lua hook ignored on non-authoritative side"
            )

            return
        end

        local pos =
            Vector2(
                item.WorldPosition.X,
                item.WorldPosition.Y
            )

        Timer.Wait(
            function()

                generate(
                    pos,
                    item
                )

            end,
            50
        )
    end
)

--------------------------------------------------
-- Fixed Revolver Hook
--------------------------------------------------

Hook.Add(
    "ntccg.fixed.revolver.onUse",
    "NTCCG.FixedRevolverOnUse",
    function(
        statusEffect,
        deltaTime,
        item
    )

        if item == nil
            or item.Prefab == nil
            or item.Prefab.Identifier == nil then

            debug(
                "fixed lua hook fired with nil item"
            )

            return
        end

        debug(
            string.format(
                "fixed lua hook item=%s delta=%.3f",
                tostring(
                    item.Prefab.Identifier.Value
                ),
                deltaTime or -1
            )
        )

        if item.WorldPosition == nil then

            debug(
                "fixed lua hook aborted: item.WorldPosition is nil"
            )

            return
        end

        if not authoritative() then

            debug(
                "fixed lua hook ignored on non-authoritative side"
            )

            return
        end

        local pos =
            Vector2(
                item.WorldPosition.X,
                item.WorldPosition.Y
            )

        Timer.Wait(
            function()

                generate_fixed(
                    pos,
                    item
                )

            end,
            50
        )
    end
)

print(
    "[NTCCG] Loaded. LuaHooks armed for NT Combat Casualty Revolver and Fixed Revolver."
)