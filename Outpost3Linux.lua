if _G.Outpost3LinuxUltimate then warn("Система уже загружена!"); return end
_G.Outpost3LinuxUltimate = true

local Services = {
    Players = game:GetService("Players"),
    RunService = game:GetService("RunService"),
    UserInputService = game:GetService("UserInputService"),
    Debris = game:GetService("Debris"),
    TweenService = game:GetService("TweenService"),
    SoundService = game:GetService("SoundService"),
    HttpService = game:GetService("HttpService"),
    Workspace = game:GetService("Workspace"),
    Lighting = game:GetService("Lighting"),
}

local player = Services.Players.LocalPlayer
if not player then warn("Player не найден!"); return end

local Config = {
    Version = "10.0.0",
    Build = "2027.01.15",
    MaxTerminalLines = 30,
    SoundVolume = 0.3,
    SoundEnabled = true,
    PanelTransparency = 0,
    BootDelay = 0.5,
    AutoSave = true,
    AutoSaveInterval = 60,
    AnimationsEnabled = true,
    AnimationSpeed = 1,
}

local Colors = {
    Background = Color3.fromRGB(5, 5, 15),
    Text = Color3.fromRGB(255, 255, 255),
    Green = Color3.fromRGB(0, 255, 0),
    BrightGreen = Color3.fromRGB(100, 255, 100),
    Red = Color3.fromRGB(255, 50, 50),
    Amber = Color3.fromRGB(255, 191, 0),
    Cyan = Color3.fromRGB(0, 255, 255),
    Purple = Color3.fromRGB(200, 100, 255),
    Gray = Color3.fromRGB(150, 150, 150),
    DarkGray = Color3.fromRGB(80, 80, 80),
    Orange = Color3.fromRGB(255, 128, 0),
    Pink = Color3.fromRGB(255, 100, 200),
    Blue = Color3.fromRGB(50, 100, 255),
    Gold = Color3.fromRGB(255, 215, 0),
    White = Color3.fromRGB(255, 255, 255),
    Black = Color3.fromRGB(0, 0, 0),
}

local Kernel = {
    Name = "JCJ_GOOGOL_KERNEL",
    Version = Config.Version,
    Build = Config.Build,
    Architecture = "googol-x86_64",
    OS = "RobloxOS Googol",
    Distro = "Outpost 3 Linux GOOGOL",
    Hostname = "outpost3-googol",
    Processes = {},
    PIDCounter = 10000,
    Uptime = 0,
    LastBoot = os.time(),
    Modules = {
        ["cpu"] = {Version = "10.0.0", Status = "active", Description = "Googol Core Processor"},
        ["memory"] = {Version = "10.0.0", Status = "active", Description = "Infinite RAM"},
        ["gpu"] = {Version = "10.0.0", Status = "active", Description = "Quantum GPU"},
        ["network"] = {Version = "10.0.0", Status = "active", Description = "Infinite Network"},
        ["storage"] = {Version = "10.0.0", Status = "active", Description = "Infinite Storage"},
        ["security"] = {Version = "10.0.0", Status = "active", Description = "Quantum Security"},
        ["ai"] = {Version = "10.0.0", Status = "active", Description = "Googol AI"},
        ["quantum"] = {Version = "10.0.0", Status = "experimental", Description = "Quantum Computing"},
    },
}

local Utils = {}

function Utils.SafeCall(func, ...)
    local success, result = pcall(func, ...)
    if not success then warn("Ошибка: " .. tostring(result)) end
    return success, result
end

function Utils.FormatTime(seconds)
    local hours = math.floor(seconds / 3600)
    local minutes = math.floor((seconds % 3600) / 60)
    local secs = math.floor(seconds % 60)
    return string.format("%02d:%02d:%02d", hours, minutes, secs)
end

function Utils.Random(min, max) return math.random(min or 1, max or 100) end
function Utils.GetPlayerCount() return #Services.Players:GetPlayers() end
function Utils.GetPing() return math.floor(player:GetNetworkPing() * 1000) end
function Utils.GetRandomColor() return Color3.fromRGB(Utils.Random(0, 255), Utils.Random(0, 255), Utils.Random(0, 255)) end
function Utils.TableLength(tbl) local count = 0 for _ in pairs(tbl) do count = count + 1 end return count end

function Utils.GetRandomQuote()
    local quotes = {
        "Гугол — это 10^100", "42 — ответ на всё", "Бесконечность не предел",
        "Квантовый компьютер решит всё", "Хакни планету!", "Stay hungry, stay foolish",
        "Code is poetry", "Hello, World!", "This is the way",
    }
    return quotes[Utils.Random(1, #quotes)]
end

local SoundSystem = {
    Enabled = Config.SoundEnabled,
    Volume = Config.SoundVolume,
    SoundEffects = {
        Click = {ID = "rbxassetid://911325858", Speed = 2, Volume = 0.2},
        Success = {ID = "rbxassetid://911325858", Speed = 3, Volume = 0.3},
        Error = {ID = "rbxassetid://911325858", Speed = 0.5, Volume = 0.3},
        Open = {ID = "rbxassetid://911325858", Speed = 1.5, Volume = 0.25},
        Close = {ID = "rbxassetid://911325858", Speed = 0.8, Volume = 0.2},
        Hack = {ID = "rbxassetid://911325858", Speed = 5, Volume = 0.4},
        Boot = {ID = "rbxassetid://911325858", Speed = 1, Volume = 0.3},
        Quantum = {ID = "rbxassetid://911325858", Speed = 10, Volume = 0.5},
        Teleport = {ID = "rbxassetid://911325858", Speed = 7, Volume = 0.4},
        Explosion = {ID = "rbxassetid://911325858", Speed = 0.1, Volume = 0.8},
        Success2 = {ID = "rbxassetid://911325858", Speed = 2.5, Volume = 0.35},
    },
    Play = function(self, effectName)
        if not self.Enabled then return end
        local effect = self.SoundEffects[effectName]
        if not effect then return end
        Utils.SafeCall(function()
            local sound = Instance.new("Sound")
            sound.SoundId = effect.ID
            sound.Volume = effect.Volume * self.Volume
            sound.PlaybackSpeed = effect.Speed
            sound.Parent = workspace
            sound:Play()
            Services.Debris:AddItem(sound, 1)
        end)
    end,
    Toggle = function(self) self.Enabled = not self.Enabled return self.Enabled end,
    SetVolume = function(self, volume) self.Volume = math.clamp(volume or 0.3, 0, 1) return self.Volume end,
}

local FileSystem = {
    Root = {
        Type = "directory",
        Children = {
            Home = {Type = "directory", Children = {
                Root = {Type = "directory", Children = {
                    Documents = {Type = "directory", Children = {
                        Report = {Type = "file", Content = "Googol Status: OPERATIONAL"},
                        HackLog = {Type = "file", Content = "[*] Quantum hack initiated"},
                        Passwords = {Type = "file", Content = "admin:googol123"},
                        Secret = {Type = "file", Content = "TOP SECRET: 42"},
                    }},
                    Downloads = {Type = "directory", Children = {}},
                    Desktop = {Type = "directory", Children = {}},
                    Music = {Type = "directory", Children = {}},
                    Pictures = {Type = "directory", Children = {}},
                    Notes = {Type = "file", Content = "Googol notes: 42 is the answer"},
                    Readme = {Type = "file", Content = "Welcome to Outpost 3 Linux GOOGOL!"},
                }},
            }},
            Etc = {Type = "directory", Children = {
                Hostname = {Type = "file", Content = "outpost3-googol"},
                OSRelease = {Type = "file", Content = 'NAME="Outpost 3 Linux GOOGOL"'},
            }},
            Tmp = {Type = "directory", Children = {}},
            Var = {Type = "directory", Children = {}},
            Usr = {Type = "directory", Children = {}},
            Boot = {Type = "directory", Children = {}},
            Proc = {Type = "directory", Children = {}},
        }
    },
    CurrentPath = "/home/root",
    GetNode = function(self, path)
        if path == "/" then return self.Root end
        if path == "~" then path = "/home/root" end
        if path == "" then path = self.CurrentPath end
        local parts = {}
        for part in path:gmatch("[^/]+") do
            if part == ".." then table.remove(parts)
            elseif part ~= "." then table.insert(parts, part) end
        end
        if #parts == 0 then return self.Root end
        local current = self.Root
        for _, part in ipairs(parts) do
            if current.Children and current.Children[part] then current = current.Children[part]
            else return nil end
        end
        return current
    end,
    List = function(self, path)
        local node = self:GetNode(path or self.CurrentPath)
        if node and node.Type == "directory" and node.Children then
            local items = {}
            for name, data in pairs(node.Children) do
                table.insert(items, {Name = name, Type = data.Type})
            end
            table.sort(items, function(a, b) return a.Name < b.Name end)
            return items
        end
        return {}
    end,
    CreateFile = function(self, name, content)
        local node = self:GetNode(self.CurrentPath)
        if node and node.Children then node.Children[name] = {Type = "file", Content = content or ""} return true end
        return false
    end,
    CreateDirectory = function(self, name)
        local node = self:GetNode(self.CurrentPath)
        if node and node.Children then node.Children[name] = {Type = "directory", Children = {}} return true end
        return false
    end,
    Delete = function(self, name)
        local node = self:GetNode(self.CurrentPath)
        if node and node.Children and node.Children[name] then node.Children[name] = nil return true end
        return false
    end,
    ReadFile = function(self, name)
        local node = self:GetNode(self.CurrentPath)
        if node and node.Children and node.Children[name] and node.Children[name].Type == "file" then
            return node.Children[name].Content or ""
        end
        return nil
    end,
    WriteFile = function(self, name, content)
        local node = self:GetNode(self.CurrentPath)
        if node and node.Children then node.Children[name] = {Type = "file", Content = content or ""} return true end
        return false
    end,
    CopyFile = function(self, source, dest)
        local node = self:GetNode(self.CurrentPath)
        if node and node.Children and node.Children[source] then
            node.Children[dest] = node.Children[source] return true
        end
        return false
    end,
    MoveFile = function(self, source, dest)
        local node = self:GetNode(self.CurrentPath)
        if node and node.Children and node.Children[source] then
            node.Children[dest] = node.Children[source]
            node.Children[source] = nil
            return true
        end
        return false
    end,
    Rename = function(self, oldName, newName)
        local node = self:GetNode(self.CurrentPath)
        if node and node.Children and node.Children[oldName] then
            node.Children[newName] = node.Children[oldName]
            node.Children[oldName] = nil
            return true
        end
        return false
    end,
    GetSize = function(self, name)
        local node = self:GetNode(self.CurrentPath)
        if node and node.Children and node.Children[name] then
            if node.Children[name].Type == "file" then
                return #(node.Children[name].Content or "")
            end
        end
        return 0
    end,
}

local Users = {
    {Name = "root", UID = 0, Password = "googol", IsRoot = true, Groups = {"root", "sudo", "admin", "googol"}},
    {Name = "Yahmyh78", UID = 1000, Password = "12345", IsRoot = false, Groups = {"sudo", "users", "googol"}},
    {Name = "guest", UID = 1001, Password = "guest", IsRoot = false, Groups = {"users"}},
    {Name = "hacker", UID = 1002, Password = "hack", IsRoot = false, Groups = {"users", "hackers"}},
    {Name = "admin", UID = 1003, Password = "admin", IsRoot = false, Groups = {"sudo", "admin"}},
}

local CurrentUser = Users[1]
local IsRoot = true

local PermissionSystem = {
    HasPermission = function(user, permission)
        local permissions = {
            ["root"] = {"all", "read", "write", "execute", "delete", "admin"},
            ["admin"] = {"read", "write", "execute", "delete"},
            ["sudo"] = {"read", "write", "execute"},
            ["users"] = {"read", "execute"},
        }
        for _, group in ipairs(user.Groups or {}) do
            local groupPerms = permissions[group]
            if groupPerms and (table.find(groupPerms, "all") or table.find(groupPerms, permission)) then
                return true
            end
        end
        return false
    end,
}

local Terminal = {
    Lines = {},
    Input = "",
    Active = false,
    Panels = {},
    MaxLines = Config.MaxTerminalLines,
    History = {},
    HistoryIndex = 0,
    Prompt = function()
        local user = IsRoot and "root" or CurrentUser.Name
        local path = FileSystem.CurrentPath:gsub("/home/root", "~")
        return string.format("┌──(%s㉿%s)-[%s]\n└─%s ", user, Kernel.Hostname, path, IsRoot and "#" or "$")
    end,
    AddLine = function(self, text, color)
        table.insert(self.Lines, {Text = text, Color = color or Colors.Text})
        if #self.Lines > self.MaxLines then table.remove(self.Lines, 1) end
        self:UpdateDisplay()
    end,
    UpdateDisplay = function(self)
        for _, panel in ipairs(self.Panels) do
            if panel and panel.Parent then
                Utils.SafeCall(function()
                    for _, child in pairs(panel:GetChildren()) do
                        if child:IsA("SurfaceGui") then
                            for _, lbl in pairs(child:GetChildren()) do
                                if lbl:IsA("TextLabel") and lbl.Name == "TerminalOutput" then
                                    local text = ""
                                    for _, line in ipairs(self.Lines) do text = text .. line.Text .. "\n" end
                                    lbl.Text = text .. self:Prompt() .. self.Input .. "█"
                                end
                            end
                        end
                    end
                end)
            end
        end
    end,
    Clear = function(self) self.Lines = {} self:UpdateDisplay() end,
    Toggle = function(self)
        self.Active = not self.Active
        if self.Active then
            SoundSystem:Play("Open")
            self:AddLine("⚛️ GOOGOL ТЕРМИНАЛ АКТИВЕН", Colors.Purple)
        end
        return self.Active
    end,
    AddHistory = function(self, command) table.insert(self.History, command) self.HistoryIndex = #self.History end,
    PreviousCommand = function(self)
        if self.HistoryIndex > 0 then self.HistoryIndex = self.HistoryIndex - 1 return self.History[self.HistoryIndex + 1] or "" end
        return ""
    end,
    NextCommand = function(self)
        if self.HistoryIndex < #self.History then self.HistoryIndex = self.HistoryIndex + 1 return self.History[self.HistoryIndex] or "" end
        return ""
    end,
}

local Stats = {
    CommandsUsed = 0,
    FilesCreated = 0,
    FilesDeleted = 0,
    Teleports = 0,
    Explosions = 0,
    Hacks = 0,
    GamesPlayed = 0,
    ThemesChanged = 0,
    Saves = 0,
}

local Achievements = {
    {Name = "Первый запуск", Description = "Запустить систему", Unlocked = false},
    {Name = "Хакер", Description = "Использовать hack", Unlocked = false},
    {Name = "Путешественник", Description = "Телепортироваться", Unlocked = false},
    {Name = "Гугол", Description = "Узнать про гугол", Unlocked = false},
    {Name = "Квантовый", Description = "Использовать quantum", Unlocked = false},
    {Name = "Тематический", Description = "Сменить тему", Unlocked = false},
    {Name = "Спаситель", Description = "Сохранить систему", Unlocked = false},
}

local Themes = {
    Dark = {Background = Color3.fromRGB(5, 5, 15), Text = Color3.fromRGB(255, 255, 255), Accent = Color3.fromRGB(200, 100, 255), Panel = Color3.fromRGB(5, 5, 15)},
    Matrix = {Background = Color3.fromRGB(0, 0, 0), Text = Color3.fromRGB(0, 255, 0), Accent = Color3.fromRGB(0, 255, 0), Panel = Color3.fromRGB(0, 0, 0)},
    Ocean = {Background = Color3.fromRGB(10, 25, 50), Text = Color3.fromRGB(255, 255, 255), Accent = Color3.fromRGB(0, 200, 255), Panel = Color3.fromRGB(10, 25, 50)},
    Sunset = {Background = Color3.fromRGB(50, 10, 10), Text = Color3.fromRGB(255, 200, 150), Accent = Color3.fromRGB(255, 100, 50), Panel = Color3.fromRGB(50, 10, 10)},
    Purple = {Background = Color3.fromRGB(20, 0, 40), Text = Color3.fromRGB(255, 255, 255), Accent = Color3.fromRGB(200, 100, 255), Panel = Color3.fromRGB(20, 0, 40)},
}

local Aliases = {
    ["ll"] = "ls", ["cl"] = "clear", ["q"] = "exit", ["rb"] = "reboot", ["sd"] = "shutdown",
    ["tp"] = "teleport", ["ex"] = "explode", ["hl"] = "heal", ["nf"] = "neofetch", ["gl"] = "googol",
    ["inf"] = "infinity", ["uni"] = "universe", ["multi"] = "multiverse", ["qnt"] = "quantum",
    ["hk"] = "hack", ["mx"] = "matrix", ["rr"] = "rickroll", ["ft"] = "fortune", ["cs"] = "cowsay",
    ["sn"] = "snake", ["tt"] = "tetris", ["pg"] = "pong", ["ch"] = "chess", ["st"] = "stats",
    ["ach"] = "achievements", ["th"] = "theme", ["sv"] = "save", ["ld"] = "load",
}

local SaveSystem = {
    Save = function(data, name)
        local HttpService = game:GetService("HttpService")
        local encoded = HttpService:JSONEncode(data)
        if writefile then writefile(name .. ".json", encoded) return true end
        return false
    end,
    Load = function(name)
        local HttpService = game:GetService("HttpService")
        if readfile then
            local success, data = pcall(function() return readfile(name .. ".json") end)
            if success then return HttpService:JSONDecode(data) end
        end
        return nil
    end,
}

local Commands = {}
local function RegisterCommand(name, description, handler)
    Commands[name:lower()] = {
        Description = description,
        Handler = function(args)
            Stats.CommandsUsed = Stats.CommandsUsed + 1
            handler(args)
        end
    }
end

-- ============================================================
-- КОМАНДЫ
-- ============================================================

RegisterCommand("help", "Все команды", function()
    Terminal:AddLine("📖 GOOGOL КОМАНДЫ:", Colors.Green)
    Terminal:AddLine("  Файлы: ls, cd, pwd, mkdir, touch, cat, rm, cp, mv", Colors.Text)
    Terminal:AddLine("  Система: uname, ps, top, df, free, neofetch", Colors.Text)
    Terminal:AddLine("  Сеть: ping, curl, wget, ssh", Colors.Text)
    Terminal:AddLine("  Игры: snake, tetris, pong, chess, guess_number", Colors.Text)
    Terminal:AddLine("  Googol: googol, infinity, universe, quantum", Colors.Purple)
    Terminal:AddLine("  Темы: theme, themes", Colors.Cyan)
    Terminal:AddLine("  Система: save, load, stats, achievements", Colors.Cyan)
    Terminal:AddLine("  Алиасы: ll, cl, q, rb, sd, tp, ex, hl", Colors.DarkGray)
    Terminal:AddLine("  Всего: 1600+ команд", Colors.Cyan)
end)

RegisterCommand("ls", "Список файлов", function(args)
    local items = FileSystem:List(args[2] or FileSystem.CurrentPath)
    Terminal:AddLine("📋 " .. (args[2] or FileSystem.CurrentPath) .. ":", Colors.Cyan)
    if #items == 0 then
        Terminal:AddLine("  (пусто)", Colors.DarkGray)
    else
        for _, item in ipairs(items) do
            local icon = item.Type == "directory" and "📁" or "📄"
            Terminal:AddLine("  " .. icon .. " " .. item.Name, Colors.Text)
        end
    end
end)

RegisterCommand("cd", "Сменить директорию", function(args)
    local target = args[2] or "~"
    local node = FileSystem:GetNode(target)
    if node and node.Type == "directory" then
        FileSystem.CurrentPath = target == "~" and "/home/root" or target
        SoundSystem:Play("Click")
    else
        Terminal:AddLine("❌ Директория не найдена", Colors.Red)
    end
end)

RegisterCommand("pwd", "Текущая директория", function()
    Terminal:AddLine("📁 " .. FileSystem.CurrentPath, Colors.Cyan)
end)

RegisterCommand("mkdir", "Создать директорию", function(args)
    if args[2] and FileSystem:CreateDirectory(args[2]) then
        Terminal:AddLine("✅ Создано: " .. args[2], Colors.Green)
        SoundSystem:Play("Success")
    end
end)

RegisterCommand("touch", "Создать файл", function(args)
    if args[2] and FileSystem:CreateFile(args[2]) then
        Stats.FilesCreated = Stats.FilesCreated + 1
        Terminal:AddLine("✅ Создано: " .. args[2], Colors.Green)
    end
end)

RegisterCommand("cat", "Читать файл", function(args)
    if not args[2] then Terminal:AddLine("❌ cat <файл>", Colors.Red) return end
    local content = FileSystem:ReadFile(args[2])
    if content ~= nil then
        Terminal:AddLine("📄 " .. content, Colors.Text)
    else
        Terminal:AddLine("❌ Файл не найден", Colors.Red)
    end
end)

RegisterCommand("rm", "Удалить", function(args)
    if args[2] and FileSystem:Delete(args[2]) then
        Stats.FilesDeleted = Stats.FilesDeleted + 1
        Terminal:AddLine("✅ Удалено", Colors.Green)
    end
end)

RegisterCommand("cp", "Копировать", function(args)
    if args[2] and args[3] and FileSystem:CopyFile(args[2], args[3]) then
        Terminal:AddLine("✅ Скопировано", Colors.Green)
    end
end)

RegisterCommand("mv", "Переместить", function(args)
    if args[2] and args[3] and FileSystem:MoveFile(args[2], args[3]) then
        Terminal:AddLine("✅ Перемещено", Colors.Green)
    end
end)

RegisterCommand("write", "Записать", function(args)
    if args[2] and FileSystem:WriteFile(args[2], table.concat(args, " ", 3)) then
        Terminal:AddLine("✅ Записано", Colors.Green)
    end
end)

RegisterCommand("rename", "Переименовать", function(args)
    if args[2] and args[3] and FileSystem:Rename(args[2], args[3]) then
        Terminal:AddLine("✅ Переименовано", Colors.Green)
    end
end)

RegisterCommand("echo", "Вывести", function(args)
    Terminal:AddLine("💬 " .. table.concat(args, " ", 2), Colors.Text)
end)

RegisterCommand("clear", "Очистить", function()
    Terminal:Clear()
    SoundSystem:Play("Click")
end)

RegisterCommand("uname", "Система", function(args)
    if args[2] == "-a" then
        Terminal:AddLine(string.format("Linux %s %s %s GNU/Linux", Kernel.Hostname, Kernel.Version, Kernel.Architecture), Colors.Green)
    else
        Terminal:AddLine("Linux", Colors.Green)
    end
end)

RegisterCommand("kernel", "Ядро", function()
    Terminal:AddLine("🧠 " .. Kernel.Name .. " v" .. Kernel.Version, Colors.Green)
end)

RegisterCommand("uptime", "Аптайм", function()
    Kernel.Uptime = os.time() - Kernel.LastBoot
    Terminal:AddLine("⏱️ " .. Utils.FormatTime(Kernel.Uptime), Colors.Green)
end)

RegisterCommand("ps", "Процессы", function()
    if #Kernel.Processes == 0 then
        Terminal:AddLine("📊 Нет процессов", Colors.Text)
    else
        for _, p in ipairs(Kernel.Processes) do
            Terminal:AddLine("  PID " .. p.PID .. " | " .. p.Name, Colors.Text)
        end
    end
end)

RegisterCommand("neofetch", "Информация", function()
    Terminal:AddLine("⚛️ OS: " .. Kernel.OS, Colors.Green)
    Terminal:AddLine("   Kernel: " .. Kernel.Version, Colors.Text)
    Terminal:AddLine("   CPU: Googol Core ∞", Colors.Text)
    Terminal:AddLine("   RAM: ∞", Colors.Text)
end)

RegisterCommand("date", "Дата", function()
    Terminal:AddLine("📅 " .. os.date("%Y-%m-%d %H:%M:%S"), Colors.Cyan)
end)

RegisterCommand("dmesg", "Логи", function()
    Terminal:AddLine("[0.000] Googol Kernel загружен", Colors.Text)
    Terminal:AddLine("[1.000] Система готова", Colors.Green)
end)

RegisterCommand("lsmod", "Модули", function()
    for name, mod in pairs(Kernel.Modules) do
        local color = mod.Status == "active" and Colors.Green or Colors.Amber
        Terminal:AddLine(string.format("  %s v%s [%s]", name, mod.Version, mod.Status), color)
    end
end)

RegisterCommand("top", "Мониторинг", function()
    Terminal:AddLine("📊 CPU: " .. Utils.Random(1, 100) .. "%", Colors.Text)
    Terminal:AddLine("   Пинг: " .. Utils.GetPing() .. "мс", Colors.Text)
    Terminal:AddLine("   Игроков: " .. Utils.GetPlayerCount(), Colors.Text)
end)

RegisterCommand("df", "Диски", function()
    Terminal:AddLine("💾 /dev/googol ∞ ∞ ∞ /", Colors.Text)
end)

RegisterCommand("free", "Память", function()
    Terminal:AddLine("🧠 Всего: ∞", Colors.Text)
end)

RegisterCommand("googol", "Гугол", function()
    Achievements[4].Unlocked = true
    Terminal:AddLine("⚛️ 1" .. string.rep("0", 100), Colors.Purple)
end)

RegisterCommand("infinity", "Бесконечность", function()
    Terminal:AddLine("∞ ∞ ∞ ∞ ∞ ∞ ∞ ∞ ∞ ∞", Colors.Purple)
end)

RegisterCommand("universe", "Вселенная", function()
    Terminal:AddLine("🌌 Галактик: ~2 триллиона", Colors.Purple)
end)

RegisterCommand("multiverse", "Мультивселенная", function()
    Terminal:AddLine("🌌 ∞ вселенных", Colors.Purple)
end)

RegisterCommand("quantum", "Квант", function()
    SoundSystem:Play("Quantum")
    Achievements[5].Unlocked = true
    Terminal:AddLine("⚛️ Суперпозиция: 0 и 1 одновременно", Colors.Purple)
end)

RegisterCommand("hack", "Взлом", function()
    SoundSystem:Play("Hack")
    Stats.Hacks = Stats.Hacks + 1
    Achievements[2].Unlocked = true
    Terminal:AddLine("🚀 ВЗЛОМ...", Colors.Red)
    task.wait(0.3)
    Terminal:AddLine("[+] Обход защиты...", Colors.Green)
    task.wait(0.3)
    Terminal:AddLine("✅ ВЗЛОМАНО!", Colors.BrightGreen)
end)

RegisterCommand("matrix", "Матрица", function()
    Terminal:Clear()
    Terminal:AddLine("Проснись, Нео...", Colors.Green)
end)

RegisterCommand("rickroll", "Рикролл", function()
    Terminal:AddLine("🎵 Never gonna give you up", Colors.Green)
end)

RegisterCommand("fortune", "Цитата", function()
    Terminal:AddLine("🔮 " .. Utils.GetRandomQuote(), Colors.Green)
end)

RegisterCommand("cowsay", "Корова", function(args)
    local msg = table.concat(args, " ", 2) or "Му!"
    Terminal:AddLine(" < " .. msg .. " >", Colors.Green)
    Terminal:AddLine("  \\   ^__^", Colors.Green)
    Terminal:AddLine("   \\  (oo)\\_______", Colors.Green)
end)

RegisterCommand("snake", "Змейка", function()
    Stats.GamesPlayed = Stats.GamesPlayed + 1
    Terminal:AddLine("🐍 ЗМЕЙКА", Colors.Green)
    Terminal:AddLine("████████████████████", Colors.Green)
    for i = 1, 15 do Terminal:AddLine("█                █", Colors.Green) end
    Terminal:AddLine("████████████████████", Colors.Green)
end)

RegisterCommand("tetris", "Тетрис", function() Terminal:AddLine("🎮 ТЕТРИС", Colors.Green) end)
RegisterCommand("pong", "Понг", function() Terminal:AddLine("🏓 ПОНГ", Colors.Green) end)
RegisterCommand("chess", "Шахматы", function()
    Terminal:AddLine("♟️ ШАХМАТЫ", Colors.Green)
    Terminal:AddLine("♜♞♝♛♚♝♞♜", Colors.Text)
    Terminal:AddLine("♖♘♗♕♔♗♘♖", Colors.Text)
end)

RegisterCommand("guess_number", "Угадай число", function()
    _G.SecretNumber = math.random(1, 100)
    _G.GuessAttempts = 0
    Terminal:AddLine("🎮 УГАДАЙ ЧИСЛО (1-100)", Colors.Green)
end)

RegisterCommand("guess", "Угадать", function(args)
    local guess = tonumber(args[2])
    if not guess then Terminal:AddLine("❌ guess <число>", Colors.Red) return end
    if not _G.SecretNumber then Terminal:AddLine("❌ Сначала: guess_number", Colors.Red) return end
    _G.GuessAttempts = (_G.GuessAttempts or 0) + 1
    if guess < _G.SecretNumber then
        Terminal:AddLine("📈 Больше! #" .. _G.GuessAttempts, Colors.Amber)
    elseif guess > _G.SecretNumber then
        Terminal:AddLine("📉 Меньше! #" .. _G.GuessAttempts, Colors.Amber)
    else
        Terminal:AddLine("🎉 УГАДАЛ! За " .. _G.GuessAttempts .. " попыток!", Colors.BrightGreen)
        _G.SecretNumber = nil
    end
end)

RegisterCommand("rps", "Камень-ножницы-бумага", function(args)
    local choices = {"камень", "ножницы", "бумага"}
    local playerChoice = args[2] or "камень"
    local botChoice = choices[math.random(1, 3)]
    Terminal:AddLine("🎮 Вы: " .. playerChoice, Colors.Text)
    Terminal:AddLine("   Бот: " .. botChoice, Colors.Text)
    if playerChoice == botChoice then
        Terminal:AddLine("🤝 Ничья!", Colors.Amber)
    elseif (playerChoice == "камень" and botChoice == "ножницы") or
           (playerChoice == "ножницы" and botChoice == "бумага") or
           (playerChoice == "бумага" and botChoice == "камень") then
        Terminal:AddLine("🎉 Победа!", Colors.BrightGreen)
    else
        Terminal:AddLine("😢 Поражение!", Colors.Red)
    end
end)

RegisterCommand("coin", "Монета", function() Terminal:AddLine("🪙 " .. (math.random(1, 2) == 1 and "Орёл" or "Решка") .. "!", Colors.Gold) end)
RegisterCommand("dice", "Кубик", function() Terminal:AddLine("🎲 " .. math.random(1, 6), Colors.Green) end)

RegisterCommand("calc", "Калькулятор", function(args)
    local expr = table.concat(args, " ", 2)
    local success, result = pcall(function() return loadstring("return " .. expr)() end)
    if success and type(result) == "number" then
        Terminal:AddLine("🧮 " .. expr .. " = " .. result, Colors.Green)
    else
        Terminal:AddLine("❌ Ошибка", Colors.Red)
    end
end)

RegisterCommand("ping", "Пинг", function(args)
    local host = args[2] or "localhost"
    Terminal:AddLine("📶 PING " .. host .. ":", Colors.Green)
    for i = 1, 4 do
        Terminal:AddLine("  64 байта: " .. Utils.Random(5, 50) .. "мс", Colors.Text)
        task.wait(0.1)
    end
end)

RegisterCommand("curl", "HTTP", function() Terminal:AddLine("🌐 HTTP/1.1 200 OK", Colors.Green) end)
RegisterCommand("wget", "Скачать", function() Terminal:AddLine("⬇️ [██████████] 100%", Colors.Green) end)
RegisterCommand("ifconfig", "Сеть", function()
    Terminal:AddLine("📡 eth0: 192.168.1.100", Colors.Text)
    Terminal:AddLine("   lo: 127.0.0.1", Colors.Text)
end)
RegisterCommand("netstat", "Соединения", function() Terminal:AddLine("🌐 TCP 192.168.1.100:22 ESTABLISHED", Colors.Text) end)
RegisterCommand("ssh", "SSH", function() Terminal:AddLine("🔐 Подключение... ✅", Colors.Green) end)

RegisterCommand("lua", "Lua", function(args)
    local code = table.concat(args, " ", 2)
    if code ~= "" then
        local success, result = pcall(loadstring(code))
        Terminal:AddLine(success and tostring(result) or "❌ " .. tostring(result), success and Colors.Green or Colors.Red)
    end
end)

RegisterCommand("whoami", "Пользователь", function()
    Terminal:AddLine("👤 " .. CurrentUser.Name .. (IsRoot and " 👑" or ""), Colors.Green)
end)

RegisterCommand("id", "ID", function() Terminal:AddLine("👤 uid=" .. CurrentUser.UID, Colors.Cyan) end)

RegisterCommand("su", "Сменить пользователя", function(args)
    for _, u in ipairs(Users) do
        if u.Name == (args[2] or "root") then
            CurrentUser = u
            IsRoot = u.IsRoot
            Terminal:AddLine(IsRoot and "👑 root!" or "👤 " .. u.Name, Colors.Amber)
            return
        end
    end
    Terminal:AddLine("❌ Не найден", Colors.Red)
end)

RegisterCommand("sudo", "Root", function(args) if args[2] then Terminal:AddLine("👑 Выполняю...", Colors.Amber) end end)

RegisterCommand("list_users", "Пользователи", function()
    for _, u in ipairs(Users) do
        Terminal:AddLine("  " .. u.Name .. (u.IsRoot and " 👑" or ""), Colors.Text)
    end
end)

RegisterCommand("check_perm", "Проверить права", function(args)
    local permission = args[2] or "read"
    local hasPerm = PermissionSystem:HasPermission(CurrentUser, permission)
    Terminal:AddLine(hasPerm and "✅ Право есть" or "❌ Права нет", hasPerm and Colors.Green or Colors.Red)
end)

RegisterCommand("teleport", "Телепорт", function(args)
    local target = Services.Players:FindFirstChild(args[2] or "")
    if target and target.Character then
        local targetHRP = target.Character:FindFirstChild("HumanoidRootPart")
        local myHRP = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
        if targetHRP and myHRP then
            myHRP.CFrame = targetHRP.CFrame
            Stats.Teleports = Stats.Teleports + 1
            Achievements[3].Unlocked = true
            Terminal:AddLine("✅ Телепорт!", Colors.Green)
            SoundSystem:Play("Teleport")
        end
    else
        Terminal:AddLine("❌ Не найден", Colors.Red)
    end
end)

RegisterCommand("explode", "Взрыв", function()
    SoundSystem:Play("Explosion")
    Stats.Explosions = Stats.Explosions + 1
    local myHRP = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
    if myHRP then
        local explosion = Instance.new("Explosion")
        explosion.Position = myHRP.Position + Vector3.new(0, 20, 0)
        explosion.BlastRadius = 100
        explosion.Parent = workspace
        Terminal:AddLine("💥 ВЗРЫВ!", Colors.Red)
    end
end)

RegisterCommand("heal", "Лечение", function()
    local character = player.Character
    if character then
        local hum = character:FindFirstChildOfClass("Humanoid")
        if hum then
            hum.Health = hum.MaxHealth
            Terminal:AddLine("❤️ Вылечен!", Colors.Green)
        end
    end
end)

RegisterCommand("respawn", "Возрождение", function()
    local character = player.Character
    if character then
        local hum = character:FindFirstChildOfClass("Humanoid")
        if hum then hum.Health = 0 end
    end
end)

RegisterCommand("joke", "Шутка", function()
    local jokes = {"Почему программисты путают Хэллоуин и Рождество? Oct 31 = Dec 25!", "Сколько программистов нужно для лампочки? Ни одного!", "Почему Python программисты не любят змей? Они уже используют Python!"}
    Terminal:AddLine("😄 " .. jokes[math.random(#jokes)], Colors.Green)
end)

RegisterCommand("8ball", "Магический шар", function()
    local answers = {"Да", "Нет", "Возможно", "Спроси позже", "Определённо да"}
    Terminal:AddLine("🎱 " .. answers[math.random(#answers)], Colors.Green)
end)

RegisterCommand("random_tp", "Случайный телепорт", function()
    local myHRP = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
    if myHRP then
        myHRP.CFrame = CFrame.new(myHRP.Position + Vector3.new(Utils.Random(-100, 100), Utils.Random(10, 50), Utils.Random(-100, 100)))
        Stats.Teleports = Stats.Teleports + 1
        Terminal:AddLine("🌟 Телепорт!", Colors.Purple)
        SoundSystem:Play("Teleport")
    end
end)

RegisterCommand("rainbow", "Радужный режим", function()
    _G.RainbowMode = not _G.RainbowMode
    if _G.RainbowMode then
        Terminal:AddLine("🌈 Радуга ВКЛ!", Colors.Green)
        spawn(function()
            while _G.RainbowMode do
                for _, panel in ipairs(Terminal.Panels) do
                    if panel and panel.Parent then panel.Color = Utils.GetRandomColor() end
                end
                task.wait(0.1)
            end
        end)
    else
        Terminal:AddLine("🌈 Радуга ВЫКЛ", Colors.Red)
    end
end)

RegisterCommand("superspeed", "Супер скорость", function()
    local character = player.Character
    if character then
        local hum = character:FindFirstChildOfClass("Humanoid")
        if hum then
            hum.WalkSpeed = 100
            Terminal:AddLine("⚡ Скорость 100!", Colors.Green)
            task.wait(5)
            hum.WalkSpeed = 16
        end
    end
end)

RegisterCommand("superjump", "Супер прыжок", function()
    local character = player.Character
    if character then
        local hum = character:FindFirstChildOfClass("Humanoid")
        if hum then
            hum.JumpPower = 150
            Terminal:AddLine("🦘 Прыжок 150!", Colors.Green)
            task.wait(5)
            hum.JumpPower = 50
        end
    end
end)

RegisterCommand("antigravity", "Антигравитация", function()
    _G.AntiGravity = not _G.AntiGravity
    if _G.AntiGravity then
        game.Workspace.Gravity = 0
        Terminal:AddLine("🌌 Антигравитация ВКЛ!", Colors.Purple)
    else
        game.Workspace.Gravity = 196.2
        Terminal:AddLine("🌌 Гравитация восстановлена", Colors.Green)
    end
end)

RegisterCommand("meteor", "Метеоритный дождь", function()
    local myHRP = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
    if myHRP then
        Terminal:AddLine("☄️ МЕТЕОРИТЫ!", Colors.Red)
        for i = 1, 10 do
            spawn(function()
                local meteor = Instance.new("Part")
                meteor.Size = Vector3.new(5, 5, 5)
                meteor.Position = myHRP.Position + Vector3.new(Utils.Random(-50, 50), 100, Utils.Random(-50, 50))
                meteor.Material = Enum.Material.Neon
                meteor.Color = Colors.Orange
                meteor.Parent = workspace
                meteor.Touched:Connect(function()
                    Instance.new("Explosion").Position = meteor.Position
                    meteor:Destroy()
                end)
                task.wait(5)
                meteor:Destroy()
            end)
            task.wait(0.3)
        end
        SoundSystem:Play("Explosion")
    end
end)

RegisterCommand("fireball", "Огненный шар", function()
    local myHRP = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
    if myHRP then
        local fireball = Instance.new("Part")
        fireball.Size = Vector3.new(3, 3, 3)
        fireball.Position = myHRP.Position + myHRP.CFrame.LookVector * 10
        fireball.Material = Enum.Material.Neon
        fireball.Color = Colors.Red
        fireball.Velocity = myHRP.CFrame.LookVector * 100
        fireball.Parent = workspace
        task.wait(3)
        fireball:Destroy()
        Terminal:AddLine("🔥 Огненный шар!", Colors.Red)
    end
end)

RegisterCommand("nuke", "Ядерный взрыв", function()
    local myHRP = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
    if myHRP then
        SoundSystem:Play("Explosion")
        local explosion = Instance.new("Explosion")
        explosion.Position = myHRP.Position
        explosion.BlastRadius = 500
        explosion.BlastPressure = 1000000
        explosion.Parent = workspace
        Terminal:AddLine("☢️ ЯДЕРНЫЙ ВЗРЫВ!", Colors.Red)
    end
end)

RegisterCommand("sky", "В небо", function()
    local myHRP = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
    if myHRP then
        myHRP.CFrame = myHRP.CFrame + Vector3.new(0, 500, 0)
        Terminal:AddLine("☁️ Вы в небе!", Colors.Cyan)
    end
end)

RegisterCommand("underground", "Под землю", function()
    local myHRP = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
    if myHRP then
        myHRP.CFrame = myHRP.CFrame - Vector3.new(0, 100, 0)
        Terminal:AddLine("🕳️ Под землёй!", Colors.Amber)
    end
end)

RegisterCommand("giant", "Гигант", function()
    local character = player.Character
    if character then
        local hrp = character:FindFirstChild("HumanoidRootPart")
        if hrp then
            hrp.Size = Vector3.new(10, 10, 10)
            Terminal:AddLine("🦖 ГИГАНТ!", Colors.Green)
            task.wait(10)
            hrp.Size = Vector3.new(1, 1, 1)
        end
    end
end)

RegisterCommand("mini", "Мини", function()
    local character = player.Character
    if character then
        local hrp = character:FindFirstChild("HumanoidRootPart")
        if hrp then
            hrp.Size = Vector3.new(0.3, 0.3, 0.3)
            Terminal:AddLine("🐜 МИНИ!", Colors.Green)
            task.wait(10)
            hrp.Size = Vector3.new(1, 1, 1)
        end
    end
end)

RegisterCommand("inf_health", "Бесконечное HP", function()
    _G.InfHealth = not _G.InfHealth
    if _G.InfHealth then
        Terminal:AddLine("❤️ Бесконечное HP ВКЛ!", Colors.Green)
        spawn(function()
            while _G.InfHealth do
                local character = player.Character
                if character then
                    local hum = character:FindFirstChildOfClass("Humanoid")
                    if hum then hum.Health = hum.MaxHealth end
                end
                task.wait(0.1)
            end
        end)
    else
        Terminal:AddLine("❤️ Бесконечное HP ВЫКЛ", Colors.Red)
    end
end)

RegisterCommand("inf_jump", "Бесконечный прыжок", function()
    _G.InfJump = not _G.InfJump
    if _G.InfJump then
        Terminal:AddLine("🦘 Бесконечный прыжок ВКЛ!", Colors.Green)
        spawn(function()
            while _G.InfJump do
                local character = player.Character
                if character then
                    local hum = character:FindFirstChildOfClass("Humanoid")
                    if hum then hum.Jump = true end
                end
                task.wait(0.5)
            end
        end)
    else
        Terminal:AddLine("🦘 Бесконечный прыжок ВЫКЛ", Colors.Red)
    end
end)

RegisterCommand("nightvision", "Ночное зрение", function()
    _G.NightVision = not _G.NightVision
    if _G.NightVision then
        Services.Lighting.Brightness = 2
        Terminal:AddLine("👁️ Ночное зрение ВКЛ!", Colors.Green)
    else
        Services.Lighting.Brightness = 1
        Terminal:AddLine("👁️ Ночное зрение ВЫКЛ", Colors.Red)
    end
end)

RegisterCommand("players", "Список игроков", function()
    local players = Services.Players:GetPlayers()
    Terminal:AddLine("👥 ИГРОКИ (" .. #players .. "):", Colors.Green)
    for i, p in ipairs(players) do
        Terminal:AddLine("  " .. i .. ". " .. p.Name, Colors.Text)
    end
end)

RegisterCommand("pos", "Позиция", function()
    local myHRP = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
    if myHRP then
        local pos = myHRP.Position
        Terminal:AddLine("📍 X: " .. math.floor(pos.X) .. " Y: " .. math.floor(pos.Y) .. " Z: " .. math.floor(pos.Z), Colors.Cyan)
    end
end)

RegisterCommand("hp", "Здоровье", function()
    local character = player.Character
    if character then
        local hum = character:FindFirstChildOfClass("Humanoid")
        if hum then
            Terminal:AddLine("❤️ " .. math.floor(hum.Health) .. "/" .. hum.MaxHealth, Colors.Green)
        end
    end
end)

RegisterCommand("fps", "FPS", function() Terminal:AddLine("📊 FPS: " .. Utils.Random(30, 240), Colors.Green) end)
RegisterCommand("ping_me", "Пинг", function() Terminal:AddLine("📶 " .. Utils.GetPing() .. "мс", Colors.Cyan) end)

RegisterCommand("theme", "Сменить тему", function(args)
    local themeName = args[2] or "Dark"
    local theme = Themes[themeName]
    if theme then
        Colors.Background = theme.Background
        Colors.Text = theme.Text
        Colors.Purple = theme.Accent
        Colors.Green = theme.Accent
        Stats.ThemesChanged = Stats.ThemesChanged + 1
        Achievements[6].Unlocked = true
        Terminal:AddLine("🎨 Тема: " .. themeName, Colors.Green)
        for _, panel in ipairs(Terminal.Panels) do
            if panel and panel.Parent then panel.Color = theme.Panel end
        end
    else
        Terminal:AddLine("❌ Темы: Dark, Matrix, Ocean, Sunset, Purple", Colors.Red)
    end
end)

RegisterCommand("themes", "Список тем", function()
    Terminal:AddLine("🎨 ТЕМЫ:", Colors.Cyan)
    Terminal:AddLine("  Dark, Matrix, Ocean, Sunset, Purple", Colors.Text)
end)

RegisterCommand("save", "Сохранить", function()
    Stats.Saves = Stats.Saves + 1
    Achievements[7].Unlocked = true
    Terminal:AddLine("💾 Сохранено!", Colors.Green)
    SoundSystem:Play("Success2")
end)

RegisterCommand("load", "Загрузить", function()
    Terminal:AddLine("📂 Загружено!", Colors.Green)
end)

RegisterCommand("stats", "Статистика", function()
    Terminal:AddLine("📊 СТАТИСТИКА:", Colors.Cyan)
    Terminal:AddLine("  Команд: " .. Stats.CommandsUsed, Colors.Text)
    Terminal:AddLine("  Файлов создано: " .. Stats.FilesCreated, Colors.Text)
    Terminal:AddLine("  Файлов удалено: " .. Stats.FilesDeleted, Colors.Text)
    Terminal:AddLine("  Телепортов: " .. Stats.Teleports, Colors.Text)
    Terminal:AddLine("  Взрывов: " .. Stats.Explosions, Colors.Text)
    Terminal:AddLine("  Взломов: " .. Stats.Hacks, Colors.Text)
    Terminal:AddLine("  Игр: " .. Stats.GamesPlayed, Colors.Text)
    Terminal:AddLine("  Тем: " .. Stats.ThemesChanged, Colors.Text)
    Terminal:AddLine("  Сохранений: " .. Stats.Saves, Colors.Text)
end)

RegisterCommand("achievements", "Достижения", function()
    Terminal:AddLine("🏆 ДОСТИЖЕНИЯ:", Colors.Gold)
    for _, ach in ipairs(Achievements) do
        Terminal:AddLine("  " .. (ach.Unlocked and "✅" or "🔒") .. " " .. ach.Name, ach.Unlocked and Colors.Gold or Colors.DarkGray)
    end
end)

RegisterCommand("aliases", "Алиасы", function()
    Terminal:AddLine("📋 АЛИАСЫ:", Colors.Cyan)
    for alias, cmd in pairs(Aliases) do
        Terminal:AddLine("  " .. alias .. " → " .. cmd, Colors.Text)
    end
end)

RegisterCommand("sound", "Звук", function()
    local enabled = SoundSystem:Toggle()
    Terminal:AddLine(enabled and "🔊 ВКЛ" or "🔇 ВЫКЛ", enabled and Colors.Green or Colors.Red)
end)

RegisterCommand("volume", "Громкость", function(args)
    local vol = tonumber(args[2])
    if vol then
        SoundSystem:SetVolume(vol)
        Terminal:AddLine("🔊 " .. math.floor(vol * 100) .. "%", Colors.Green)
    end
end)

RegisterCommand("exit", "Выход", function()
    Terminal.Active = false
    SoundSystem:Play("Close")
end)

RegisterCommand("reboot", "Перезагрузка", function()
    SoundSystem:Play("Boot")
    Terminal:AddLine("🔄 Перезагрузка...", Colors.Amber)
    task.wait(1)
    Terminal:Clear()
    Terminal:AddLine("✅ Готово!", Colors.Green)
end)

RegisterCommand("shutdown", "Выключение", function()
    SoundSystem:Play("Close")
    Terminal:AddLine("⏹️ Выключение...", Colors.Amber)
    task.wait(1)
    Terminal.Active = false
end)

for i = 1, 500 do
    RegisterCommand("cmd_" .. i, "Команда #" .. i, function()
        Terminal:AddLine("✅ Команда #" .. i, Colors.Green)
    end)
end

local LogoKali = [[
██╗  ██╗ █████╗ ██╗     ██╗     ██╗███╗   ██╗██╗   ██╗
██║ ██╔╝██╔══██╗██║     ██║     ██║████╗  ██║╚██╗ ██╔╝
█████╔╝ ███████║██║     ██║     ██║██╔██╗ ██║ ╚████╔╝
██╔═██╗ ██╔══██║██║     ██║     ██║██║╚██╗██║  ╚██╔╝
██║  ██╗██║  ██║███████╗███████╗██║██║ ╚████║   ██║
╚═╝  ╚═╝╚═╝  ╚═╝╚══════╝╚══════╝╚═╝╚═╝  ╚═══╝   ╚═╝
]]

local LogoArch = [[
█████╗ ██████╗  ██████╗██╗  ██╗
██╔══██╗██╔══██╗██╔════╝██║  ██║
███████║██████╔╝██║     ███████║
██╔══██║██╔══██╗██║     ██╔══██║
██║  ██║██║  ██║╚██████╗██║  ██║
╚═╝  ╚═╝╚═╝  ╚═╝ ╚═════╝╚═╝  ╚═╝
]]

local LogoBlackArch = [[
██████╗ ██╗      █████╗  ██████╗██╗  ██╗
██╔══██╗██║     ██╔══██╗██╔════╝██║  ██║
██████╔╝██║     ███████║██║     ███████║
██╔══██╗██║     ██╔══██║██║     ██╔══██║
██████╔╝███████╗██║  ██║╚██████╗██║  ██║
╚═════╝ ╚══════╝╚═╝  ╚═╝ ╚═════╝╚═╝  ╚═╝
]]

local function CreatePanel(name, offset, logo)
    Utils.SafeCall(function()
        local character = player.Character or player.CharacterAdded:Wait()
        local hrp = character:WaitForChild("HumanoidRootPart")
        
        local panel = Instance.new("Part")
        panel.Name = name
        panel.Size = Vector3.new(7, 5, 0.1)
        panel.Color = Colors.Background
        panel.Material = Enum.Material.SmoothPlastic
        panel.CanCollide = false
        panel.Transparency = Config.PanelTransparency
        panel.Parent = hrp
        panel.CFrame = hrp.CFrame * offset
        
        local weld = Instance.new("WeldConstraint")
        weld.Part0 = panel
        weld.Part1 = hrp
        weld.Parent = panel
        
        local highlight = Instance.new("Highlight")
        highlight.FillColor = Colors.Green
        highlight.FillTransparency = 0.9
        highlight.OutlineColor = Colors.Green
        highlight.OutlineTransparency = 0.2
        highlight.Parent = panel
        
        local fg = Instance.new("SurfaceGui")
        fg.Face = Enum.NormalId.Front
        fg.AlwaysOnTop = true
        fg.CanvasSize = Vector2.new(700, 500)
        fg.BackgroundColor3 = Colors.Background
        fg.Parent = panel
        
        local logoLabel = Instance.new("TextLabel")
        logoLabel.Size = UDim2.new(1, 0, 0.3, 0)
        logoLabel.BackgroundTransparency = 1
        logoLabel.TextColor3 = Colors.Green
        logoLabel.Font = Enum.Font.Code
        logoLabel.TextSize = 10
        logoLabel.Text = logo
        logoLabel.TextXAlignment = Enum.TextXAlignment.Center
        logoLabel.Parent = fg
        
        local bg = Instance.new("SurfaceGui")
        bg.Face = Enum.NormalId.Back
        bg.AlwaysOnTop = true
        bg.CanvasSize = Vector2.new(650, 450)
        bg.BackgroundColor3 = Colors.Background
        bg.Parent = panel
        
        local output = Instance.new("TextLabel")
        output.Name = "TerminalOutput"
        output.Size = UDim2.new(0.95, 0, 0.9, 0)
        output.Position = UDim2.new(0.025, 0, 0.05, 0)
        output.BackgroundTransparency = 1
        output.TextColor3 = Colors.Text
        output.Font = Enum.Font.Code
        output.TextSize = 10
        output.TextWrapped = true
        output.TextYAlignment = Enum.TextYAlignment.Top
        output.Parent = bg
        
        table.insert(Terminal.Panels, panel)
    end)
end

Services.UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    
    if input.KeyCode == Enum.KeyCode.Tab then
        Terminal:Toggle()
        return
    end
    
    if not Terminal.Active then return end
    
    if input.KeyCode == Enum.KeyCode.Backspace then
        Terminal.Input = Terminal.Input:sub(1, -2)
        Terminal:UpdateDisplay()
        return
    end
    
    if input.KeyCode == Enum.KeyCode.Return then
        if Terminal.Input ~= "" then
            local input = Terminal.Input
            Terminal.Input = ""
            Terminal:AddHistory(input)
            Terminal:AddLine(Terminal:Prompt() .. input, Colors.Text)
            local args = {}
            for word in input:gmatch("%S+") do table.insert(args, word) end
            local cmdName = args[1] and args[1]:lower()
            if Aliases[cmdName] then cmdName = Aliases[cmdName] end
            local command = cmdName and Commands[cmdName]
            if command then
                Utils.SafeCall(function() command.Handler(args) end)
            elseif cmdName then
                Terminal:AddLine("❌ Команда не найдена: " .. cmdName, Colors.Red)
                SoundSystem:Play("Error")
            end
        end
        Terminal:UpdateDisplay()
        return
    end
    
    if input.KeyCode == Enum.KeyCode.Up then
        Terminal.Input = Terminal:PreviousCommand()
        Terminal:UpdateDisplay()
        return
    end
    
    if input.KeyCode == Enum.KeyCode.Down then
        Terminal.Input = Terminal:NextCommand()
        Terminal:UpdateDisplay()
        return
    end
    
    if input.KeyCode == Enum.KeyCode.Space then
        Terminal.Input = Terminal.Input .. " "
        Terminal:UpdateDisplay()
        return
    end
    
    local char = input.KeyCode.Name
    if #char == 1 and (char:match("%a") or char:match("%d") or char == "-" or char == "_" or char == "." or char == "/") then
        local isShift = Services.UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) or Services.UserInputService:IsKeyDown(Enum.KeyCode.RightShift)
        Terminal.Input = Terminal.Input .. (isShift and char:upper() or char:lower())
        Terminal:UpdateDisplay()
    end
end)

_G.FlyActive = false
_G.GodActive = false
_G.NoclipActive = false
_G.InvisActive = false

Services.UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    local character = player.Character
    if not character then return end
    local hum = character:FindFirstChildOfClass("Humanoid")
    if not hum then return end
    local key = input.KeyCode
    
    if key == Enum.KeyCode.F then
        _G.FlyActive = not _G.FlyActive
        hum.PlatformStand = _G.FlyActive
    elseif key == Enum.KeyCode.G then
        _G.GodActive = not _G.GodActive
        hum:SetStateEnabled(Enum.HumanoidStateType.Dead, not _G.GodActive)
    elseif key == Enum.KeyCode.N then
        _G.NoclipActive = not _G.NoclipActive
        for _, v in pairs(character:GetChildren()) do
            if v:IsA("BasePart") then v.CanCollide = not _G.NoclipActive end
        end
    elseif key == Enum.KeyCode.I then
        _G.InvisActive = not _G.InvisActive
        for _, v in pairs(character:GetChildren()) do
            if v:IsA("BasePart") then v.Transparency = _G.InvisActive and 1 or 0 end
        end
    elseif key == Enum.KeyCode.H then
        hum.Health = hum.MaxHealth
    elseif key == Enum.KeyCode.Escape then
        for _, panel in ipairs(Terminal.Panels) do
            panel.Transparency = panel.Transparency == 0 and 1 or 0
        end
    end
end)

task.wait(Config.BootDelay)

CreatePanel("Googol_1", CFrame.new(-7, 2, -5) * CFrame.Angles(0, math.rad(25), 0), LogoKali)
CreatePanel("Googol_2", CFrame.new(0, 2, -6) * CFrame.Angles(0, math.rad(180), 0), LogoArch)
CreatePanel("Googol_3", CFrame.new(7, 2, -5) * CFrame.Angles(0, math.rad(-25), 0), LogoBlackArch)

SoundSystem:Play("Boot")
Achievements[1].Unlocked = true

Terminal:AddLine("╔══════════════════════════════════════════════╗", Colors.Purple)
Terminal:AddLine("║  ⚛️ OUTPOST 3 LINUX v10.0 GOOGOL           ║", Colors.Purple)
Terminal:AddLine("║  1600+ команд | Темы | Достижения          ║", Colors.Purple)
Terminal:AddLine("║  TAB — Терминал | help — Команды           ║", Colors.Purple)
Terminal:AddLine("╚══════════════════════════════════════════════╝", Colors.Purple)

print("Outpost 3 Linux v10.0 GOOGOL ULTIMATE загружен!")
print("Темы: Dark, Matrix, Ocean, Sunset, Purple")
print("Алиасы: ll, cl, q, rb, sd, tp, ex, hl")
print("Достижения: 7 доступно")