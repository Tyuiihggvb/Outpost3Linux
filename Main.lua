-- ============================================================
--   ██╗  ██╗ █████╗ ██╗     ██╗     ██╗███╗   ██╗██╗   ██╗
--   ██║ ██╔╝██╔══██╗██║     ██║     ██║████╗  ██║╚██╗ ██╔╝
--   █████╔╝ ███████║██║     ██║     ██║██╔██╗ ██║ ╚████╔╝
--   ██╔═██╗ ██╔══██║██║     ██║     ██║██║╚██╗██║  ╚██╔╝
--   ██║  ██╗██║  ██║███████╗███████╗██║██║ ╚████║   ██║
--   ╚═╝  ╚═╝╚═╝  ╚═╝╚══════╝╚══════╝╚═╝╚═╝  ╚═══╝   ╚═╝
-- ============================================================
-- ===== ПОЛНАЯ LINUX-СИСТЕМА В 3D =====
-- ============================================================

local player = game.Players.LocalPlayer
local runService = game:GetService("RunService")
local uis = game:GetService("UserInputService")

-- Предварительные объявления: функции ниже больше не становятся глобальными,
-- а terminalCommands виден внутри help/sudo (раньше там был nil)
local addTerminalLine, updateTerminalDisplay, showBootloader, bootEntry
local setTerminalActive
local terminalCommands

-- Состояние эффектов (раньше хранилось в _G)
local state = {fly = false, god = false, noclip = false, invis = false, speed = 1}

-- Общие переменные новых подсистем (объявлены заранее, определяются ниже)
local captureBuffer = nil        -- не nil => вывод команды копится здесь (пайпы и перенаправление >)
local stdinLines = nil           -- ввод для команды, стоящей после "|"
local interruptFlag = false      -- Ctrl+C / Enter во время работы команды
local renderSuspended = false    -- пакетное обновление терминала (top, watch, редактор)
local pendingPrompt = nil        -- {label=, masked=} пока команда ждёт ввода (пароль, редактор)
local inputEvent = Instance.new("BindableEvent")
local env = {}                   -- переменные окружения
local aliases = {}               -- алиасы команд
local sshStack = {}              -- стек ssh-сессий
local bootTime = os.time()
local scrollOffset = 0           -- прокрутка терминала (PageUp/PageDown)
local bootToken, autoBootActive = 0, false
local currentThemeName = "classic"
local desktopGui                 -- ScreenGui рабочего стола (startx)
local executeLine, readLine, applyTheme, saveState, loadState, openDesktop, closeDesktop
local errorSeen = false          -- команда вывела ошибку (нужно для кода возврата $?)
local noPrompt = false           -- true => readLine сразу отменяется (команды из окна рабочего стола)
local cursorOn = true            -- мигающий курсор
local crtEnabled = true          -- CRT-линии на панелях
local NUM_SESSIONS = 3           -- панели-сессии (как окна tmux)
local sessions, activeSession, paneMode = {}, 1, false
local switchSession, setPaneMode, setCrt, setSoundEnabled, playSound

-- ============================================================
-- ===== 1. ЦВЕТА (КЛАССИЧЕСКИЙ ТЕРМИНАЛ) =====
-- ============================================================
local colors = {
    bg = Color3.fromRGB(0, 0, 0),
    text = Color3.fromRGB(255, 255, 255),
    green = Color3.fromRGB(0, 255, 0),
    amber = Color3.fromRGB(255, 191, 0),
    red = Color3.fromRGB(255, 0, 0),
    cyan = Color3.fromRGB(0, 255, 255),
    purple = Color3.fromRGB(200, 100, 255),
    gray = Color3.fromRGB(150, 150, 150),
    darkgray = Color3.fromRGB(80, 80, 80),
}


-- Темы оформления (команда `theme`); classic совпадает с исходными цветами
local themes = {
    classic = {
        text = colors.text, green = colors.green, amber = colors.amber, red = colors.red,
        cyan = colors.cyan, purple = colors.purple, gray = colors.gray, darkgray = colors.darkgray,
    },
    amber = {
        text = Color3.fromRGB(255, 205, 120), green = Color3.fromRGB(255, 176, 0), amber = Color3.fromRGB(255, 120, 0),
        red = Color3.fromRGB(255, 70, 60), cyan = Color3.fromRGB(255, 225, 160), purple = Color3.fromRGB(255, 150, 100),
        gray = Color3.fromRGB(160, 135, 95), darkgray = Color3.fromRGB(90, 75, 50),
    },
    cyberpunk = {
        text = Color3.fromRGB(225, 225, 255), green = Color3.fromRGB(255, 0, 170), amber = Color3.fromRGB(255, 235, 0),
        red = Color3.fromRGB(255, 60, 90), cyan = Color3.fromRGB(0, 240, 255), purple = Color3.fromRGB(160, 80, 255),
        gray = Color3.fromRGB(140, 130, 175), darkgray = Color3.fromRGB(70, 60, 100),
    },
    ice = {
        text = Color3.fromRGB(235, 250, 255), green = Color3.fromRGB(120, 220, 255), amber = Color3.fromRGB(255, 220, 120),
        red = Color3.fromRGB(255, 110, 130), cyan = Color3.fromRGB(165, 255, 255), purple = Color3.fromRGB(190, 160, 255),
        gray = Color3.fromRGB(150, 170, 190), darkgray = Color3.fromRGB(80, 95, 110),
    },
}

-- ============================================================
-- ===== 2. ЯДРО (KERNEL) =====
-- ============================================================
local kernel = {
    name = "JCJ_KERNEL",
    version = "3.0.0",
    build = "2026.07.31",
    architecture = "x86_64",
    os = "RobloxOS",
    distro = "Outpost 3 Linux",
    hostname = "outpost3",
    user = "root",
    uptime = 0,
    processes = {},
    pid_counter = 100,
    modules = {
        ["nvme"] = {version = "1.2.3", status = "loaded"},
        ["usb"] = {version = "4.5.6", status = "loaded"},
        ["wifi"] = {version = "2.1.0", status = "active"},
        ["bluetooth"] = {version = "3.0.1", status = "active"},
        ["audio"] = {version = "5.1.2", status = "loaded"},
        ["gpu"] = {version = "6.0.0", status = "active"},
        ["network"] = {version = "4.3.2", status = "loaded"},
        ["storage"] = {version = "3.2.1", status = "active"},
        ["input"] = {version = "2.0.0", status = "loaded"},
        ["security"] = {version = "1.0.0", status = "active"},
    },
    drivers = {
        ["nvidia"] = {version = "535.154.05", status = "loaded"},
        ["amd"] = {version = "6.5.3", status = "inactive"},
        ["intel"] = {version = "2.1.0", status = "inactive"},
        ["realtek"] = {version = "1.0.0", status = "loaded"},
    }
}

-- ============================================================
-- ===== 3. ЗАГРУЗЧИК (BOOTLOADER) =====
-- ============================================================
local bootloader = {
    version = "2.0.0",
    timeout = 5,
    default_entry = 1,
    entries = {
        {name = "JCJ_KERNEL v3.0.0", description = "Outpost 3 Linux (x86_64)", kernel = "jcj_kernel"},
        {name = "JCJ_KERNEL (Recovery)", description = "Single-user mode", kernel = "jcj_kernel_recovery", recovery = true},
        {name = "Windows 11 Pro", description = "Windows 11 Pro (NTFS)", kernel = "windows", type = "ntfs"},
        {name = "Kali Linux 2026.1", description = "Kali Linux (live mode)", kernel = "kali_linux", type = "live"},
        {name = "Arch Linux", description = "Arch Linux (rolling release)", kernel = "arch_linux", type = "rolling"},
        {name = "Ubuntu 24.04 LTS", description = "Ubuntu LTS (stable)", kernel = "ubuntu", type = "lts"},
    }
}

-- ============================================================
-- ===== 4. ПОЛЬЗОВАТЕЛИ =====
-- ============================================================
local users = {
    {name = "root", uid = 0, gid = 0, home = "/root", shell = "/bin/bash", password = "toor", is_root = true, groups = {"root", "sudo", "admin", "wheel"}},
    {name = "Yahmyh78", uid = 1000, gid = 1000, home = "/home/Yahmyh78", shell = "/bin/zsh", password = "12345", is_root = false, groups = {"sudo", "users", "wheel"}},
    {name = "guest", uid = 1001, gid = 1001, home = "/home/guest", shell = "/bin/bash", password = "guest", is_root = false, groups = {"users"}},
}

local currentUser = users[2]
local isRoot = false
local lastSudoTime = 0
local currentHost = "outpost3"   -- имя текущей машины (меняется при ssh)

-- ============================================================
-- ===== 5. ФАЙЛОВАЯ СИСТЕМА =====
-- ============================================================
local fileSystem = {
    ["/"] = {
        type = "dir",
        children = {
            ["home"] = {type = "dir", children = {
                ["root"] = {type = "dir", children = {
                    ["Desktop"] = {type = "dir", children = {}},
                    ["Documents"] = {type = "dir", children = {
                        ["report.txt"] = {type = "file", content = "Outpost 3 Status: OPERATIONAL"},
                        ["hack.log"] = {type = "file", content = "[*] Hack initiated at " .. os.date("%Y-%m-%d %H:%M:%S")},
                    }},
                    ["Downloads"] = {type = "dir", children = {}},
                    [".bashrc"] = {type = "file", content = "alias ll='ls -la'\nalias la='ls -a'\nexport PS1='┌──(\\u@\\h)-[\\w]\\n└─$ '"},
                    [".zshrc"] = {type = "file", content = "PROMPT='[%n@%m %1~]$ '\nZSH_THEME='robbyrussell'"},
                    ["hack.sh"] = {type = "file", content = "#!/bin/bash\necho '🚀 Hacking the system...'\n./activate_console"},
                    ["outpost3.log"] = {type = "file", content = "[*] OUTPOST 3 CONNECTION LOG\n[+] Connection established at " .. os.date("%Y-%m-%d %H:%M:%S") .. "\n[+] Solver protocol active"},
                    ["notes.txt"] = {type = "file", content = "Remember: With great power comes great responsibility."},
                }},
                ["Yahmyh78"] = {type = "dir", children = {
                    ["Desktop"] = {type = "dir", children = {}},
                    ["Documents"] = {type = "dir", children = {}},
                }},
            }},
            ["etc"] = {type = "dir", children = {
                ["hostname"] = {type = "file", content = "outpost3"},
                ["hosts"] = {type = "file", content = "127.0.0.1 localhost\n::1 localhost\n192.168.1.100 outpost3"},
                ["passwd"] = {type = "file", content = "root:x:0:0:root:/root:/bin/bash\nYahmyh78:x:1000:1000::/home/Yahmyh78:/bin/zsh"},
                ["shadow"] = {type = "file", content = "root:$6$xyz:19000:0:99999:7:::\nYahmyh78:$6$abc:19000:0:99999:7:::"},
                ["fstab"] = {type = "file", content = "/dev/sda1 / ext4 defaults 0 1\n/dev/sda2 swap swap defaults 0 0"},
                ["os-release"] = {type = "file", content = "NAME=\"Outpost 3 Linux\"\nVERSION=\"3.0.0\"\nID=outpost\nPRETTY_NAME=\"Outpost 3 Linux 3.0.0\""},
            }},
            ["usr"] = {type = "dir", children = {
                ["bin"] = {type = "dir", children = {
                    ["bash"] = {type = "file", content = "#!/bin/bash\necho 'Bash 5.2'"},
                    ["ls"] = {type = "file", content = "#!/bin/bash\necho 'Listing files...'"},
                    ["python"] = {type = "file", content = "#!/usr/bin/python3\nprint('Python 3.11')"},
                }},
                ["lib"] = {type = "dir", children = {}},
                ["share"] = {type = "dir", children = {}},
            }},
            ["tmp"] = {type = "dir", children = {}},
            ["var"] = {type = "dir", children = {
                ["log"] = {type = "dir", children = {
                    ["syslog"] = {type = "file", content = "[*] System log\n[+] Boot completed at " .. os.date("%Y-%m-%d %H:%M:%S")},
                }},
            }},
            ["sys"] = {type = "dir", children = {}},
            ["proc"] = {type = "dir", children = {}},
            ["boot"] = {type = "dir", children = {
                ["vmlinuz"] = {type = "file", content = "[KERNEL IMAGE] v" .. kernel.version},
                ["initrd.img"] = {type = "file", content = "[INITRD IMAGE]"},
                ["grub"] = {type = "dir", children = {
                    ["grub.cfg"] = {type = "file", content = "set default=0\nset timeout=5\nmenuentry 'Outpost 3 Linux' { linux /vmlinuz root=/dev/sda1 }"},
                }},
            }},
            ["mnt"] = {type = "dir", children = {}},
            ["opt"] = {type = "dir", children = {}},
            ["srv"] = {type = "dir", children = {}},
        }
    }
}

local currentPath = "/home/Yahmyh78"

-- ===== Домашние папки, приглашение, права и владельцы =====
local function homeOf(user)
    -- в этой файловой системе домашняя папка root лежит в /home/root
    if user.name == "root" then return "/home/root" end
    return user.home
end

local function getPrompt()
    local cwd = currentPath
    local home = homeOf(currentUser)
    if cwd == home then
        cwd = "~"
    elseif cwd:sub(1, #home + 1) == home .. "/" then
        cwd = "~" .. cwd:sub(#home + 1)
    end
    return "┌──(" .. currentUser.name .. "㉿" .. currentHost .. ")-[" .. cwd .. "]\n└─" .. (isRoot and "#" or "$") .. " "
end

-- owner/mode хранятся в узлах; по умолчанию владелец root, режим 755 для папок и 644 для файлов
local function nodeOwner(node) return node.owner or "root" end
local function nodeMode(node) return node.mode or (node.type == "dir" and "755" or "644") end

local function chownTree(node, owner)
    node.owner = owner
    if node.children then
        for _, child in pairs(node.children) do chownTree(child, owner) end
    end
end

-- perm: "r" | "w" | "x"; root может всё
local function hasPerm(node, perm)
    if isRoot then return true end
    local mode = nodeMode(node)
    local digit
    if nodeOwner(node) == currentUser.name then
        digit = tonumber(mode:sub(1, 1))
    else
        digit = tonumber(mode:sub(3, 3))
        for _, group in ipairs(currentUser.groups or {}) do
            if group == nodeOwner(node) then
                digit = tonumber(mode:sub(2, 2))
                break
            end
        end
    end
    local bit = ({r = 4, w = 2, x = 1})[perm]
    return math.floor((digit or 0) / bit) % 2 == 1
end

do
    local rootNode = fileSystem["/"]
    local home = rootNode.children.home
    chownTree(home.children.Yahmyh78, "Yahmyh78")
    home.children.guest = {type = "dir", children = {}, owner = "guest"}
    home.children.root.mode = "700"
    home.children.root.children["hack.sh"].mode = "755"
    rootNode.children.etc.children.shadow.mode = "640"
    rootNode.children.tmp.mode = "777"
end

-- ===== Удалённые машины для ssh =====
local function makeUser(name, uid, password, groups, rootUser)
    return {
        name = name, uid = uid, gid = uid, home = rootUser and "/home/root" or ("/home/" .. name),
        shell = "/bin/bash", password = password, is_root = rootUser or false, groups = groups,
    }
end

local function buildRemoteFs(host, distro, userNames, notes)
    local home = {
        root = {type = "dir", owner = "root", mode = "700", children = {
            ["flag.txt"] = {type = "file", owner = "root", mode = "600", content = "FLAG{" .. host .. "_root_pwned}"},
        }},
    }
    for _, name in ipairs(userNames) do
        home[name] = {type = "dir", owner = name, children = {
            ["notes.txt"] = {type = "file", owner = name, content = notes[name] or "Nothing here."},
        }}
    end
    return {["/"] = {type = "dir", children = {
        home = {type = "dir", children = home},
        etc = {type = "dir", children = {
            hostname = {type = "file", content = host},
            ["os-release"] = {type = "file", content = 'NAME="' .. distro .. '"'},
        }},
        tmp = {type = "dir", mode = "777", children = {}},
        usr = {type = "dir", children = {bin = {type = "dir", children = {}}}},
        var = {type = "dir", children = {log = {type = "dir", children = {
            syslog = {type = "file", content = "[*] " .. host .. " boot completed"},
        }}}},
    }}}
end

local function buildMachine(host, ip, distro, rootPassword, accounts, notes)
    local list = {makeUser("root", 0, rootPassword, {"root", "sudo"}, true)}
    local names = {}
    local uid = 1000
    for _, acc in ipairs(accounts) do
        table.insert(list, makeUser(acc[1], uid, acc[2], {"sudo", "users"}))
        table.insert(names, acc[1])
        uid = uid + 1
    end
    return {ip = ip, distro = distro, users = list, fs = buildRemoteFs(host, distro, names, notes)}
end

local machines = {
    kali = buildMachine("kali", "192.168.1.101", "Kali Linux 2026.1", "kali",
        {{"pentester", "hunter2"}}, {pentester = "TODO: change the root password (it's still the distro name)."}),
    arch = buildMachine("arch", "192.168.1.102", "Arch Linux", "arch",
        {{"archer", "btw"}}, {archer = "I use Arch, btw."}),
    blackarch = buildMachine("blackarch", "192.168.1.103", "BlackArch Linux", "blackarch",
        {{"ghost", "boo"}}, {ghost = "Nothing to see here. (root has a flag.txt...)"}),
}

-- локальная машина (после загрузки/сохранения именно на неё указывают сессии без ssh)
local localMachine = {fs = fileSystem, users = users}

-- ============================================================
-- ===== 6. ФУНКЦИИ ФАЙЛОВОЙ СИСТЕМЫ =====
-- ============================================================
local function resolvePath(path)
    path = path or ""
    if path == "" or path == "~" then
        path = homeOf(currentUser)
    elseif path:sub(1, 2) == "~/" then
        path = homeOf(currentUser) .. "/" .. path:sub(3)
    elseif path:sub(1, 1) ~= "/" then
        path = currentPath .. "/" .. path
    end
    local parts = {}
    for part in path:gmatch("[^/]+") do
        if part == ".." then table.remove(parts)
        elseif part ~= "." then table.insert(parts, part) end
    end
    return "/" .. table.concat(parts, "/")
end

-- Возвращает узел, либо nil, "denied" если нет права x на одну из папок пути
local function getPathObject(path)
    local current = fileSystem["/"]
    for part in resolvePath(path):gmatch("[^/]+") do
        if current.type ~= "dir" or not current.children[part] then return nil end
        if not hasPerm(current, "x") then return nil, "denied" end
        current = current.children[part]
    end
    return current
end

local function getFullPath() return currentPath end

local function formatBytes(bytes)
    if bytes > 1024*1024*1024 then return string.format("%.2f GB", bytes/1024/1024/1024)
    elseif bytes > 1024*1024 then return string.format("%.2f MB", bytes/1024/1024)
    elseif bytes > 1024 then return string.format("%.2f KB", bytes/1024)
    else return bytes .. " B" end
end

local function hasSudoAccess(user)
    for _, g in ipairs(user.groups or {}) do
        if g == "sudo" or g == "admin" then return true end
    end
    return user.is_root or false
end

local function checkRoot()
    if isRoot then return true end
    addTerminalLine("❌ Permission denied! Need root privileges.", colors.red)
    addTerminalLine("   Use 'sudo' or 'su root'", colors.gray)
    return false
end

-- ============================================================
-- ===== 7. ПРОЦЕССЫ =====
-- ============================================================
local function createProcess(name, action, system)
    kernel.pid_counter = kernel.pid_counter + 1
    local proc = {
        pid = kernel.pid_counter,
        name = name,
        status = "running",
        alive = true,                -- фоновые команды проверяют этот флаг и завершаются после kill
        action = action,
        start_time = os.time(),
        system = system or false,
        user = system and "root" or currentUser.name,
    }
    table.insert(kernel.processes, proc)
    return proc.pid, proc
end

local function killProcess(pid)
    for i, proc in ipairs(kernel.processes) do
        if proc.pid == pid then
            if proc.system then
                addTerminalLine("❌ kill: (" .. pid .. ") - Operation not permitted", colors.red)
                return
            end
            if proc.user ~= currentUser.name and not isRoot then
                addTerminalLine("❌ kill: (" .. pid .. ") - Permission denied", colors.red)
                return
            end
            proc.status = "terminated"
            proc.alive = false
            table.remove(kernel.processes, i)
            addTerminalLine("✅ Process " .. pid .. " terminated", colors.green)
            return
        end
    end
    addTerminalLine("❌ Process " .. pid .. " not found", colors.red)
end

local function listProcesses()
    if not captureBuffer then
        addTerminalLine("  PID USER       TIME   STATUS    COMMAND", colors.green)
    end
    for _, proc in ipairs(kernel.processes) do
        local runtime = os.time() - proc.start_time
        addTerminalLine(string.format("%5d %-10s %02d:%02d  %-9s %s", proc.pid, proc.user or "root",
            math.floor(runtime / 60), runtime % 60, proc.status, proc.name), colors.text)
    end
end

-- ============================================================
-- ===== 8. ПАНЕЛИ И ТЕРМИНАЛ =====
-- ============================================================
local panels = {}
local monitorConnection = nil
local terminalLines = {}
local currentInput = ""
local maxLines = 22
local terminalActive = false

local fps = 0
local frameCount = 0
local lastFpsUpdate = tick()

local terminalLabels = {}   -- кэш лейблов терминала (заполняется в createPanel)
local terminalHeaders, terminalFooters = {}, {}   -- заголовки и статус-строки панелей
local commandHistory = {}
local historyIndex = 1
local busy = false

-- Персонаж и GUI (заполняются в setupCharacter / разделе 14)
local hrp, hum, baseWalkSpeed
local i1, i2, i3
local panelFolder
local screenGui, inputBox

-- ============================================================
-- ===== 9. ФУНКЦИИ ТЕРМИНАЛА (история прокрутки, RichText, панели) =====
-- ============================================================
local MAX_SCROLLBACK = 500

local function escapeRich(s)
    s = s:gsub("&", "&amp;")
    s = s:gsub("<", "&lt;")
    s = s:gsub(">", "&gt;")
    return s
end

-- Возвращает добавленную строку (её можно обновлять, например таймер автозагрузки)
-- force = true или красный цвет (ошибки, как stderr) всегда идут на экран, мимо пайпов и перенаправления
function addTerminalLine(text, color, force)
    text = tostring(text)
    if color == colors.red then errorSeen = true end   -- нужен для кода возврата $?
    if captureBuffer and color ~= colors.red and not force then
        for line in (text .. "\n"):gmatch("(.-)\n") do
            table.insert(captureBuffer, line)
        end
        return nil
    end
    local last
    for line in (text .. "\n"):gmatch("(.-)\n") do
        last = {text = line, color = color or colors.text}
        table.insert(terminalLines, last)
        if #terminalLines > MAX_SCROLLBACK then table.remove(terminalLines, 1) end
    end
    updateTerminalDisplay()
    return last
end

local function renderLines(lines, scroll, tailLine)
    local total = #lines
    scroll = math.clamp(scroll, 0, math.max(0, total - maxLines))
    local first = math.max(1, total - maxLines + 1 - scroll)
    local last = math.min(total, first + maxLines - 1)
    local parts = {}
    for i = first, last do
        local line = lines[i]
        parts[#parts + 1] = string.format('<font color="#%s">%s</font>', line.color:ToHex(), escapeRich(line.text))
    end
    if scroll > 0 then
        parts[#parts + 1] = string.format('<font color="#%s">  ↓ %d more line(s) below — PageDown / End</font>', colors.gray:ToHex(), scroll)
    elseif tailLine then
        parts[#parts + 1] = tailLine
    end
    return table.concat(parts, "\n"), scroll
end

function updateTerminalDisplay()
    if renderSuspended then return end

    -- активная сессия: строки + приглашение с курсором
    local label, shown = getPrompt(), currentInput
    if pendingPrompt then
        label = pendingPrompt.label
        if pendingPrompt.masked then shown = string.rep("*", #currentInput) end
    end
    local cursor = (not terminalActive or cursorOn) and "█" or " "
    local tail = string.format('<font color="#%s">%s</font>', colors.text:ToHex(), escapeRich(label .. shown .. cursor))
    local activeText, clamped = renderLines(terminalLines, scrollOffset, tail)
    scrollOffset = clamped

    for i, lbl in ipairs(terminalLabels) do
        if lbl.Parent then
            if not paneMode or i == activeSession then
                lbl.Text = activeText
            else
                local s = sessions[i]
                if s then
                    local tailOther = string.format('<font color="#%s">%s</font>', colors.gray:ToHex(), escapeRich(s.prompt or "$ "))
                    lbl.Text = (renderLines(s.lines, s.scroll, tailOther))
                else
                    lbl.Text = ""
                end
            end
        end
    end

    -- заголовки панелей: вкладки или номер панели
    for i, hdr in ipairs(terminalHeaders) do
        if hdr.Parent then
            if paneMode then
                hdr.Text = "╔══ PANE " .. i .. (i == activeSession and " ● ACTIVE " or "          ") .. "══════════════════════════════╗"
                hdr.TextColor3 = (i == activeSession) and colors.green or colors.gray
            else
                local tabs = {}
                for n = 1, NUM_SESSIONS do
                    tabs[n] = (n == activeSession) and ("[" .. n .. "*]") or ("[" .. n .. "]")
                end
                hdr.Text = "╔══ TERMINAL " .. table.concat(tabs, " ") .. " ══════════════════════════╗"
                hdr.TextColor3 = colors.green
            end
        end
    end
end

-- ============================================================
-- ===== 10. ЗАГРУЗЧИК (ФУНКЦИИ) =====
-- ============================================================
function showBootloader()
    addTerminalLine("╔═══════════════════════════════════════════════════════════════╗", colors.green)
    addTerminalLine("║                                                               ║", colors.green)
    addTerminalLine("║   ██╗  ██╗ █████╗ ██╗     ██╗     ██╗███╗   ██╗██╗   ██╗     ║", colors.green)
    addTerminalLine("║   ██║ ██╔╝██╔══██╗██║     ██║     ██║████╗  ██║╚██╗ ██╔╝     ║", colors.green)
    addTerminalLine("║   █████╔╝ ███████║██║     ██║     ██║██╔██╗ ██║ ╚████╔╝      ║", colors.green)
    addTerminalLine("║   ██╔═██╗ ██╔══██║██║     ██║     ██║██║╚██╗██║  ╚██╔╝       ║", colors.green)
    addTerminalLine("║   ██║  ██╗██║  ██║███████╗███████╗██║██║ ╚████║   ██║        ║", colors.green)
    addTerminalLine("║   ╚═╝  ╚═╝╚═╝  ╚═╝╚══════╝╚══════╝╚═╝╚═╝  ╚═══╝   ╚═╝        ║", colors.green)
    addTerminalLine("║                                                               ║", colors.green)
    addTerminalLine("║           JCJ_BOOTLOADER v" .. bootloader.version .. "               ║", colors.green)
    addTerminalLine("║           Build: " .. kernel.build .. "                        ║", colors.green)
    addTerminalLine("║                                                               ║", colors.green)
    addTerminalLine("╚═══════════════════════════════════════════════════════════════╝", colors.green)
    addTerminalLine("", colors.text)
    for i, entry in ipairs(bootloader.entries) do
        local marker = (i == bootloader.default_entry) and "▶" or " "
        local color = entry.recovery and colors.amber or colors.green
        addTerminalLine(marker .. " " .. i .. ". " .. entry.name, color)
        addTerminalLine("   " .. entry.description, colors.gray)
    end
    addTerminalLine("", colors.text)
    addTerminalLine("  Use 'boot_entry <number>' to select", colors.gray)
end

function bootEntry(index)
    local entry = bootloader.entries[index]
    if not entry then addTerminalLine("❌ Invalid entry!", colors.red) return end
    addTerminalLine("", colors.text)
    addTerminalLine("⟳ Loading " .. entry.name .. "...", colors.green)
    task.wait(0.5)
    if entry.kernel == "windows" then
        addTerminalLine("[+] NTFS partition detected", colors.green)
        task.wait(0.3)
        addTerminalLine("[+] Loading Windows kernel...", colors.green)
        task.wait(0.3)
        addTerminalLine("[✓] Windows 11 booted successfully!", colors.green)
    elseif entry.kernel == "kali_linux" then
        addTerminalLine("[+] Loading Kali Linux live image...", colors.green)
        task.wait(0.3)
        addTerminalLine("[+] Booting from USB...", colors.green)
        task.wait(0.3)
        addTerminalLine("[✓] Kali Linux live booted!", colors.green)
    elseif entry.kernel == "arch_linux" then
        addTerminalLine("[+] Loading Arch Linux...", colors.green)
        task.wait(0.3)
        addTerminalLine("[+] Syncing pacman...", colors.green)
        task.wait(0.3)
        addTerminalLine("[✓] Arch Linux booted!", colors.green)
    elseif entry.kernel == "ubuntu" then
        addTerminalLine("[+] Loading Ubuntu LTS...", colors.green)
        task.wait(0.3)
        addTerminalLine("[+] Starting snap services...", colors.green)
        task.wait(0.3)
        addTerminalLine("[✓] Ubuntu 24.04 LTS booted!", colors.green)
    else
        addTerminalLine("[+] Loading kernel image...", colors.green)
        task.wait(0.3)
        addTerminalLine("[+] Loading initrd...", colors.green)
        task.wait(0.3)
        addTerminalLine("[+] Detecting hardware...", colors.green)
        task.wait(0.3)
        addTerminalLine("[+] Mounting root filesystem...", colors.green)
        task.wait(0.3)
        addTerminalLine("[+] Starting system services...", colors.green)
        task.wait(0.3)
        if entry.recovery then
            addTerminalLine("[✓] RECOVERY MODE: Single-user shell", colors.amber)
        else
            addTerminalLine("[✓] JCJ_KERNEL booted successfully!", colors.green)
        end
    end
end

-- ============================================================
-- ===== 11. ВСЕ КОМАНДЫ ТЕРМИНАЛА =====
-- ============================================================
terminalCommands = {
    -- Базовые
    ["clear"] = {
        desc = "Clear terminal",
        action = function()
            terminalLines = {}
            updateTerminalDisplay()
            addTerminalLine("🔄 Terminal cleared", colors.green)
        end
    },

    -- Пользователи и права
    ["id"] = {
        desc = "Show user and group IDs",
        action = function()
            addTerminalLine("👤 uid=" .. currentUser.uid .. "(" .. currentUser.name .. ") gid=" .. currentUser.gid .. "(" .. currentUser.groups[1] .. ")", colors.green)
            addTerminalLine("   groups=" .. table.concat(currentUser.groups, ","), colors.text)
            if isRoot then addTerminalLine("   👑 ROOT PRIVILEGES", colors.amber) end
        end
    },
    ["groups"] = {
        desc = "Show user groups",
        action = function(args)
            local target = args[2] or currentUser.name
            local user = nil
            for _, u in ipairs(users) do
                if u.name == target then user = u; break end
            end
            if not user then
                addTerminalLine("❌ User not found: " .. target, colors.red)
                return
            end
            addTerminalLine("👤 " .. target .. ":", colors.green)
            for _, group in ipairs(user.groups or {}) do
                addTerminalLine("   " .. group, colors.text)
            end
        end
    },
    ["who"] = {
        desc = "Show logged in users",
        action = function()
            addTerminalLine("👤 LOGGED IN USERS:", colors.green)
            addTerminalLine("  root     tty1  " .. os.date("%Y-%m-%d %H:%M"), colors.text)
            addTerminalLine("  " .. currentUser.name .. "  pts/0  " .. os.date("%Y-%m-%d %H:%M"), colors.text)
            for _, u in ipairs(users) do
                if u.name ~= "root" and u.name ~= currentUser.name then
                    addTerminalLine("  " .. u.name .. "  pts/" .. math.random(1,5) .. "  " .. os.date("%Y-%m-%d %H:%M"), colors.text)
                end
            end
        end
    },
    ["adduser_sudo"] = {
        desc = "Add user to sudo (admin only)",
        action = function(args)
            if not checkRoot() then return end
            if not args[2] then
                addTerminalLine("❌ Usage: adduser_sudo <username>", colors.red)
                return
            end
            local user = nil
            for _, u in ipairs(users) do
                if u.name == args[2] then user = u; break end
            end
            if not user then
                addTerminalLine("❌ User not found: " .. args[2], colors.red)
                return
            end
            if not table.find(user.groups, "sudo") then
                table.insert(user.groups, "sudo")
                addTerminalLine("✅ User " .. user.name .. " added to sudo group", colors.green)
            else
                addTerminalLine("ℹ️ User already in sudo group", colors.amber)
            end
        end
    },
    ["deluser_sudo"] = {
        desc = "Remove from sudo (admin only)",
        action = function(args)
            if not checkRoot() then return end
            if not args[2] then
                addTerminalLine("❌ Usage: deluser_sudo <username>", colors.red)
                return
            end
            local user = nil
            for _, u in ipairs(users) do
                if u.name == args[2] then user = u; break end
            end
            if not user then
                addTerminalLine("❌ User not found: " .. args[2], colors.red)
                return
            end
            for i, g in ipairs(user.groups) do
                if g == "sudo" then
                    table.remove(user.groups, i)
                    addTerminalLine("✅ User " .. user.name .. " removed from sudo", colors.green)
                    return
                end
            end
            addTerminalLine("ℹ️ User not in sudo group", colors.amber)
        end
    },
     ["list_users"] = {
        desc = "List all users",
        action = function()
            addTerminalLine("👥 ALL USERS:", colors.green)
            for _, u in ipairs(users) do
                local status = u.is_root and " 👑" or ""
                local sudo = table.find(u.groups, "sudo") and " (sudo)" or ""
                addTerminalLine("  " .. u.name .. status .. sudo .. " (UID: " .. u.uid .. ")", colors.text)
            end
        end
    },

    -- Системные
    ["kernel"] = {
        desc = "Show kernel info",
        action = function()
            addTerminalLine("🧠 JCJ_KERNEL v" .. kernel.version, colors.green)
            addTerminalLine("  Build: " .. kernel.build, colors.text)
            addTerminalLine("  Arch: " .. kernel.architecture, colors.text)
            addTerminalLine("  OS: " .. kernel.os, colors.text)
            addTerminalLine("  Distro: " .. kernel.distro, colors.text)
            addTerminalLine("  Hostname: " .. kernel.hostname, colors.text)
            addTerminalLine("  Processes: " .. #kernel.processes, colors.text)
        end
    },
    ["ps"] = {
        desc = "List processes",
        action = function() listProcesses() end
    },
    ["kill"] = {
        desc = "Kill process (kill <PID>)",
        action = function(args)
            if args[2] then
                local pid = tonumber(args[2])
                if pid then killProcess(pid)
                else addTerminalLine("❌ Invalid PID", colors.red) end
            else
                addTerminalLine("❌ Usage: kill <PID>", colors.red)
            end
        end
    },
    ["dmesg"] = {
        desc = "Show kernel messages",
        action = function()
            addTerminalLine("📋 KERNEL MESSAGES:", colors.green)
            addTerminalLine("[    0.000] Linux version " .. kernel.version .. "-jcj (gcc-13)", colors.text)
            addTerminalLine("[    0.123] CPU: AMD Ryzen 9 7950X (16 cores, 32 threads)", colors.text)
            addTerminalLine("[    0.456] RAM: 16384MB available", colors.text)
            addTerminalLine("[    0.789] GPU: NVIDIA RTX 4090 detected", colors.text)
            addTerminalLine("[    1.012] NVMe: 1TB SSD detected", colors.text)
            addTerminalLine("[    1.345] USB: 4 ports detected", colors.text)
            addTerminalLine("[    1.678] Network: eth0 UP (1000Mbps)", colors.text)
            addTerminalLine("[    2.000] Wi-Fi: wlan0 UP", colors.text)
            addTerminalLine("[    2.345] Bluetooth: hci0 UP", colors.text)
            addTerminalLine("[    2.678] Audio: Realtek ALC1220 detected", colors.text)
            addTerminalLine("[    3.000] Input: Keyboard and Mouse detected", colors.text)
            addTerminalLine("[    3.456] Security: SELinux enabled", colors.text)
            addTerminalLine("[    4.000] System ready", colors.green)
        end
    },
     ["date"] = {
        desc = "Show date and time",
        action = function()
            addTerminalLine("📅 " .. os.date("%A, %B %d, %Y %H:%M:%S"), colors.green)
        end
    },
    ["cal"] = {
        desc = "Show calendar",
        action = function()
            local d = os.date("*t")
            addTerminalLine("📅 " .. os.date("%B %Y"), colors.green)
            addTerminalLine("  Mo Tu We Th Fr Sa Su", colors.text)
            addTerminalLine("     1  2  3  4  5  6", colors.text)
            addTerminalLine("  7  8  9 10 11 12 13", colors.text)
            addTerminalLine(" 14 15 16 17 18 19 20", colors.text)
            addTerminalLine(" 21 22 23 24 25 26 27", colors.text)
            addTerminalLine(" 28 29 30 31", colors.text)
        end
    },

    -- Сеть
    ["ifconfig"] = {
        desc = "Show network interfaces",
        action = function()
            addTerminalLine("📡 NETWORK INTERFACES:", colors.green)
            addTerminalLine("  eth0: flags=4163<UP,BROADCAST,RUNNING>  mtu 1500", colors.text)
            addTerminalLine("    inet 192.168.1.100  netmask 255.255.255.0  broadcast 192.168.1.255", colors.gray)
            addTerminalLine("    ether 00:1A:2B:3C:4D:5E  txqueuelen 1000", colors.gray)
            addTerminalLine("    RX packets 1234567  bytes 2.3 GB", colors.gray)
            addTerminalLine("    TX packets 987654  bytes 1.8 GB", colors.gray)
            addTerminalLine("", colors.text)
            addTerminalLine("  lo: flags=73<UP,LOOPBACK,RUNNING>  mtu 65536", colors.text)
            addTerminalLine("    inet 127.0.0.1  netmask 255.0.0.0", colors.gray)
        end
    },
     ["ping"] = {
        desc = "Ping a host",
        action = function(args)
            local host = args[2] or "localhost"
            local dns = {
                ["localhost"] = "127.0.0.1",
                ["google.com"] = "142.250.185.78",
                ["github.com"] = "140.82.121.3",
                ["outpost3"] = "192.168.1.100",
                ["roblox.com"] = "128.116.126.118"
            }
            local ip = dns[host] or "0.0.0.0"
            addTerminalLine("📶 PING " .. host .. " (" .. ip .. "):", colors.green)
            for i = 1, 4 do
                local loss = math.random(0, 1)
                if loss == 0 then
                    addTerminalLine("  64 bytes from " .. ip .. ": icmp_seq=" .. i .. " ttl=64 time=" .. math.random(10, 50) .. "ms", colors.green)
                else
                    addTerminalLine("  Request timeout for icmp_seq " .. i, colors.amber)
                end
                task.wait(0.3)
            end
            addTerminalLine("--- " .. host .. " ping statistics ---", colors.text)
            addTerminalLine("  4 packets transmitted, 3 received, 25% packet loss", colors.text)
        end
    },
    ["netstat"] = {
        desc = "Show network connections",
        action = function()
            addTerminalLine("🌐 ACTIVE CONNECTIONS:", colors.green)
            addTerminalLine("  Proto  Local Address          Foreign Address        State", colors.text)
            addTerminalLine("  TCP    192.168.1.100:22       192.168.1.50:54321     ESTABLISHED", colors.gray)
            addTerminalLine("  TCP    192.168.1.100:443      192.168.1.60:12345     ESTABLISHED", colors.gray)
            addTerminalLine("  TCP    192.168.1.100:80       192.168.1.70:67890     TIME_WAIT", colors.gray)
            addTerminalLine("  UDP    192.168.1.100:53       8.8.8.8:53             ESTABLISHED", colors.gray)
            addTerminalLine("  SSH    192.168.1.100:22       192.168.1.80:98765     ESTABLISHED", colors.gray)
        end
    },
    ["nslookup"] = {
        desc = "DNS lookup",
        action = function(args)
            local host = args[2] or "localhost"
            local dns = {
                ["localhost"] = "127.0.0.1",
                ["google.com"] = "142.250.185.78",
                ["github.com"] = "140.82.121.3",
                ["outpost3"] = "192.168.1.100",
                ["roblox.com"] = "128.116.126.118"
            }
            local ip = dns[host] or "Unknown"
            if ip ~= "Unknown" then
                addTerminalLine("🔍 DNS RESOLUTION:", colors.green)
                addTerminalLine("  Name:    " .. host, colors.text)
                addTerminalLine("  Address: " .. ip, colors.text)
                addTerminalLine("  TTL:     3600", colors.text)
            else
                addTerminalLine("❌ Host not found", colors.red)
            end
        end
    },
     
     -- Ядро и модули
    ["lsmod"] = {
        desc = "Show loaded kernel modules",
        action = function()
            addTerminalLine("📦 LOADED KERNEL MODULES:", colors.green)
            addTerminalLine("  Module      Version  Status", colors.text)
            for name, data in pairs(kernel.modules) do
                local color = data.status == "active" and colors.green or colors.amber
                addTerminalLine("  " .. string.upper(name) .. string.rep(" ", 12 - #name) .. data.version .. string.rep(" ", 10 - #data.version) .. data.status, color)
            end
        end
    },
    ["modprobe"] = {
        desc = "Load kernel module",
        action = function(args)
            if not checkRoot() then return end
            if not args[2] then
                addTerminalLine("❌ Usage: modprobe <module>", colors.red)
                return
            end
            if kernel.modules[args[2]] then
                kernel.modules[args[2]].status = "loaded"
                addTerminalLine("✅ Module " .. args[2] .. " loaded", colors.green)
            else
                addTerminalLine("❌ Module not found: " .. args[2], colors.red)
            end
        end
    },
    ["rmmod"] = {
        desc = "Remove kernel module",
        action = function(args)
            if not checkRoot() then return end
            if not args[2] then
                addTerminalLine("❌ Usage: rmmod <module>", colors.red)
                return
            end
            if kernel.modules[args[2]] then
                kernel.modules[args[2]].status = "unloaded"
                addTerminalLine("✅ Module " .. args[2] .. " removed", colors.green)
            else
                addTerminalLine("❌ Module not found: " .. args[2], colors.red)
            end
        end
    },
    ["modinfo"] = {
        desc = "Show module information",
        action = function(args)
            if not args[2] then
                addTerminalLine("❌ Usage: modinfo <module>", colors.red)
                return
            end
            local mod = kernel.modules[args[2]]
            if mod then
                addTerminalLine("📦 MODULE: " .. string.upper(args[2]), colors.green)
                addTerminalLine("  Version: " .. mod.version, colors.text)
                addTerminalLine("  Status: " .. mod.status, colors.text)
                addTerminalLine("  Path: /lib/modules/" .. kernel.version .. "/kernel/drivers/" .. args[2] .. ".ko", colors.text)
            else
                addTerminalLine("❌ Module not found", colors.red)
            end
        end
    },
     
     -- Загрузчик
    ["bootloader"] = {
        desc = "Show bootloader info",
        action = function()
            addTerminalLine("🌀 JCJ_BOOTLOADER v" .. bootloader.version, colors.green)
            addTerminalLine("  Timeout: " .. bootloader.timeout .. "s", colors.text)
            addTerminalLine("  Default: " .. bootloader.entries[bootloader.default_entry].name, colors.text)
            addTerminalLine("  Entries: " .. #bootloader.entries, colors.text)
        end
    },
    ["boot_entry"] = {
        desc = "Boot specific entry (boot_entry 1)",
        action = function(args)
            if args[2] then
                local num = tonumber(args[2])
                if num and num >= 1 and num <= #bootloader.entries then
                    bootEntry(num)
                else
                    addTerminalLine("❌ Invalid entry. Available: 1-" .. #bootloader.entries, colors.red)
                end
            else
                addTerminalLine("❌ Usage: boot_entry <number>", colors.red)
            end
        end
    },

     -- Пакетные менеджеры

     -- Развлечения
    ["fortune"] = {
        desc = "Random quote",
        action = function()
            local quotes = {
                "The best way to predict the future is to create it.",
                "Hack the planet!",
                "With great power comes great responsibility.",
                "The only way to do great work is to love what you do.",
                "Stay hungry, stay foolish.",
                "The code is strong with this one.",
                "Hello, World!",
                "This is the way.",
                "In the middle of difficulty lies opportunity.",
                "To be or not to be, that is the question."
            }
            addTerminalLine("🔮 " .. quotes[math.random(#quotes)], colors.green)
        end
    },
    ["cmatrix"] = {
        desc = "Matrix rain effect",
        action = function()
            addTerminalLine("🟢 MATRIX RAIN", colors.green)
            for i = 1, 10 do
                local line = ""
                for j = 1, 40 do
                    line = line .. (math.random() > 0.3 and string.char(math.random(65, 90)) or " ")
                end
                addTerminalLine(line, colors.green)
                task.wait(0.05)
            end
            addTerminalLine("🟢 Matrix rain stopped.", colors.green)
        end
    },
    ["cowsay"] = {
        desc = "Cow says message",
        action = function(args)
            local msg = table.concat(args, " ", 2)
            if msg == "" then msg = "Moo!" end
            addTerminalLine(" _________________ ", colors.green)
            addTerminalLine("< " .. msg .. " >", colors.green)
            addTerminalLine(" ----------------- ", colors.green)
            addTerminalLine("        \\   ^__^", colors.green)
            addTerminalLine("         \\  (oo)\\_______", colors.green)
            addTerminalLine("            (__)\\       )\\/\\", colors.green)
            addTerminalLine("                ||----w |", colors.green)
            addTerminalLine("                ||     ||", colors.green)
        end
    },
    ["sl"] = {
        desc = "Steam locomotive 🚂",
        action = function()
            addTerminalLine("  🚂 CHOO CHOO!", colors.amber)
            addTerminalLine("     ________", colors.amber)
            addTerminalLine("    /        \\", colors.amber)
            addTerminalLine("   /  ______  \\", colors.amber)
            addTerminalLine("  /  /      \\  \\", colors.amber)
            addTerminalLine("  |  |  🚂  |  |", colors.amber)
            addTerminalLine("  |  |______|  |", colors.amber)
            addTerminalLine("  |___________|", colors.amber)
        end
    },

     -- Программирование
    ["lua"] = {
        desc = "Lua interpreter",
        action = function(args)
            local code = table.concat(args, " ", 2)
            if code == "" then
                addTerminalLine("💻 Lua 5.4", colors.green)
                addTerminalLine("  Type 'lua <code>' to execute", colors.text)
                return
            end
            local okLoad, fn, compileErr = pcall(loadstring, code)
            if not okLoad then
                addTerminalLine("❌ loadstring недоступен в этом окружении", colors.red)
                return
            end
            if not fn then
                addTerminalLine("❌ " .. tostring(compileErr), colors.red)
                return
            end
            local success, result = pcall(fn)
            if success then
                addTerminalLine("  " .. tostring(result), colors.green)
            else
                addTerminalLine("❌ Error: " .. tostring(result), colors.red)
            end
        end
    },
    ["python"] = {
        desc = "Python interpreter",
        action = function(args)
            local code = table.concat(args, " ", 2)
            if code == "" then
                addTerminalLine("🐍 Python 3.11", colors.green)
                addTerminalLine("  Type 'python <code>' to execute", colors.text)
                return
            end
            addTerminalLine("  " .. code .. " -> Hello from Python!", colors.green)
        end
    },

     -- Графический интерфейс

    -- Безопасность
    ["security"] = {
        desc = "Show security status",
        action = function()
            addTerminalLine("🔒 SECURITY STATUS:", colors.green)
            addTerminalLine("  Firewall: 🟢 ACTIVE", colors.green)
            addTerminalLine("  SELinux: 🟢 ENFORCING", colors.green)
            addTerminalLine("  AppArmor: 🟢 LOADED", colors.green)
            addTerminalLine("  Security Updates: 🟢 INSTALLED", colors.green)
            addTerminalLine("  Root Access: " .. (isRoot and "🔴 ACTIVE" or "🟢 RESTRICTED"), isRoot and colors.red or colors.green)
            local sudoCount = 0
            for _, u in ipairs(users) do
                if table.find(u.groups, "sudo") then sudoCount = sudoCount + 1 end
            end
            addTerminalLine("  Sudo Users: " .. sudoCount .. " users have sudo access", colors.text)
        end
    },
}

-- ============================================================
-- ===== 11b. ОБОЛОЧКА: ПАЙПЫ, ПЕРЕНАПРАВЛЕНИЕ, СКРИПТЫ =====
-- ============================================================
local function trim(s)
    return (s:match("^%s*(.-)%s*$"))
end

-- украшения (заголовки, иконки) не попадают в пайпы и файлы
local function decor(text, color)
    if not captureBuffer then addTerminalLine(text, color) end
end

local function usage(name)
    local entry = terminalCommands[name]
    addTerminalLine("❌ Usage: " .. ((entry and entry.usage) or name), colors.red)
end

local function sortedKeys(t)
    local keys = {}
    for key in pairs(t) do keys[#keys + 1] = key end
    table.sort(keys)
    return keys
end

-- Ввод строки от пользователя (пароли, редактор, read). nil = отмена (Tab / Ctrl+C)
readLine = function(label, masked)
    if noPrompt then return nil end
    pendingPrompt = {label = label, masked = masked}
    currentInput = ""
    updateTerminalDisplay()
    local line = inputEvent.Event:Wait()
    pendingPrompt = nil
    currentInput = ""
    if line ~= nil then
        addTerminalLine(label .. (masked and string.rep("*", #line) or line), colors.text, true)
    end
    updateTerminalDisplay()
    return line
end

local function askPassword(user, label)
    for attempt = 1, 3 do
        local pw = readLine(label, true)
        if pw == nil then
            addTerminalLine("^C", colors.gray, true)
            return false
        end
        if pw == user.password then return true end
        addTerminalLine("Sorry, try again.", colors.red)
        if attempt == 2 then
            addTerminalLine("   (hint: starts with '" .. user.password:sub(1, 1) .. "', " .. #user.password .. " chars)", colors.gray, true)
        end
    end
    addTerminalLine("3 incorrect password attempts", colors.red)
    return false
end

-- Остановка: для фоновых команд флаг proc.alive, для обычных — Ctrl+C / Enter
local function stopRequested(ctx)
    if ctx and ctx.proc then return not ctx.proc.alive end
    return interruptFlag
end

local function uptimeString()
    local secs = os.time() - bootTime
    local hours = math.floor(secs / 3600)
    local mins = math.floor(secs % 3600 / 60)
    if hours > 0 then return string.format("%d h %d min", hours, mins) end
    return string.format("%d min %d s", mins, secs % 60)
end

local function getPingMs()
    local ok, value = pcall(function()
        return game:GetService("Stats").Network.ServerStatsItem["Data Ping"]:GetValue()
    end)
    return (ok and type(value) == "number") and math.floor(value) or nil
end

local function getMemoryMb()
    local ok, value = pcall(function()
        return game:GetService("Stats"):GetTotalMemoryUsageMb()
    end)
    return (ok and type(value) == "number") and math.floor(value) or nil
end

-- ---------- состояние оболочки ----------
local lastStatus = 0           -- $?
local positional = {}          -- стек аргументов $1..$9 (скрипты и функции)
local shellFunctions = {}      -- функции, объявленные в скриптах
local scriptExit = nil         -- {kind = "exit"|"return", code = N}

local function currentArgs()
    return positional[#positional] or {}
end

-- арифметика $((...)): + - * / % и скобки (без loadstring)
local function evalArith(expr)
    expr = expr:gsub("%s+", "")
    local pos = 1
    local parseExpr
    local function parsePrimary()
        local c = expr:sub(pos, pos)
        if c == "(" then
            pos = pos + 1
            local v = parseExpr()
            if expr:sub(pos, pos) == ")" then pos = pos + 1 end
            return v
        elseif c == "-" then
            pos = pos + 1
            return -parsePrimary()
        elseif c == "+" then
            pos = pos + 1
            return parsePrimary()
        end
        local num = expr:match("^%d+%.?%d*", pos)
        if num then
            pos = pos + #num
            return tonumber(num)
        end
        local name = expr:match("^[%a_][%w_]*", pos)
        if name then
            pos = pos + #name
            return tonumber(env[name] or "0") or 0
        end
        error("arithmetic syntax error")
    end
    local function parseTerm()
        local v = parsePrimary()
        while true do
            local op = expr:sub(pos, pos)
            if op == "*" then
                pos = pos + 1
                v = v * parsePrimary()
            elseif op == "/" then
                pos = pos + 1
                local d = parsePrimary()
                if d == 0 then error("division by 0") end
                v = math.floor(v / d)
            elseif op == "%" then
                pos = pos + 1
                local d = parsePrimary()
                if d == 0 then error("division by 0") end
                v = v % d
            else
                return v
            end
        end
    end
    parseExpr = function()
        local v = parseTerm()
        while true do
            local op = expr:sub(pos, pos)
            if op == "+" then
                pos = pos + 1
                v = v + parseTerm()
            elseif op == "-" then
                pos = pos + 1
                v = v - parseTerm()
            else
                return v
            end
        end
    end
    return parseExpr()
end

local function formatNumber(v)
    if v == math.floor(v) then return tostring(math.floor(v)) end
    return string.format("%.4g", v)
end

-- делит строку по символу sep вне кавычек и вне скобок (чтобы не ломать $(...))
local function splitUnquoted(line, sep)
    local parts, cur, quote, depth = {}, "", nil, 0
    for i = 1, #line do
        local c = line:sub(i, i)
        if quote then
            cur = cur .. c
            if c == quote then quote = nil end
        elseif c == '"' or c == "'" then
            quote = c
            cur = cur .. c
        elseif c == "(" then
            depth = depth + 1
            cur = cur .. c
        elseif c == ")" then
            depth = math.max(0, depth - 1)
            cur = cur .. c
        elseif c == sep and depth == 0 then
            table.insert(parts, cur)
            cur = ""
        else
            cur = cur .. c
        end
    end
    table.insert(parts, cur)
    return parts
end

-- ---------- помощники файловой системы ----------
local function splitParent(path)
    local resolved = resolvePath(path)
    if resolved == "/" then return nil, nil, resolved end
    local parentPath, name = resolved:match("^(.*)/([^/]+)$")
    if parentPath == "" then parentPath = "/" end
    return (getPathObject(parentPath)), name, resolved
end

local function newNode(kind, content)
    if kind == "dir" then
        return {type = "dir", children = {}, owner = currentUser.name, mode = "755"}
    end
    return {type = "file", content = content or "", owner = currentUser.name, mode = "644"}
end

local function contentLines(node)
    local lines = {}
    local content = node.content or ""
    if content == "" then return lines end
    for line in (content .. "\n"):gmatch("(.-)\n") do lines[#lines + 1] = line end
    return lines
end

-- размер узла для ls -l, du, stat (архивы и .gz считаются сжатыми)
local function nodeSize(node)
    if node.type == "dir" then return 4096 end
    if node.archive then
        local count = 0
        for _ in pairs(node.archive) do count = count + 1 end
        return 10240 + count * 512
    end
    local size = #(node.content or "")
    if node.gz then size = math.max(20, math.floor(size * 0.45) + 18) end
    return size
end

local function writeFile(path, text, append)
    if resolvePath(path) == "/dev/null" then return true end
    local parent, name = splitParent(path)
    if not parent or parent.type ~= "dir" or not name then return false, "No such file or directory" end
    local node = parent.children[name]
    if node then
        if node.type == "dir" then return false, "Is a directory" end
        if not hasPerm(node, "w") then return false, "Permission denied" end
        if append and (node.content or "") ~= "" then
            node.content = node.content .. "\n" .. text
        else
            node.content = text
        end
    else
        if not hasPerm(parent, "w") then return false, "Permission denied" end
        parent.children[name] = newNode("file", text)
    end
    return true
end

local function openReadable(path, cmdName)
    local node, why = getPathObject(path)
    if why == "denied" then
        addTerminalLine(cmdName .. ": " .. path .. ": Permission denied", colors.red)
        return nil
    end
    if not node then
        addTerminalLine(cmdName .. ": " .. path .. ": No such file or directory", colors.red)
        return nil
    end
    if not hasPerm(node, "r") then
        addTerminalLine(cmdName .. ": " .. path .. ": Permission denied", colors.red)
        return nil
    end
    return node
end

local function inputLines(cmdName, filePath)
    if filePath then
        local node = openReadable(filePath, cmdName)
        if not node then return nil end
        if node.type ~= "file" then
            addTerminalLine(cmdName .. ": " .. filePath .. ": Is a directory", colors.red)
            return nil
        end
        return contentLines(node)
    end
    return stdinLines
end

local function permString(node)
    local function triple(d)
        d = tonumber(d) or 0
        return (math.floor(d / 4) % 2 == 1 and "r" or "-")
            .. (math.floor(d / 2) % 2 == 1 and "w" or "-")
            .. (d % 2 == 1 and "x" or "-")
    end
    local mode = nodeMode(node)
    return (node.type == "dir" and "d" or "-") .. triple(mode:sub(1, 1)) .. triple(mode:sub(2, 2)) .. triple(mode:sub(3, 3))
end

local function ensureHome(user)
    local homeDir = getPathObject("/home")
    if homeDir and homeDir.type == "dir" and not homeDir.children[user.name] then
        homeDir.children[user.name] = {type = "dir", children = {}, owner = user.name, mode = "755"}
    end
end

-- создаёт цепочку папок от имени системы (без проверки прав); возвращает последнюю
local function ensureDirPath(path, mode)
    local node = fileSystem["/"]
    for part in resolvePath(path):gmatch("[^/]+") do
        local child = node.children[part]
        if not child then
            child = {type = "dir", children = {}, owner = "root", mode = mode or "755"}
            node.children[part] = child
        end
        node = child
    end
    return node
end

-- ---------- системный журнал (journalctl, /var/log) ----------
local journal = {}

local function appendLog(path, line)
    local dirPath, name = path:match("^(.*)/([^/]+)$")
    local dir = ensureDirPath(dirPath == "" and "/" or dirPath)
    local node = dir.children[name]
    if not node then
        node = {type = "file", owner = "root", mode = "640", content = ""}
        dir.children[name] = node
    end
    node.content = (node.content == "" and "" or (node.content .. "\n")) .. line
    if #node.content > 12000 then node.content = node.content:sub(-9000) end
end

local function syslog(unit, msg, auth)
    local stamp = os.date("%b %d %H:%M:%S")
    table.insert(journal, {time = stamp, unit = unit, msg = msg, host = currentHost})
    if #journal > 300 then table.remove(journal, 1) end
    local entry = stamp .. " " .. currentHost .. " " .. unit .. ": " .. msg
    appendLog("/var/log/syslog", entry)
    if auth then appendLog("/var/log/auth.log", entry) end
end

-- наружу выходят только эти функции; остальные помощники оболочки спрятаны в do-блок (лимит 200 локальных в Luau)
local runScript, runScriptText, popSsh

do
local function lookupVar(name)
    local dyn = {
        USER = currentUser.name, HOME = homeOf(currentUser), PWD = currentPath,
        HOSTNAME = currentHost, SHELL = currentUser.shell, UID = tostring(currentUser.uid),
    }
    return dyn[name] or env[name] or ""
end

-- позиция ")" для "(" на openPos (с учётом вложенности)
local function findClosing(text, openPos)
    local depth = 0
    for i = openPos, #text do
        local c = text:sub(i, i)
        if c == "(" then
            depth = depth + 1
        elseif c == ")" then
            depth = depth - 1
            if depth == 0 then return i end
        end
    end
    return nil
end

-- $(команда): выполняем с перехватом вывода
local function runSubstitution(cmd)
    local saved = captureBuffer
    captureBuffer = {}
    pcall(executeLine, cmd, 1)
    local out = captureBuffer
    captureBuffer = saved
    return trim(table.concat(out, " "))
end

-- $VAR, ${VAR}, $?, $#, $@, $0-$9, $((expr)), $(cmd); в одинарных кавычках не раскрывается
local function expandVars(text)
    local result = {}
    local i, n = 1, #text
    local inSingle, inDouble = false, false
    while i <= n do
        local c = text:sub(i, i)
        if c == "'" and not inDouble then
            inSingle = not inSingle
            result[#result + 1] = c
            i = i + 1
        elseif c == '"' and not inSingle then
            inDouble = not inDouble
            result[#result + 1] = c
            i = i + 1
        elseif c ~= "$" or inSingle then
            result[#result + 1] = c
            i = i + 1
        else
            local nextTwo = text:sub(i + 1, i + 2)
            local nextOne = text:sub(i + 1, i + 1)
            if nextTwo == "((" then
                local close = findClosing(text, i + 1)
                if close then
                    local ok, v = pcall(evalArith, text:sub(i + 2, close - 1))
                    result[#result + 1] = ok and formatNumber(v) or "0"
                    i = close + 1
                else
                    result[#result + 1] = c
                    i = i + 1
                end
            elseif nextOne == "(" then
                local close = findClosing(text, i + 1)
                if close then
                    result[#result + 1] = runSubstitution(text:sub(i + 2, close - 1))
                    i = close + 1
                else
                    result[#result + 1] = c
                    i = i + 1
                end
            elseif nextOne == "{" then
                local close = text:find("}", i + 2, true)
                if close then
                    result[#result + 1] = lookupVar(text:sub(i + 2, close - 1))
                    i = close + 1
                else
                    result[#result + 1] = c
                    i = i + 1
                end
            elseif nextOne == "?" then
                result[#result + 1] = tostring(lastStatus)
                i = i + 2
            elseif nextOne == "#" then
                result[#result + 1] = tostring(#currentArgs())
                i = i + 2
            elseif nextOne == "@" or nextOne == "*" then
                result[#result + 1] = table.concat(currentArgs(), " ")
                i = i + 2
            elseif nextOne:match("%d") then
                local idx = tonumber(nextOne)
                result[#result + 1] = idx == 0 and "bash" or (currentArgs()[idx] or "")
                i = i + 2
            else
                local name = text:match("^[%a_][%w_]*", i + 1)
                if name then
                    result[#result + 1] = lookupVar(name)
                    i = i + 1 + #name
                else
                    result[#result + 1] = c
                    i = i + 1
                end
            end
        end
    end
    return table.concat(result)
end

-- ---------- разбор строки ----------
-- возвращает токены и флаги "содержит неэкранированный * или ?"
local function tokenize(line)
    local tokens, globs = {}, {}
    local i, n = 1, #line
    while i <= n do
        if line:sub(i, i):match("%s") then
            i = i + 1
        else
            local tok, quote, glob = "", nil, false
            while i <= n do
                local c = line:sub(i, i)
                if quote then
                    if c == quote then quote = nil else tok = tok .. c end
                elseif c == '"' or c == "'" then
                    quote = c
                elseif c:match("%s") then
                    break
                else
                    if c == "*" or c == "?" then glob = true end
                    tok = tok .. c
                end
                i = i + 1
            end
            table.insert(tokens, tok)
            table.insert(globs, glob)
        end
    end
    return tokens, globs
end

local function globToPattern(glob)
    local escaped = glob:gsub("[%^%$%(%)%%%.%[%]%+%-]", "%%%0")
    escaped = escaped:gsub("%*", ".*")
    escaped = escaped:gsub("%?", ".")
    return "^" .. escaped .. "$"
end

-- подстановка *.txt, f?.sh и т.д. в аргументах (первый токен — имя команды)
local function expandGlobs(tokens, globs)
    local out = {tokens[1]}
    for i = 2, #tokens do
        if globs[i] then
            local dirPart, namePart = tokens[i]:match("^(.*/)([^/]*)$")
            if not dirPart then dirPart, namePart = "", tokens[i] end
            local dirNode = getPathObject(dirPart == "" and "." or dirPart)
            local matches = {}
            if dirNode and dirNode.type == "dir" and hasPerm(dirNode, "r") then
                local pattern = globToPattern(namePart)
                for _, name in ipairs(sortedKeys(dirNode.children)) do
                    if (namePart:sub(1, 1) == "." or name:sub(1, 1) ~= ".") and name:match(pattern) then
                        matches[#matches + 1] = dirPart .. name
                    end
                end
            end
            if #matches == 0 then
                out[#out + 1] = tokens[i]
            else
                for _, m in ipairs(matches) do out[#out + 1] = m end
            end
        else
            out[#out + 1] = tokens[i]
        end
    end
    return out
end

local function expandWords(text)
    local tokens, globs = tokenize(expandVars(text))
    table.insert(tokens, 1, "for")
    table.insert(globs, 1, false)
    local expanded = expandGlobs(tokens, globs)
    table.remove(expanded, 1)
    return expanded
end

-- делит по && и || вне кавычек/скобок: {text=, op=} где op — оператор ПЕРЕД фрагментом
local function splitLogical(line)
    local parts, cur, quote, op, depth = {}, "", nil, nil, 0
    local i = 1
    while i <= #line do
        local c = line:sub(i, i)
        local two = line:sub(i, i + 1)
        if quote then
            cur = cur .. c
            if c == quote then quote = nil end
            i = i + 1
        elseif c == '"' or c == "'" then
            quote = c
            cur = cur .. c
            i = i + 1
        elseif c == "(" then
            depth = depth + 1
            cur = cur .. c
            i = i + 1
        elseif c == ")" then
            depth = math.max(0, depth - 1)
            cur = cur .. c
            i = i + 1
        elseif depth == 0 and (two == "&&" or two == "||") then
            table.insert(parts, {text = cur, op = op})
            cur, op = "", two
            i = i + 2
        else
            cur = cur .. c
            i = i + 1
        end
    end
    table.insert(parts, {text = cur, op = op})
    return parts
end

-- ищет > или >> вне кавычек; возвращает команду, режим и файл
local function splitRedirect(seg)
    local quote = nil
    for i = 1, #seg do
        local c = seg:sub(i, i)
        if quote then
            if c == quote then quote = nil end
        elseif c == '"' or c == "'" then
            quote = c
        elseif c == ">" then
            local mode, nextPos = ">", i + 1
            if seg:sub(i + 1, i + 1) == ">" then
                mode, nextPos = ">>", i + 2
            end
            return seg:sub(1, i - 1), mode, trim(seg:sub(nextPos)):match("^(%S+)")
        end
    end
    return seg, nil, nil
end

-- делит по одиночному & (фон) вне кавычек/скобок: {text=, bg=}; && не трогаем
local function splitAmpersand(line)
    local jobs, cur, quote, depth = {}, "", nil, 0
    local i = 1
    while i <= #line do
        local c = line:sub(i, i)
        local nextC = line:sub(i + 1, i + 1)
        if quote then
            cur = cur .. c
            if c == quote then quote = nil end
        elseif c == '"' or c == "'" then
            quote = c
            cur = cur .. c
        elseif c == "(" then
            depth = depth + 1
            cur = cur .. c
        elseif c == ")" then
            depth = math.max(0, depth - 1)
            cur = cur .. c
        elseif c == "&" and nextC == "&" then
            cur = cur .. "&&"
            i = i + 1
        elseif c == "&" and depth == 0 then
            jobs[#jobs + 1] = {text = trim(cur), bg = true}
            cur = ""
        else
            cur = cur .. c
        end
        i = i + 1
    end
    if trim(cur) ~= "" then jobs[#jobs + 1] = {text = trim(cur), bg = false} end
    return jobs
end

-- ---------- интерпретатор скриптов (if / for / while / функции) ----------
-- превращает строки в список простых утверждений (then/do/else — отдельными)
local function toStatements(lines)
    local stmts = {}
    local function push(s)
        s = trim(s)
        if s ~= "" then stmts[#stmts + 1] = s end
    end
    for _, raw in ipairs(lines) do
        local line = trim(raw)
        if line ~= "" and line:sub(1, 1) ~= "#" then
            for _, part in ipairs(splitUnquoted(line, ";")) do
                local s = trim(part)
                while true do
                    local kw, rest = s:match("^(%a+)%s+(.*)$")
                    if kw == "then" or kw == "do" or kw == "else" then
                        push(kw)
                        s = trim(rest)
                    else
                        break
                    end
                end
                -- однострочная функция:  name() { cmd; }
                local fname, body = s:match("^([%w_]+)%(%)%s*{%s*(.*)$")
                if fname then
                    push(fname .. "() {")
                    s = trim(body)
                end
                push(s)
            end
        end
    end
    return stmts
end

local parseBlock
parseBlock = function(stmts, i, stops)
    local nodes = {}
    while i <= #stmts do
        local s = stmts[i]
        local first = s:match("^(%S+)")
        if stops[first] then return nodes, i end

        if first == "if" then
            local node = {type = "if", branches = {}}
            local cond = trim(s:sub(3))
            i = i + 1
            if stmts[i] ~= "then" then error("syntax error: expected 'then' after if") end
            i = i + 1
            local body
            body, i = parseBlock(stmts, i, {elif = true, ["else"] = true, fi = true})
            table.insert(node.branches, {cond = cond, body = body})
            while true do
                local kw = stmts[i] and stmts[i]:match("^(%S+)")
                if kw == "elif" then
                    local cond2 = trim(stmts[i]:sub(5))
                    i = i + 1
                    if stmts[i] ~= "then" then error("syntax error: expected 'then' after elif") end
                    i = i + 1
                    local body2
                    body2, i = parseBlock(stmts, i, {elif = true, ["else"] = true, fi = true})
                    table.insert(node.branches, {cond = cond2, body = body2})
                elseif kw == "else" then
                    i = i + 1
                    node.elseBody, i = parseBlock(stmts, i, {fi = true})
                elseif kw == "fi" then
                    i = i + 1
                    break
                else
                    error("syntax error: missing 'fi'")
                end
            end
            nodes[#nodes + 1] = node

        elseif first == "for" then
            local var, words = s:match("^for%s+([%w_]+)%s+in%s*(.*)$")
            if not var then error("syntax error in for: " .. s) end
            i = i + 1
            if stmts[i] ~= "do" then error("syntax error: expected 'do' after for") end
            i = i + 1
            local body
            body, i = parseBlock(stmts, i, {done = true})
            if stmts[i] ~= "done" then error("syntax error: missing 'done'") end
            i = i + 1
            nodes[#nodes + 1] = {type = "for", var = var, words = words, body = body}

        elseif first == "while" then
            local cond = trim(s:sub(6))
            i = i + 1
            if stmts[i] ~= "do" then error("syntax error: expected 'do' after while") end
            i = i + 1
            local body
            body, i = parseBlock(stmts, i, {done = true})
            if stmts[i] ~= "done" then error("syntax error: missing 'done'") end
            i = i + 1
            nodes[#nodes + 1] = {type = "while", cond = cond, body = body}

        elseif s:match("^[%w_]+%(%)%s*{$") then
            local fname = s:match("^([%w_]+)%(%)")
            i = i + 1
            local body
            body, i = parseBlock(stmts, i, {["}"] = true})
            if stmts[i] ~= "}" then error("syntax error: missing '}'") end
            i = i + 1
            nodes[#nodes + 1] = {type = "func", name = fname, body = body}

        else
            nodes[#nodes + 1] = {type = "cmd", text = s}
            i = i + 1
        end
    end
    return nodes, i
end

local execNodes
execNodes = function(nodes, depth)
    for _, node in ipairs(nodes) do
        if interruptFlag or scriptExit ~= nil then return end
        if node.type == "cmd" then
            executeLine(node.text, depth)
        elseif node.type == "if" then
            local handled = false
            for _, branch in ipairs(node.branches) do
                executeLine(branch.cond, depth)
                if lastStatus == 0 then
                    execNodes(branch.body, depth)
                    handled = true
                    break
                end
            end
            if not handled and node.elseBody then execNodes(node.elseBody, depth) end
        elseif node.type == "while" then
            local guard = 0
            while guard < 1000 and not interruptFlag and scriptExit == nil do
                executeLine(node.cond, depth)
                if lastStatus ~= 0 then break end
                execNodes(node.body, depth)
                guard = guard + 1
                task.wait()
            end
        elseif node.type == "for" then
            for _, word in ipairs(expandWords(node.words)) do
                if interruptFlag or scriptExit ~= nil then break end
                env[node.var] = word
                execNodes(node.body, depth)
            end
        elseif node.type == "func" then
            shellFunctions[node.name] = node.body
        end
    end
end

local function callFunction(name, args, depth)
    table.insert(positional, args)
    execNodes(shellFunctions[name], depth)
    table.remove(positional)
    if scriptExit and scriptExit.kind == "return" then
        lastStatus = scriptExit.code
        scriptExit = nil
    end
end

runScriptText = function(text, depth, args)
    local lines = {}
    for line in (text .. "\n"):gmatch("(.-)\n") do lines[#lines + 1] = line end
    local base = #positional
    local ok, err = pcall(function()
        local nodes = parseBlock(toStatements(lines), 1, {})
        table.insert(positional, args or {})
        execNodes(nodes, depth + 1)
    end)
    while #positional > base do table.remove(positional) end
    if not ok then
        addTerminalLine("bash: " .. tostring(err), colors.red)
        lastStatus = 2
    end
    if scriptExit and scriptExit.kind == "exit" then
        lastStatus = scriptExit.code
        scriptExit = nil
    end
end

runScript = function(path, depth, args)
    local node = getPathObject(path)
    if not node or node.type ~= "file" then
        addTerminalLine("bash: " .. path .. ": No such file or directory", colors.red)
        return
    end
    if not hasPerm(node, "r") then
        addTerminalLine("bash: " .. path .. ": Permission denied", colors.red)
        return
    end
    runScriptText(node.content or "", depth or 0, args)
end

-- ---------- выполнение ----------
local function runStage(seg, input, ctx)
    local tokens, globs = tokenize(expandVars(seg))
    if #tokens == 0 then return end

    -- присваивание переменной: FOO=bar
    local varName, varValue = tokens[1]:match("^([%a_][%w_]*)=(.*)$")
    if varName then
        env[varName] = varValue
        lastStatus = 0
        return
    end

    -- алиасы
    if aliases[tokens[1]] then
        local expanded = tokenize(aliases[tokens[1]])
        table.remove(tokens, 1)
        table.remove(globs, 1)
        for i = #expanded, 1, -1 do
            table.insert(tokens, 1, expanded[i])
            table.insert(globs, 1, false)
        end
    end
    tokens = expandGlobs(tokens, globs)

    local name = tokens[1]
    local depth = ctx and ctx.depth or 0
    local callArgs = {}
    for i = 2, #tokens do callArgs[#callArgs + 1] = tokens[i] end

    -- функция оболочки
    if shellFunctions[name] then
        callFunction(name, callArgs, depth)
        return
    end

    -- запуск скрипта по пути: ./hack.sh или /tmp/x.sh
    if name:sub(1, 2) == "./" or name:sub(1, 1) == "/" then
        local node = getPathObject(name)
        if not node then
            addTerminalLine("bash: " .. name .. ": No such file or directory", colors.red)
            lastStatus = 127
        elseif node.type ~= "file" then
            addTerminalLine("bash: " .. name .. ": Is a directory", colors.red)
            lastStatus = 126
        elseif not hasPerm(node, "x") then
            addTerminalLine("bash: " .. name .. ": Permission denied (chmod +x?)", colors.red)
            lastStatus = 126
        else
            runScript(name, depth, callArgs)
        end
        return
    end

    local entry = terminalCommands[name:lower()]
    if not entry then
        addTerminalLine("❌ Command not found: " .. name, colors.red)
        lastStatus = 127
        return
    end
    tokens[1] = name:lower()

    local savedInput = stdinLines
    stdinLines = input
    errorSeen = false
    local ok, ret = pcall(entry.action, tokens, ctx)
    stdinLines = savedInput
    if not ok then
        addTerminalLine("❌ Error: " .. tostring(ret), colors.red)
        lastStatus = 1
    elseif type(ret) == "number" then
        lastStatus = ret
    else
        lastStatus = errorSeen and 1 or 0
    end
end

local function runPipeline(statement, ctx)
    local segments = splitUnquoted(statement, "|")
    local input = nil
    local outer = captureBuffer   -- перехват внешнего $(...) должен пережить внутренние пайпы
    for idx, seg in ipairs(segments) do
        local isLast = idx == #segments
        local cmdText, mode, target = seg, nil, nil
        if isLast then cmdText, mode, target = splitRedirect(seg) end
        if mode and not target then
            addTerminalLine("bash: syntax error near unexpected token `newline'", colors.red)
            lastStatus = 2
            return
        end
        local capture = (not isLast) or (mode ~= nil)
        if capture then captureBuffer = {} end
        runStage(cmdText, input, ctx)
        if capture then
            local buffer = captureBuffer
            captureBuffer = outer
            if not isLast then
                input = buffer
            else
                local ok, why = writeFile(target, table.concat(buffer, "\n"), mode == ">>")
                if not ok then
                    addTerminalLine("bash: " .. target .. ": " .. why, colors.red)
                    lastStatus = 1
                end
            end
        end
    end
end

-- цепочка a && b || c: выполняется слева направо по коду возврата
local function runChain(statement, ctx)
    for _, part in ipairs(splitLogical(statement)) do
        local run = true
        if part.op == "&&" then run = lastStatus == 0 end
        if part.op == "||" then run = lastStatus ~= 0 end
        if run then runPipeline(trim(part.text), ctx) end
    end
end

executeLine = function(line, depth)
    depth = depth or 0
    if depth > 8 then
        addTerminalLine("❌ Nesting too deep", colors.red)
        return
    end
    if depth == 0 then
        scrollOffset = 0
        interruptFlag = false
        scriptExit = nil
        if autoBootActive then
            bootToken = bootToken + 1
            autoBootActive = false
            addTerminalLine("⏹ Auto-boot cancelled", colors.amber)
        end
    end
    -- составные конструкции (if / for / while / функции) разбирает интерпретатор скриптов
    local needsParser = line:match("^%s*[%w_]+%(%)%s*{") ~= nil
    for _, part in ipairs(splitUnquoted(line, ";")) do
        local kw = trim(part):match("^(%a+)")
        if kw == "if" or kw == "for" or kw == "while" then needsParser = true end
    end
    if needsParser then
        runScriptText(line, depth, currentArgs())
        return
    end
    for _, statement in ipairs(splitUnquoted(line, ";")) do
        if interruptFlag or scriptExit ~= nil then break end
        statement = trim(statement)
        if statement ~= "" then
            for _, job in ipairs(splitAmpersand(statement)) do
                if interruptFlag or scriptExit ~= nil then break end
                if job.text ~= "" and job.bg then
                    -- фоновый процесс: виден в ps, убивается через kill
                    local jobText = job.text
                    local pid, proc = createProcess(jobText)
                    addTerminalLine("[" .. pid .. "] started: " .. jobText, colors.gray)
                    task.spawn(function()
                        runChain(jobText, {proc = proc, depth = depth})
                        if proc.alive then
                            proc.alive = false
                            for i, p in ipairs(kernel.processes) do
                                if p == proc then
                                    table.remove(kernel.processes, i)
                                    break
                                end
                            end
                            addTerminalLine("[" .. pid .. "] Done: " .. jobText, colors.gray)
                        end
                    end)
                elseif job.text ~= "" then
                    runChain(job.text, {depth = depth})
                end
            end
        end
    end
end

popSsh = function()
    local ctx = table.remove(sshStack)
    if not ctx then return end
    fileSystem, users, currentUser, isRoot, currentPath, currentHost =
        ctx.fs, ctx.users, ctx.user, ctx.root, ctx.path, ctx.host
end

end

-- ---------- службы (systemctl) и системные процессы ----------
local services = {
    NetworkManager = {desc = "Network Manager", enabled = true},
    sshd = {desc = "OpenBSD Secure Shell server", enabled = true},
    cron = {desc = "Regular background program processing daemon", enabled = true},
}

local function findProcess(name)
    for i, proc in ipairs(kernel.processes) do
        if proc.name == name then return proc, i end
    end
    return nil
end

local function createSystemProcesses()
    for _, name in ipairs({"init", "systemd-journald", "dbus-daemon", "jcj_kernel"}) do
        createProcess(name, nil, true)
    end
    for _, name in ipairs(sortedKeys(services)) do
        if services[name].enabled then createProcess(name, nil, true) end
    end
end

-- ============================================================
-- ===== 11c. ФАЙЛЫ И ТЕКСТОВЫЕ УТИЛИТЫ =====
-- ============================================================
local deepCopy, editFile

do
terminalCommands["help"] = {
    desc = "Show commands (help <command> for details)",
    usage = "help [command]",
    action = function(args)
        if args[2] then
            local entry = terminalCommands[args[2]:lower()]
            if not entry then
                addTerminalLine("❌ No help for: " .. args[2], colors.red)
                return
            end
            addTerminalLine(args[2]:lower() .. " — " .. (entry.desc or ""), colors.green)
            if entry.usage then addTerminalLine("   usage: " .. entry.usage, colors.text) end
            return
        end
        addTerminalLine("📖 Commands (help <cmd> / man <cmd> for details):", colors.green)
        local line, count = "", 0
        for _, name in ipairs(sortedKeys(terminalCommands)) do
            line = line .. string.format("%-13s", name)
            count = count + 1
            if count % 5 == 0 then
                addTerminalLine("  " .. line, colors.text)
                line = ""
            end
        end
        if line ~= "" then addTerminalLine("  " .. line, colors.text) end
        addTerminalLine("Tab=autocomplete  ↑/↓=history  PgUp/PgDn=scroll  Ctrl+C=interrupt  cmd1 | cmd2  > file  cmd &", colors.gray)
    end,
}

terminalCommands["man"] = {
    desc = "Manual page for a command",
    usage = "man <command>",
    action = function(args)
        local name = args[2] and args[2]:lower()
        local entry = name and terminalCommands[name]
        if not name then usage("man") return end
        if not entry then
            addTerminalLine("No manual entry for " .. name, colors.red)
            return
        end
        addTerminalLine("NAME", colors.green)
        addTerminalLine("    " .. name .. " - " .. (entry.desc or "no description"), colors.text)
        addTerminalLine("SYNOPSIS", colors.green)
        addTerminalLine("    " .. (entry.usage or name), colors.text)
    end,
}

terminalCommands["pwd"] = {
    desc = "Print working directory",
    action = function()
        addTerminalLine((captureBuffer and "" or "📁 ") .. getFullPath(), colors.green)
    end,
}

terminalCommands["cd"] = {
    desc = "Change directory",
    usage = "cd [path]",
    action = function(args)
        local node, why = getPathObject(args[2] or "~")
        if why == "denied" or (node and node.type == "dir" and not hasPerm(node, "x")) then
            addTerminalLine("cd: " .. (args[2] or "~") .. ": Permission denied", colors.red)
        elseif node and node.type == "dir" then
            currentPath = resolvePath(args[2] or "~")
        elseif node then
            addTerminalLine("cd: " .. args[2] .. ": Not a directory", colors.red)
        else
            addTerminalLine("cd: " .. (args[2] or "~") .. ": No such file or directory", colors.red)
        end
    end,
}

terminalCommands["ls"] = {
    desc = "List directory contents",
    usage = "ls [-l] [-a] [path]",
    action = function(args)
        local showAll, long, path = false, false, nil
        for i = 2, #args do
            local a = args[i]
            if a:sub(1, 1) == "-" and #a > 1 then
                if a:find("a") then showAll = true end
                if a:find("l") then long = true end
            else
                path = a
            end
        end
        local resolved = resolvePath(path or ".")
        local target, why = getPathObject(resolved)
        if why == "denied" or (target and not hasPerm(target, "r")) then
            addTerminalLine("ls: cannot open '" .. resolved .. "': Permission denied", colors.red)
            return
        end
        if not target then
            addTerminalLine("ls: cannot access '" .. resolved .. "': No such file or directory", colors.red)
            return
        end
        if target.type ~= "dir" then
            addTerminalLine(path or resolved, colors.text)
            return
        end
        decor("📋 " .. resolved .. ":", colors.green)
        local count = 0
        for _, name in ipairs(sortedKeys(target.children)) do
            if showAll or name:sub(1, 1) ~= "." then
                local child = target.children[name]
                local isDir = child.type == "dir"
                local line
                if long then
                    local size = nodeSize(child)
                    line = string.format("%s %-10s %6d %s", permString(child), nodeOwner(child), size, name .. (isDir and "/" or ""))
                elseif captureBuffer then
                    line = name
                else
                    line = "  " .. (isDir and "📁 " or "📄 ") .. name
                end
                addTerminalLine(line, isDir and colors.cyan or colors.text)
                count = count + 1
            end
        end
        if count == 0 then decor("  (empty)", colors.gray) end
    end,
}

terminalCommands["tree"] = {
    desc = "Show directory tree",
    usage = "tree [path]",
    action = function(args)
        local path = resolvePath(args[2] or ".")
        local root = getPathObject(path)
        if not root or root.type ~= "dir" then
            addTerminalLine("tree: " .. path .. ": No such directory", colors.red)
            return
        end
        if not hasPerm(root, "r") then
            addTerminalLine("tree: " .. path .. ": Permission denied", colors.red)
            return
        end
        addTerminalLine(path, colors.cyan)
        local dirs, files = 0, 0
        local function walk(node, prefix, depth)
            local names = sortedKeys(node.children)
            for i, name in ipairs(names) do
                local child = node.children[name]
                local last = i == #names
                local isDir = child.type == "dir"
                addTerminalLine(prefix .. (last and "└── " or "├── ") .. name .. (isDir and "/" or ""), isDir and colors.cyan or colors.text)
                if isDir then
                    dirs = dirs + 1
                    if depth < 6 and hasPerm(child, "r") then
                        walk(child, prefix .. (last and "    " or "│   "), depth + 1)
                    end
                else
                    files = files + 1
                end
            end
        end
        walk(root, "", 1)
        addTerminalLine(dirs .. " directories, " .. files .. " files", colors.gray)
    end,
}

terminalCommands["mkdir"] = {
    desc = "Create directories",
    usage = "mkdir [-p] <dir>...",
    action = function(args)
        local parents, targets = false, {}
        for i = 2, #args do
            if args[i] == "-p" then parents = true else targets[#targets + 1] = args[i] end
        end
        if #targets == 0 then usage("mkdir") return end
        for _, target in ipairs(targets) do
            if parents then
                local node = fileSystem["/"]
                local failed = false
                for part in resolvePath(target):gmatch("[^/]+") do
                    local child = node.children and node.children[part]
                    if not child then
                        if not hasPerm(node, "w") then
                            addTerminalLine("mkdir: cannot create directory '" .. target .. "': Permission denied", colors.red)
                            failed = true
                        else
                            child = newNode("dir")
                            node.children[part] = child
                        end
                    elseif child.type ~= "dir" then
                        addTerminalLine("mkdir: '" .. target .. "': Not a directory", colors.red)
                        failed = true
                    end
                    if failed then break end
                    node = child
                end
            else
                local parent, name = splitParent(target)
                if not parent or parent.type ~= "dir" or not name then
                    addTerminalLine("mkdir: cannot create directory '" .. target .. "': No such file or directory", colors.red)
                elseif parent.children[name] then
                    addTerminalLine("mkdir: cannot create directory '" .. target .. "': File exists", colors.red)
                elseif not hasPerm(parent, "w") then
                    addTerminalLine("mkdir: cannot create directory '" .. target .. "': Permission denied", colors.red)
                else
                    parent.children[name] = newNode("dir")
                    decor("📁 Created: " .. target, colors.green)
                end
            end
        end
    end,
}

terminalCommands["touch"] = {
    desc = "Create empty files",
    usage = "touch <file>...",
    action = function(args)
        if not args[2] then usage("touch") return end
        for i = 2, #args do
            local parent, name = splitParent(args[i])
            if not parent or parent.type ~= "dir" or not name then
                addTerminalLine("touch: cannot touch '" .. args[i] .. "': No such file or directory", colors.red)
            elseif not parent.children[name] then
                if hasPerm(parent, "w") then
                    parent.children[name] = newNode("file")
                    decor("📄 Created: " .. args[i], colors.green)
                else
                    addTerminalLine("touch: cannot touch '" .. args[i] .. "': Permission denied", colors.red)
                end
            end
        end
    end,
}

terminalCommands["rm"] = {
    desc = "Remove files or directories",
    usage = "rm [-r] <path>...",
    action = function(args)
        local recursive, targets = false, {}
        for i = 2, #args do
            local a = args[i]
            if a:sub(1, 1) == "-" and #a > 1 then
                if a:find("r") or a:find("R") then recursive = true end
            else
                targets[#targets + 1] = a
            end
        end
        if #targets == 0 then usage("rm") return end
        for _, target in ipairs(targets) do
            local parent, name, resolved = splitParent(target)
            if resolved == "/" then
                addTerminalLine("rm: it is dangerous to operate recursively on '/'", colors.red)
            elseif not parent or not parent.children or not parent.children[name] then
                addTerminalLine("rm: cannot remove '" .. target .. "': No such file or directory", colors.red)
            else
                local node = parent.children[name]
                if node.type == "dir" and not recursive then
                    addTerminalLine("rm: cannot remove '" .. target .. "': Is a directory (use rm -r)", colors.red)
                elseif not hasPerm(parent, "w") then
                    addTerminalLine("rm: cannot remove '" .. target .. "': Permission denied", colors.red)
                else
                    parent.children[name] = nil
                    -- если удалили текущую папку (или её родителя), поднимаемся выше
                    if currentPath == resolved or currentPath:sub(1, #resolved + 1) == resolved .. "/" then
                        currentPath = resolved:match("^(.*)/[^/]+$") or "/"
                        if currentPath == "" then currentPath = "/" end
                    end
                    decor("🗑️ Removed: " .. target, colors.green)
                end
            end
        end
    end,
}

terminalCommands["rmdir"] = {
    desc = "Remove empty directories",
    usage = "rmdir <dir>",
    action = function(args)
        if not args[2] then usage("rmdir") return end
        local parent, name = splitParent(args[2])
        local node = parent and parent.children and parent.children[name]
        if not node then
            addTerminalLine("rmdir: failed to remove '" .. args[2] .. "': No such file or directory", colors.red)
        elseif node.type ~= "dir" then
            addTerminalLine("rmdir: failed to remove '" .. args[2] .. "': Not a directory", colors.red)
        elseif next(node.children) ~= nil then
            addTerminalLine("rmdir: failed to remove '" .. args[2] .. "': Directory not empty", colors.red)
        elseif not hasPerm(parent, "w") then
            addTerminalLine("rmdir: failed to remove '" .. args[2] .. "': Permission denied", colors.red)
        else
            parent.children[name] = nil
            decor("🗑️ Removed directory: " .. args[2], colors.green)
        end
    end,
}

deepCopy = function(node)
    local copy = {type = node.type, owner = currentUser.name, mode = node.mode, gz = node.gz, zip = node.zip}
    if node.type == "file" then
        copy.content = node.content
        if node.archive then
            copy.archive = {}
            for name, entry in pairs(node.archive) do copy.archive[name] = deepCopy(entry) end
        end
    else
        copy.children = {}
        for name, child in pairs(node.children) do copy.children[name] = deepCopy(child) end
    end
    return copy
end

-- общая часть cp и mv: находит папку назначения и имя
local function resolveDestination(cmdName, srcResolved, dstArg)
    local dstNode = getPathObject(dstArg)
    local srcName = srcResolved:match("([^/]+)$")
    local parent, name
    if dstNode and dstNode.type == "dir" then
        parent, name = dstNode, srcName
    else
        parent, name = splitParent(dstArg)
    end
    if not parent or parent.type ~= "dir" or not name then
        addTerminalLine(cmdName .. ": cannot create '" .. dstArg .. "': No such file or directory", colors.red)
        return nil
    end
    if not hasPerm(parent, "w") then
        addTerminalLine(cmdName .. ": cannot create '" .. dstArg .. "': Permission denied", colors.red)
        return nil
    end
    return parent, name
end

terminalCommands["cp"] = {
    desc = "Copy files and directories",
    usage = "cp [-r] <source> <destination>",
    action = function(args)
        local recursive, rest = false, {}
        for i = 2, #args do
            local a = args[i]
            if a:sub(1, 1) == "-" and #a > 1 then
                if a:find("r") or a:find("R") then recursive = true end
            else
                rest[#rest + 1] = a
            end
        end
        if #rest < 2 then usage("cp") return end
        local src, dst = rest[1], rest[2]
        local node = openReadable(src, "cp")
        if not node then return end
        if node.type == "dir" and not recursive then
            addTerminalLine("cp: -r not specified; omitting directory '" .. src .. "'", colors.red)
            return
        end
        local parent, name = resolveDestination("cp", resolvePath(src), dst)
        if not parent then return end
        parent.children[name] = deepCopy(node)
        decor("📄 Copied: " .. src .. " -> " .. dst, colors.green)
    end,
}

terminalCommands["mv"] = {
    desc = "Move or rename files and directories",
    usage = "mv <source> <destination>",
    action = function(args)
        if not args[3] then usage("mv") return end
        local src, dst = args[2], args[3]
        local srcParent, srcName, srcResolved = splitParent(src)
        if not srcParent or not srcParent.children or not srcParent.children[srcName] then
            addTerminalLine("mv: cannot stat '" .. src .. "': No such file or directory", colors.red)
            return
        end
        if not hasPerm(srcParent, "w") then
            addTerminalLine("mv: cannot move '" .. src .. "': Permission denied", colors.red)
            return
        end
        local dstResolved = resolvePath(dst)
        if dstResolved == srcResolved or dstResolved:sub(1, #srcResolved + 1) == srcResolved .. "/" then
            addTerminalLine("mv: cannot move '" .. src .. "' to a subdirectory of itself", colors.red)
            return
        end
        local parent, name = resolveDestination("mv", srcResolved, dst)
        if not parent then return end
        local node = srcParent.children[srcName]
        srcParent.children[srcName] = nil
        parent.children[name] = node
        if currentPath == srcResolved or currentPath:sub(1, #srcResolved + 1) == srcResolved .. "/" then
            currentPath = "/"
        end
        decor("📦 Moved: " .. src .. " -> " .. dst, colors.green)
    end,
}

terminalCommands["cat"] = {
    desc = "Read files (or pipe input)",
    usage = "cat <file>...",
    action = function(args)
        if not args[2] then
            if stdinLines then
                for _, l in ipairs(stdinLines) do addTerminalLine(l, colors.text) end
                return
            end
            usage("cat")
            return
        end
        for i = 2, #args do
            local node = openReadable(args[i], "cat")
            if node then
                if node.type ~= "file" then
                    addTerminalLine("cat: " .. args[i] .. ": Is a directory", colors.red)
                else
                    decor("📄 " .. args[i] .. ":", colors.green)
                    if (node.content or "") ~= "" then
                        addTerminalLine(node.content, colors.text)
                    else
                        decor("(empty)", colors.gray)
                    end
                end
            end
        end
    end,
}

terminalCommands["echo"] = {
    desc = "Print text (supports $VARIABLES, > and >>)",
    usage = "echo <text>",
    action = function(args)
        local first, interpret = 2, false
        while args[first] == "-e" or args[first] == "-n" do
            if args[first] == "-e" then interpret = true end
            first = first + 1
        end
        local msg = table.concat(args, " ", first)
        if interpret then msg = msg:gsub("\\n", "\n"):gsub("\\t", "\t") end
        addTerminalLine((captureBuffer and "" or "💬 ") .. msg, colors.text)
    end,
}

local function parseCount(args, default)
    local n, file = default, nil
    local i = 2
    while i <= #args do
        local a = args[i]
        if a == "-n" then
            n = tonumber(args[i + 1]) or default
            i = i + 2
        elseif a:match("^%-%d+$") then
            n = tonumber(a:sub(2))
            i = i + 1
        else
            file = a
            i = i + 1
        end
    end
    return n, file
end

terminalCommands["head"] = {
    desc = "Show the first lines of a file",
    usage = "head [-n N] [file]",
    action = function(args)
        local n, file = parseCount(args, 10)
        if not file and not stdinLines then usage("head") return end
        local lines = inputLines("head", file)
        if not lines then return end
        for i = 1, math.min(n, #lines) do addTerminalLine(lines[i], colors.text) end
    end,
}

terminalCommands["tail"] = {
    desc = "Show the last lines of a file",
    usage = "tail [-n N] [file]",
    action = function(args)
        local n, file = parseCount(args, 10)
        if not file and not stdinLines then usage("tail") return end
        local lines = inputLines("tail", file)
        if not lines then return end
        for i = math.max(1, #lines - n + 1), #lines do addTerminalLine(lines[i], colors.text) end
    end,
}

terminalCommands["wc"] = {
    desc = "Count lines, words and characters",
    usage = "wc [-l|-w|-c] [file]",
    action = function(args)
        local flag, file
        for i = 2, #args do
            if args[i]:sub(1, 1) == "-" then flag = args[i] else file = args[i] end
        end
        if not file and not stdinLines then usage("wc") return end
        local lines = inputLines("wc", file)
        if not lines then return end
        local words, chars = 0, 0
        for _, l in ipairs(lines) do
            for _ in l:gmatch("%S+") do words = words + 1 end
            chars = chars + #l + 1
        end
        local out
        if flag == "-l" then out = tostring(#lines)
        elseif flag == "-w" then out = tostring(words)
        elseif flag == "-c" then out = tostring(chars)
        else out = string.format("%d %d %d", #lines, words, chars) end
        addTerminalLine(out .. (file and (" " .. file) or ""), colors.text)
    end,
}

terminalCommands["sort"] = {
    desc = "Sort lines",
    usage = "sort [-r] [file]",
    action = function(args)
        local reverse, file = false, nil
        for i = 2, #args do
            if args[i] == "-r" then reverse = true else file = args[i] end
        end
        if not file and not stdinLines then usage("sort") return end
        local lines = inputLines("sort", file)
        if not lines then return end
        local copy = {table.unpack(lines)}
        table.sort(copy, function(a, b)
            if reverse then return a > b end
            return a < b
        end)
        for _, l in ipairs(copy) do addTerminalLine(l, colors.text) end
    end,
}

terminalCommands["uniq"] = {
    desc = "Collapse adjacent duplicate lines",
    usage = "uniq [-c] [file]",
    action = function(args)
        local counting, file = false, nil
        for i = 2, #args do
            if args[i] == "-c" then counting = true else file = args[i] end
        end
        if not file and not stdinLines then usage("uniq") return end
        local lines = inputLines("uniq", file)
        if not lines then return end
        local i = 1
        while i <= #lines do
            local j = i
            while j < #lines and lines[j + 1] == lines[i] do j = j + 1 end
            addTerminalLine((counting and string.format("%4d ", j - i + 1) or "") .. lines[i], colors.text)
            i = j + 1
        end
    end,
}

terminalCommands["grep"] = {
    desc = "Search text in files or piped input",
    usage = "grep [-i] [-v] [-n] [-r] <pattern> [file|dir...]",
    action = function(args)
        local ignoreCase, invert, numbered, recursive, quiet, counting = false, false, false, false, false, false
        local matchCount = 0
        local rest = {}
        for i = 2, #args do
            local a = args[i]
            if a:sub(1, 1) == "-" and #a > 1 and #rest == 0 then
                if a:find("i") then ignoreCase = true end
                if a:find("v") then invert = true end
                if a:find("n") then numbered = true end
                if a:find("q") then quiet = true end
                if a:find("c") then counting = true end
                if a:find("r") or a:find("R") then recursive = true end
            else
                rest[#rest + 1] = a
            end
        end
        local pattern = rest[1]
        if not pattern then usage("grep") return end
        local needle = ignoreCase and pattern:lower() or pattern
        local found = false

        local function scan(lines, label)
            for n, line in ipairs(lines) do
                local hay = ignoreCase and line:lower() or line
                if (hay:find(needle, 1, true) ~= nil) ~= invert then
                    local prefix = (label and (label .. ":") or "") .. (numbered and (n .. ":") or "")
                    if counting then matchCount = matchCount + 1 elseif not quiet then addTerminalLine(prefix .. line, colors.text) end
                    found = true
                end
            end
        end

        local targets = {}
        for i = 2, #rest do targets[#targets + 1] = rest[i] end
        if #targets == 0 then
            if recursive then
                targets = {"."}
            elseif stdinLines then
                scan(stdinLines, nil)
                if counting then addTerminalLine(tostring(matchCount), colors.text) end
                return found and 0 or 1
            else
                usage("grep")
                return
            end
        end
        local multi = #targets > 1 or recursive

        local function visit(node, displayPath)
            if node.type == "file" then
                if hasPerm(node, "r") then scan(contentLines(node), multi and displayPath or nil) end
            elseif recursive and hasPerm(node, "r") then
                for _, name in ipairs(sortedKeys(node.children)) do
                    visit(node.children[name], displayPath .. "/" .. name)
                end
            end
        end

        for _, target in ipairs(targets) do
            local node = openReadable(target, "grep")
            if node then
                if node.type == "dir" and not recursive then
                    addTerminalLine("grep: " .. target .. ": Is a directory", colors.red)
                else
                    visit(node, target)
                end
            end
        end
        if counting then addTerminalLine(tostring(matchCount), colors.text) end
        return found and 0 or 1
    end,
}

terminalCommands["find"] = {
    desc = "Search for files by name",
    usage = "find [path] [-name pattern]",
    action = function(args)
        local startPath, namePattern = ".", nil
        local i = 2
        while i <= #args do
            if args[i] == "-name" then
                namePattern = args[i + 1]
                i = i + 2
            else
                startPath = args[i]
                i = i + 1
            end
        end
        local root = getPathObject(startPath)
        if not root then
            addTerminalLine("find: '" .. startPath .. "': No such file or directory", colors.red)
            return
        end
        local luaPattern
        if namePattern then
            local escaped = namePattern:gsub("[%^%$%(%)%%%.%[%]%+%-]", "%%%0")
            escaped = escaped:gsub("%*", ".*")
            escaped = escaped:gsub("%?", ".")
            luaPattern = "^" .. escaped .. "$"
        end
        local function walk(node, path)
            local name = path:match("([^/]+)$") or "/"
            if not luaPattern or name:match(luaPattern) then
                addTerminalLine(path, colors.text)
            end
            if node.type == "dir" and hasPerm(node, "r") then
                for _, childName in ipairs(sortedKeys(node.children)) do
                    walk(node.children[childName], (path == "/" and "" or path) .. "/" .. childName)
                end
            end
        end
        walk(root, startPath)
    end,
}

-- chmod: восьмеричные (755) и символьные (+x, u-w, go+r) режимы
local function applyMode(node, spec)
    if spec:match("^[0-7][0-7][0-7]$") then
        node.mode = spec
        return true
    end
    local who, op, perms = spec:match("^([ugoa]*)([%+%-=])([rwx]*)$")
    if not op then return false end
    if who == "" then who = "a" end
    local current = nodeMode(node)
    local digits = {tonumber(current:sub(1, 1)), tonumber(current:sub(2, 2)), tonumber(current:sub(3, 3))}
    local bits = 0
    if perms:find("r") then bits = bits + 4 end
    if perms:find("w") then bits = bits + 2 end
    if perms:find("x") then bits = bits + 1 end
    local function applyTo(i)
        if op == "+" then
            digits[i] = bit32.bor(digits[i], bits)
        elseif op == "-" then
            digits[i] = bit32.band(digits[i], bit32.bnot(bits))
        else
            digits[i] = bits
        end
    end
    local index = {u = 1, g = 2, o = 3}
    for ch in who:gmatch(".") do
        if ch == "a" then
            applyTo(1)
            applyTo(2)
            applyTo(3)
        else
            applyTo(index[ch])
        end
    end
    node.mode = digits[1] .. digits[2] .. digits[3]
    return true
end

terminalCommands["chmod"] = {
    desc = "Change file permissions",
    usage = "chmod <755|+x|u-w|go+r> <file>",
    action = function(args)
        if not args[3] then usage("chmod") return end
        local node = getPathObject(args[3])
        if not node then
            addTerminalLine("chmod: cannot access '" .. args[3] .. "': No such file or directory", colors.red)
        elseif nodeOwner(node) ~= currentUser.name and not isRoot then
            addTerminalLine("chmod: changing permissions of '" .. args[3] .. "': Operation not permitted", colors.red)
        elseif not applyMode(node, args[2]) then
            addTerminalLine("chmod: invalid mode: '" .. args[2] .. "'", colors.red)
        else
            decor("🔐 " .. args[3] .. " -> " .. nodeMode(node) .. " (" .. permString(node) .. ")", colors.green)
        end
    end,
}

terminalCommands["chown"] = {
    desc = "Change file owner (root only)",
    usage = "chown [-R] <user> <file>",
    action = function(args)
        if not checkRoot() then return end
        local recursive, rest = false, {}
        for i = 2, #args do
            if args[i] == "-R" then recursive = true else rest[#rest + 1] = args[i] end
        end
        if #rest < 2 then usage("chown") return end
        local ownerName = rest[1]:match("^([^:]+)")
        local exists = false
        for _, u in ipairs(users) do
            if u.name == ownerName then exists = true end
        end
        if not exists then
            addTerminalLine("chown: invalid user: '" .. ownerName .. "'", colors.red)
            return
        end
        local node = getPathObject(rest[2])
        if not node then
            addTerminalLine("chown: cannot access '" .. rest[2] .. "': No such file or directory", colors.red)
            return
        end
        if recursive then chownTree(node, ownerName) else node.owner = ownerName end
        decor("👤 Owner of " .. rest[2] .. " is now " .. ownerName, colors.green)
    end,
}

-- ---------- текстовый редактор (nano / vim / vi) ----------
editFile = function(name, args)
    local path = args[2]
    if not path then usage(name) return end
    local parent, fileName = splitParent(path)
    if not parent or parent.type ~= "dir" or not fileName then
        addTerminalLine(name .. ": " .. path .. ": No such directory", colors.red)
        return
    end
    local node = parent.children[fileName]
    local lines = {}
    local canWrite = true
    if node then
        if node.type ~= "file" then
            addTerminalLine(name .. ": " .. path .. ": Is a directory", colors.red)
            return
        end
        if not hasPerm(node, "r") then
            addTerminalLine(name .. ": " .. path .. ": Permission denied", colors.red)
            return
        end
        lines = contentLines(node)
        canWrite = hasPerm(node, "w")
    elseif not hasPerm(parent, "w") then
        addTerminalLine(name .. ": " .. path .. ": Permission denied", colors.red)
        return
    end

    local modified = false
    local message = nil

    local function show()
        renderSuspended = true
        terminalLines = {}
        scrollOffset = 0
        addTerminalLine("── " .. name .. ": " .. fileName .. (modified and " [modified]" or "") .. (canWrite and "" or " [read-only]") .. " ──", colors.green)
        local window = maxLines - 6
        for i = math.max(1, #lines - window + 1), #lines do
            addTerminalLine(string.format("%3d│ %s", i, lines[i]), colors.text)
        end
        if #lines == 0 then addTerminalLine("  (empty file)", colors.gray) end
        addTerminalLine("─────────────", colors.gray)
        addTerminalLine("text+Enter = add line | :w save | :q quit | :wq | :q! discard", colors.gray)
        addTerminalLine(":d N delete line | :e N text replace | :i N text insert before", colors.gray)
        if message then addTerminalLine(message, colors.amber) end
        renderSuspended = false
        updateTerminalDisplay()
    end

    local function save()
        if not canWrite then
            message = "⛔ Permission denied (read-only)"
            return false
        end
        local text = table.concat(lines, "\n")
        if node then
            node.content = text
        else
            node = newNode("file", text)
            parent.children[fileName] = node
        end
        modified = false
        message = "💾 Saved " .. fileName
        return true
    end

    while true do
        show()
        message = nil
        local input = readLine("edit> ", false)
        if input == nil then break end
        local cmd, rest = input:match("^:(%S+)%s*(.*)$")
        if cmd == "q" then
            if modified then
                message = "Unsaved changes! Use :wq, :w or :q! to discard"
            else
                break
            end
        elseif cmd == "q!" then
            break
        elseif cmd == "w" then
            save()
        elseif cmd == "wq" then
            if save() then break end
        elseif cmd == "d" then
            local n = tonumber(rest)
            if n and lines[n] then
                table.remove(lines, n)
                modified = true
            else
                message = "Usage: :d N"
            end
        elseif cmd == "e" or cmd == "i" then
            local n, text = rest:match("^(%d+)%s*(.*)$")
            n = tonumber(n)
            if n and (cmd == "e" and lines[n] or (cmd == "i" and n >= 1 and n <= #lines + 1)) then
                if cmd == "e" then lines[n] = text else table.insert(lines, n, text) end
                modified = true
            else
                message = "Usage: :" .. cmd .. " N text"
            end
        elseif cmd then
            message = "Unknown command: :" .. cmd
        else
            table.insert(lines, input)
            modified = true
        end
    end
    addTerminalLine("📝 Closed " .. fileName, colors.gray)
end

for _, editorName in ipairs({"nano", "vim", "vi"}) do
    terminalCommands[editorName] = {
        desc = "Simple line-based text editor",
        usage = editorName .. " <file>",
        action = function(args) editFile(editorName, args) end,
    }
end
end

-- ============================================================
-- ===== 11d. НАСТОЯЩИЙ LINUX: УТИЛИТЫ, АРХИВЫ, CRON, SYSTEMD =====
-- ============================================================
local startCron

do
local function humanSize(bytes)
    local units = {"B", "K", "M", "G", "T"}
    local v, i = bytes, 1
    while v >= 1024 and i < #units do
        v = v / 1024
        i = i + 1
    end
    if i == 1 or v >= 10 then return string.format("%d%s", math.floor(v + 0.5), units[i]) end
    return string.format("%.1f%s", v, units[i])
end

local function treeBytes(node)
    if node.type ~= "dir" then return nodeSize(node) end
    local total = 4096
    for _, child in pairs(node.children) do total = total + treeBytes(child) end
    return total
end

-- простая замена регулярных выражений на шаблоны Lua (. * + ? ^ $ [] \d \w \s)
local function regexToLua(re)
    local out = {}
    local classes = {d = "%d", D = "%D", w = "%w", W = "%W", s = "%s", S = "%S"}
    local i, n, inSet = 1, #re, false
    while i <= n do
        local c = re:sub(i, i)
        if c == "\\" and i < n then
            local d = re:sub(i + 1, i + 1)
            out[#out + 1] = classes[d] or ("%" .. d)
            i = i + 2
        else
            if inSet then
                if c == "]" then inSet = false end
                out[#out + 1] = (c == "%") and "%%" or c
            elseif c == "[" then
                inSet = true
                out[#out + 1] = c
            elseif c == "%" or c == "-" or c == "(" or c == ")" then
                out[#out + 1] = "%" .. c
            else
                out[#out + 1] = c
            end
            i = i + 1
        end
    end
    return table.concat(out)
end

local function quoteWord(w)
    if w:match("[%s;|&<>$()]") or w == "" then return "'" .. w:gsub("'", "") .. "'" end
    return w
end

-- ---------- true / false / test / [ ----------
local function testExpr(tokens)
    if tokens[1] == "!" then
        table.remove(tokens, 1)
        return not testExpr(tokens)
    end
    if #tokens == 0 then return false end
    if #tokens == 1 then return tokens[1] ~= "" end
    if #tokens == 2 then
        local op, v = tokens[1], tokens[2]
        if op == "-z" then return v == "" end
        if op == "-n" then return v ~= "" end
        local node = getPathObject(v)
        if op == "-e" then return node ~= nil end
        if op == "-f" then return node ~= nil and node.type == "file" end
        if op == "-d" then return node ~= nil and node.type == "dir" end
        if op == "-r" then return node ~= nil and hasPerm(node, "r") end
        if op == "-w" then return node ~= nil and hasPerm(node, "w") end
        if op == "-x" then return node ~= nil and hasPerm(node, "x") end
        if op == "-s" then return node ~= nil and nodeSize(node) > 0 end
        return false
    end
    if #tokens == 3 then
        local a, op, b = tokens[1], tokens[2], tokens[3]
        if op == "=" or op == "==" then return a == b end
        if op == "!=" then return a ~= b end
        local x, y = tonumber(a), tonumber(b)
        if not x or not y then return false end
        if op == "-eq" then return x == y end
        if op == "-ne" then return x ~= y end
        if op == "-lt" then return x < y end
        if op == "-le" then return x <= y end
        if op == "-gt" then return x > y end
        if op == "-ge" then return x >= y end
    end
    return false
end

terminalCommands["test"] = {
    desc = "Evaluate a condition (-f -d -e -z -n = != -eq -lt ...)",
    usage = "test <expr>   |   [ <expr> ]",
    action = function(args)
        local tokens = {}
        for i = 2, #args do tokens[#tokens + 1] = args[i] end
        return testExpr(tokens) and 0 or 1
    end,
}
terminalCommands["["] = {
    desc = "Evaluate a condition: [ -f file ]",
    usage = "[ <expr> ]",
    action = function(args)
        local tokens = {}
        for i = 2, #args do tokens[#tokens + 1] = args[i] end
        if tokens[#tokens] == "]" then table.remove(tokens) end
        return testExpr(tokens) and 0 or 1
    end,
}
terminalCommands["true"] = {desc = "Exit with status 0", action = function() return 0 end}
terminalCommands["false"] = {desc = "Exit with status 1", action = function() return 1 end}

terminalCommands["return"] = {
    desc = "Return from a shell function",
    usage = "return [code]",
    action = function(args)
        scriptExit = {kind = "return", code = tonumber(args[2]) or 0}
    end,
}

terminalCommands["read"] = {
    desc = "Read a line into a variable",
    usage = "read [-p prompt] VAR",
    action = function(args)
        local prompt, var = "", nil
        local i = 2
        while i <= #args do
            if args[i] == "-p" then
                prompt = args[i + 1] or ""
                i = i + 2
            else
                var = args[i]
                i = i + 1
            end
        end
        if not var then usage("read") return end
        local line = readLine(prompt, false)
        if line == nil then return 1 end
        env[var] = line
    end,
}

terminalCommands["unset"] = {
    desc = "Remove a variable",
    usage = "unset NAME",
    action = function(args)
        if args[2] then env[args[2]] = nil end
    end,
}

terminalCommands["printf"] = {
    desc = "Formatted output (%s %d %%, \\n \\t)",
    usage = "printf <format> [args...]",
    action = function(args)
        if not args[2] then usage("printf") return end
        local values, idx = {}, 3
        for i = 3, #args do values[#values + 1] = args[i] end
        local fmt = args[2]:gsub("\\n", "\n"):gsub("\\t", "\t")
        local out = fmt:gsub("%%([sd%%])", function(kind)
            if kind == "%" then return "%" end
            local v = values[idx - 2]
            idx = idx + 1
            if kind == "d" then return tostring(math.floor(tonumber(v) or 0)) end
            return v or ""
        end)
        out = out:gsub("\n$", "")
        addTerminalLine(out, colors.text)
    end,
}

terminalCommands["seq"] = {
    desc = "Print a sequence of numbers",
    usage = "seq [first [step]] last",
    action = function(args)
        local a, b, c = tonumber(args[2]), tonumber(args[3]), tonumber(args[4])
        local first, step, last = 1, 1, nil
        if c then first, step, last = a, b, c
        elseif b then first, last = a, b
        else last = a end
        if not last or not first or not step or step == 0 then usage("seq") return end
        local count = 0
        local v = first
        while (step > 0 and v <= last or step < 0 and v >= last) and count < 5000 do
            addTerminalLine(formatNumber(v), colors.text)
            v = v + step
            count = count + 1
        end
    end,
}

terminalCommands["basename"] = {
    desc = "Strip directory and suffix",
    usage = "basename <path> [suffix]",
    action = function(args)
        if not args[2] then usage("basename") return end
        local name = args[2]:gsub("/+$", ""):match("([^/]*)$")
        if args[3] and name:sub(-#args[3]) == args[3] and #name > #args[3] then name = name:sub(1, -#args[3] - 1) end
        addTerminalLine(name, colors.text)
    end,
}

terminalCommands["dirname"] = {
    desc = "Strip the last path component",
    usage = "dirname <path>",
    action = function(args)
        if not args[2] then usage("dirname") return end
        local dir = args[2]:match("^(.*)/[^/]*$")
        addTerminalLine(dir == nil and "." or (dir == "" and "/" or dir), colors.text)
    end,
}

terminalCommands["which"] = {
    desc = "Locate a command",
    usage = "which <command>",
    action = function(args)
        if not args[2] then usage("which") return end
        local found = 0
        for i = 2, #args do
            local name = args[i]:lower()
            if shellFunctions[args[i]] then
                addTerminalLine(args[i] .. ": shell function", colors.text)
            elseif aliases[args[i]] then
                addTerminalLine(args[i] .. ": aliased to " .. aliases[args[i]], colors.text)
            elseif terminalCommands[name] then
                addTerminalLine("/usr/bin/" .. name, colors.text)
            else
                found = 1
            end
        end
        return found
    end,
}

terminalCommands["tee"] = {
    desc = "Copy input to a file and to the screen",
    usage = "cmd | tee [-a] <file>",
    action = function(args)
        local append, file = false, nil
        for i = 2, #args do
            if args[i] == "-a" then append = true else file = args[i] end
        end
        if not file or not stdinLines then usage("tee") return end
        for _, line in ipairs(stdinLines) do addTerminalLine(line, colors.text) end
        local ok, why = writeFile(file, table.concat(stdinLines, "\n"), append)
        if not ok then addTerminalLine("tee: " .. file .. ": " .. why, colors.red) end
    end,
}

terminalCommands["xargs"] = {
    desc = "Build command lines from input",
    usage = "cmd | xargs [-n N] [-I {}] command...",
    action = function(args)
        if not stdinLines then usage("xargs") return end
        local perBatch, replace, cmdParts = nil, nil, {}
        local i = 2
        while i <= #args do
            if args[i] == "-n" then
                perBatch = tonumber(args[i + 1])
                i = i + 2
            elseif args[i] == "-I" then
                replace = args[i + 1]
                i = i + 2
            else
                cmdParts[#cmdParts + 1] = args[i]
                i = i + 1
            end
        end
        if #cmdParts == 0 then cmdParts = {"echo"} end
        local base = {}
        for _, p in ipairs(cmdParts) do base[#base + 1] = quoteWord(p) end
        local baseText = table.concat(base, " ")

        local words = {}
        for _, line in ipairs(stdinLines) do
            if replace then
                words[#words + 1] = line
            else
                for w in line:gmatch("%S+") do words[#words + 1] = w end
            end
        end
        if replace then
            for _, w in ipairs(words) do
                if interruptFlag then break end
                executeLine((baseText:gsub(replace:gsub("%p", "%%%0"), (w:gsub("%%", "%%%%")))), 1)
            end
            return
        end
        local size = perBatch or #words
        if size < 1 then size = 1 end
        local pos = 1
        while pos <= #words and not interruptFlag do
            local batch = {}
            for k = pos, math.min(pos + size - 1, #words) do batch[#batch + 1] = quoteWord(words[k]) end
            executeLine(baseText .. " " .. table.concat(batch, " "), 1)
            pos = pos + size
        end
    end,
}

terminalCommands["cut"] = {
    desc = "Select fields or characters",
    usage = "cut -d<sep> -f<list> [file]  |  cut -c<range> [file]",
    action = function(args)
        local sep, fields, chars, file = "\t", nil, nil, nil
        local i = 2
        while i <= #args do
            local a = args[i]
            if a:sub(1, 2) == "-d" then
                sep = #a > 2 and a:sub(3) or (args[i + 1] or "\t")
                if #a == 2 then i = i + 1 end
            elseif a:sub(1, 2) == "-f" then
                fields = #a > 2 and a:sub(3) or args[i + 1]
                if #a == 2 then i = i + 1 end
            elseif a:sub(1, 2) == "-c" then
                chars = #a > 2 and a:sub(3) or args[i + 1]
                if #a == 2 then i = i + 1 end
            else
                file = a
            end
            i = i + 1
        end
        local spec = fields or chars
        if not spec or (not file and not stdinLines) then usage("cut") return end
        local lines = inputLines("cut", file)
        if not lines then return end
        local picks = {}
        for part in spec:gmatch("[^,]+") do
            local lo, hi = part:match("^(%d*)%-(%d*)$")
            if lo then
                picks[#picks + 1] = {tonumber(lo) or 1, tonumber(hi) or math.huge}
            else
                local n = tonumber(part)
                if n then picks[#picks + 1] = {n, n} end
            end
        end
        local function wanted(k)
            for _, r in ipairs(picks) do
                if k >= r[1] and k <= r[2] then return true end
            end
            return false
        end
        for _, line in ipairs(lines) do
            local out = {}
            if fields then
                local k = 0
                for piece in (line .. sep):gmatch("(.-)" .. sep:gsub("%p", "%%%0")) do
                    k = k + 1
                    if wanted(k) then out[#out + 1] = piece end
                end
                addTerminalLine(table.concat(out, sep), colors.text)
            else
                for k = 1, #line do
                    if wanted(k) then out[#out + 1] = line:sub(k, k) end
                end
                addTerminalLine(table.concat(out), colors.text)
            end
        end
    end,
}

local function expandCharSet(set)
    set = set:gsub("\\n", "\n"):gsub("\\t", "\t")
    local out = {}
    local i = 1
    while i <= #set do
        local c = set:sub(i, i)
        if set:sub(i + 1, i + 1) == "-" and i + 2 <= #set then
            for code = c:byte(), set:sub(i + 2, i + 2):byte() do out[#out + 1] = string.char(code) end
            i = i + 3
        else
            out[#out + 1] = c
            i = i + 1
        end
    end
    return out
end

terminalCommands["tr"] = {
    desc = "Translate or delete characters",
    usage = "cmd | tr <set1> <set2>   |   tr -d <set>",
    action = function(args)
        if not stdinLines then usage("tr") return end
        local delete = args[2] == "-d"
        local set1 = expandCharSet(args[delete and 3 or 2] or "")
        local set2 = expandCharSet(args[3] or "")
        if #set1 == 0 or (not delete and #set2 == 0) then usage("tr") return end
        local map = {}
        for idx, ch in ipairs(set1) do
            map[ch] = delete and true or (set2[idx] or set2[#set2])
        end
        for _, line in ipairs(stdinLines) do
            local out = {}
            for k = 1, #line do
                local ch = line:sub(k, k)
                local m = map[ch]
                if m == nil then out[#out + 1] = ch
                elseif m ~= true then out[#out + 1] = m end
            end
            addTerminalLine(table.concat(out), colors.text)
        end
    end,
}

-- ---------- sed ----------
local function parseSedCommand(text)
    text = trim(text)
    local function parseAddr(s)
        local num = s:match("^(%d+)")
        if num then return {n = tonumber(num)}, s:sub(#num + 1) end
        if s:sub(1, 1) == "$" then return {last = true}, s:sub(2) end
        local re = s:match("^/(.-)/")
        if re then return {re = regexToLua(re)}, s:sub(#re + 3) end
        return nil, s
    end
    local a1, rest = parseAddr(text)
    local a2
    if a1 and rest:sub(1, 1) == "," then a2, rest = parseAddr(rest:sub(2)) end
    local cmd = rest:sub(1, 1)
    if cmd == "s" then
        local delim = rest:sub(2, 2)
        local d = delim:gsub("%p", "%%%0")
        local pat, repl, flags = rest:sub(3):match("^(.-)" .. d .. "(.-)" .. d .. "(.*)$")
        if not pat then error("sed: unterminated `s' command") end
        return {a1 = a1, a2 = a2, cmd = "s", pat = regexToLua(pat), repl = repl, global = flags:find("g") ~= nil}
    elseif cmd == "d" or cmd == "p" then
        return {a1 = a1, a2 = a2, cmd = cmd}
    end
    error("sed: unknown command: '" .. cmd .. "'")
end

terminalCommands["sed"] = {
    desc = "Stream editor (s/old/new/[g], Nd, N,Mp, /re/d)",
    usage = "sed [-n] [-e] 's/old/new/g' [file]",
    action = function(args)
        local quiet, scripts, file = false, {}, nil
        local i = 2
        while i <= #args do
            local a = args[i]
            if a == "-n" then
                quiet = true
            elseif a == "-e" then
                scripts[#scripts + 1] = args[i + 1]
                i = i + 1
            elseif a:sub(1, 1) ~= "-" or #a == 1 then
                if #scripts == 0 then scripts[1] = a else file = a end
            end
            i = i + 1
        end
        if #scripts == 0 or (not file and not stdinLines) then usage("sed") return end
        local lines = inputLines("sed", file)
        if not lines then return end

        local cmds = {}
        for _, script in ipairs(scripts) do
            for _, part in ipairs(splitUnquoted(script, ";")) do
                if trim(part) ~= "" then cmds[#cmds + 1] = parseSedCommand(part) end
            end
        end

        local function addrHit(addr, n, total, line)
            if addr.n then return n == addr.n end
            if addr.last then return n == total end
            return line:find(addr.re) ~= nil
        end
        local function selected(c, n, total, line)
            if not c.a1 then return true end
            if not c.a2 then return addrHit(c.a1, n, total, line) end
            if not c.active then
                if addrHit(c.a1, n, total, line) then
                    c.active = true
                    if addrHit(c.a2, n, total, line) and not c.a2.re then c.active = c.a2.n and c.a2.n > n or false end
                    return true
                end
                return false
            end
            if addrHit(c.a2, n, total, line) then c.active = false end
            return true
        end

        for n, line in ipairs(lines) do
            local current, deleted = line, false
            for _, c in ipairs(cmds) do
                if selected(c, n, #lines, current) then
                    if c.cmd == "s" then
                        local function replace(m)
                            return (c.repl:gsub("&", function() return m end))
                        end
                        if c.global then current = current:gsub(c.pat, replace)
                        else current = current:gsub(c.pat, replace, 1) end
                    elseif c.cmd == "d" then
                        deleted = true
                        break
                    elseif c.cmd == "p" then
                        addTerminalLine(current, colors.text)
                    end
                end
            end
            if not deleted and not quiet then addTerminalLine(current, colors.text) end
        end
    end,
}

-- ---------- awk (print, условия, END, сумма) ----------
terminalCommands["awk"] = {
    desc = "Pattern scanning: print $1 $NF NR NF, /re/, NR==N, END{...}, sum += $1",
    usage = "awk [-F sep] 'prog' [file]     e.g. awk -F: '{print $1}' f ; awk '{s+=$1} END{print s}'",
    action = function(args)
        local sep, prog, file = nil, nil, nil
        local i = 2
        while i <= #args do
            local a = args[i]
            if a == "-F" then
                sep = args[i + 1]
                i = i + 1
            elseif a:sub(1, 2) == "-F" then
                sep = a:sub(3)
            elseif not prog then
                prog = a
            else
                file = a
            end
            i = i + 1
        end
        if not prog or (not file and not stdinLines) then usage("awk") return end
        local lines = inputLines("awk", file)
        if not lines then return end

        -- разбор программы на блоки  [условие] { действия }
        local blocks = {}
        local pos = 1
        while pos <= #prog do
            local open = prog:find("{", pos, true)
            if not open then break end
            local depth, close = 0, nil
            for k = open, #prog do
                local ch = prog:sub(k, k)
                if ch == "{" then depth = depth + 1
                elseif ch == "}" then
                    depth = depth - 1
                    if depth == 0 then close = k break end
                end
            end
            if not close then error("awk: missing }") end
            blocks[#blocks + 1] = {cond = trim(prog:sub(pos, open - 1)), body = prog:sub(open + 1, close - 1)}
            pos = close + 1
        end
        if #blocks == 0 then error("awk: no action found") end

        local vars, fields, nr = {}, {}, 0
        local line0 = ""

        local function substitute(expr)
            expr = expr:gsub("%$NF", function() return fields[#fields] or "" end)
            expr = expr:gsub("%$(%d+)", function(k)
                k = tonumber(k)
                if k == 0 then return line0 end
                return fields[k] or ""
            end)
            expr = expr:gsub("[%a_][%w_]*", function(word)
                if word == "NR" then return tostring(nr) end
                if word == "NF" then return tostring(#fields) end
                if vars[word] ~= nil then return tostring(vars[word]) end
                return word
            end)
            return expr
        end

        local function evalItem(item)
            item = trim(item)
            local quoted = item:match('^"(.*)"$')
            if quoted then return (quoted:gsub("\\n", "\n"):gsub("\\t", "\t")) end
            local text = substitute(item)
            if text:match("^[%d%.%+%-%*/%(%)%s%%]+$") then
                local ok, v = pcall(evalArith, text)
                if ok then return formatNumber(v) end
            end
            return text
        end

        local function runActions(body)
            for _, stmt in ipairs(splitUnquoted(body, ";")) do
                stmt = trim(stmt)
                if stmt:sub(1, 5) == "print" then
                    local rest = trim(stmt:sub(6))
                    if rest == "" then
                        addTerminalLine(line0, colors.text)
                    else
                        local out = {}
                        for _, item in ipairs(splitUnquoted(rest, ",")) do out[#out + 1] = evalItem(item) end
                        addTerminalLine(table.concat(out, " "), colors.text)
                    end
                else
                    local name, op, expr = stmt:match("^([%a_][%w_]*)%s*([%+%-%*/]?)=%s*(.+)$")
                    if name then
                        local value = tonumber(evalItem(expr)) or evalItem(expr)
                        if op ~= "" then
                            local old = tonumber(vars[name]) or 0
                            local v = tonumber(value) or 0
                            if op == "+" then value = old + v
                            elseif op == "-" then value = old - v
                            elseif op == "*" then value = old * v
                            else value = v ~= 0 and old / v or 0 end
                        end
                        vars[name] = value
                    else
                        local inc = stmt:match("^([%a_][%w_]*)%+%+$")
                        if inc then vars[inc] = (tonumber(vars[inc]) or 0) + 1 end
                    end
                end
            end
        end

        local function condHolds(cond)
            if cond == "" then return true end
            local re = cond:match("^/(.*)/$")
            if re then return line0:find(regexToLua(re)) ~= nil end
            local lhs, op, rhs = cond:match("^(.-)%s*([=!<>]=?)%s*(.+)$")
            if lhs then
                local a, b = evalItem(lhs), evalItem(rhs)
                local x, y = tonumber(a), tonumber(b)
                if x and y then a, b = x, y end
                if op == "==" then return a == b end
                if op == "!=" then return a ~= b end
                if x and y then
                    if op == ">" then return a > b end
                    if op == "<" then return a < b end
                    if op == ">=" then return a >= b end
                    if op == "<=" then return a <= b end
                end
            end
            return false
        end

        for _, b in ipairs(blocks) do
            if b.cond == "BEGIN" then runActions(b.body) end
        end
        for _, line in ipairs(lines) do
            nr = nr + 1
            line0 = line
            fields = {}
            if sep and sep ~= " " then
                for piece in (line .. sep):gmatch("(.-)" .. sep:gsub("%p", "%%%0")) do fields[#fields + 1] = piece end
            else
                for w in line:gmatch("%S+") do fields[#fields + 1] = w end
            end
            for _, b in ipairs(blocks) do
                if b.cond ~= "BEGIN" and b.cond ~= "END" and condHolds(b.cond) then runActions(b.body) end
            end
        end
        for _, b in ipairs(blocks) do
            if b.cond == "END" then runActions(b.body) end
        end
    end,
}

-- ---------- diff ----------
terminalCommands["diff"] = {
    desc = "Compare two files line by line",
    usage = "diff <file1> <file2>",
    action = function(args)
        if not args[3] then usage("diff") return end
        local a = inputLines("diff", args[2])
        local b = inputLines("diff", args[3])
        if not a or not b then return end
        if #a > 300 or #b > 300 then
            addTerminalLine("diff: files too large (max 300 lines)", colors.red)
            return
        end
        local n, m = #a, #b
        local lcs = {}
        for i = 0, n do
            lcs[i] = {}
            for j = 0, m do lcs[i][j] = 0 end
        end
        for i = n - 1, 0, -1 do
            for j = m - 1, 0, -1 do
                if a[i + 1] == b[j + 1] then
                    lcs[i][j] = lcs[i + 1][j + 1] + 1
                else
                    lcs[i][j] = math.max(lcs[i + 1][j], lcs[i][j + 1])
                end
            end
        end
        -- последовательность операций: eq / del / add
        local ops, i, j = {}, 0, 0
        while i < n or j < m do
            if i < n and j < m and a[i + 1] == b[j + 1] then
                ops[#ops + 1] = {"eq"}
                i, j = i + 1, j + 1
            elseif i < n and (j >= m or lcs[i + 1][j] >= lcs[i][j + 1]) then
                ops[#ops + 1] = {"del", a[i + 1]}
                i = i + 1
            else
                ops[#ops + 1] = {"add", b[j + 1]}
                j = j + 1
            end
        end
        -- группируем изменения в блоки как обычный diff
        local differences = false
        local ai, bi, k = 0, 0, 1
        local function range(first, count)
            if count <= 1 then return tostring(first) end
            return first .. "," .. (first + count - 1)
        end
        while k <= #ops do
            if ops[k][1] == "eq" then
                ai, bi, k = ai + 1, bi + 1, k + 1
            else
                differences = true
                local dels, adds = {}, {}
                while k <= #ops and ops[k][1] ~= "eq" do
                    if ops[k][1] == "del" then dels[#dels + 1] = ops[k][2] else adds[#adds + 1] = ops[k][2] end
                    k = k + 1
                end
                local header
                if #dels > 0 and #adds > 0 then
                    header = range(ai + 1, #dels) .. "c" .. range(bi + 1, #adds)
                elseif #dels > 0 then
                    header = range(ai + 1, #dels) .. "d" .. bi
                else
                    header = ai .. "a" .. range(bi + 1, #adds)
                end
                addTerminalLine(header, colors.cyan)
                for _, l in ipairs(dels) do addTerminalLine("< " .. l, colors.red) end
                if #dels > 0 and #adds > 0 then addTerminalLine("---", colors.gray) end
                for _, l in ipairs(adds) do addTerminalLine("> " .. l, colors.green) end
                ai, bi = ai + #dels, bi + #adds
            end
        end
        return differences and 1 or 0
    end,
}

-- ---------- stat / file ----------
terminalCommands["stat"] = {
    desc = "Show file status",
    usage = "stat <file>",
    action = function(args)
        if not args[2] then usage("stat") return end
        local node = openReadable(args[2], "stat")
        if not node then return end
        addTerminalLine("  File: " .. resolvePath(args[2]), colors.green)
        addTerminalLine("  Size: " .. nodeSize(node) .. "   Type: " .. (node.type == "dir" and "directory" or "regular file"), colors.text)
        addTerminalLine("Access: (" .. nodeMode(node) .. "/" .. permString(node) .. ")  Owner: " .. nodeOwner(node), colors.text)
    end,
}

terminalCommands["file"] = {
    desc = "Guess the file type",
    usage = "file <file>...",
    action = function(args)
        if not args[2] then usage("file") return end
        for i = 2, #args do
            local node = openReadable(args[i], "file")
            if node then
                local kind
                if node.type == "dir" then kind = "directory"
                elseif node.archive and node.zip then kind = "Zip archive data"
                elseif node.archive then kind = node.gz and "gzip compressed POSIX tar archive" or "POSIX tar archive"
                elseif node.gz then kind = "gzip compressed data"
                elseif (node.content or "") == "" then kind = "empty"
                elseif (node.content or ""):sub(1, 2) == "#!" then kind = "Bourne-Again shell script, ASCII text executable"
                else kind = "ASCII text" end
                addTerminalLine(args[i] .. ": " .. kind, colors.text)
            end
        end
    end,
}

-- ---------- система: df, du, free, mount, uname ----------
terminalCommands["df"] = {
    desc = "Disk space usage",
    usage = "df [-h]",
    action = function(args)
        local human = args[2] == "-h"
        local used = 2.4 * 1024 ^ 3 + treeBytes(fileSystem["/"])
        local size = 16 * 1024 ^ 3
        local function fmt(bytes) return human and humanSize(bytes) or tostring(math.floor(bytes / 1024)) end
        addTerminalLine(string.format("%-12s %8s %8s %8s %5s %s", "Filesystem", human and "Size" or "1K-blocks", "Used", "Avail", "Use%", "Mounted on"), colors.green)
        addTerminalLine(string.format("%-12s %8s %8s %8s %4d%% %s", "/dev/sda1", fmt(size), fmt(used), fmt(size - used), math.floor(used / size * 100), "/"), colors.text)
        addTerminalLine(string.format("%-12s %8s %8s %8s %4d%% %s", "tmpfs", fmt(2 * 1024 ^ 3), fmt(1024 * 40), fmt(2 * 1024 ^ 3 - 1024 * 40), 1, "/tmp"), colors.text)
        addTerminalLine(string.format("%-12s %8s %8s %8s %4d%% %s", "/dev/sda2", fmt(512 * 1024 ^ 2), fmt(96 * 1024 ^ 2), fmt(416 * 1024 ^ 2), 19, "/boot"), colors.text)
    end,
}

terminalCommands["du"] = {
    desc = "Estimate file space usage",
    usage = "du [-s] [-h] [path]",
    action = function(args)
        local summary, human, path = false, false, "."
        for i = 2, #args do
            local a = args[i]
            if a:sub(1, 1) == "-" and #a > 1 then
                if a:find("s") then summary = true end
                if a:find("h") then human = true end
            else
                path = a
            end
        end
        local node = openReadable(path, "du")
        if not node then return end
        local function fmt(bytes) return human and humanSize(bytes) or tostring(math.max(1, math.floor(bytes / 1024))) end
        if node.type ~= "dir" or summary then
            addTerminalLine(fmt(treeBytes(node)) .. "\t" .. path, colors.text)
            return
        end
        for _, name in ipairs(sortedKeys(node.children)) do
            local child = node.children[name]
            if child.type == "dir" then
                addTerminalLine(fmt(treeBytes(child)) .. "\t" .. path .. "/" .. name, colors.text)
            end
        end
        addTerminalLine(fmt(treeBytes(node)) .. "\t" .. path, colors.text)
    end,
}

terminalCommands["free"] = {
    desc = "Memory usage",
    usage = "free [-h|-m]",
    action = function(args)
        local total = 16384
        local used = getMemoryMb() or 512
        local human = args[2] == "-h"
        local function fmt(mb) return human and humanSize(mb * 1024 * 1024) or tostring(mb) end
        addTerminalLine(string.format("%-8s %10s %10s %10s", "", "total", "used", "free"), colors.green)
        addTerminalLine(string.format("%-8s %10s %10s %10s", "Mem:", fmt(total), fmt(used), fmt(total - used)), colors.text)
        addTerminalLine(string.format("%-8s %10s %10s %10s", "Swap:", fmt(2048), fmt(0), fmt(2048)), colors.text)
    end,
}

terminalCommands["mount"] = {
    desc = "Show mounted filesystems",
    action = function()
        addTerminalLine("/dev/sda1 on / type ext4 (rw,relatime)", colors.text)
        addTerminalLine("/dev/sda2 on /boot type ext4 (rw,relatime)", colors.text)
        addTerminalLine("tmpfs on /tmp type tmpfs (rw,nosuid,nodev)", colors.text)
        addTerminalLine("proc on /proc type proc (rw,nosuid,nodev,noexec)", colors.text)
    end,
}
terminalCommands["umount"] = {
    desc = "Unmount a filesystem (simulated)",
    usage = "umount <dir>",
    action = function(args)
        if not checkRoot() then return end
        if not args[2] then usage("umount") return end
        addTerminalLine("umount: " .. args[2] .. ": target is busy", colors.red)
    end,
}

terminalCommands["uname"] = {
    desc = "Print system information",
    usage = "uname [-a|-s|-r|-m|-n]",
    action = function(args)
        local flag = args[2] or "-s"
        local machine = machines[currentHost]
        local release = kernel.version .. "-jcj"
        if flag == "-a" then
            addTerminalLine("Linux " .. currentHost .. " " .. release .. " #1 SMP x86_64 GNU/Linux" .. (machine and (" (" .. machine.distro .. ")") or ""), colors.text)
        elseif flag == "-r" then addTerminalLine(release, colors.text)
        elseif flag == "-m" then addTerminalLine("x86_64", colors.text)
        elseif flag == "-n" then addTerminalLine(currentHost, colors.text)
        else addTerminalLine("Linux", colors.text) end
    end,
}

-- ---------- архивы: tar, gzip, gunzip, zip, unzip ----------
local function archiveCreate(cmdName, archivePath, files, opts)
    if #files == 0 then
        addTerminalLine(cmdName .. ": Cowardly refusing to create an empty archive", colors.red)
        return
    end
    local entries = {}
    for _, p in ipairs(files) do
        local node = openReadable(p, cmdName)
        if node then
            local base = resolvePath(p):match("([^/]+)$") or "root"
            entries[base] = deepCopy(node)
            if opts.verbose then addTerminalLine(p .. (node.type == "dir" and "/" or ""), colors.gray) end
        end
    end
    local parent, name = splitParent(archivePath)
    if not parent or parent.type ~= "dir" or not name then
        addTerminalLine(cmdName .. ": " .. archivePath .. ": No such directory", colors.red)
        return
    end
    if not hasPerm(parent, "w") or (parent.children[name] and not hasPerm(parent.children[name], "w")) then
        addTerminalLine(cmdName .. ": " .. archivePath .. ": Permission denied", colors.red)
        return
    end
    parent.children[name] = {
        type = "file", owner = currentUser.name, mode = "644", content = "",
        archive = entries, gz = opts.gz or nil, zip = opts.zip or nil,
    }
    decor("📦 Created " .. archivePath, colors.green)
end

local function archiveList(node, prefix, out)
    for _, name in ipairs(sortedKeys(node)) do
        local entry = node[name]
        out[#out + 1] = prefix .. name .. (entry.type == "dir" and "/" or "")
        if entry.type == "dir" then archiveList(entry.children, prefix .. name .. "/", out) end
    end
    return out
end

local function archiveExtract(cmdName, archivePath, destDir, verbose)
    local node = openReadable(archivePath, cmdName)
    if not node then return end
    if not node.archive then
        addTerminalLine(cmdName .. ": " .. archivePath .. ": not an archive", colors.red)
        return
    end
    local dest = getPathObject(destDir or ".")
    if not dest or dest.type ~= "dir" or not hasPerm(dest, "w") then
        addTerminalLine(cmdName .. ": cannot write to " .. (destDir or "."), colors.red)
        return
    end
    for _, name in ipairs(sortedKeys(node.archive)) do
        dest.children[name] = deepCopy(node.archive[name])
        if verbose then addTerminalLine(name, colors.gray) end
    end
    decor("📂 Extracted " .. #sortedKeys(node.archive) .. " item(s) from " .. archivePath, colors.green)
end

terminalCommands["tar"] = {
    desc = "Create, list or extract archives",
    usage = "tar -czf a.tar.gz files... | tar -xf a.tar [-C dir] | tar -tf a.tar   (c x t z v f)",
    action = function(args)
        local flags = (args[2] or ""):gsub("^%-", "")
        if flags == "" then usage("tar") return end
        local create, extract, list = flags:find("c") ~= nil, flags:find("x") ~= nil, flags:find("t") ~= nil
        local verbose, gz = flags:find("v") ~= nil, flags:find("z") ~= nil
        local archive, destDir, files = nil, nil, {}
        local i = 3
        while i <= #args do
            if args[i] == "-C" then
                destDir = args[i + 1]
                i = i + 1
            elseif not archive and flags:find("f") then
                archive = args[i]
            else
                files[#files + 1] = args[i]
            end
            i = i + 1
        end
        if not archive then usage("tar") return end
        if create then
            archiveCreate("tar", archive, files, {verbose = verbose, gz = gz})
        elseif extract then
            archiveExtract("tar", archive, destDir, verbose)
        elseif list then
            local node = openReadable(archive, "tar")
            if node and node.archive then
                for _, line in ipairs(archiveList(node.archive, "", {})) do addTerminalLine(line, colors.text) end
            elseif node then
                addTerminalLine("tar: " .. archive .. ": not an archive", colors.red)
            end
        else
            usage("tar")
        end
    end,
}

terminalCommands["zip"] = {
    desc = "Package files into a .zip",
    usage = "zip <archive.zip> <files...>",
    action = function(args)
        if not args[3] then usage("zip") return end
        local archive = args[2]
        if not archive:match("%.zip$") then archive = archive .. ".zip" end
        local files = {}
        for i = 3, #args do
            if args[i] ~= "-r" then files[#files + 1] = args[i] end
        end
        archiveCreate("zip", archive, files, {zip = true, verbose = true})
    end,
}

terminalCommands["unzip"] = {
    desc = "Extract a .zip archive",
    usage = "unzip <archive.zip> [-d dir]",
    action = function(args)
        if not args[2] then usage("unzip") return end
        local destDir
        if args[3] == "-d" then destDir = args[4] end
        archiveExtract("unzip", args[2], destDir, true)
    end,
}

terminalCommands["gzip"] = {
    desc = "Compress a file (creates file.gz)",
    usage = "gzip <file>",
    action = function(args)
        if not args[2] then usage("gzip") return end
        local parent, name = splitParent(args[2])
        local node = parent and parent.children and parent.children[name]
        if not node then
            addTerminalLine("gzip: " .. args[2] .. ": No such file or directory", colors.red)
        elseif node.type ~= "file" then
            addTerminalLine("gzip: " .. args[2] .. " is a directory -- ignored", colors.red)
        elseif node.gz then
            addTerminalLine("gzip: " .. args[2] .. " already has .gz suffix -- unchanged", colors.red)
        elseif not hasPerm(parent, "w") or not hasPerm(node, "r") then
            addTerminalLine("gzip: " .. args[2] .. ": Permission denied", colors.red)
        else
            local before = nodeSize(node)
            node.gz = true
            parent.children[name .. ".gz"] = node
            parent.children[name] = nil
            decor(string.format("%s: %d%% compressed", args[2], 100 - math.floor(nodeSize(node) / math.max(1, before) * 100)), colors.green)
        end
    end,
}

terminalCommands["gunzip"] = {
    desc = "Decompress a .gz file",
    usage = "gunzip <file.gz>",
    action = function(args)
        if not args[2] then usage("gunzip") return end
        local parent, name = splitParent(args[2])
        local node = parent and parent.children and parent.children[name]
        if not node then
            addTerminalLine("gunzip: " .. args[2] .. ": No such file or directory", colors.red)
        elseif not node.gz or not name:match("%.gz$") then
            addTerminalLine("gunzip: " .. args[2] .. ": not in gzip format", colors.red)
        elseif not hasPerm(parent, "w") then
            addTerminalLine("gunzip: " .. args[2] .. ": Permission denied", colors.red)
        else
            node.gz = nil
            parent.children[name:gsub("%.gz$", "")] = node
            parent.children[name] = nil
        end
    end,
}

-- ---------- журнал и systemd ----------
terminalCommands["journalctl"] = {
    desc = "Query the system journal",
    usage = "journalctl [-n N] [-u unit]",
    action = function(args)
        local limit, unit = 20, nil
        local i = 2
        while i <= #args do
            if args[i] == "-n" then
                limit = tonumber(args[i + 1]) or 20
                i = i + 1
            elseif args[i] == "-u" then
                unit = (args[i + 1] or ""):gsub("%.service$", "")
                i = i + 1
            end
            i = i + 1
        end
        local shown = {}
        for _, entry in ipairs(journal) do
            if entry.host == currentHost and (not unit or entry.unit == unit) then shown[#shown + 1] = entry end
        end
        if #shown == 0 then
            addTerminalLine("-- No entries --", colors.gray)
            return
        end
        for k = math.max(1, #shown - limit + 1), #shown do
            local e = shown[k]
            addTerminalLine(e.time .. " " .. e.host .. " " .. e.unit .. ": " .. e.msg, colors.text)
        end
    end,
}

local function serviceStatus(name)
    local svc = services[name]
    local proc = findProcess(name)
    addTerminalLine((proc and "● " or "○ ") .. name .. ".service - " .. svc.desc, proc and colors.green or colors.gray)
    addTerminalLine("     Loaded: loaded (/lib/systemd/system/" .. name .. ".service; " .. (svc.enabled and "enabled" or "disabled") .. ")", colors.text)
    if proc then
        local secs = os.time() - proc.start_time
        addTerminalLine("     Active: active (running) for " .. secs .. "s", colors.green)
        addTerminalLine("   Main PID: " .. proc.pid, colors.text)
    else
        addTerminalLine("     Active: inactive (dead)", colors.amber)
    end
end

local function systemctlAction(args)
    local verb = args[2]
    if not verb or verb == "list-units" or verb == "list-units" then
        addTerminalLine(string.format("%-22s %-8s %s", "UNIT", "ACTIVE", "DESCRIPTION"), colors.green)
        for _, name in ipairs(sortedKeys(services)) do
            addTerminalLine(string.format("%-22s %-8s %s", name .. ".service", findProcess(name) and "active" or "inactive", services[name].desc), colors.text)
        end
        return
    end
    local unit = (args[3] or ""):gsub("%.service$", "")
    if unit == "" then usage("systemctl") return end
    local svc = services[unit]
    if not svc then
        addTerminalLine("Unit " .. unit .. ".service could not be found.", colors.red)
        return 4
    end
    if verb == "status" then
        serviceStatus(unit)
        return findProcess(unit) and 0 or 3
    elseif verb == "is-active" then
        addTerminalLine(findProcess(unit) and "active" or "inactive", colors.text)
        return findProcess(unit) and 0 or 3
    elseif verb == "start" or verb == "stop" or verb == "restart" or verb == "enable" or verb == "disable" then
        if not checkRoot() then return 1 end
        if verb == "stop" or verb == "restart" then
            local proc, idx = findProcess(unit)
            if proc then
                proc.alive = false
                table.remove(kernel.processes, idx)
                syslog("systemd", "Stopped " .. svc.desc .. ".")
            end
        end
        if verb == "start" or verb == "restart" then
            if not findProcess(unit) then
                createProcess(unit, nil, true)
                syslog("systemd", "Started " .. svc.desc .. ".")
            end
        end
        if verb == "enable" then svc.enabled = true; syslog("systemd", "Enabled " .. unit .. ".service") end
        if verb == "disable" then svc.enabled = false; syslog("systemd", "Disabled " .. unit .. ".service") end
        decor("✅ " .. verb .. " " .. unit .. ".service", colors.green)
    else
        addTerminalLine("Unknown operation '" .. verb .. "'.", colors.red)
        return 1
    end
end

terminalCommands["systemctl"] = {
    desc = "Control system services (status/start/stop/restart/enable/disable/is-active/list-units)",
    usage = "systemctl <verb> [unit]",
    action = systemctlAction,
}
terminalCommands["service"] = {
    desc = "Control services (service <name> start|stop|restart|status)",
    usage = "service <name> <verb>",
    action = function(args)
        if not args[3] then usage("service") return end
        return systemctlAction({"systemctl", args[3], args[2]})
    end,
}

-- ---------- cron ----------
local function cronMatch(field, value, lo, hi)
    for part in field:gmatch("[^,]+") do
        local range, step = part:match("^(.-)/(%d+)$")
        if not range then range = part end
        local a, b
        if range == "*" then
            a, b = lo, hi
        elseif range:find("-", 1, true) then
            local x, y = range:match("^(%d+)%-(%d+)$")
            a, b = tonumber(x), tonumber(y)
        else
            a = tonumber(range)
            b = step and hi or a
        end
        if a and b then
            local s = tonumber(step) or 1
            if value >= a and value <= b and (value - a) % s == 0 then return true end
        end
    end
    return false
end

local cronState = {lastMinute = nil, nextRun = {}}

local function runCronJob(user, cmd)
    syslog("CRON", "(" .. user .. ") CMD (" .. cmd .. ")")
    addTerminalLine("⏰ cron(" .. user .. "): " .. cmd, colors.gray)
    pcall(executeLine, cmd, 1)
end

-- демон cron: проверяет /var/spool/cron/<user> (только локальная машина, пока нет ssh)
startCron = function()
    task.spawn(function()
        while true do
            task.wait(2)
            if findProcess("cron") and #sshStack == 0 and not busy then
                local spool = localMachine.fs["/"].children.var
                spool = spool and spool.children.spool
                spool = spool and spool.children.cron
                if spool then
                    local t = os.date("*t")
                    local minuteKey = t.yday .. "-" .. t.hour .. "-" .. t.min
                    local newMinute = minuteKey ~= cronState.lastMinute
                    cronState.lastMinute = minuteKey
                    local now = os.clock()
                    for _, userName in ipairs(sortedKeys(spool.children)) do
                        for _, raw in ipairs(contentLines(spool.children[userName])) do
                            local line = trim(raw)
                            if line ~= "" and line:sub(1, 1) ~= "#" then
                                local secs, cmd = line:match("^@every%s+(%d+)s?%s+(.+)$")
                                if secs then
                                    local key = userName .. ":" .. line
                                    local nextAt = cronState.nextRun[key]
                                    if not nextAt then
                                        cronState.nextRun[key] = now + tonumber(secs)
                                    elseif now >= nextAt then
                                        cronState.nextRun[key] = now + tonumber(secs)
                                        runCronJob(userName, cmd)
                                    end
                                elseif newMinute then
                                    local m, h, dom, mon, dow, command = line:match("^(%S+)%s+(%S+)%s+(%S+)%s+(%S+)%s+(%S+)%s+(.+)$")
                                    if m and cronMatch(m, t.min, 0, 59) and cronMatch(h, t.hour, 0, 23)
                                        and cronMatch(dom, t.day, 1, 31) and cronMatch(mon, t.month, 1, 12)
                                        and cronMatch(dow, t.wday - 1, 0, 6) then
                                        runCronJob(userName, command)
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
    end)
end

terminalCommands["crontab"] = {
    desc = "Per-user scheduled jobs: m h dom mon dow command  (or  @every 10s command)",
    usage = "crontab -l | -e | -r",
    action = function(args)
        local path = "/var/spool/cron/" .. currentUser.name
        local dir = ensureDirPath("/var/spool/cron", "777")
        if args[2] == "-l" then
            local node = dir.children[currentUser.name]
            if not node then
                addTerminalLine("no crontab for " .. currentUser.name, colors.gray)
                return 1
            end
            for _, l in ipairs(contentLines(node)) do addTerminalLine(l, colors.text) end
        elseif args[2] == "-e" then
            if not dir.children[currentUser.name] then
                dir.children[currentUser.name] = {
                    type = "file", owner = currentUser.name, mode = "600",
                    content = "# m h dom mon dow command\n# @every 10s echo tick",
                }
            end
            editFile("crontab", {"crontab", path})
            syslog("crontab", "(" .. currentUser.name .. ") REPLACE")
        elseif args[2] == "-r" then
            dir.children[currentUser.name] = nil
            decor("🗑️ crontab removed", colors.green)
        else
            usage("crontab")
        end
    end,
}

end

-- ============================================================
-- ===== 11d. ПОЛЬЗОВАТЕЛИ, СИСТЕМА, ПРОЦЕССЫ, ПАКЕТЫ, ЗАГРУЗКА =====
-- ============================================================
-- База пакетов (используется apt, pacman, neofetch и сохранением состояния)
local installed

do
local repo = {
    htop = "3.3.0", vim = "9.1", nano = "7.2", git = "2.43.0", python3 = "3.11.6", tree = "2.1.1",
    neofetch = "7.1.0", cmatrix = "2.0", sl = "5.02", cowsay = "3.04", figlet = "2.2.5",
    nmap = "7.94", curl = "8.5.0", wget = "1.21.4", tmux = "3.4",
}
installed = {jcj_kernel = "3.0.0", murder_drones = "2.0.0", robux = "1.0.0", bash = "5.2", coreutils = "9.4"}
local protectedPackages = {jcj_kernel = true, bash = true, coreutils = true}

terminalCommands["whoami"] = {
    desc = "Print current user",
    action = function()
        if captureBuffer then
            addTerminalLine(currentUser.name, colors.green)
            return
        end
        addTerminalLine("👤 " .. currentUser.name .. (isRoot and " 👑 ROOT" or ""), colors.green)
    end,
}

terminalCommands["hostname"] = {
    desc = "Print machine name",
    action = function() addTerminalLine(currentHost, colors.text) end,
}

terminalCommands["su"] = {
    desc = "Switch user (password required unless root)",
    usage = "su [-] [user]",
    action = function(args)
        local idx, login = 2, false
        if args[2] == "-" then
            login = true
            idx = 3
        end
        local targetName = args[idx] or "root"
        local target
        for _, u in ipairs(users) do
            if u.name == targetName then target = u end
        end
        if not target then
            addTerminalLine("su: user " .. targetName .. " does not exist", colors.red)
            return
        end
        if not isRoot and target.name ~= currentUser.name then
            if not askPassword(target, "Password: ") then
                syslog("su", "FAILED SU (to " .. target.name .. ") by " .. currentUser.name, true)
                addTerminalLine("su: Authentication failure", colors.red)
                return
            end
        end
        syslog("su", "(to " .. target.name .. ") " .. currentUser.name .. " on pts/0", true)
        currentUser = target
        isRoot = target.is_root == true
        if login then currentPath = homeOf(target) end
        if isRoot then
            addTerminalLine("👑 You are now root!", colors.amber)
        else
            addTerminalLine("👤 Switched to: " .. target.name, colors.green)
        end
    end,
}

terminalCommands["sudo"] = {
    desc = "Run a command as root (asks your password)",
    usage = "sudo <command> [args]",
    action = function(args, ctx)
        if not args[2] then usage("sudo") return end
        if not hasSudoAccess(currentUser) then
            addTerminalLine(currentUser.name .. " is not in the sudoers file. This incident will be reported.", colors.red)
            return
        end
        if not isRoot and os.time() - lastSudoTime > 300 then
            if not askPassword(currentUser, "[sudo] password for " .. currentUser.name .. ": ") then
                syslog("sudo", "3 incorrect password attempts for " .. currentUser.name, true)
                return
            end
        end
        lastSudoTime = os.time()
        syslog("sudo", currentUser.name .. " : TTY=pts/0 ; COMMAND=" .. table.concat(args, " ", 2), true)
        local sub = {}
        for i = 2, #args do sub[#sub + 1] = args[i] end
        local entry = terminalCommands[sub[1]:lower()]
        if not entry then
            addTerminalLine("❌ Command not found: " .. sub[1], colors.red)
            return
        end
        local oldUser, oldRoot = currentUser, isRoot
        isRoot = true
        currentUser = users[1]
        addTerminalLine("👑 Executing '" .. sub[1] .. "' as root...", colors.amber)
        local ok, err = pcall(entry.action, sub, ctx)
        -- `sudo su` должен оставить root-сессию; всё остальное возвращает права
        if sub[1]:lower() ~= "su" then currentUser, isRoot = oldUser, oldRoot end
        if not ok then addTerminalLine("❌ Error: " .. tostring(err), colors.red) end
    end,
}

terminalCommands["passwd"] = {
    desc = "Change a password",
    usage = "passwd [user]",
    action = function(args)
        local target = currentUser
        if args[2] then
            target = nil
            for _, u in ipairs(users) do
                if u.name == args[2] then target = u end
            end
            if not target then
                addTerminalLine("passwd: user '" .. args[2] .. "' does not exist", colors.red)
                return
            end
        end
        if target.name ~= currentUser.name and not isRoot then
            addTerminalLine("passwd: You may not view or modify password information for " .. target.name, colors.red)
            return
        end
        if not isRoot then
            local current = readLine("Current password: ", true)
            if current == nil then return end
            if current ~= target.password then
                addTerminalLine("passwd: Authentication token manipulation error", colors.red)
                return
            end
        end
        local first = readLine("New password: ", true)
        if first == nil then return end
        if first == "" then
            addTerminalLine("passwd: password cannot be empty", colors.red)
            return
        end
        local second = readLine("Retype new password: ", true)
        if second == nil then return end
        if first ~= second then
            addTerminalLine("Sorry, passwords do not match.", colors.red)
            return
        end
        target.password = first
        syslog("passwd", "password changed for " .. target.name, true)
        addTerminalLine("✅ passwd: password updated successfully", colors.green)
    end,
}

terminalCommands["useradd"] = {
    desc = "Add a user (root only)",
    usage = "useradd <username>",
    action = function(args)
        if not checkRoot() then return end
        local name = args[2]
        if not name then usage("useradd") return end
        if not name:match("^[%a_][%w_%-]*$") then
            addTerminalLine("useradd: invalid user name '" .. name .. "'", colors.red)
            return
        end
        for _, u in ipairs(users) do
            if u.name == name then
                addTerminalLine("useradd: user '" .. name .. "' already exists", colors.red)
                return
            end
        end
        local pw = readLine("Set password for " .. name .. ": ", true)
        if pw == nil then return end
        if pw == "" then pw = "password" end
        local newUser = {
            name = name, uid = 2000 + #users, gid = 100, home = "/home/" .. name,
            shell = "/bin/bash", password = pw, is_root = false, groups = {"users"},
        }
        table.insert(users, newUser)
        syslog("useradd", "new user: name=" .. name .. ", UID=" .. newUser.uid, true)
        ensureHome(newUser)
        addTerminalLine("✅ User " .. name .. " created (home: /home/" .. name .. ")", colors.green)
    end,
}

terminalCommands["userdel"] = {
    desc = "Delete a user (root only, home is kept)",
    usage = "userdel <username>",
    action = function(args)
        if not checkRoot() then return end
        if not args[2] then usage("userdel") return end
        if args[2] == "root" or args[2] == currentUser.name then
            addTerminalLine("userdel: cannot remove this user", colors.red)
            return
        end
        for i, u in ipairs(users) do
            if u.name == args[2] then
                table.remove(users, i)
                syslog("userdel", "delete user '" .. args[2] .. "'", true)
                addTerminalLine("🗑️ User " .. args[2] .. " removed", colors.green)
                return
            end
        end
        addTerminalLine("userdel: user '" .. args[2] .. "' does not exist", colors.red)
    end,
}

-- ---------- окружение ----------
terminalCommands["export"] = {
    desc = "Set an environment variable",
    usage = "export NAME=value",
    action = function(args)
        local spec = table.concat(args, " ", 2)
        local name, value = spec:match("^([%a_][%w_]*)=(.*)$")
        if not name then usage("export") return end
        env[name] = value
    end,
}

terminalCommands["env"] = {
    desc = "Print environment variables",
    action = function()
        local all = {
            USER = currentUser.name, HOME = homeOf(currentUser), PWD = currentPath,
            HOSTNAME = currentHost, SHELL = currentUser.shell,
        }
        for k, v in pairs(env) do all[k] = v end
        for _, key in ipairs(sortedKeys(all)) do
            addTerminalLine(key .. "=" .. tostring(all[key]), colors.text)
        end
    end,
}

terminalCommands["alias"] = {
    desc = "Define or list command aliases",
    usage = "alias [name='command']",
    action = function(args)
        if not args[2] then
            for _, name in ipairs(sortedKeys(aliases)) do
                addTerminalLine("alias " .. name .. "='" .. aliases[name] .. "'", colors.text)
            end
            return
        end
        local spec = table.concat(args, " ", 2)
        local name, value = spec:match("^([%w_%.%-]+)=(.*)$")
        if name then
            aliases[name] = value
        elseif aliases[spec] then
            addTerminalLine("alias " .. spec .. "='" .. aliases[spec] .. "'", colors.text)
        else
            addTerminalLine("alias: " .. spec .. ": not found", colors.red)
        end
    end,
}

terminalCommands["unalias"] = {
    desc = "Remove an alias",
    usage = "unalias <name>",
    action = function(args)
        if not args[2] then usage("unalias") return end
        if aliases[args[2]] then
            aliases[args[2]] = nil
        else
            addTerminalLine("unalias: " .. args[2] .. ": not found", colors.red)
        end
    end,
}

terminalCommands["history"] = {
    desc = "Show command history",
    action = function()
        for i, cmd in ipairs(commandHistory) do
            addTerminalLine(string.format("%4d  %s", i, cmd), colors.text)
        end
    end,
}

-- ---------- процессы и время ----------
terminalCommands["sleep"] = {
    desc = "Wait N seconds (try: sleep 30 &)",
    usage = "sleep <seconds>",
    action = function(args, ctx)
        local secs = tonumber(args[2])
        if not secs then usage("sleep") return end
        local waited = 0
        while waited < secs and not stopRequested(ctx) do
            task.wait(0.1)
            waited = waited + 0.1
        end
    end,
}

terminalCommands["yes"] = {
    desc = "Repeat text until interrupted (Ctrl+C / Enter / kill)",
    usage = "yes [text]",
    action = function(args, ctx)
        local text = #args > 1 and table.concat(args, " ", 2) or "y"
        local n = 0
        while not stopRequested(ctx) and n < 2000 do
            addTerminalLine(text, colors.text)
            n = n + 1
            task.wait(0.05)
        end
    end,
}

terminalCommands["watch"] = {
    desc = "Run a command repeatedly (Ctrl+C / Enter to stop)",
    usage = "watch [-n sec] <command>",
    action = function(args, ctx)
        local interval, idx = 2, 2
        if args[2] == "-n" then
            interval = tonumber(args[3]) or 2
            idx = 4
        end
        local cmd = table.concat(args, " ", idx)
        if cmd == "" then usage("watch") return end
        local runs = 0
        while not stopRequested(ctx) and runs < 300 do
            renderSuspended = true
            terminalLines = {}
            addTerminalLine("Every " .. interval .. "s: " .. cmd .. "    " .. os.date("%H:%M:%S"), colors.green)
            executeLine(cmd, 1)
            renderSuspended = false
            updateTerminalDisplay()
            runs = runs + 1
            local waited = 0
            while waited < interval and not stopRequested(ctx) do
                task.wait(0.1)
                waited = waited + 0.1
            end
        end
    end,
}

local function renderTop()
    renderSuspended = true
    terminalLines = {}
    local ping, mem = getPingMs(), getMemoryMb()
    addTerminalLine(string.format("top - %s  up %s  fps %d", os.date("%H:%M:%S"), uptimeString(), fps), colors.green)
    addTerminalLine(string.format("Players: %d   Ping: %s   Mem: %s", #game.Players:GetPlayers(),
        ping and (ping .. " ms") or "n/a", mem and (mem .. " MB") or "n/a"), colors.text)
    addTerminalLine("Tasks: " .. #kernel.processes .. " total   (Enter / Ctrl+C to quit)", colors.text)
    addTerminalLine("  PID USER       CPU%  MEM%  COMMAND", colors.amber)
    for i, proc in ipairs(kernel.processes) do
        if i > 12 then break end
        local cpu = proc.system and math.random(0, 3) or math.random(1, 40)
        local memory = proc.system and math.random(1, 4) or math.random(1, 9)
        addTerminalLine(string.format("%5d %-10s %4d  %4d  %s", proc.pid, proc.user or "root", cpu, memory, proc.name), colors.text)
    end
    renderSuspended = false
    updateTerminalDisplay()
end

local function topAction(args, ctx)
    local frames = 0
    while not stopRequested(ctx) and frames < 120 do
        renderTop()
        frames = frames + 1
        local waited = 0
        while waited < 1 and not stopRequested(ctx) do
            task.wait(0.1)
            waited = waited + 0.1
        end
    end
    addTerminalLine("top: stopped", colors.gray)
end

terminalCommands["top"] = {desc = "Live process and system monitor", action = topAction}
terminalCommands["htop"] = {desc = "Live process and system monitor", action = topAction}

terminalCommands["uptime"] = {
    desc = "Time since boot",
    action = function()
        addTerminalLine((captureBuffer and "" or "⏱️ ") .. "up " .. uptimeString(), colors.green)
    end,
}

terminalCommands["neofetch"] = {
    desc = "System information",
    action = function()
        local machine = machines[currentHost]
        local distro = machine and machine.distro or kernel.distro
        local mem = getMemoryMb()
        addTerminalLine("        .-.        " .. currentUser.name .. "@" .. currentHost, colors.green)
        addTerminalLine("       (o o)       ----------------", colors.green)
        addTerminalLine("       | O \\       OS: " .. distro .. " " .. kernel.architecture, colors.green)
        addTerminalLine("        \\   \\      Kernel: " .. kernel.name .. " " .. kernel.version, colors.green)
        addTerminalLine("         `~~~'     Uptime: " .. uptimeString(), colors.green)
        addTerminalLine("                   Shell: " .. (currentUser.shell or "/bin/bash"), colors.text)
        addTerminalLine("                   Theme: " .. currentThemeName, colors.text)
        local packageCount = 0
        for _ in pairs(installed) do packageCount = packageCount + 1 end
        addTerminalLine("                   Packages: " .. packageCount, colors.text)
        addTerminalLine("                   Memory: " .. (mem and (mem .. " MiB") or "n/a") .. " / 16384 MiB", colors.text)
    end,
}

-- ---------- скрипты ----------
local function bashAction(args, ctx)
    if args[2] == "-c" then
        runScriptText(args[3] or "", (ctx and ctx.depth) or 0, {})
    elseif args[2] then
        local callArgs = {}
        for i = 3, #args do callArgs[#callArgs + 1] = args[i] end
        runScript(args[2], (ctx and ctx.depth) or 0, callArgs)
    else
        addTerminalLine("GNU bash 5.2 — usage: bash <script> | bash -c \"cmd1; cmd2\"", colors.text)
    end
end
terminalCommands["bash"] = {desc = "Run a script or command line", usage = "bash <script> | bash -c \"cmds\"", action = bashAction}
terminalCommands["sh"] = {desc = "Run a script or command line", usage = "sh <script> | sh -c \"cmds\"", action = bashAction}
terminalCommands["source"] = {desc = "Run a script", usage = "source <script>", action = bashAction}
terminalCommands["."] = {desc = "Run a script (same as source)", usage = ". <script>", action = bashAction}

-- ---------- графика, темы, сохранение ----------
terminalCommands["startx"] = {
    desc = "Start the X11 desktop (windows: Files, Clock, Monitor, Notes)",
    action = function() openDesktop("X11") end,
}
terminalCommands["wayland"] = {
    desc = "Start the Wayland desktop",
    action = function() openDesktop("Wayland") end,
}
terminalCommands["stopx"] = {
    desc = "Stop the graphical desktop",
    action = function() closeDesktop() end,
}

terminalCommands["theme"] = {
    desc = "Change terminal colors",
    usage = "theme [classic|amber|cyberpunk|ice]",
    action = function(args)
        if not args[2] then
            addTerminalLine("🎨 Themes:", colors.green)
            for _, name in ipairs(sortedKeys(themes)) do
                addTerminalLine("  " .. name .. (name == currentThemeName and "   (current)" or ""), colors.text)
            end
            return
        end
        if applyTheme(args[2]) then
            addTerminalLine("🎨 Theme: " .. args[2], colors.green)
        else
            addTerminalLine("❌ Unknown theme: " .. args[2], colors.red)
        end
    end,
}

terminalCommands["save"] = {
    desc = "Save the filesystem and settings (needs Outpost3Save.server.lua)",
    action = function()
        if saveState(false) then addTerminalLine("💾 State saved", colors.green) end
    end,
}
terminalCommands["load"] = {
    desc = "Load the saved filesystem and settings",
    action = function()
        if loadState(false) then addTerminalLine("💾 State restored", colors.green) end
    end,
}

-- ---------- ssh ----------
terminalCommands["ssh"] = {
    desc = "Connect to another machine (kali, arch, blackarch)",
    usage = "ssh [user@]<host>   hosts: kali, arch, blackarch",
    action = function(args)
        local target = args[2]
        if not target then usage("ssh") return end
        local userName, host = target:match("^(.-)@(.+)$")
        if not host then
            host, userName = target, currentUser.name
        end
        local machine = machines[host]
        if not machine then
            if host == currentHost then
                addTerminalLine("ssh: you are already on " .. host, colors.amber)
            else
                addTerminalLine("ssh: Could not resolve hostname " .. host .. ": Name or service not known", colors.red)
            end
            return
        end
        addTerminalLine("🔗 Connecting to " .. host .. " (" .. machine.ip .. ")...", colors.green)
        task.wait(0.4)
        local remoteUser
        for _, u in ipairs(machine.users) do
            if u.name == userName then remoteUser = u end
        end
        if not remoteUser then
            addTerminalLine(userName .. "@" .. host .. ": Permission denied (publickey,password).", colors.red)
            return
        end
        if not askPassword(remoteUser, userName .. "@" .. host .. "'s password: ") then return end
        table.insert(sshStack, {fs = fileSystem, users = users, user = currentUser, root = isRoot, path = currentPath, host = currentHost})
        fileSystem, users, currentUser, isRoot, currentPath, currentHost =
            machine.fs, machine.users, remoteUser, remoteUser.is_root == true, homeOf(remoteUser), host
        syslog("sshd", "Accepted password for " .. userName .. " from 192.168.1.100 port 52" .. math.random(100, 999), true)
        addTerminalLine("✅ Connected to " .. host .. " — " .. machine.distro, colors.green)
        addTerminalLine("   Last login: " .. os.date("%a %b %d %H:%M:%S") .. " from 192.168.1.100", colors.gray)
        addTerminalLine("   Type 'exit' to close the connection.", colors.gray)
    end,
}

terminalCommands["exit"] = {
    desc = "Close ssh session, or close the terminal (in scripts: stop the script)",
    usage = "exit [code]",
    action = function(args, ctx)
        if ctx and ctx.depth and ctx.depth > 0 then
            scriptExit = {kind = "exit", code = tonumber(args[2]) or lastStatus}
            return
        end
        if #sshStack > 0 then
            local host = currentHost
            popSsh()
            addTerminalLine("Connection to " .. host .. " closed.", colors.amber)
        else
            addTerminalLine("🖥️ Terminal closed", colors.gray)
            setTerminalActive(false)
        end
    end,
}

-- ---------- пакетные менеджеры (общая реализация apt / pacman) ----------
local function makePackageManager(title, summary, ops)
    return {
        desc = title,
        usage = summary,
        action = function(args)
            local op = args[2]
            if not op then
                addTerminalLine("📦 " .. title, colors.green)
                addTerminalLine("   " .. summary, colors.text)
                return
            end
            local kind = ops[op]
            if not kind then
                addTerminalLine("❌ Unknown operation: " .. op, colors.red)
                return
            end
            if kind ~= "list" and kind ~= "search" and not checkRoot() then return end

            if kind == "update" then
                addTerminalLine("[+] Updating package lists...", colors.green)
                task.wait(0.5)
                addTerminalLine("[✓] Package lists are up to date", colors.green)
            elseif kind == "upgrade" then
                addTerminalLine("[+] Checking for upgrades...", colors.green)
                task.wait(0.5)
                addTerminalLine("[✓] 0 upgraded, 0 newly installed", colors.green)
            elseif kind == "install" then
                if not args[3] then usage(args[1]) return end
                for i = 3, #args do
                    local pkg = args[i]
                    if installed[pkg] then
                        addTerminalLine("ℹ️ " .. pkg .. " is already installed", colors.amber)
                    elseif not repo[pkg] then
                        addTerminalLine("E: Unable to locate package " .. pkg, colors.red)
                    else
                        addTerminalLine("[+] Installing " .. pkg .. "...", colors.green)
                        task.wait(0.5)
                        installed[pkg] = repo[pkg]
                        syslog("apt", "installed " .. pkg .. " " .. repo[pkg])
                        local bin = getPathObject("/usr/bin")
                        if bin and bin.type == "dir" then
                            bin.children[pkg] = {type = "file", owner = "root", mode = "755", content = "#!/bin/sh\n# " .. pkg .. " " .. repo[pkg]}
                        end
                        addTerminalLine("[✓] " .. pkg .. " " .. repo[pkg] .. " installed", colors.green)
                    end
                end
            elseif kind == "remove" then
                if not args[3] then usage(args[1]) return end
                for i = 3, #args do
                    local pkg = args[i]
                    if protectedPackages[pkg] then
                        addTerminalLine("E: " .. pkg .. " is essential and cannot be removed", colors.red)
                    elseif not installed[pkg] then
                        addTerminalLine("E: " .. pkg .. " is not installed", colors.red)
                    else
                        installed[pkg] = nil
                        syslog("apt", "removed " .. pkg)
                        local bin = getPathObject("/usr/bin")
                        if bin and bin.type == "dir" then bin.children[pkg] = nil end
                        addTerminalLine("[✓] " .. pkg .. " removed", colors.green)
                    end
                end
            elseif kind == "list" then
                for _, pkg in ipairs(sortedKeys(installed)) do
                    addTerminalLine(pkg .. " " .. installed[pkg], colors.text)
                end
            elseif kind == "search" then
                local query = args[3] or ""
                local seen = {}
                for _, source in ipairs({repo, installed}) do
                    for _, pkg in ipairs(sortedKeys(source)) do
                        if not seen[pkg] and pkg:find(query, 1, true) then
                            seen[pkg] = true
                            addTerminalLine(pkg .. " " .. source[pkg] .. (installed[pkg] and "  [installed]" or ""), colors.text)
                        end
                    end
                end
            end
        end,
    }
end

terminalCommands["apt"] = makePackageManager("APT package manager",
    "apt update | upgrade | install <pkg> | remove <pkg> | list | search <text>  (install/remove need root)",
    {update = "update", upgrade = "upgrade", install = "install", remove = "remove", list = "list", search = "search"})
terminalCommands["pacman"] = makePackageManager("Pacman package manager",
    "pacman -Sy | -Syu | -S <pkg> | -R <pkg> | -Q | -Ss <text>  (install/remove need root)",
    {["-Sy"] = "update", ["-Syu"] = "upgrade", ["-S"] = "install", ["-R"] = "remove", ["-Q"] = "list", ["-Ss"] = "search"})

-- ---------- загрузчик с рабочей автозагрузкой ----------
local AUTOBOOT_SECONDS = 5

local function runAutoBoot(seconds)
    bootToken = bootToken + 1
    local token = bootToken
    autoBootActive = true
    local line = addTerminalLine("  Auto-booting in " .. seconds .. "s  (any command cancels)", colors.amber)
    task.spawn(function()
        for remaining = seconds, 1, -1 do
            if bootToken ~= token then return end
            if line then
                line.text = "  Auto-booting in " .. remaining .. "s  (any command cancels)"
                updateTerminalDisplay()
            end
            task.wait(1)
        end
        if bootToken ~= token then return end
        autoBootActive = false
        bootEntry(bootloader.default_entry)
    end)
end

terminalCommands["reboot"] = {
    desc = "Reboot to the bootloader (auto-boots after 5s)",
    action = function()
        while #sshStack > 0 do popSsh() end
        syslog("systemd", "System is rebooting.")
        addTerminalLine("🔄 Rebooting system...", colors.amber)
        task.wait(0.5)
        terminalLines = {}
        showBootloader()
        runAutoBoot(AUTOBOOT_SECONDS)
    end,
}

terminalCommands["shutdown"] = {
    desc = "Save and power off (closes the terminal)",
    action = function()
        while #sshStack > 0 do popSsh() end
        syslog("systemd", "System is powering off.")
        addTerminalLine("⏹️ Shutting down system...", colors.amber)
        task.wait(0.5)
        if saveState then saveState(true) end
        addTerminalLine("[✓] System powered off!", colors.green)
        if closeDesktop and desktopGui then closeDesktop() end
        setTerminalActive(false)
    end,
}

local function bootMenuAction()
    showBootloader()
    addTerminalLine("  (auto-boot is only used after 'reboot')", colors.gray)
end
terminalCommands["boot"] = {desc = "Show the bootloader menu", action = bootMenuAction}
terminalCommands["menu"] = {desc = "Show the bootloader menu", action = bootMenuAction}
end

-- ============================================================
-- ===== 11e. ПАНЕЛИ-СЕССИИ (tmux-подобно), CRT, ЗВУК =====
-- ============================================================
-- Каждая сессия — отдельная «оболочка»: свои строки, ввод, папка, история и даже ssh-соединение.
local initSessions

do
local function captureSession()
    return {
        lines = terminalLines, input = currentInput, scroll = scrollOffset, path = currentPath,
        fs = fileSystem, users = users, user = currentUser, root = isRoot, host = currentHost, ssh = sshStack,
        history = commandHistory, histIndex = historyIndex, prompt = getPrompt(),
    }
end

local function applySession(s)
    terminalLines, currentInput, scrollOffset, currentPath = s.lines, s.input, s.scroll, s.path
    fileSystem, users, currentUser, isRoot, currentHost, sshStack = s.fs, s.users, s.user, s.root, s.host, s.ssh
    commandHistory, historyIndex = s.history, s.histIndex
end

-- force = true: переключение из самой команды (busy уже выставлен)
switchSession = function(n, force)
    if n < 1 or n > NUM_SESSIONS then return false end
    if n == activeSession then return true end
    if busy and not force then
        addTerminalLine("⚠️ Wait for the running command to finish before switching panes", colors.amber)
        return false
    end
    sessions[activeSession] = captureSession()
    applySession(sessions[n])
    activeSession = n
    if inputBox and inputBox.Text ~= currentInput then inputBox.Text = currentInput end
    updateTerminalDisplay()
    return true
end

setPaneMode = function(on)
    paneMode = on
    updateTerminalDisplay()
end

initSessions = function()
    for n = 1, NUM_SESSIONS do
        if n ~= activeSession then
            sessions[n] = {
                lines = {{text = "Pane " .. n .. " — shell ready. Press Ctrl+" .. n .. " to focus.", color = colors.gray}},
                input = "", scroll = 0, path = currentPath,
                fs = localMachine.fs, users = localMachine.users, user = currentUser, root = isRoot, host = "outpost3",
                ssh = {}, history = {}, histIndex = 1, prompt = getPrompt(),
            }
        end
    end
end

local function paneAction(args)
    local a = args[2]
    if not a then
        addTerminalLine("🪟 Panes: active " .. activeSession .. "/" .. NUM_SESSIONS .. " — mode: " .. (paneMode and "split (each panel = own shell)" or "mirror (all panels show the active shell)"), colors.green)
        addTerminalLine("   pane <1-3> | pane split | pane mirror     keys: Ctrl+1..3, Ctrl+0", colors.gray)
        return
    end
    if a == "split" then
        setPaneMode(true)
    elseif a == "mirror" then
        setPaneMode(false)
    elseif tonumber(a) then
        if not switchSession(tonumber(a), true) then usage("pane") end
    else
        usage("pane")
    end
end
terminalCommands["pane"] = {desc = "Switch / split terminal panes (like tmux)", usage = "pane [1|2|3|split|mirror]   (Ctrl+1..3, Ctrl+0)", action = paneAction}
terminalCommands["tmux"] = {desc = "Alias of pane (tmux-like panes)", usage = "tmux [1|2|3|split|mirror]", action = paneAction}

terminalCommands["crt"] = {
    desc = "CRT scanlines and flicker on the panels",
    usage = "crt [on|off]",
    action = function(args)
        local want
        if args[2] == "on" then want = true elseif args[2] == "off" then want = false else want = not crtEnabled end
        setCrt(want)
        addTerminalLine("📺 CRT effect " .. (crtEnabled and "ON" or "OFF"), colors.green)
    end,
}

terminalCommands["sound"] = {
    desc = "Key click and boot sounds (set SOUND_IDS in Main.lua first)",
    usage = "sound [on|off]",
    action = function(args)
        local want
        if args[2] == "on" then want = true elseif args[2] == "off" then want = false else want = nil end
        addTerminalLine("🔊 " .. setSoundEnabled(want), colors.green)
    end,
}
end

-- ============================================================
-- ===== 12. СОЗДАНИЕ 3D ПАНЕЛЕЙ =====
-- ============================================================
local function createPanel(name, offset, logo, info)
    local panel = Instance.new("Part")
    panel.Name = name
    panel.Size = Vector3.new(6.5, 4.5, 0.1)
    panel.Color = colors.bg
    panel.Material = Enum.Material.SmoothPlastic
    panel.Transparency = 0
    panel.CanCollide = false
    panel.CanQuery = false
    panel.CanTouch = false
    panel.Massless = true      -- панели не утяжеляют персонажа
    panel.Anchored = false
    panel.CFrame = hrp.CFrame * offset
    panel.Parent = panelFolder

    -- ИСПРАВЛЕНО: раньше Part1 присваивался самой панели (ошибка)
    local weld = Instance.new("WeldConstraint")
    weld.Part0 = panel
    weld.Part1 = hrp
    weld.Parent = panel

    local highlight = Instance.new("Highlight")
    highlight.FillColor = colors.green
    highlight.FillTransparency = 0.9
    highlight.OutlineColor = colors.green
    highlight.OutlineTransparency = 0.2
    highlight.Parent = panel

    -- Передняя сторона
    local fg = Instance.new("SurfaceGui")
    fg.Face = Enum.NormalId.Front
    fg.AlwaysOnTop = true
    fg.CanvasSize = Vector2.new(650, 450)
    fg.Parent = panel

    local logoL = Instance.new("TextLabel")
    logoL.Size = UDim2.new(1, 0, 0.2, 0)
    logoL.BackgroundTransparency = 1
    logoL.TextColor3 = colors.green
    logoL.Font = Enum.Font.GothamBold
    logoL.TextSize = 24
    logoL.Text = logo
    logoL.TextXAlignment = Enum.TextXAlignment.Center
    logoL.Parent = fg

    local infoL = Instance.new("TextLabel")
    infoL.Size = UDim2.new(0.95, 0, 0.75, 0)
    infoL.Position = UDim2.new(0.025, 0, 0.22, 0)
    infoL.BackgroundTransparency = 1
    infoL.TextColor3 = colors.text
    infoL.Font = Enum.Font.Code
    infoL.TextSize = 11
    infoL.Text = info
    infoL.TextXAlignment = Enum.TextXAlignment.Left
    infoL.TextYAlignment = Enum.TextYAlignment.Top
    infoL.TextWrapped = true
    infoL.Parent = fg

    -- Задняя сторона (терминал)
    local bg = Instance.new("SurfaceGui")
    bg.Face = Enum.NormalId.Back
    bg.AlwaysOnTop = true
    bg.CanvasSize = Vector2.new(600, 400)
    bg.Parent = panel

    local hdr = Instance.new("TextLabel")
    hdr.Size = UDim2.new(1, 0, 0.06, 0)
    hdr.BackgroundTransparency = 1
    hdr.TextColor3 = colors.green
    hdr.Font = Enum.Font.Code
    hdr.TextSize = 11
    hdr.Text = "╔══ TERMINAL ═══════════════════════════════════════════════════╗"
    hdr.TextXAlignment = Enum.TextXAlignment.Left
    hdr.Parent = bg
    table.insert(terminalHeaders, hdr)

    local out = Instance.new("TextLabel")
    out.Name = "TerminalOutput"
    out.Size = UDim2.new(0.95, 0, 0.86, 0)
    out.Position = UDim2.new(0.025, 0, 0.07, 0)
    out.BackgroundTransparency = 1
    out.TextColor3 = colors.text
    out.Font = Enum.Font.Code
    out.TextSize = 11
    out.TextWrapped = true
    out.RichText = true
    out.TextYAlignment = Enum.TextYAlignment.Top
    out.TextXAlignment = Enum.TextXAlignment.Left
    out.Text = ""
    out.Parent = bg

    local ftr = Instance.new("TextLabel")
    ftr.Size = UDim2.new(1, 0, 0.04, 0)
    ftr.Position = UDim2.new(0, 0, 0.96, 0)
    ftr.BackgroundTransparency = 1
    ftr.TextColor3 = colors.green
    ftr.Font = Enum.Font.Code
    ftr.TextSize = 11
    ftr.Text = "╚════════════════════════════════════════════════════════════════╝"
    ftr.TextXAlignment = Enum.TextXAlignment.Left
    ftr.Parent = bg
    table.insert(terminalFooters, ftr)

    -- CRT: полупрозрачные линии поверх терминала (команда `crt off` их скрывает)
    local scan = Instance.new("Frame")
    scan.Name = "Scanlines"
    scan.Size = UDim2.fromScale(1, 1)
    scan.BackgroundTransparency = 1
    scan.ZIndex = 50
    scan.Visible = crtEnabled
    scan.Parent = bg
    for y = 0, 396, 4 do
        local stripe = Instance.new("Frame")
        stripe.Size = UDim2.new(1, 0, 0, 1)
        stripe.Position = UDim2.new(0, 0, 0, y)
        stripe.BackgroundColor3 = Color3.new(0, 0, 0)
        stripe.BackgroundTransparency = 0.8
        stripe.BorderSizePixel = 0
        stripe.ZIndex = 50
        stripe.Parent = scan
    end

    -- Кэшируем лейбл терминала, чтобы не обходить GetChildren() при каждом обновлении
    table.insert(terminalLabels, out)
    return infoL
end

-- Логотипы
-- Логотипы
local l1 = [[
██╗  ██╗ █████╗ ██╗     ██╗     ██╗███╗   ██╗██╗   ██╗
██║ ██╔╝██╔══██╗██║     ██║     ██║████╗  ██║╚██╗ ██╔╝
█████╔╝ ███████║██║     ██║     ██║██╔██╗ ██║ ╚████╔╝
██╔═██╗ ██╔══██║██║     ██║     ██║██║╚██╗██║  ╚██╔╝
██║  ██╗██║  ██║███████╗███████╗██║██║ ╚████║   ██║
╚═╝  ╚═╝╚═╝  ╚═╝╚══════╝╚══════╝╚═╝╚═╝  ╚═══╝   ╚═╝
]]

local l2 = [[
█████╗ ██████╗  ██████╗██╗  ██╗
██╔══██╗██╔══██╗██╔════╝██║  ██║
███████║██████╔╝██║     ███████║
██╔══██║██╔══██╗██║     ██╔══██║
██║  ██║██║  ██║╚██████╗██║  ██║
╚═╝  ╚═╝╚═╝  ╚═╝ ╚═════╝╚═╝  ╚═╝
]]

local l3 = [[
██████╗ ██╗      █████╗  ██████╗██╗  ██╗
██╔══██╗██║     ██╔══██╗██╔════╝██║  ██║
██████╔╝██║     ███████║██║     ███████║
██╔══██╗██║     ██╔══██║██║     ██╔══██║
██████╔╝███████╗██║  ██║╚██████╗██║  ██║
╚═════╝ ╚══════╝╚═╝  ╚═╝ ╚═════╝╚═╝  ╚═╝
]]

-- ============================================================
-- ===== 13. ПЕРСОНАЖ, ЭФФЕКТЫ И МОНИТОРИНГ =====
-- ============================================================
local FLY_SPEED = 50
local flyAttachment, flyVelocity, flyAlign
local originalTransparency = {}
local panelsVisible = true

local function onoff(v)
    return v and "🟢 ON" or "🔴 OFF"
end

local function stopFly()
    state.fly = false
    if flyVelocity then flyVelocity:Destroy() end
    if flyAlign then flyAlign:Destroy() end
    if flyAttachment then flyAttachment:Destroy() end
    flyVelocity, flyAlign, flyAttachment = nil, nil, nil
    if hum and hum.Parent then hum.PlatformStand = false end
end

local function startFly()
    state.fly = true
    flyAttachment = Instance.new("Attachment")
    flyAttachment.Parent = hrp

    flyVelocity = Instance.new("LinearVelocity")
    flyVelocity.Attachment0 = flyAttachment
    flyVelocity.RelativeTo = Enum.ActuatorRelativeTo.World
    flyVelocity.MaxForce = math.huge
    flyVelocity.VectorVelocity = Vector3.new(0, 0, 0)
    flyVelocity.Parent = hrp

    -- держит персонажа вертикально, пока PlatformStand отключает стандартное управление
    flyAlign = Instance.new("AlignOrientation")
    flyAlign.Mode = Enum.OrientationAlignmentMode.OneAttachment
    flyAlign.Attachment0 = flyAttachment
    flyAlign.RigidityEnabled = true
    flyAlign.CFrame = hrp.CFrame.Rotation
    flyAlign.Parent = hrp

    hum.PlatformStand = true
end

local function setNoclip(on)
    state.noclip = on
    if not on and player.Character then
        -- Humanoid сам вернёт коллизии остальным частям; восстанавливаем основные
        for _, name in ipairs({"HumanoidRootPart", "Head", "Torso", "UpperTorso", "LowerTorso"}) do
            local part = player.Character:FindFirstChild(name)
            if part then part.CanCollide = true end
        end
    end
end

local function setInvisible(on)
    state.invis = on
    local char = player.Character
    if not char then return end
    for _, obj in ipairs(char:GetDescendants()) do
        if obj:IsA("BasePart") or obj:IsA("Decal") then
            if on then
                if originalTransparency[obj] == nil then
                    originalTransparency[obj] = obj.Transparency
                end
                obj.Transparency = 1
            else
                -- ИСПРАВЛЕНО: возвращаем исходную прозрачность (HumanoidRootPart раньше становился видимым)
                local orig = originalTransparency[obj]
                if orig ~= nil then obj.Transparency = orig end
            end
        end
    end
    if not on then originalTransparency = {} end
end

local function setGod(on)
    state.god = on
    hum:SetStateEnabled(Enum.HumanoidStateType.Dead, not on)
    hum.BreakJointsOnDeath = not on
end

local function setPanelsVisible(visible)
    if not panelFolder then return end
    for _, p in ipairs(panelFolder:GetChildren()) do
        p.Transparency = visible and 0 or 1
        for _, child in ipairs(p:GetChildren()) do
            if child:IsA("SurfaceGui") or child:IsA("Highlight") then
                child.Enabled = visible
            end
        end
    end
end

-- Полёт: движение по направлению камеры (W/A/S/D, Space вверх, Ctrl вниз)
runService.RenderStepped:Connect(function()
    if not state.fly or not flyVelocity or not flyVelocity.Parent then return end
    local cam = workspace.CurrentCamera
    local move = Vector3.new(0, 0, 0)
    if not terminalActive then
        if uis:IsKeyDown(Enum.KeyCode.W) then move = move + cam.CFrame.LookVector end
        if uis:IsKeyDown(Enum.KeyCode.S) then move = move - cam.CFrame.LookVector end
        if uis:IsKeyDown(Enum.KeyCode.D) then move = move + cam.CFrame.RightVector end
        if uis:IsKeyDown(Enum.KeyCode.A) then move = move - cam.CFrame.RightVector end
        if uis:IsKeyDown(Enum.KeyCode.Space) then move = move + Vector3.new(0, 1, 0) end
        if uis:IsKeyDown(Enum.KeyCode.LeftControl) then move = move - Vector3.new(0, 1, 0) end
    end
    if move.Magnitude > 0 then move = move.Unit end
    flyVelocity.VectorVelocity = move * FLY_SPEED * state.speed

    local look = cam.CFrame.LookVector
    local flat = Vector3.new(look.X, 0, look.Z)
    if flyAlign and flat.Magnitude > 0.01 then
        flyAlign.CFrame = CFrame.lookAt(Vector3.new(0, 0, 0), flat)
    end
end)

-- Noclip: Roblox каждый шаг физики возвращает CanCollide, поэтому отключаем его в Stepped
runService.Stepped:Connect(function()
    if not state.noclip then return end
    local char = player.Character
    if not char then return end
    for _, part in ipairs(char:GetDescendants()) do
        if part:IsA("BasePart") then part.CanCollide = false end
    end
end)

-- Создание панелей для нового персонажа (вызывается при каждом респауне)
local function setupCharacter(char)
    -- сбрасываем эффекты прошлого персонажа
    state.fly, state.god, state.noclip, state.invis, state.speed = false, false, false, false, 1
    originalTransparency = {}
    flyVelocity, flyAlign, flyAttachment = nil, nil, nil

    hrp = char:WaitForChild("HumanoidRootPart")
    hum = char:WaitForChild("Humanoid")
    baseWalkSpeed = hum.WalkSpeed

    -- ИСПРАВЛЕНО: старые панели лежат в папке MDPanels, её и удаляем (в том числе от прошлого запуска скрипта)
    local old = workspace:FindFirstChild("MDPanels")
    if old then old:Destroy() end
    panelFolder = Instance.new("Folder")
    panelFolder.Name = "MDPanels"
    panelFolder.Parent = workspace

    terminalLabels = {}
    terminalHeaders, terminalFooters = {}, {}
    i1 = createPanel("MDPanel_Kali", CFrame.new(-7.0, 2.0, -5.0) * CFrame.Angles(0, math.rad(25), 0), "🦞 KALI LINUX", l1 .. "\n\n[STATUS]: LOADING...")
    i2 = createPanel("MDPanel_Arch", CFrame.new(0, 2.0, -6.0), "🐧 ARCH LINUX", l2 .. "\n\n[STATUS]: LOADING...")
    i3 = createPanel("MDPanel_BlackArch", CFrame.new(7.0, 2.0, -5.0) * CFrame.Angles(0, math.rad(-25), 0), "💀 BLACKARCH", l3 .. "\n\n[STATUS]: LOADING...")
    updateTerminalDisplay()
end

-- Мониторинг: FPS считаем каждый кадр, текст панелей обновляем 5 раз в секунду
local accum = 0
monitorConnection = runService.Heartbeat:Connect(function(dt)
    if not hrp or not hrp.Parent or not hum or not hum.Parent then return end

    frameCount = frameCount + 1
    if tick() - lastFpsUpdate >= 1 then
        fps = frameCount
        frameCount = 0
        lastFpsUpdate = tick()
    end

    if state.god and hum.Health < hum.MaxHealth then
        hum.Health = hum.MaxHealth
    end

    accum = accum + dt
    if accum < 0.2 then return end
    accum = 0

    -- статус-строки панелей и лёгкое мерцание CRT
    local footer = string.format("╚═ %s@%s ═ %s ═ %d/%d ═ %s ═══════╝", currentUser.name, currentHost,
        paneMode and "split" or "mirror", activeSession, NUM_SESSIONS, os.date("%H:%M"))
    for _, ftr in ipairs(terminalFooters) do
        if ftr.Parent then ftr.Text = footer end
    end
    for _, lbl in ipairs(terminalLabels) do
        if lbl.Parent then
            lbl.TextTransparency = (crtEnabled and math.random() < 0.12) and 0.07 or 0
        end
    end

    local time = os.date("%H:%M:%S")
    local health = math.floor(hum.Health)
    local maxHealth = hum.MaxHealth
    local players = #game.Players:GetPlayers()
    local pos = hrp.Position
    local x, y, z = math.floor(pos.X), math.floor(pos.Y), math.floor(pos.Z)

    if i1 and i1.Parent then
        i1.Text = l1 .. string.format([[
[STATUS]: ACTIVE
[TIME]: %s
[FPS]: %d
[PLAYERS]: %d
[HP]: %d/%d
]], time, fps, players, health, maxHealth)
    end

    if i2 and i2.Parent then
        i2.Text = l2 .. string.format([[
[STATUS]: ACTIVE
[POS]: %d %d %d
[FLY]: %s
[GOD]: %s
]], x, y, z, onoff(state.fly), onoff(state.god))
    end

    if i3 and i3.Parent then
        i3.Text = l3 .. string.format([[
[STATUS]: ACTIVE
[NOCLIP]: %s
[INVIS]: %s
[SPEED]: x%d
]], onoff(state.noclip), onoff(state.invis), state.speed)
    end
end)


-- ============================================================
-- ===== 13a. ЭФФЕКТЫ: ЗВУК И CRT =====
-- ============================================================
-- Вставь сюда свои звуки в виде "rbxassetid://123456" (доступные твоему experience). Пустая строка = без звука.
do
local SOUND_IDS = {key = "", enter = "", boot = ""}
local soundEnabled = true
local soundCache = {}

playSound = function(name)
    local id = SOUND_IDS[name]
    if not soundEnabled or not id or id == "" then return end
    local sound = soundCache[name]
    if not sound then
        sound = Instance.new("Sound")
        sound.SoundId = id
        sound.Volume = (name == "boot") and 0.5 or 0.25
        sound.Parent = game:GetService("SoundService")
        soundCache[name] = sound
    end
    sound:Play()
end

setSoundEnabled = function(want)
    if want ~= nil then soundEnabled = want end
    local configured = false
    for _, id in pairs(SOUND_IDS) do
        if id ~= "" then configured = true end
    end
    return "sound " .. (soundEnabled and "ON" or "OFF") .. (configured and "" or "  (no SOUND_IDS set in Main.lua yet)")
end

setCrt = function(on)
    crtEnabled = on
    if panelFolder then
        for _, obj in ipairs(panelFolder:GetDescendants()) do
            if obj.Name == "Scanlines" then obj.Visible = on end
        end
    end
    if not on then
        for _, lbl in ipairs(terminalLabels) do
            if lbl.Parent then lbl.TextTransparency = 0 end
        end
    end
end
end

-- колесо мыши прокручивает терминал (пока он активен); камеру при этом не масштабирует
local function bindWheel(on)
    local ContextActionService = game:GetService("ContextActionService")
    if on then
        ContextActionService:BindActionAtPriority("Outpost3Wheel", function(_, state, input)
            if state == Enum.UserInputState.Change then
                scrollOffset = math.max(0, scrollOffset + (input.Position.Z > 0 and 3 or -3))
                updateTerminalDisplay()
            end
            return Enum.ContextActionResult.Sink
        end, false, Enum.ContextActionPriority.High.Value, Enum.UserInputType.MouseWheel)
    else
        ContextActionService:UnbindAction("Outpost3Wheel")
    end
end

-- ============================================================
-- ===== 13b. ТЕМЫ ОФОРМЛЕНИЯ =====
-- ============================================================
applyTheme = function(name)
    local theme = themes[name]
    if not theme then return false end

    -- карта "цвет -> имя" для старой темы
    local old = {}
    for key, c in pairs(colors) do old[c:ToHex()] = key end
    for key, c in pairs(theme) do colors[key] = c end

    for _, line in ipairs(terminalLines) do
        local key = old[line.color:ToHex()]
        if key then line.color = colors[key] end
    end

    local function remap(c)
        local key = old[c:ToHex()]
        return key and colors[key] or c
    end
    local function recolor(container)
        if not container then return end
        for _, d in ipairs(container:GetDescendants()) do
            if d:IsA("TextLabel") or d:IsA("TextButton") or d:IsA("TextBox") then
                d.TextColor3 = remap(d.TextColor3)
            elseif d:IsA("UIStroke") then
                d.Color = remap(d.Color)
            elseif d:IsA("Highlight") then
                d.FillColor = remap(d.FillColor)
                d.OutlineColor = remap(d.OutlineColor)
            end
        end
    end
    recolor(panelFolder)
    recolor(desktopGui)

    currentThemeName = name
    updateTerminalDisplay()
    return true
end

-- ============================================================
-- ===== 13c. РАБОЧИЙ СТОЛ (startx / wayland) =====
-- ============================================================
do
local desktopRoot
local taskbarList
local zCounter = 10
local clipboardItem = nil   -- {node=, name=} для Copy/Paste в файловом менеджере

local function mk(className, props, parent)
    local obj = Instance.new(className)
    for k, v in pairs(props) do obj[k] = v end
    obj.Parent = parent
    return obj
end

local function bringToFront(win)
    zCounter = zCounter + 1
    win.ZIndex = zCounter
end

-- Окно: заголовок, кнопки «развернуть» и «закрыть», кнопка на панели задач
local function makeWindow(title, size, position)
    zCounter = zCounter + 1
    local win = mk("Frame", {
        Size = size, Position = position, BackgroundColor3 = Color3.fromRGB(14, 18, 22),
        BorderSizePixel = 0, ZIndex = zCounter, Active = true,
    }, desktopRoot)
    mk("UIStroke", {Color = colors.green, Thickness = 1}, win)

    local bar = mk("Frame", {Size = UDim2.new(1, 0, 0, 26), BackgroundColor3 = Color3.fromRGB(26, 34, 30), BorderSizePixel = 0}, win)
    mk("TextLabel", {
        Size = UDim2.new(1, -60, 1, 0), BackgroundTransparency = 1, Text = "  " .. title,
        TextColor3 = colors.green, Font = Enum.Font.Code, TextSize = 14, TextXAlignment = Enum.TextXAlignment.Left,
    }, bar)
    local maxBtn = mk("TextButton", {
        Size = UDim2.new(0, 28, 1, 0), Position = UDim2.new(1, -58, 0, 0), BackgroundTransparency = 1,
        Text = "□", TextColor3 = colors.cyan, Font = Enum.Font.Code, TextSize = 16,
    }, bar)
    local closeBtn = mk("TextButton", {
        Size = UDim2.new(0, 28, 1, 0), Position = UDim2.new(1, -28, 0, 0), BackgroundTransparency = 1,
        Text = "✕", TextColor3 = colors.red, Font = Enum.Font.Code, TextSize = 14,
    }, bar)
    closeBtn.Activated:Connect(function() win:Destroy() end)

    local savedGeometry = nil
    maxBtn.Activated:Connect(function()
        if savedGeometry then
            win.Size, win.Position = savedGeometry.size, savedGeometry.position
            savedGeometry = nil
        else
            savedGeometry = {size = win.Size, position = win.Position}
            win.Size = UDim2.new(1, 0, 1, -36)
            win.Position = UDim2.new(0, 0, 0, 0)
        end
        bringToFront(win)
    end)

    -- кнопка на панели задач: свернуть / показать
    local taskButton
    if taskbarList then
        taskButton = mk("TextButton", {
            Size = UDim2.fromOffset(120, 28), BackgroundColor3 = Color3.fromRGB(26, 34, 30), Text = title:sub(1, 14),
            TextColor3 = colors.text, Font = Enum.Font.Code, TextSize = 13,
        }, taskbarList)
        taskButton.Activated:Connect(function()
            if win.Visible and win.ZIndex == zCounter then
                win.Visible = false
            else
                win.Visible = true
                bringToFront(win)
            end
        end)
    end

    local dragging, dragStart, startPos = false, nil, nil
    bar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = win.Position
            bringToFront(win)
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then dragging = false end
            end)
        end
    end)
    local moveConn = uis.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local delta = input.Position - dragStart
            win.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
    end)
    win.Destroying:Connect(function()
        moveConn:Disconnect()
        if taskButton then taskButton:Destroy() end
    end)

    local content = mk("Frame", {Size = UDim2.new(1, 0, 1, -26), Position = UDim2.new(0, 0, 0, 26), BackgroundTransparency = 1}, win)
    return win, content
end

local function styledBox(props, parent)
    local base = {
        BackgroundColor3 = Color3.fromRGB(10, 14, 16), TextColor3 = colors.text, PlaceholderColor3 = colors.gray,
        Font = Enum.Font.Code, TextSize = 14, ClearTextOnFocus = false, BorderSizePixel = 0,
        TextXAlignment = Enum.TextXAlignment.Left,
    }
    for k, v in pairs(props) do base[k] = v end
    return mk("TextBox", base, parent)
end

local function smallButton(text, order, parent, onClick)
    local btn = mk("TextButton", {
        Size = UDim2.fromOffset(54, 26), Text = text, LayoutOrder = order, BackgroundColor3 = Color3.fromRGB(26, 34, 30),
        TextColor3 = colors.text, Font = Enum.Font.Code, TextSize = 13, BorderSizePixel = 0,
    }, parent)
    btn.Activated:Connect(onClick)
    return btn
end

-- Текстовый редактор: открывает файл (или создаёт новый) и сохраняет с проверкой прав
local function openEditorWindow(path)
    local node = getPathObject(path)
    if node and node.type ~= "file" then return end
    local readable = (not node) or hasPerm(node, "r")
    local _, content = makeWindow("📝 " .. (path:match("([^/]+)$") or path), UDim2.fromOffset(440, 320),
        UDim2.fromOffset(200 + math.random(0, 80), 80 + math.random(0, 60)))
    local box = styledBox({
        Size = UDim2.new(1, -8, 1, -40), Position = UDim2.fromOffset(4, 4), MultiLine = true, TextWrapped = false,
        TextYAlignment = Enum.TextYAlignment.Top,
        Text = readable and (node and (node.content or "") or "") or "⛔ Permission denied",
    }, content)
    local status = mk("TextLabel", {
        Size = UDim2.new(1, -80, 0, 24), Position = UDim2.new(0, 64, 1, -28), BackgroundTransparency = 1, Text = path,
        TextColor3 = colors.gray, Font = Enum.Font.Code, TextSize = 12, TextXAlignment = Enum.TextXAlignment.Left,
    }, content)
    local saveBtn = smallButton("Save", 0, content, function()
        local ok, why = writeFile(path, box.Text, false)
        status.Text = ok and ("💾 Saved " .. path) or ("⛔ " .. tostring(why))
        status.TextColor3 = ok and colors.green or colors.red
    end)
    saveBtn.Position = UDim2.new(0, 4, 1, -30)
    if not readable then box.TextEditable = false end
end

-- Файловый менеджер: навигация, создание, удаление, копирование и вставка
local function openFiles()
    local _, content = makeWindow("📁 Files", UDim2.fromOffset(470, 350), UDim2.fromOffset(130, 50))
    local pathLabel = mk("TextLabel", {
        Size = UDim2.new(1, -8, 0, 20), Position = UDim2.fromOffset(4, 2), BackgroundTransparency = 1, Text = "",
        TextColor3 = colors.cyan, Font = Enum.Font.Code, TextSize = 14, TextXAlignment = Enum.TextXAlignment.Left,
    }, content)
    local toolbar = mk("Frame", {Size = UDim2.new(1, -8, 0, 26), Position = UDim2.fromOffset(4, 24), BackgroundTransparency = 1}, content)
    mk("UIListLayout", {FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder}, toolbar)
    local nameBox = styledBox({Size = UDim2.fromOffset(120, 26), Text = "", PlaceholderText = "name...", LayoutOrder = 0}, toolbar)
    local status = mk("TextLabel", {
        Size = UDim2.new(1, -8, 0, 18), Position = UDim2.new(0, 4, 1, -20), BackgroundTransparency = 1, Text = "",
        TextColor3 = colors.gray, Font = Enum.Font.Code, TextSize = 12, TextXAlignment = Enum.TextXAlignment.Left,
    }, content)
    local list = mk("ScrollingFrame", {
        Size = UDim2.new(1, -8, 1, -78), Position = UDim2.fromOffset(4, 54), BackgroundTransparency = 1,
        BorderSizePixel = 0, ScrollBarThickness = 6, AutomaticCanvasSize = Enum.AutomaticSize.Y, CanvasSize = UDim2.new(),
    }, content)
    mk("UIListLayout", {SortOrder = Enum.SortOrder.LayoutOrder}, list)

    local path = currentPath
    local selected = nil
    local refresh

    local function say(text, color)
        status.Text = text
        status.TextColor3 = color or colors.gray
    end
    local function currentDir()
        local node = getPathObject(path)
        if node and node.type == "dir" then return node end
        return nil
    end
    local function fullPath(name)
        return (path == "/" and "" or path) .. "/" .. name
    end
    local function createEntry(kind)
        local name = trim(nameBox.Text)
        local dir = currentDir()
        if name == "" or name:find("/", 1, true) then say("Enter a valid name first", colors.amber) return end
        if not dir then return end
        if dir.children[name] then say("⛔ '" .. name .. "' already exists", colors.red) return end
        if not hasPerm(dir, "w") then say("⛔ Permission denied", colors.red) return end
        dir.children[name] = newNode(kind)
        nameBox.Text = ""
        refresh(path)
        say("Created " .. name, colors.green)
    end

    smallButton("+File", 1, toolbar, function() createEntry("file") end)
    smallButton("+Dir", 2, toolbar, function() createEntry("dir") end)
    smallButton("Del", 3, toolbar, function()
        local dir = currentDir()
        if not dir or not selected or not dir.children[selected] then say("Select an item first", colors.amber) return end
        if not hasPerm(dir, "w") then say("⛔ Permission denied", colors.red) return end
        dir.children[selected] = nil
        say("Deleted " .. selected, colors.green)
        selected = nil
        refresh(path)
    end)
    smallButton("Copy", 4, toolbar, function()
        local dir = currentDir()
        local node = dir and selected and dir.children[selected]
        if not node then say("Select an item first", colors.amber) return end
        if not hasPerm(node, "r") then say("⛔ Permission denied", colors.red) return end
        clipboardItem = {node = deepCopy(node), name = selected}
        say("Copied " .. selected, colors.green)
    end)
    smallButton("Paste", 5, toolbar, function()
        local dir = currentDir()
        if not clipboardItem then say("Clipboard is empty", colors.amber) return end
        if not dir or not hasPerm(dir, "w") then say("⛔ Permission denied", colors.red) return end
        local name = clipboardItem.name
        while dir.children[name] do name = name .. "_copy" end
        dir.children[name] = deepCopy(clipboardItem.node)
        refresh(path)
        say("Pasted as " .. name, colors.green)
    end)
    smallButton("Edit", 6, toolbar, function()
        local dir = currentDir()
        local node = dir and selected and dir.children[selected]
        if node and node.type == "file" then
            openEditorWindow(fullPath(selected))
        else
            say("Select a file first", colors.amber)
        end
    end)

    refresh = function(target)
        local node, why = getPathObject(target)
        if why == "denied" or not node or node.type ~= "dir" or not hasPerm(node, "r") then
            say("⛔ " .. resolvePath(target) .. ": permission denied", colors.red)
            return
        end
        path = resolvePath(target)
        pathLabel.Text = path
        for _, child in ipairs(list:GetChildren()) do
            if child:IsA("TextButton") then child:Destroy() end
        end
        local order = 0
        local function addRow(text, color, highlighted, onClick)
            order = order + 1
            local btn = mk("TextButton", {
                Size = UDim2.new(1, -6, 0, 24), BackgroundColor3 = Color3.fromRGB(30, 46, 38),
                BackgroundTransparency = highlighted and 0.2 or 1, Text = text, TextColor3 = color,
                Font = Enum.Font.Code, TextSize = 14, TextXAlignment = Enum.TextXAlignment.Left, LayoutOrder = order,
                BorderSizePixel = 0,
            }, list)
            btn.Activated:Connect(onClick)
        end
        if path ~= "/" then
            addRow("📁 ..", colors.gray, false, function()
                selected = nil
                refresh(path .. "/..")
            end)
        end
        for _, name in ipairs(sortedKeys(node.children)) do
            local child = node.children[name]
            local isDir = child.type == "dir"
            local size = isDir and "" or (" " .. nodeSize(child) .. "B")
            addRow((isDir and "📁 " or "📄 ") .. name .. "   " .. permString(child) .. size,
                isDir and colors.cyan or colors.text, selected == name, function()
                    if isDir then
                        selected = nil
                        refresh(fullPath(name))
                    else
                        selected = name
                        refresh(path)
                    end
                end)
        end
    end
    refresh(path)
end

-- Окно терминала: команды выполняются тем же интерпретатором, вывод идёт в окно
local function openTerminalWindow()
    local _, content = makeWindow("🖥 Terminal", UDim2.fromOffset(540, 330), UDim2.fromOffset(160, 70))
    local output = mk("ScrollingFrame", {
        Size = UDim2.new(1, -8, 1, -38), Position = UDim2.fromOffset(4, 4), BackgroundColor3 = Color3.fromRGB(6, 10, 10),
        BorderSizePixel = 0, ScrollBarThickness = 6, AutomaticCanvasSize = Enum.AutomaticSize.Y, CanvasSize = UDim2.new(),
    }, content)
    local outLabel = mk("TextLabel", {
        Size = UDim2.new(1, -8, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, Text = "",
        TextColor3 = colors.text, Font = Enum.Font.Code, TextSize = 13, TextWrapped = true,
        TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top,
    }, output)
    local input = styledBox({
        Size = UDim2.new(1, -8, 0, 26), Position = UDim2.new(0, 4, 1, -30), Text = "", PlaceholderText = "command... (Enter)",
    }, content)

    local lines = {}
    local function push(text)
        for line in (text .. "\n"):gmatch("(.-)\n") do lines[#lines + 1] = line end
        while #lines > 300 do table.remove(lines, 1) end
        outLabel.Text = table.concat(lines, "\n")
        output.CanvasPosition = Vector2.new(0, 1000000)
    end
    push("Outpost 3 terminal window — Enter runs a command (password prompts are disabled here)")

    local running = false
    input.FocusLost:Connect(function(enterPressed)
        if not enterPressed then return end
        if running then
            interruptFlag = true
            return
        end
        local line = trim(input.Text)
        input.Text = ""
        if line == "" then return end
        if busy then
            push("⚠️ The main terminal is busy")
            return
        end
        push((getPrompt():gsub("\n", " ")) .. line)
        running = true
        noPrompt = true
        captureBuffer = {}
        local ok, err = pcall(executeLine, line)
        local out = captureBuffer or {}
        captureBuffer = nil
        noPrompt = false
        running = false
        if not ok then out[#out + 1] = "Error: " .. tostring(err) end
        if #out > 0 then push(table.concat(out, "\n")) end
        input:CaptureFocus()
    end)
end

local function openCalculator()
    local _, content = makeWindow("🧮 Calculator", UDim2.fromOffset(222, 272), UDim2.fromOffset(300, 90))
    local display = mk("TextLabel", {
        Size = UDim2.new(1, -8, 0, 36), Position = UDim2.fromOffset(4, 4), BackgroundColor3 = Color3.fromRGB(10, 14, 16),
        Text = "0", TextColor3 = colors.green, Font = Enum.Font.Code, TextSize = 22, TextXAlignment = Enum.TextXAlignment.Right,
        BorderSizePixel = 0,
    }, content)
    local expr = ""
    local keys = {"7", "8", "9", "/", "4", "5", "6", "*", "1", "2", "3", "-", "0", ".", "=", "+", "(", ")", "C", "<"}
    for i, key in ipairs(keys) do
        local col, row = (i - 1) % 4, math.floor((i - 1) / 4)
        local btn = mk("TextButton", {
            Size = UDim2.fromOffset(50, 40), Position = UDim2.fromOffset(4 + col * 54, 46 + row * 44),
            BackgroundColor3 = Color3.fromRGB(26, 34, 30), Text = key, TextColor3 = colors.text,
            Font = Enum.Font.Code, TextSize = 20, BorderSizePixel = 0,
        }, content)
        btn.Activated:Connect(function()
            if expr == "Error" then expr = "" end
            if key == "C" then
                expr = ""
            elseif key == "<" then
                expr = expr:sub(1, -2)
            elseif key == "=" then
                local ok, value = pcall(evalArith, expr)
                expr = ok and formatNumber(value) or "Error"
            else
                expr = expr .. key
            end
            display.Text = expr == "" and "0" or expr
        end)
    end
end

local function openClock()
    local win, content = makeWindow("🕒 Clock", UDim2.fromOffset(240, 120), UDim2.fromOffset(180, 80))
    local label = mk("TextLabel", {
        Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = "", TextColor3 = colors.green,
        Font = Enum.Font.Code, TextSize = 28,
    }, content)
    task.spawn(function()
        while win.Parent do
            label.Text = os.date("%H:%M:%S") .. "\n" .. os.date("%Y-%m-%d")
            task.wait(0.5)
        end
    end)
end

local function openMonitor()
    local win, content = makeWindow("📊 Monitor", UDim2.fromOffset(330, 250), UDim2.fromOffset(240, 120))
    local label = mk("TextLabel", {
        Size = UDim2.new(1, -12, 1, -8), Position = UDim2.fromOffset(6, 4), BackgroundTransparency = 1, Text = "",
        TextColor3 = colors.text, Font = Enum.Font.Code, TextSize = 14, TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Top,
    }, content)
    task.spawn(function()
        while win.Parent do
            local ping, mem = getPingMs(), getMemoryMb()
            local lines = {
                "FPS:      " .. fps,
                "Ping:     " .. (ping and (ping .. " ms") or "n/a"),
                "Players:  " .. #game.Players:GetPlayers(),
                "Memory:   " .. (mem and (mem .. " MB") or "n/a"),
                "Uptime:   " .. uptimeString(),
                "",
                "PID  COMMAND",
            }
            for i, proc in ipairs(kernel.processes) do
                if i > 8 then break end
                lines[#lines + 1] = string.format("%-4d %s", proc.pid, proc.name)
            end
            label.Text = table.concat(lines, "\n")
            task.wait(0.5)
        end
    end)
end

local function openNotes()
    local _, content = makeWindow("🗒 Notes", UDim2.fromOffset(320, 220), UDim2.fromOffset(280, 160))
    styledBox({
        Size = UDim2.new(1, -8, 1, -8), Position = UDim2.fromOffset(4, 4), BackgroundTransparency = 1, Text = "",
        PlaceholderText = "Type notes here...", MultiLine = true, TextWrapped = true, TextYAlignment = Enum.TextYAlignment.Top,
    }, content)
end

openDesktop = function(kind)
    if desktopGui then
        addTerminalLine("ℹ️ Desktop already running (stopx to exit)", colors.amber)
        return
    end
    addTerminalLine("🖥️ Starting " .. kind .. " graphical interface...", colors.green)
    task.wait(0.5)

    local gui = mk("ScreenGui", {Name = "OutpostDesktop", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 5}, player:WaitForChild("PlayerGui"))
    desktopGui = gui
    desktopRoot = mk("Frame", {
        Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(6, 10, 12), BackgroundTransparency = 0.1, BorderSizePixel = 0,
    }, gui)
    mk("TextLabel", {
        Size = UDim2.new(1, 0, 0, 60), Position = UDim2.fromScale(0, 0.42), BackgroundTransparency = 1,
        Text = kind .. " · OUTPOST 3 LINUX", TextColor3 = colors.green, TextTransparency = 0.7,
        Font = Enum.Font.GothamBold, TextSize = 40,
    }, desktopRoot)

    -- панель задач: выход слева, кнопки окон по центру, часы справа
    local bar = mk("Frame", {
        Size = UDim2.new(1, 0, 0, 36), Position = UDim2.new(0, 0, 1, -36), BackgroundColor3 = Color3.fromRGB(16, 22, 24),
        BorderSizePixel = 0, ZIndex = 100000,
    }, desktopRoot)
    local exitButton = mk("TextButton", {
        Size = UDim2.fromOffset(140, 36), BackgroundTransparency = 1, Text = "⏻ Exit " .. kind,
        TextColor3 = colors.red, Font = Enum.Font.Code, TextSize = 16, ZIndex = 100001,
    }, bar)
    exitButton.Activated:Connect(function() closeDesktop() end)
    taskbarList = mk("Frame", {
        Size = UDim2.new(1, -320, 1, -8), Position = UDim2.fromOffset(150, 4), BackgroundTransparency = 1, ZIndex = 100001,
    }, bar)
    mk("UIListLayout", {FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 4), VerticalAlignment = Enum.VerticalAlignment.Center}, taskbarList)
    local clock = mk("TextLabel", {
        Size = UDim2.fromOffset(160, 36), Position = UDim2.new(1, -170, 0, 0), BackgroundTransparency = 1, Text = "",
        TextColor3 = colors.green, Font = Enum.Font.Code, TextSize = 16, ZIndex = 100001,
    }, bar)
    task.spawn(function()
        while gui.Parent do
            clock.Text = os.date("%H:%M:%S")
            task.wait(1)
        end
    end)

    local apps = {
        {"📁\nFiles", openFiles},
        {"🖥\nTerminal", openTerminalWindow},
        {"📝\nEditor", function() openEditorWindow("/tmp/untitled.txt") end},
        {"🧮\nCalc", openCalculator},
        {"🕒\nClock", openClock},
        {"📊\nMonitor", openMonitor},
        {"🗒\nNotes", openNotes},
    }
    for i, app in ipairs(apps) do
        local col, row = math.floor((i - 1) / 5), (i - 1) % 5
        local icon = mk("TextButton", {
            Size = UDim2.fromOffset(84, 70), Position = UDim2.fromOffset(16 + col * 96, 16 + row * 80),
            BackgroundColor3 = Color3.fromRGB(18, 24, 26), BackgroundTransparency = 0.2, Text = app[1],
            TextColor3 = colors.text, Font = Enum.Font.Code, TextSize = 16,
        }, desktopRoot)
        mk("UIStroke", {Color = colors.green, Thickness = 1, Transparency = 0.6}, icon)
        icon.Activated:Connect(app[2])
    end

    -- освобождаем клавиатуру, чтобы можно было пользоваться мышью и текстовыми полями окон
    setTerminalActive(false)
    addTerminalLine("✅ Desktop started — click icons, drag windows, □ maximizes, taskbar minimizes", colors.green)
end

closeDesktop = function()
    if not desktopGui then
        addTerminalLine("ℹ️ Desktop is not running", colors.gray)
        return
    end
    desktopGui:Destroy()
    desktopGui = nil
    desktopRoot = nil
    taskbarList = nil
    addTerminalLine("🖥️ Desktop stopped", colors.green)
end
end

-- ============================================================
-- ===== 14. ВВОД ТЕРМИНАЛА (скрытый TextBox) =====
-- ============================================================
screenGui = Instance.new("ScreenGui")
screenGui.Name = "OutpostInput"
screenGui.ResetOnSpawn = false
screenGui.Parent = player:WaitForChild("PlayerGui")

inputBox = Instance.new("TextBox")
inputBox.Size = UDim2.fromOffset(1, 1)
inputBox.BackgroundTransparency = 1
inputBox.TextTransparency = 1
inputBox.ClearTextOnFocus = false
inputBox.Text = ""
inputBox.Parent = screenGui

local function runCommand(line)
    if busy then return end
    line = trim(line)
    if line == "" then return end

    table.insert(commandHistory, line)
    historyIndex = #commandHistory + 1
    scrollOffset = 0
    addTerminalLine(getPrompt() .. line, colors.text)

    busy = true -- команды с task.wait не перемешиваются между собой
    local ok, err = pcall(executeLine, line)
    busy = false
    renderSuspended = false
    captureBuffer = nil
    if not ok then
        addTerminalLine("❌ Error: " .. tostring(err), colors.red)
    end
    updateTerminalDisplay()
end

setTerminalActive = function(active)
    terminalActive = active
    if active then
        scrollOffset = 0
        bindWheel(true)
        addTerminalLine(string.rep("─", 51), colors.gray)
        addTerminalLine("🖥️ TERMINAL ACTIVATED", colors.green)
        addTerminalLine("'help' = commands | Tab = autocomplete (empty line: exit)", colors.gray)
        addTerminalLine(string.rep("─", 51), colors.gray)
        task.defer(function()
            if terminalActive then inputBox:CaptureFocus() end
        end)
    else
        if pendingPrompt then inputEvent:Fire(nil) end
        bindWheel(false)
        inputBox:ReleaseFocus()
        inputBox.Text = ""
        currentInput = ""
        updateTerminalDisplay()
    end
end

-- Автодополнение: команды (первое слово) и пути (остальные)
local function completeInput(text)
    local prefixText, word = text:match("^(.*%s)(%S*)$")
    if not prefixText then prefixText, word = "", text end
    local candidates = {}
    if prefixText == "" then
        for name in pairs(terminalCommands) do
            if name:sub(1, #word) == word then candidates[#candidates + 1] = name end
        end
        for name in pairs(aliases) do
            if name:sub(1, #word) == word then candidates[#candidates + 1] = name end
        end
    else
        local dirPart, namePart = word:match("^(.*/)([^/]*)$")
        if not dirPart then dirPart, namePart = "", word end
        local dirNode = getPathObject(dirPart == "" and "." or dirPart)
        if dirNode and dirNode.type == "dir" and hasPerm(dirNode, "r") then
            for name, child in pairs(dirNode.children) do
                if name:sub(1, #namePart) == namePart and (namePart ~= "" or name:sub(1, 1) ~= ".") then
                    candidates[#candidates + 1] = dirPart .. name .. (child.type == "dir" and "/" or "")
                end
            end
        end
    end
    table.sort(candidates)
    if #candidates == 0 then return text end
    if #candidates == 1 then
        return prefixText .. candidates[1] .. (prefixText == "" and " " or "")
    end
    local common = candidates[1]
    for _, c in ipairs(candidates) do
        while c:sub(1, #common) ~= common do common = common:sub(1, -2) end
    end
    local shown = {}
    for i = 1, math.min(#candidates, 12) do shown[i] = candidates[i] end
    addTerminalLine(table.concat(shown, "  ") .. (#candidates > 12 and "  ..." or ""), colors.gray)
    return prefixText .. common
end

local lastTextLength = 0
inputBox:GetPropertyChangedSignal("Text"):Connect(function()
    local clean = (inputBox.Text:gsub("[\t\r\n]", ""))
    if clean ~= inputBox.Text then
        inputBox.Text = clean -- убираем случайно попавший символ Tab
        return
    end
    if #inputBox.Text > lastTextLength then playSound("key") end
    lastTextLength = #inputBox.Text
    currentInput = inputBox.Text
    scrollOffset = 0
    updateTerminalDisplay()
end)

inputBox.FocusLost:Connect(function(enterPressed)
    if enterPressed then
        playSound("enter")
        local line = inputBox.Text
        inputBox.Text = ""
        currentInput = ""
        if pendingPrompt then
            inputEvent:Fire(line)          -- ответ на запрос пароля / редактора
        elseif busy then
            interruptFlag = true           -- Enter во время работы команды её прерывает
        else
            task.spawn(runCommand, line)
        end
        updateTerminalDisplay()
    end
    -- при открытом рабочем столе фокус не возвращаем (иначе нельзя печатать в Notes)
    if terminalActive and not desktopGui then
        task.defer(function()
            if terminalActive and not desktopGui then inputBox:CaptureFocus() end
        end)
    end
end)

uis.InputBegan:Connect(function(input, gp)
    local key = input.KeyCode

    -- Tab работает и тогда, когда фокус в TextBox (там gp = true)
    if key == Enum.KeyCode.Tab and (not gp or terminalActive) then
        if terminalActive and pendingPrompt then
            inputEvent:Fire(nil)           -- Tab отменяет запрос
            return
        end
        if terminalActive and currentInput ~= "" then
            local typed = currentInput
            task.defer(function()
                local completed = completeInput(typed)
                inputBox.Text = completed
                inputBox.CursorPosition = #completed + 1
            end)
            return
        end
        setTerminalActive(not terminalActive)
        return
    end

    if not terminalActive then return end

    local ctrl = uis:IsKeyDown(Enum.KeyCode.LeftControl) or uis:IsKeyDown(Enum.KeyCode.RightControl)
    if key == Enum.KeyCode.C and ctrl then
        if pendingPrompt then
            inputEvent:Fire(nil)
        elseif busy then
            interruptFlag = true
            addTerminalLine("^C", colors.gray)
        end
        return
    end

    if ctrl and (key == Enum.KeyCode.One or key == Enum.KeyCode.Two or key == Enum.KeyCode.Three) then
        switchSession(key == Enum.KeyCode.One and 1 or (key == Enum.KeyCode.Two and 2 or 3), false)
        return
    elseif ctrl and key == Enum.KeyCode.Zero then
        setPaneMode(not paneMode)
        return
    end

    if key == Enum.KeyCode.Up then
        if historyIndex > 1 and not pendingPrompt then
            historyIndex = historyIndex - 1
            inputBox.Text = commandHistory[historyIndex]
            inputBox.CursorPosition = #inputBox.Text + 1
        end
    elseif key == Enum.KeyCode.Down then
        if not pendingPrompt then
            if historyIndex < #commandHistory then
                historyIndex = historyIndex + 1
                inputBox.Text = commandHistory[historyIndex]
            else
                historyIndex = #commandHistory + 1
                inputBox.Text = ""
            end
            inputBox.CursorPosition = #inputBox.Text + 1
        end
    elseif key == Enum.KeyCode.PageUp then
        scrollOffset = scrollOffset + 8
        updateTerminalDisplay()
    elseif key == Enum.KeyCode.PageDown then
        scrollOffset = math.max(0, scrollOffset - 8)
        updateTerminalDisplay()
    elseif key == Enum.KeyCode.End then
        scrollOffset = 0
        updateTerminalDisplay()
    end
end)

-- ============================================================
-- ===== 14b. СОХРАНЕНИЕ И ЗАГРУЗКА СОСТОЯНИЯ (через сервер) =====
-- ============================================================
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local autosaveEnabled = false

saveState = function(quiet)
    local remote = ReplicatedStorage:FindFirstChild("Outpost3Save")
    if not remote then
        if not quiet then
            addTerminalLine("⚠️ Save server not found. Put Outpost3Save.server.lua into ServerScriptService.", colors.amber)
        end
        return false
    end
    -- сохраняем локальную машину (даже если сейчас открыта ssh-сессия)
    local okEncode, payload = pcall(function()
        return HttpService:JSONEncode({
            v = 2, fs = localMachine.fs, users = localMachine.users, env = env, aliases = aliases,
            theme = currentThemeName, installed = installed, crt = crtEnabled,
        })
    end)
    if not okEncode then
        if not quiet then addTerminalLine("❌ Cannot encode state", colors.red) end
        return false
    end
    if #payload > 190000 then
        if not quiet then addTerminalLine("❌ State is too large to save (" .. #payload .. " bytes)", colors.red) end
        return false
    end
    local okCall, ok, msg = pcall(function() return remote:InvokeServer("save", payload) end)
    if not okCall or not ok then
        if not quiet then addTerminalLine("❌ Save failed: " .. tostring(okCall and msg or ok), colors.red) end
        return false
    end
    return true
end

loadState = function(quiet)
    local remote = ReplicatedStorage:FindFirstChild("Outpost3Save")
    if not remote then
        if not quiet then addTerminalLine("⚠️ Save server not found (see Outpost3Save.server.lua)", colors.amber) end
        return false
    end
    local okCall, data = pcall(function() return remote:InvokeServer("load") end)
    if not okCall then
        if not quiet then addTerminalLine("❌ Load failed", colors.red) end
        return false
    end
    autosaveEnabled = true
    if type(data) ~= "string" then
        if not quiet then addTerminalLine("ℹ️ No saved state yet — use 'save'", colors.gray) end
        return false
    end
    local okDecode, saved = pcall(function() return HttpService:JSONDecode(data) end)
    if not okDecode or type(saved) ~= "table" or type(saved.fs) ~= "table" or type(saved.fs["/"]) ~= "table"
        or type(saved.users) ~= "table" or #saved.users < 1 then
        if not quiet then addTerminalLine("❌ Saved state is corrupted", colors.red) end
        return false
    end

    -- перенаправляем все сессии (активную и фоновые) на загруженную локальную машину
    localMachine.fs, localMachine.users = saved.fs, saved.users
    local function findUser(name)
        for _, u in ipairs(saved.users) do
            if u.name == name then return u end
        end
        return saved.users[2] or saved.users[1]
    end
    local function repoint(c)
        local target = (#c.ssh > 0) and c.ssh[1] or c   -- у ssh-сессии локальный контекст лежит в стеке
        target.fs, target.users = saved.fs, saved.users
        target.user = findUser(target.user.name)
        target.root = target.user.is_root == true
        target.path = homeOf(target.user)
    end
    local active = {
        fs = fileSystem, users = users, user = currentUser, root = isRoot, path = currentPath, ssh = sshStack,
    }
    repoint(active)
    fileSystem, users, currentUser, isRoot, currentPath = active.fs, active.users, active.user, active.root, active.path
    for i = 1, NUM_SESSIONS do
        if i ~= activeSession and sessions[i] then repoint(sessions[i]) end
    end

    if type(saved.env) == "table" then env = saved.env end
    if type(saved.aliases) == "table" then aliases = saved.aliases end
    if type(saved.installed) == "table" then installed = saved.installed end
    if saved.theme and themes[saved.theme] then applyTheme(saved.theme) end
    if type(saved.crt) == "boolean" then setCrt(saved.crt) end
    updateTerminalDisplay()
    return true
end

-- ============================================================
-- ===== 15. ГОРЯЧИЕ КЛАВИШИ =====
-- ============================================================
uis.InputBegan:Connect(function(input, gp)
    -- ИСПРАВЛЕНО: при активном терминале хоткеи не срабатывают
    if gp or terminalActive then return end
    if not hum or not hum.Parent then return end
    local k = input.KeyCode

    if k == Enum.KeyCode.F then
        if state.fly then stopFly() else startFly() end
        addTerminalLine(state.fly and "🕊️ Fly ON" or "🕊️ Fly OFF", state.fly and colors.green or colors.red)
    elseif k == Enum.KeyCode.G then
        setGod(not state.god)
        addTerminalLine(state.god and "🛡️ God ON" or "🛡️ God OFF", colors.amber)
    elseif k == Enum.KeyCode.N then
        setNoclip(not state.noclip)
        addTerminalLine(state.noclip and "🧱 Noclip ON" or "🧱 Noclip OFF", colors.purple)
    elseif k == Enum.KeyCode.I then
        setInvisible(not state.invis)
        addTerminalLine(state.invis and "👁️ Invisible ON" or "👁️ Invisible OFF", colors.gray)
    elseif k == Enum.KeyCode.S and uis:IsKeyDown(Enum.KeyCode.LeftShift) then
        state.speed = state.speed == 1 and 2 or 1
        hum.WalkSpeed = baseWalkSpeed * state.speed
        addTerminalLine("🏃 Speed x" .. state.speed, colors.green)
    elseif k == Enum.KeyCode.H then
        hum.Health = hum.MaxHealth
        addTerminalLine("❤️ Healed!", colors.red)
    elseif k == Enum.KeyCode.P then
        -- ИСПРАВЛЕНО: Esc обрабатывается Roblox (gp = true), поэтому скрытие панелей перенесено на P
        panelsVisible = not panelsVisible
        setPanelsVisible(panelsVisible)
    end
end)


-- ============================================================
-- ===== 16. ЗАПУСК, АНИМАЦИЯ ЗАГРУЗКИ И ПРИВЕТСТВИЕ =====
-- ============================================================
-- Панели пересоздаются при каждом респауне
player.CharacterAdded:Connect(setupCharacter)
setupCharacter(player.Character or player.CharacterAdded:Wait())

-- Системные процессы, окружение, алиасы (как в ~/.bashrc), сессии и демон cron
createSystemProcesses()
env.PATH = "/usr/local/bin:/usr/bin:/bin"
env.LANG = "en_US.UTF-8"
env.TERM = "xterm-256color"
env.EDITOR = "nano"
aliases.ll = "ls -la"
aliases.la = "ls -a"
initSessions()
startCron()

-- мигающий курсор
task.spawn(function()
    while true do
        task.wait(0.5)
        cursorOn = not cursorOn
        if not renderSuspended then updateTerminalDisplay() end
    end
end)

local BOOT_ANIMATION = true   -- false = сразу показывать приветствие

local function playBootAnimation()
    local steps = {
        "[    0.000] JCJ_KERNEL " .. kernel.version .. " booting on x86_64",
        "[    0.142] Detected 3 virtual displays (panels)",
        "[  OK  ] Mounted /",
        "[  OK  ] Started systemd-journald",
        "[  OK  ] Started Network Manager",
        "[  OK  ] Started OpenBSD Secure Shell server",
        "[  OK  ] Started Regular background program processing daemon",
        "[  OK  ] Reached target Multi-User System",
    }
    playSound("boot")
    for _, text in ipairs(steps) do
        addTerminalLine(text, text:find("OK", 1, true) and colors.green or colors.gray)
        task.wait(0.12)
    end
    local bar = addTerminalLine("", colors.cyan)
    for p = 0, 10 do
        bar.text = "Starting Outpost 3 [" .. string.rep("█", p) .. string.rep("░", 10 - p) .. "] " .. (p * 10) .. "%"
        updateTerminalDisplay()
        task.wait(0.06)
    end
end

local function pad(s, width)
    return s .. string.rep(" ", math.max(0, width - (utf8.len(s) or #s)))
end
local BANNER_W = 52
local function bannerLine(s)
    addTerminalLine("║ " .. pad(s, BANNER_W) .. " ║", colors.green)
end

if BOOT_ANIMATION then
    playBootAnimation()
else
    task.wait(0.5)
end
addTerminalLine("╔" .. string.rep("═", BANNER_W + 2) .. "╗", colors.green)
bannerLine("🦞 OUTPOST 3 LINUX v" .. kernel.version)
bannerLine("Kernel: JCJ_KERNEL " .. kernel.version)
bannerLine("Bootloader: JCJ_BOOTLOADER v" .. bootloader.version)
bannerLine("Press TAB to open the terminal, 'help' for commands")
bannerLine("User: Yahmyh78 (password 12345), root: toor")
bannerLine("Panes: Ctrl+1..3 switch, Ctrl+0 split")
bannerLine("Hotkeys: F-G-N-I, Shift+S, H, P (hide panels)")
addTerminalLine("╚" .. string.rep("═", BANNER_W + 2) .. "╝", colors.green)

print("🦞 OUTPOST 3 LINUX LOADED!")
print("  TAB - Open/close terminal (with text: autocomplete)")
print("  Ctrl+1..3 - panes, Ctrl+0 - split, mouse wheel - scroll")
print("  F - Fly | G - God | N - Noclip | I - Invisible")
print("  Shift+S - Speed | H - Heal | P - Hide/Show panels")

-- Загрузка сохранённого состояния и автосохранение (нужен Outpost3Save.server.lua)
task.spawn(function()
    task.wait(1)
    if loadState(true) then
        addTerminalLine("💾 Saved state restored", colors.green)
    end
end)
task.spawn(function()
    while true do
        task.wait(120)
        if autosaveEnabled then saveState(true) end
    end
end)
