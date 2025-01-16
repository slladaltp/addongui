local imgui = require 'mimgui'
local ffi = require 'ffi'
local vkeys = require 'vkeys'
local http = require("socket.http")
local encoding = require 'encoding'
local requests = require 'requests'

-- Настраиваем кодировки
encoding.default = 'CP1251'
local u8 = encoding.UTF8

local wm = require 'windows.message'
local new, str, sizeof = imgui.new, ffi.string, ffi.sizeof

-- Глобальные переменные
local renderWindow = new.bool(false) -- Видимость окна
local updateAvailable = new.bool(false) -- Есть ли обновление
local updateText = new.char[256]() -- Текст статуса обновления
local sizeX, sizeY = getScreenResolution() -- Разрешение экрана

-- Текущая версия скрипта
local CURRENT_VERSION = "1.6"
-- URL для проверки версии
local VERSION_URL = "https://addon.sendmessage.online/version.php"
local DOWNLOAD_URL = "https://addon.sendmessage.online/addon-new.lua"

-- Настройка imgui
imgui.OnInitialize(function()
    imgui.GetIO().IniFilename = nil -- Отключаем сохранение конфигурации в файл
end)

-- Функция безопасной установки текста
local function safeStrCopy(destination, text)
    local encodedText = u8(text) -- Преобразуем текст в UTF-8
    ffi.copy(destination, encodedText, math.min(#encodedText, sizeof(destination) - 1))
    destination[#encodedText] = 0 -- Завершаем строку нулевым символом
end

-- Функция проверки версии
local function checkVersion()
    local response = requests.get(VERSION_URL, {
        headers = { ["User-Agent"] = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) Gecko/20100101 Firefox/118.0" }
    })

    if response.status_code == 200 then
        local data = response.json() -- Разбираем JSON

        if data and data.latest_version then
            if data.latest_version > CURRENT_VERSION then
                updateAvailable[0] = true
                safeStrCopy(updateText, "Доступно обновление: " .. data.latest_version)
            else
                updateAvailable[0] = false
                safeStrCopy(updateText, "Скрипт обновлен. Версия: " .. CURRENT_VERSION)
            end
        else
            safeStrCopy(updateText, "Ошибка: Некорректный ответ от сервера.")
        end
    else
        safeStrCopy(updateText, "Ошибка: Не удалось получить данные. Код: " .. response.status_code)
    end
end

-- Функция обновления
local function downloadUpdate()
    local newFilePath = getWorkingDirectory() .. "/moonloader/scripts/new-addon.lua"
    local downloadUrl = "https://addon.sendmessage.online/scripts/addon.lua"
    local maxRedirects = 5 -- Лимит на перенаправления

    sampAddChatMessage(u8:decode("Начинаю загрузку новой версии..."), 0xFFFF00)

    local function fetch(url, attempt)
        attempt = attempt or 1
        if attempt > maxRedirects then
            return nil, "Превышено количество перенаправлений"
        end

        local response, status, headers = http.request {
            url = url,
            method = "GET",
            headers = {
                ["User-Agent"] = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) Gecko/20100101 Firefox/118.0"
            }
        }

        if status == 301 or status == 302 then
            local redirectUrl = headers.location
            if redirectUrl then
                return fetch(redirectUrl, attempt + 1)
            else
                return nil, "Ошибка перенаправления: отсутствует заголовок Location"
            end
        end

        return response, status
    end

    -- Выполняем загрузку
    local response, status = fetch(downloadUrl)

    if response and status == 200 then
        local file = io.open(newFilePath, "wb")
        if file then
            file:write(response)
            file:close()
            sampAddChatMessage(u8:decode("Загрузка завершена! Скрипт сохранён как new-addon.lua."), 0x00FF00)
            sampAddChatMessage(u8:decode("Путь: " .. newFilePath), 0x00FF00)
        else
            sampAddChatMessage(u8:decode("Ошибка сохранения файла. Проверьте права доступа!"), 0xFF0000)
        end
    else
        sampAddChatMessage(u8:decode("Ошибка загрузки файла. Код: " .. tostring(status)), 0xFF0000)
        if status == 301 or status == 302 then
            sampAddChatMessage(u8:decode("Сервер вернул перенаправление, но не удалось завершить загрузку."), 0xFFFF00)
        end
    end
end






-- Отрисовка окна
imgui.OnFrame(
    function() return renderWindow[0] end,
    function()
        -- Установка позиции и размера окна
        imgui.SetNextWindowPos(imgui.ImVec2(sizeX / 2, sizeY / 2), imgui.Cond.FirstUseEver, imgui.ImVec2(0.5, 0.5))
        imgui.SetNextWindowSize(imgui.ImVec2(400, 200), imgui.Cond.FirstUseEver)

        -- Начало окна
        imgui.Begin(u8"Меню обновлений", renderWindow)

        imgui.Text(u8"Система проверки обновлений")
        imgui.Separator()

        -- Кнопка проверки обновлений
        if imgui.Button(u8"Проверить обновления") then
            safeStrCopy(updateText, "Проверка обновлений...")
            checkVersion()
        end

        -- Текст статуса обновления
        imgui.Text(str(updateText))

        -- Кнопка "Обновить"
        if updateAvailable[0] then
            if imgui.Button(u8"Обновить") then
                safeStrCopy(updateText, "Загрузка обновления...")
                downloadUpdate()
            end
        end

        imgui.End() -- Конец окна
    end
)

-- Основной цикл
function main()
    -- Регистрация обработчика событий
    addEventHandler('onWindowMessage', function(msg, wparam, lparam)
        if msg == wm.WM_KEYDOWN or msg == wm.WM_SYSKEYDOWN then
            if wparam == vkeys.VK_X then -- Переключение окна по клавише X
                renderWindow[0] = not renderWindow[0]
            end
        end
    end)

    sampRegisterChatCommand("testmenu", function()
        renderWindow[0] = not renderWindow[0] -- Открываем/закрываем меню по команде
    end)

    sampAddChatMessage("[Скрипт] Команда /testmenu успешно зарегистрирована!", -1)

    wait(-1) -- Бесконечное ожидание
end
