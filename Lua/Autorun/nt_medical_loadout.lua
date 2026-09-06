--------------------------------------------------
-- NT Combat Casualty Generator
-- Medical Loadout
--------------------------------------------------

print("[NTCCG][Medical] Autorun loaded.")

if NT == nil or HF == nil then
    print("[NTCCG][Medical] Neurotrauma was not found.")
    return
end

--------------------------------------------------
-- Namespace
--------------------------------------------------

NTCCG_Medical = NTCCG_Medical or {}

--------------------------------------------------
-- Debug
--------------------------------------------------

local DEBUG = true

local function debug(msg)
    if DEBUG then
        print("[NTCCG][Medical] " .. tostring(msg))
    end
end

--------------------------------------------------
-- Spawn helpers
--------------------------------------------------

local function get_prefab(identifier)
    if identifier == nil then
        return nil
    end

    local prefab = ItemPrefab.GetItemPrefab(identifier)

    if prefab == nil then
        debug("Missing item prefab: " .. tostring(identifier))
    end

    return prefab
end

local function spawn_item(identifier, inventory, callback)
    if identifier == nil or inventory == nil then
        return false
    end

    local prefab = get_prefab(identifier)

    if prefab == nil then
        return false
    end

    Entity.Spawner.AddItemToSpawnQueue(
        prefab,
        inventory,
        nil,
        nil,
        function(item)
            if callback ~= nil then
                callback(item)
            end
        end
    )

    return true
end

local function spawn_amount(identifier, amount, inventory)
    amount = tonumber(amount) or 1

    if amount <= 0 then
        return
    end

    for _ = 1, amount do
        spawn_item(identifier, inventory)
    end
end

--------------------------------------------------
-- Spawn a container and fill it afterwards
--------------------------------------------------

local function spawn_container(identifier, inventory, contents)
    spawn_item(identifier, inventory, function(container)

        if container == nil then
            debug("Container spawn failed: " .. tostring(identifier))
            return
        end

        if container.OwnInventory == nil then
            debug(
                "Container has no OwnInventory: "
                .. tostring(identifier)
            )
            return
        end

        for _, entry in ipairs(contents or {}) do

            local itemIdentifier = entry[1]
            local amount = entry[2] or 1
            local containedItems = entry[3]

            for _ = 1, amount do

                spawn_item(
                    itemIdentifier,
                    container.OwnInventory,
                    function(item)

                        if item == nil then
                            return
                        end

                        if containedItems == nil then
                            return
                        end

                        if item.OwnInventory == nil then
                            debug(
                                "Item has no OwnInventory: "
                                .. tostring(itemIdentifier)
                            )
                            return
                        end

                        for _, contained in ipairs(containedItems) do

                            spawn_amount(
                                contained[1],
                                contained[2] or 1,
                                item.OwnInventory
                            )

                        end
                    end
                )

            end
        end
    end)
end

--------------------------------------------------
-- Special item:
-- Spawn item and put another item inside it
--------------------------------------------------

local function spawn_loaded_item(
    identifier,
    containedIdentifier,
    inventory
)
    spawn_item(identifier, inventory, function(item)

        if item == nil then
            return
        end

        if item.OwnInventory == nil then
            debug(
                "Item has no OwnInventory: "
                .. tostring(identifier)
            )
            return
        end

        spawn_item(
            containedIdentifier,
            item.OwnInventory
        )
    end)
end

--------------------------------------------------
-- Medical loadout
--------------------------------------------------

local function give_medical_loadout(character)

    if character == nil then
        debug("give_medical_loadout: character == nil")
        return false
    end

    if character.Inventory == nil then
        debug("Character has no Inventory.")
        return false
    end

    local inventory = character.Inventory

    --------------------------------------------------
    -- Medical toolbox #1
    --
    -- Ringer's solution      x8
    -- O blood                 x16
    -- Morphine                 x8
    -- Broad-spectrum antibiotic x8
    -- Tonic liquid             x8
    -- Adrenaline               x8
    -- Liquid oxygenite         x8
    -- Thiamine                 x8
    --------------------------------------------------

    spawn_container(
        "medtoolbox",
        inventory,
        {
            { "ringerssolution", 8 }, -- 林格氏液
            { "antibloodloss2", 16 }, -- O-血袋
            { "antidama1", 8 },       -- 吗啡
            { "antibiotics", 8 },     -- 广谱抗生素
            { "tonicliquid", 8 },     -- 内用辅液
            { "adrenaline", 8 },      -- 肾上腺素
            { "liquidoxygenite", 8 }, -- 液态氧矿
            { "thiamine", 8 }         -- 硫胺素
        }
    )

    --------------------------------------------------
    -- Medical toolbox #2
    --
    -- O blood                 x24
    -- AED + battery
    -- BVM + oxygenite tank
    -- Auto CPR + battery
    -- Antiseptic spray
    -- Saline                  x8
    -- Antibiotic ointment     x8
    --------------------------------------------------

    spawn_container(
    "medtoolbox",
    inventory,
    {
        { "antibloodloss2", 24 },

        {
            "aed",
            1,
            {
                { "fulguriumbatterycell", 1 }
            }
        },

        {
            "bvm",
            1,
            {
                { "oxygenitetank", 1 }
            }
        },

        {
            "autocpr",
            1,
            {
                { "fulguriumbatterycell", 1 }
            }
        },

        {
            "antisepticspray",
            1,
            {
                { "antibloodloss1", 1 }
            }
        },

        { "antibloodloss1", 8 },
        { "ointment", 8 }
    }
)

    --------------------------------------------------
    -- Medical toolbox #3
    --
    -- Streptokinase            x8
    -- Gypsum                   x8
    -- Azathioprine             x8
    -- Mannitol                 x8
    -- Tourniquet               x8
    -- Plastiseal                x16
    --------------------------------------------------

    spawn_container(
        "medtoolbox",
        inventory,
        {
            { "streptokinase", 8 },
            { "gypsum", 8 },
            { "immunosuppressant", 8 },
            { "mannitol", 8 },
            { "tourniquet", 8 },
            { "antibleeding2", 16 }
        }
    )

    --------------------------------------------------
    -- Surgery toolbox
    --
    -- Surgical scalpel
    -- Hemostat
    -- Retractors
    -- Surgical drill
    -- Surgery saw
    -- Multi-scalpel
    -- Pneumothorax needle x16
    -- Drainage tube x8
    -- Bone implants x2
    -- Spinal implant
    --------------------------------------------------

    spawn_container(
        "surgerytoolbox",
        inventory,
        {
            { "advscalpel", 1 },
            { "advhemostat", 1 },
            { "advretractors", 1 },
            { "surgicaldrill", 1 },
            { "surgerysaw", 1 },
            { "multiscalpel", 1 },
            { "needle", 16 },
            { "drainage", 8 },
            { "osteosynthesisimplants", 2 },
            { "spinalimplant", 1 }
        }
    )

    --------------------------------------------------
    -- Bloodanalyzer
    --------------------------------------------------

    spawn_amount(
        "bloodanalyzer",
        1,
        inventory
    )

    --------------------------------------------------
    -- Toolbelt
    --------------------------------------------------

    spawn_amount(
        "toolbelt",
        1,
        inventory
    )

    --------------------------------------------------
    -- Health scanner + battery
    --------------------------------------------------

    spawn_item(
        "healthscanner",
        inventory,
        function(scanner)

            if scanner == nil
                or scanner.OwnInventory == nil then
                return
            end

            spawn_item(
                "fulguriumbatterycell",
                scanner.OwnInventory
            )
        end
    )

    --------------------------------------------------
    -- Sutures
    --------------------------------------------------

    spawn_amount(
        "suture",
        32,
        inventory
    )

    --------------------------------------------------
    -- Sodium nitroprusside
    --------------------------------------------------

    spawn_amount(
        "pressuremeds",
        8,
        inventory
    )

    debug(
        "Medical loadout queued for "
        .. tostring(character.Name)
    )

    return true
end

--------------------------------------------------
-- Public API
--------------------------------------------------

NTCCG_Medical.GiveLoadout = give_medical_loadout

--------------------------------------------------
-- Medical loadout console command
--------------------------------------------------
-- Register the command so it appears in console command completion.
Game.AddCommand(
    "ntccg_medical",
    "Generate the NTCCG medical loadout for the player executing the command.",
    function()
        -- Intentionally empty.
        --
        -- Actual execution is handled by
        -- Game.AssignOnClientRequestExecute above.
    end,
    nil,
    true
)
if SERVER then
    print("[NTCCG] ntccg_medical: into server.")
    -- Intercept client-side console commands.
    Game.AssignOnClientRequestExecute("ntccg_medical",function(client, possition, args)
        print("[NTCCG] ntccg_medical: into method.")
        if client == nil then
            print("[NTCCG] ntccg_medical: client is nil.")
            return true
        end

        if not client.HasPermission(ClientPermissions.ConsoleCommands) then
            print(
                "[NTCCG] Player "
                .. tostring(client.Name)
                .. " attempted to use ntccg_medical without permission."
            )

            local chatMessage = ChatMessage.Create(
                "NTCCG",
                "你没有权限使用医疗物资生成命令。",
                ChatMessageType.Error,
                nil
            )

            Game.SendDirectChatMessage(
                chatMessage,
                client
            )

            return true
        end

        local c = client.Character

        if c == nil then
            print(
                "[NTCCG] Player "
                .. tostring(client.Name)
                .. " has no controlled character."
            )

            local chatMessage = ChatMessage.Create(
                "NTCCG",
                "你当前没有可用的角色。",
                ChatMessageType.Error,
                nil
            )

            Game.SendDirectChatMessage(
                chatMessage,
                client
            )

            return true
        end

        if NTCCG_Medical == nil
            or NTCCG_Medical.GiveLoadout == nil then

            print("[NTCCG] NTCCG_Medical.GiveLoadout is unavailable.")

            local chatMessage = ChatMessage.Create(
                "NTCCG",
                "医疗物资生成模块尚未加载。",
                ChatMessageType.Error,
                nil
            )

            Game.SendDirectChatMessage(
                chatMessage,
                client
            )

            return true
        end

        print(
            "[NTCCG] Giving medical loadout to "
            .. tostring(client.Name)
            .. " ("
            .. tostring(c.Name)
            .. ")"
        )

        NTCCG_Medical.GiveLoadout(c)

        local chatMessage = ChatMessage.Create(
            "NTCCG",
            "医疗物资已生成。",
            ChatMessageType.Default,
            nil
        )

        Game.SendDirectChatMessage(
            chatMessage,
            client
        )

        return true
    end)

    print("[NTCCG] Console command registered: ntccg_medical")

end

--------------------------------------------------
-- Medical loadout chat command
--
-- Usage:
--   !ntccg_medical
--------------------------------------------------

if SERVER then

    Hook.Add(
        "chatMessage",
        "NTCCG.MedicalChatCommand",
        function(message, client)

            if client == nil then
                return false
            end

            if message == nil then
                return false
            end

            local text = tostring(message)

            --------------------------------------------------
            -- Match command
            --------------------------------------------------

            if text ~= "!ntccg_medical" then
                return false
            end

            --------------------------------------------------
            -- Permission check
            --------------------------------------------------

            if not client.HasPermission(
                ClientPermissions.ConsoleCommands
            ) then

                Game.Server.SendDirectChatMessage(
                    ChatMessage.Create(
                        "NTCCG",
                        "You do not have permission to use this command.",
                        ChatMessageType.Error,
                        nil
                    ),
                    client
                )

                return true
            end

            --------------------------------------------------
            -- Get player's current character
            --------------------------------------------------

            local c = client.Character

            if c == nil then

                Game.Server.SendDirectChatMessage(
                    ChatMessage.Create(
                        "NTCCG",
                        "You do not currently control a character.",
                        ChatMessageType.Error,
                        nil
                    ),
                    client
                )

                return true
            end

            --------------------------------------------------
            -- Medical module
            --------------------------------------------------

            if NTCCG_Medical == nil
                or NTCCG_Medical.GiveLoadout == nil then

                print(
                    "[NTCCG] NTCCG_Medical.GiveLoadout is unavailable."
                )

                Game.Server.SendDirectChatMessage(
                    ChatMessage.Create(
                        "NTCCG",
                        "Medical loadout system is unavailable.",
                        ChatMessageType.Error,
                        nil
                    ),
                    client
                )

                return true
            end

            --------------------------------------------------
            -- Generate loadout
            --------------------------------------------------

            print(
                "[NTCCG] Medical loadout requested by "
                .. tostring(client.Name)
            )

            NTCCG_Medical.GiveLoadout(c)

            Game.Server.SendDirectChatMessage(
                ChatMessage.Create(
                    "NTCCG",
                    "Medical loadout generated.",
                    ChatMessageType.Default,
                    nil
                ),
                client
            )

            --------------------------------------------------
            -- Prevent the command text from being shown
            -- as a normal chat message.
            --------------------------------------------------

            return true
        end
    )

    print(
        "[NTCCG] Medical chat command registered: !ntccg_medical"
    )

end