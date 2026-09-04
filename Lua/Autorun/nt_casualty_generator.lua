print("[NTCCG] Autorun loaded.")

if NT == nil or HF == nil then
    print("[NTCCG] Neurotrauma was not found. This mod requires Neurotrauma.")
    return
end

local debugEnabled = true

local CASUALTY_COUNT = 5
local TRIGGER_COOLDOWN = 0.75
local nextTriggerTime = 0

-- 固定伤情模式独立冷却
local nextFixedTriggerTime = 0

--------------------------------------------------
-- 固定伤情配置
--------------------------------------------------

local FIXED_EXTREMITY_GUNSHOT = 20
local FIXED_EXTREMITY_BLEEDING = 30

local FIXED_ASSISTANT_EXTREMITY_GUNSHOT = 10
local FIXED_ASSISTANT_EXTREMITY_BLEEDING = 15

local FIXED_TORSO_GUNSHOT = 30
local FIXED_TORSO_BLEEDING = 50
local FIXED_ASSISTANT_TORSO_BLEEDING = 40
local FIXED_ENGINEER_TORSO_BLEEDING = 40

local FIXED_FOREIGN_BODY = 30
local FIXED_RIB_FRACTURE = 100
local FIXED_ASSISTANT_RIB_FRACTURE = 30

local FIXED_BLOODLOSS = 100
local FIXED_INFECTED_CAVITY = 5
local FIXED_HYPOXEMIA = 50
local FIXED_CARDIAC_ARREST = 10
local FIXED_SKULL_FRACTURE = 100
local FIXED_AMPUTATION_FRACTURE = 100
local FIXED_OTHER_LEG_FRACTURE = 100
local FIXED_ARTERY_DAMAGE = 30

-- 机电只保留一个创伤性截肢，固定左腿。
local FIXED_AMPUTATION_LIMB = LimbType.LeftLeg
local FIXED_OTHER_LEG = LimbType.RightLeg

-- 主动脉破裂 identifier。若当前 Neurotrauma 版本使用不同 identifier，
-- 只需修改这一项，不影响其他固定伤情。
local FIXED_AORTIC_RUPTURE_AFFLICTION = "aorticrupture"
local FIXED_AORTIC_RUPTURE_STRENGTH = 100

-- NPC 横向排列间距
-- 约 1.5 个角色身高
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

local LIMB_CUT_FIX = 2

--------------------------------------------------
-- 子弹伤害配置
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
    },
}

--------------------------------------------------
-- 工具函数
--------------------------------------------------

local function debug(msg)
    if debugEnabled then
        print("[NTCCG][DEBUG] " .. msg)
    end
end

local function now()
    if Timing ~= nil and Timing.TotalTime ~= nil then
        return Timing.TotalTime
    end

    return os.clock()
end

local function authoritative()
    -- 多人游戏只允许服务器生成 NPC
    if Game ~= nil and Game.IsMultiplayer then
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
-- Affliction
--------------------------------------------------

local function hasAffliction(identifier)
    if AfflictionPrefab == nil
        or AfflictionPrefab.Prefabs == nil then
        return false
    end

    local ok, prefab = pcall(function()
        return AfflictionPrefab.Prefabs[identifier]
    end)

    return ok and prefab ~= nil
end

local function add(c, identifier, strength, limb)
    if c == nil
        or strength == nil
        or strength <= 0 then
        return
    end

    if not hasAffliction(identifier) then
        debug("missing affliction: " .. tostring(identifier))
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
-- 四肢
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
-- 截肢对应的 Neurotrauma Affliction
--------------------------------------------------

local AMPUTATION_AFFLICTIONS = {
    [LimbType.LeftArm] = "tla_amputation",
    [LimbType.RightArm] = "tra_amputation",
    [LimbType.LeftLeg] = "tll_amputation",
    [LimbType.RightLeg] = "trl_amputation"
}

--------------------------------------------------
-- 截肢状态
--------------------------------------------------

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
-- 截肢
--
-- 截肢时：
-- 1. 添加对应 amputation Affliction
-- 2. 使用 NT.BreakLimb 添加骨折
-- 3. 记录已经截肢的肢体
--------------------------------------------------

local function amputate_limb(c, limb, state)
    if c == nil or state == nil then
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

    local affliction = AMPUTATION_AFFLICTIONS[limb]

    if affliction == nil then
        debug("missing amputation affliction for limb: " .. tostring(limb))
        return false
    end

    --------------------------------------------------
    -- 截肢
    --------------------------------------------------

    add(
        c,
        affliction,
        100,
        limb
    )

    --------------------------------------------------
    -- 同时骨折
    --------------------------------------------------

    if NT.BreakLimb ~= nil then
        NT.BreakLimb(
            c,
            limb
        )
    end

    --------------------------------------------------
    -- 更新截肢状态
    --------------------------------------------------

    state.limbs[limb] = true
    state.count = state.count + 1

    debug(string.format(
        "amputation limb=%s count=%d/%d",
        tostring(limb),
        state.count,
        LIMB_CUT_FIX
    ))

    return true
end

--------------------------------------------------
-- 外部枪伤
--------------------------------------------------

local function external_wound(c, limb, severity)
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
-- 四肢枪伤
--------------------------------------------------

local function extremity_wound(c, limb, severity, arterial)
    external_wound(
        c,
        limb,
        severity
    )

    --------------------------------------------------
    -- 骨折（ban)
    --------------------------------------------------

    -- if chance(
    --     math.min(
    --         0.12 + severity * 0.28,
    --         0.85
    --     )
    -- ) then
    --     if NT.BreakLimb ~= nil then
    --         NT.BreakLimb(
    --             c,
    --             limb
    --         )
    --     end
    -- end

    --------------------------------------------------
    -- 肢体内部损伤
    --------------------------------------------------

    add(
        c,
        "internaldamage",
        randf(10.0, 28.0) * severity,
        limb
    )

    --------------------------------------------------
    -- 动脉损伤
    --
    -- 使用 Neurotrauma 专用函数
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
-- 躯干枪伤
--------------------------------------------------

local function torso_wound(c, severity, isCaptain)
    external_wound(
        c,
        LimbType.Torso,
        severity
    )

    --------------------------------------------------
    -- 内出血
    --
    -- 仅舰长
    --------------------------------------------------

    if isCaptain then
        add(
            c,
            "internalbleeding",
            randf(18.0, 42.0) * severity
        )
    end

    --------------------------------------------------
    -- 失血(ban)
    --------------------------------------------------

    -- add(
    --     c,
    --     "bloodloss",
    --     randf(18.0, 50.0) * severity
    -- )

    --------------------------------------------------
    -- 肺损伤
    --------------------------------------------------

    add(
        c,
        "lungdamage",
        randf(10.0, 28.0) * severity,
        LimbType.Torso
    )

    --------------------------------------------------
    -- 气胸(ban)
    --------------------------------------------------

    -- add(
    --     c,
    --     "pneumothorax",
    --     randf(3.0, 7.0) * severity
    -- )

    --------------------------------------------------
    -- 缺氧（ban）
    --------------------------------------------------

    -- add(
    --     c,
    --     "hypoxemia",
    --     randf(4.0, 15.0) * severity
    -- )
end

--------------------------------------------------
-- 获取血量比例
--------------------------------------------------

local function get_health_fraction(c)
    if c.Health ~= nil then
        return c.Health / 100.0
    end

    return 1.0
end

--------------------------------------------------
-- 随机枪击
--------------------------------------------------

local function apply_random_ballistic(
    c,
    profile,
    impactLimb,
    amputationState,
    isCaptain
)
    -- 一次枪击
    local hits = randi(1, 1)

    for _ = 1, hits do

        local severity =
            profile.base * randf(0.85, 1.35)

        local limb =
            impactLimb or pick(LIMB_POOL)

        debug(string.format(
            "ballistics %s limb=%s sev=%.2f",
            profile.name,
            tostring(limb),
            severity
        ))

        --------------------------------------------------
        -- 躯干
        --------------------------------------------------

        if limb == LimbType.Torso then

            torso_wound(
                c,
                severity,
                isCaptain
            )

        --------------------------------------------------
        -- 四肢 / 头部
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
                -- 头部
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
            -- 碎片
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
        -- 通用内出血
        --
        -- 只有舰长
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
        -- 截肢判定
        --
        -- 只有四肢可以截肢
        -- 已达到目标后不再计算
        -- 已截肢肢体不重复计算
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

                debug(string.format(
                    "sever limb=%s profile=%s sev=%.2f",
                    tostring(limb),
                    profile.name,
                    severity
                ))

                --------------------------------------------------
                -- 截肢前额外严重损伤
                --------------------------------------------------

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

                --------------------------------------------------
                -- 截肢 + 骨折
                --------------------------------------------------

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
-- 持续增加枪伤直到死亡
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

        debug(string.format(
            "amplify %s health=%.2f",
            profileName,
            healthFrac
        ))

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
-- 强制补足截肢
--------------------------------------------------

local function force_amputation_to_target(
    c,
    state
)
    if c == nil or state == nil then
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
            debug("no available limb for forced amputation")
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
-- 生成位置
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
-- 根据名称寻找 Bullet Profile
--------------------------------------------------

local function get_bullet_profile(profileName)
    for _, profile in ipairs(BULLET_PROFILES) do
        if profile.name == profileName then
            return profile
        end
    end

    return BULLET_PROFILES[2]
end

--------------------------------------------------
-- 创建 NPC
--------------------------------------------------

local function spawn_casualty(
    origin,
    index,
    profileName,
    sourceItem
)
    local nameSeed = string.format(
        "NTCCG-%d-%d-%d",
        math.floor(now() * 1000),
        index,
        randi(100000, 999999)
    )

    --------------------------------------------------
    -- 保持原始 CharacterInfo API
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

    --------------------------------------------------
    -- 保持原始 Job API
    --------------------------------------------------

    info.Job =
        Job(
            jobPrefab,
            false
        )

    --------------------------------------------------
    -- 固定横向排列
    --------------------------------------------------

    local position =
        get_spawn_position(
            origin,
            index
        )

    --------------------------------------------------
    -- 保持原始 Character.Create API
    --------------------------------------------------

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

    --------------------------------------------------
    -- 保持原始 API
    --------------------------------------------------

    c.GiveJobItems(false)

    if CharacterTeamType ~= nil
        and CharacterTeamType.Team1 ~= nil then

        c.TeamID =
            CharacterTeamType.Team1
    end

    --------------------------------------------------
    -- Bullet Profile
    --
    -- 不再使用原来的
    -- {"limb","torso","poly","critical","torso"}
    --
    -- 直接随机选择真正存在的 profile
    --------------------------------------------------

    local profile =
        get_bullet_profile(
            profileName
        )

    --------------------------------------------------
    -- 截肢状态
    --------------------------------------------------

    local amputationState =
        new_amputation_state()

    --------------------------------------------------
    -- 舰长判断
    --------------------------------------------------

    local isCaptain =
        jobName == "captain"

    --------------------------------------------------
    -- 模拟枪伤
    --------------------------------------------------

    amplify_until_death(
        c,
        profile.name,
        profile,
        amputationState,
        isCaptain
    )

    --------------------------------------------------
    -- 最终保证 2 个不同肢体截肢
    --------------------------------------------------

    force_amputation_to_target(
        c,
        amputationState
    )

    --------------------------------------------------
    -- Rib Fracture
    --
    -- Assistt_ant 不添加
    -- 其他职业都添加
    --------------------------------------------------

    if jobName ~= "assistant" then

        add(
            c,
            "t_fracture",
            100,
            LimbType.Torso
        )

        debug(
            "Rib Fracture added to "
            .. tostring(c.Name)
            .. " | role="
            .. tostring(jobName)
        )
    end

    --------------------------------------------------
    -- 最终状态
    --------------------------------------------------

    debug(string.format(
        "spawned %s role=%s profile=%s amputations=%d/%d",
        tostring(c.Name),
        tostring(jobName),
        tostring(profile.name),
        amputationState.count,
        LIMB_CUT_FIX
    ))

    c.Enabled = true

    return c
end

--------------------------------------------------
-- 固定伤情模式
--------------------------------------------------

local function fixed_add_extremity_wounds(c, gunshot, bleeding)
    for _, limb in ipairs({
        LimbType.LeftArm,
        LimbType.RightArm,
        LimbType.LeftLeg,
        LimbType.RightLeg
    }) do
        add(c, "gunshotwound", gunshot, limb)
        add(c, "bleeding", bleeding, limb)
    end
end

local function fixed_add_torso_wounds(c, gunshot, bleeding)
    add(c, "gunshotwound", gunshot, LimbType.Torso)
    add(c, "bleeding", bleeding, LimbType.Torso)
    add(c, "foreignbody", FIXED_FOREIGN_BODY, LimbType.Torso)
end

local function fixed_add_leg_fracture(c, limb, strength)
    if limb == LimbType.LeftLeg then
        add(c, "ll_fracture", strength, limb)
    elseif limb == LimbType.RightLeg then
        add(c, "rl_fracture", strength, limb)
    end
end

local function fixed_add_artery_cut(c, limb)
    if NT.ArteryCutLimb ~= nil then
        NT.ArteryCutLimb(
            c,
            limb,
            FIXED_ARTERY_DAMAGE
        )
    end
end

local function fixed_amputate_limb(c, limb)
    local affliction = AMPUTATION_AFFLICTIONS[limb]

    if affliction == nil then
        debug(
            "fixed missing amputation affliction: "
            .. tostring(limb)
        )
        return
    end

    -- 创伤性截肢
    add(c, affliction, 100, limb)

    -- 截肢同时骨折 100
    fixed_add_leg_fracture(
        c,
        limb,
        FIXED_AMPUTATION_FRACTURE
    )

    -- 截肢部位异物 30
    add(c, "foreignbody", FIXED_FOREIGN_BODY, limb)

    -- 截肢部位动脉破裂
    fixed_add_artery_cut(c, limb)

    debug(
        "fixed traumatic amputation limb="
        .. tostring(limb)
    )
end

local function fixed_add_other_leg_trauma(c)
    -- 另一条腿：骨折 100 + 动脉破裂
    fixed_add_leg_fracture(
        c,
        FIXED_OTHER_LEG,
        FIXED_OTHER_LEG_FRACTURE
    )

    fixed_add_artery_cut(
        c,
        FIXED_OTHER_LEG
    )
end

local function fixed_apply_major_role(c, isCaptain)
    -- 四肢：枪伤 20 / 出血 30
    fixed_add_extremity_wounds(
        c,
        FIXED_EXTREMITY_GUNSHOT,
        FIXED_EXTREMITY_BLEEDING
    )

    -- 躯干：枪伤 30 / 出血 50 / 异物 30
    fixed_add_torso_wounds(
        c,
        FIXED_TORSO_GUNSHOT,
        FIXED_TORSO_BLEEDING
    )

    -- 肋骨骨折 100
    add(
        c,
        "t_fracture",
        FIXED_RIB_FRACTURE,
        LimbType.Torso
    )

    -- 低血氧 100
    add(c, "hypoxemia", FIXED_HYPOXEMIA)

    -- 心脏骤停
    add(c, "cardiacarrest", FIXED_CARDIAC_ARREST)

    -- 左腿：创伤性截肢 + 骨折 + 动脉破裂 + 异物
    fixed_amputate_limb(
        c,
        FIXED_AMPUTATION_LIMB
    )

    -- 右腿：骨折 + 动脉破裂，不截肢
    fixed_add_other_leg_trauma(c)

    -- Security 有颅骨破裂，Captain 取消
    if not isCaptain then
        add(
            c,
            "h_fracture",
            FIXED_SKULL_FRACTURE
        )
    end

    -- Captain 额外添加躯干主动脉破裂
    if isCaptain then
        add(
            c,
            FIXED_AORTIC_RUPTURE_AFFLICTION,
            FIXED_AORTIC_RUPTURE_STRENGTH,
            LimbType.Torso
        )
    end
end

local function fixed_apply_engineer_role(c)
    -- 四肢：枪伤 20 / 出血 30
    fixed_add_extremity_wounds(
        c,
        FIXED_EXTREMITY_GUNSHOT,
        FIXED_EXTREMITY_BLEEDING
    )

    -- 躯干：枪伤 30 / 出血 40 / 异物 30
    fixed_add_torso_wounds(
        c,
        FIXED_TORSO_GUNSHOT,
        FIXED_ENGINEER_TORSO_BLEEDING
    )

    -- 肋骨骨折 100
    add(
        c,
        "t_fracture",
        FIXED_RIB_FRACTURE,
        LimbType.Torso
    )

    -- 仅一个创伤性截肢，固定左腿
    fixed_amputate_limb(
        c,
        FIXED_AMPUTATION_LIMB
    )
end

local function fixed_apply_assistant(c)
    -- 四肢：枪伤 10 / 出血 15
    fixed_add_extremity_wounds(
        c,
        FIXED_ASSISTANT_EXTREMITY_GUNSHOT,
        FIXED_ASSISTANT_EXTREMITY_BLEEDING
    )

    -- 躯干：枪伤 30 / 出血 40 / 异物 30
    fixed_add_torso_wounds(
        c,
        FIXED_ASSISTANT_TORSO_GUNSHOT,
        FIXED_ASSISTANT_TORSO_BLEEDING
    )

    -- 肋骨骨折 30
    add(
        c,
        "t_fracture",
        FIXED_ASSISTANT_RIB_FRACTURE,
        LimbType.Torso
    )
end

local function fixed_apply_role_injuries(c, jobName)
    if jobName == "captain" then
        fixed_apply_major_role(c, true)

    elseif jobName == "securityofficer" then
        fixed_apply_major_role(c, false)

    elseif jobName == "mechanic"
        or jobName == "engineer" then
        fixed_apply_engineer_role(c)

    elseif jobName == "assistant" then
        fixed_apply_assistant(c)

    else
        debug(
            "fixed unknown role: "
            .. tostring(jobName)
        )
    end
end

--------------------------------------------------
-- 精确补足枪伤 / 出血直到血量归零
--
-- Character.Health 是只读的，不能直接赋值。
-- 因此通过提高已有 gunshotwound + bleeding 的强度，
-- 让 CharacterHealth 重新计算 Vitality。
--
-- 此函数必须在 c.Enabled = true 之前调用。
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
    -- 记录当前固定伤势
    --
    -- 只对已经存在枪伤/出血的肢体进行加深。
    -- 已截肢的肢体不再继续增加。
    --------------------------------------------------

    local wounds = {}

    for _, limb in ipairs(FIXED_FINISH_LIMBS) do

        local amputated = false

        if NT.LimbIsAmputated ~= nil then
            amputated = NT.LimbIsAmputated(c, limb)
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

            if gunshot > 0 or bleeding > 0 then

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
        debug("fixed_finish_health: no existing gunshot/bleeding wounds")
        return
    end

    --------------------------------------------------
    -- 设置“额外伤势”
    --
    -- extra = 0:
    --     恢复到当前固定伤势
    --
    -- extra > 0:
    --     在原固定伤势基础上同时增加
    --     gunshotwound 和 bleeding
    --------------------------------------------------

    local function apply_extra(extra)

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
    -- 当前固定伤势下的血量
    --------------------------------------------------

    local initialHealth = c.Health

    if initialHealth <= 0 then
        debug(string.format(
            "fixed_finish_health: already empty health=%.6f",
            initialHealth
        ))
        return
    end

    --------------------------------------------------
    -- 找到一个一定能把血量压到 0 以下的 upper bound
    --------------------------------------------------

    local low = 0
    local high = 1

    apply_extra(high)

    local safety = 0

    while c.Health > 0
        and high < 100
        and safety < 20 do

        high = math.min(
            high * 2,
            100
        )

        apply_extra(high)

        safety = safety + 1
    end

    --------------------------------------------------
    -- 连最大值都不够
    --------------------------------------------------

    if c.Health > 0 then

        debug(string.format(
            "fixed_finish_health: failed to reach zero, health=%.6f extra=%.2f",
            c.Health,
            high
        ))

        return
    end

    --------------------------------------------------
    -- 二分搜索真正的死亡临界点
    --
    -- low  : Health > 0
    -- high : Health <= 0
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
    -- low / high 各测试一次
    -- 选择距离 0 最近的结果
    --------------------------------------------------

    apply_extra(low)

    local lowHealth =
        c.Health

    apply_extra(high)

    local highHealth =
        c.Health

    if math.abs(lowHealth) <= math.abs(highHealth) then

        apply_extra(low)

        debug(string.format(
            "fixed_finish_health: final health=%.8f extra=%.8f",
            c.Health,
            low
        ))

    else

        apply_extra(high)

        debug(string.format(
            "fixed_finish_health: final health=%.8f extra=%.8f",
            c.Health,
            high
        ))

    end
end

--------------------------------------------------
-- 固定模式创建 NPC
--------------------------------------------------

local function spawn_fixed_casualty(
    origin,
    index,
    sourceItem
)
    local nameSeed = string.format(
        "NTCCG-Fixed-%d-%d-%d",
        math.floor(now() * 1000),
        index,
        randi(100000, 999999)
    )

    -- 保持原始 CharacterInfo API
    local info = CharacterInfo(
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

    -- 保持原始 Job API
    info.Job = Job(
        jobPrefab,
        false
    )

    -- 与旧模式相同的固定横向排列
    local position =
        get_spawn_position(
            origin,
            index
        )

    -- 保持原始 Character.Create API
    local c = Character.Create(
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

    c.Enabled = false

    -- 保持原始 API
    c.GiveJobItems(false)

    if CharacterTeamType ~= nil
        and CharacterTeamType.Team1 ~= nil then
        c.TeamID = CharacterTeamType.Team1
    end

    fixed_apply_role_injuries(
        c,
        jobName
    )

    --------------------------------------------------
    -- 在固定伤势基础上继续加深枪伤 + 出血
    -- 直到 Character.Health 接近 0
    --------------------------------------------------

    fixed_finish_health(c)
    
    --所有人5%腹腔感染
    add(c, "infectedcavity", FIXED_INFECTED_CAVITY)

    debug(string.format(
        "fixed spawned %s role=%s",
        tostring(c.Name),
        tostring(jobName)
    ))

    c.Enabled = true

    return c
end

--------------------------------------------------
-- 固定伤情模式生成
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
        debug(string.format(
            "skip fixed generate: cooldown %.2f < %.2f",
            now(),
            nextFixedTriggerTime
        ))
        return
    end

    nextFixedTriggerTime =
        now() + TRIGGER_COOLDOWN

    debug(string.format(
        "fixed generate item=%s pos=(%.1f, %.1f) id=%s",
        sourceItem ~= nil
            and sourceItem.Prefab ~= nil
            and sourceItem.Prefab.Identifier ~= nil
            and tostring(sourceItem.Prefab.Identifier.Value)
            or "nil",
        origin.X,
        origin.Y,
        sourceItem ~= nil
            and tostring(sourceItem.ID)
            or "nil"
    ))

    local spawned = 0

    for i = 1, CASUALTY_COUNT do
        if spawn_fixed_casualty(
            origin,
            i,
            sourceItem
        ) ~= nil then
            spawned = spawned + 1
        end
    end

    print(string.format(
        "[NTCCG] Fixed generated %d/%d casualties at (%.0f, %.0f).",
        spawned,
        CASUALTY_COUNT,
        origin.X,
        origin.Y
    ))
end

--------------------------------------------------
-- 生成全部 NPC
--------------------------------------------------

local function generate(origin, sourceItem)
    if not authoritative() then
        debug(
            "skip generate: not authoritative"
        )
        return
    end

    if now() < nextTriggerTime then
        debug(string.format(
            "skip generate: cooldown %.2f < %.2f",
            now(),
            nextTriggerTime
        ))
        return
    end

    nextTriggerTime =
        now() + TRIGGER_COOLDOWN

    debug(string.format(
        "generate item=%s pos=(%.1f, %.1f) id=%s",
        sourceItem ~= nil
            and sourceItem.Prefab ~= nil
            and sourceItem.Prefab.Identifier ~= nil
            and tostring(sourceItem.Prefab.Identifier.Value)
            or "nil",
        origin.X,
        origin.Y,
        sourceItem ~= nil
            and tostring(sourceItem.ID)
            or "nil"
    ))

    --------------------------------------------------
    -- 不再使用原来的 profiles 数组
    --------------------------------------------------

    local spawned = 0

    for i = 1, CASUALTY_COUNT do

        --------------------------------------------------
        -- 直接从真实 Bullet Profile 中随机选择
        --------------------------------------------------

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

    print(string.format(
        "[NTCCG] Generated %d/%d casualties at (%.0f, %.0f).",
        spawned,
        CASUALTY_COUNT,
        origin.X,
        origin.Y
    ))
end

--------------------------------------------------
-- Revolver Hook
--
-- 保持原始 Hook 和参数
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

        debug(string.format(
            "lua hook item=%s delta=%.3f",
            tostring(
                item.Prefab.Identifier.Value
            ),
            deltaTime or -1
        ))

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
--
-- 与旧 Hook 独立：只触发固定伤情模式
-- 参数形式保持与原 Hook 一致
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

        debug(string.format(
            "fixed lua hook item=%s delta=%.3f",
            tostring(
                item.Prefab.Identifier.Value
            ),
            deltaTime or -1
        ))

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
