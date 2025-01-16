local imgui = require 'mimgui'
local ffi = require 'ffi'
local vkeys = require 'vkeys'
local http = require("socket.http")
local encoding = require 'encoding'
local requests = require 'requests'

-- ����������� ���������
encoding.default = 'CP1251'
local u8 = encoding.UTF8

local wm = require 'windows.message'
local new, str, sizeof = imgui.new, ffi.string, ffi.sizeof

-- ���������� ����������
local renderWindow = new.bool(false) -- ��������� ����
local updateAvailable = new.bool(false) -- ���� �� ����������
local updateText = new.char[256]() -- ����� ������� ����������
local sizeX, sizeY = getScreenResolution() -- ���������� ������

-- ������� ������ �������
local CURRENT_VERSION = "1.6e"
-- URL ��� �������� ������
local VERSION_URL = "https://addon.sendmessage.online/version.php"
local DOWNLOAD_URL = "https://addon.sendmessage.online/addon-new.lua"

-- ��������� imgui
imgui.OnInitialize(function()
    imgui.GetIO().IniFilename = nil -- ��������� ���������� ������������ � ����
end)

-- ������� ���������� ��������� ������
local function safeStrCopy(destination, text)
    local encodedText = u8(text) -- ����������� ����� � UTF-8
    ffi.copy(destination, encodedText, math.min(#encodedText, sizeof(destination) - 1))
    destination[#encodedText] = 0 -- ��������� ������ ������� ��������
end

-- ������� �������� ������
local function checkVersion()
    local response = requests.get(VERSION_URL, {
        headers = { ["User-Agent"] = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) Gecko/20100101 Firefox/118.0" }
    })

    if response.status_code == 200 then
        local data = response.json() -- ��������� JSON

        if data and data.latest_version then
            if data.latest_version > CURRENT_VERSION then
                updateAvailable[0] = true
                safeStrCopy(updateText, "�������� ����������: " .. data.latest_version)
            else
                updateAvailable[0] = false
                safeStrCopy(updateText, "������ ��������. ������: " .. CURRENT_VERSION)
            end
        else
            safeStrCopy(updateText, "������: ������������ ����� �� �������.")
        end
    else
        safeStrCopy(updateText, "������: �� ������� �������� ������. ���: " .. response.status_code)
    end
end

-- ������� ����������
local function downloadUpdate()
    sampAddChatMessage(u8:decode("�������� ����� ������..."), 0xFFFF00)
    local response, status = http.request(DOWNLOAD_URL)
    if response and status == 200 then
        local newFilePath = getWorkingDirectory() .. "/moonloader/scripts/addon-new.lua"
        local oldFilePath = getWorkingDirectory() .. "/moonloader/scripts/addon.lua"
        local file = io.open(newFilePath, "wb")
        if file then
            file:write(response)
            file:close()

            -- ��������� ������� ������ � ��������������� ����
            sampAddChatMessage(u8:decode("�������� � ������ ������ ������..."), 0xFFFF00)
            if CURRENT_VERSION < data.latest_version then
                os.remove(oldFilePath)
                os.rename(newFilePath, oldFilePath)
                sampAddChatMessage(u8:decode("���������� ������� �����������! ������������� MoonLoader."), 0x00FF00)
            else
                sampAddChatMessage(u8:decode("���������� �� ���������. ������ ����������� ����."), 0xFFFF00)
                os.remove(newFilePath)
            end
        else
            sampAddChatMessage(u8:decode("������ ���������� �����. ��������� ����� �������."), 0xFF0000)
        end
    else
        sampAddChatMessage(u8:decode("������ �������� �����. ������: " .. tostring(status)), 0xFF0000)
    end
end

-- ��������� ����
imgui.OnFrame(
    function() return renderWindow[0] end,
    function()
        -- ��������� ������� � ������� ����
        imgui.SetNextWindowPos(imgui.ImVec2(sizeX / 2, sizeY / 2), imgui.Cond.FirstUseEver, imgui.ImVec2(0.5, 0.5))
        imgui.SetNextWindowSize(imgui.ImVec2(400, 200), imgui.Cond.FirstUseEver)

        -- ������ ����
        imgui.Begin(u8"���� ����������", renderWindow)

        imgui.Text(u8"������� �������� ����������")
        imgui.Separator()

        -- ������ �������� ����������
        if imgui.Button(u8"��������� ����������") then
            safeStrCopy(updateText, "�������� ����������...")
            checkVersion()
        end

        -- ����� ������� ����������
        imgui.Text(str(updateText))

        -- ������ "��������"
        if updateAvailable[0] then
            if imgui.Button(u8"��������") then
                safeStrCopy(updateText, "�������� ����������...")
                downloadUpdate()
            end
        end

        imgui.End() -- ����� ����
    end
)

-- �������� ����
function main()
    -- ����������� ����������� �������
    addEventHandler('onWindowMessage', function(msg, wparam, lparam)
        if msg == wm.WM_KEYDOWN or msg == wm.WM_SYSKEYDOWN then
            if wparam == vkeys.VK_X then -- ������������ ���� �� ������� X
                renderWindow[0] = not renderWindow[0]
            end
        end
    end)

    sampRegisterChatCommand("testmenu", function()
        renderWindow[0] = not renderWindow[0] -- ���������/��������� ���� �� �������
    end)

    sampAddChatMessage("[������] ������� /testmenu ������� ����������������!", -1)

    wait(-1) -- ����������� ��������
end