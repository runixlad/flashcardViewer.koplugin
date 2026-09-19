local Dispatcher = require("dispatcher")  -- luacheck:ignore
local UIManager = require("ui/uimanager")
local WidgetContainer = require("ui/widget/container/widgetcontainer")
local Font = require("ui/font")
local _ = require("gettext")
local TextWidget = require("ui/widget/textwidget")
local TextViewer = require("ui/widget/textviewer")
local ButtonDialog = require("ui/widget/buttondialog")
local ConfirmBox = require("ui/widget/confirmbox")
local InfoMessage = require("ui/widget/infomessage")
local logger = require("logger")
local ftcsv = require("ftcsv")
local DataStorage = require("datastorage")
local InputDialog = require("ui/widget/inputdialog")
local MultiInputDialog = require("ui/widget/multiinputdialog")
local Menu = require("ui/widget/menu")
local ImageViewer = require("ui/widget/imageviewer")
local PathChooser = require("ui/widget/pathchooser")
local Blitbuffer = require("ffi/blitbuffer")
local ImageWidget = require("ui/widget/imagewidget")
local Device = require("device")
local Screen = Device.screen
local LuaSettings = require("luasettings")

local device_width = Screen:getWidth()

local KO_PATH = DataStorage:getFullDataDir()

local DATA_PATH = KO_PATH.."/plugins/flashcardViewer.koplugin/data.csv"
local DAY_PATH = KO_PATH.."/plugins/flashcardViewer.koplugin/day.txt"
local IMPORT_PATH = KO_PATH.."/import.txt"
local IMAGE_PATH = "/resources/koreader.png"

G_reader_settings:readSetting("flashcard_background", false)
G_reader_settings:readSetting("flashcard_background_path", IMAGE_PATH)

-- REALLY IMPORTANT LEGACY LUA FUNCTIONS
-- This shit is older than this plugin for the most part

function addFlashcard(front2, back2, box2)
    box = box2 or "1"
    tabla = {front = front2, back = back2, box = box}
    local flashcard, headers = ftcsv.parse(DATA_PATH)
    table.insert(flashcard, tabla)
    save(flashcard, DATA_PATH)
end

function importCards()
local importCount = 0
local f = io.open(IMPORT_PATH, "r")
if f then
    importing = f:read("*all")
    f:close()
    for line in io.lines(IMPORT_PATH) do
        importCount = importCount + 1
    end
    file = io.open(DATA_PATH, "a")
    file:write(importing)
    file:close()
    if importCount == 1 then
        local popup = InfoMessage:new({
            text = _("1 flashcard has been imported"),
        })
        UIManager:show(popup)
    else
        local popup = InfoMessage:new({
            text = _(importCount .. " flashcards were imported."),
        })
        UIManager:show(popup)
    end
    os.remove(IMPORT_PATH)
else
    waste = 2+2
end
end

function save(tabla, archivo)
    local fileOutput = ftcsv.encode(tabla)
    local file = assert(io.open(archivo, "w"))
    file:write(fileOutput)
    file:close()
end

function addFlashcard(front2, back2, box2)
    box2 = box2 or "1"
    tabla = {front = front2, back = back2, box = box2}
    local flashcard, headers = ftcsv.parse(DATA_PATH)
    table.insert(flashcard, tabla)
    save(flashcard, DATA_PATH)
end

function countSilent(file)
    local file = file or DATA_PATH
    local flashcard, headers = ftcsv.parse(file)

    local box1_counted = 0
    local box2_counted = 0
    local box3_counted = 0
    local box4_counted = 0
    local box5_counted = 0
    local box6_counted = 0
    local box7_counted = 0
    local other_counted = 0

    local box_encountered

    for key, value in pairs(flashcard) do
    box_encountered = flashcard[key].box
    if box_encountered == "1" then
    box1_counted = self_sum(box1_counted, 1)
    elseif box_encountered == "2" then
    box2_counted = self_sum(box2_counted, 1)
    elseif box_encountered == "3" then
    box3_counted = self_sum(box3_counted, 1)
    elseif box_encountered == "4" then
    box4_counted = self_sum(box4_counted,1)
    elseif box_encountered == "5" then
    box5_counted = self_sum(box5_counted,1)
    elseif box_encountered == "6" then
    box6_counted = self_sum(box6_counted,1)
    elseif box_encountered == "7" then
    box7_counted = self_sum(box7_counted,1)
    else
        logger.info(box_encountered)
        logger.info(flashcard[key].front)
        other_counted = other_counted + 1
    end
    end

    return box1_counted, box2_counted, box3_counted, box4_counted, box5_counted, box6_counted, box7_counted, other_counted
    end

function self_sum(variable, sum)
    return variable + sum
end

function know_which_day()
    local day_file = io.open(DAY_PATH, "r")
    day = day_file:read("*a")
    day_file:close()
    if day == "" then
        logger.info("No day info")
        return "1"
    else
        return tostring(tonumber(day))
    end
end

function writeDay(day)
    dayMath = tostring(tonumber(day) + 1)
    local file = assert(io.open("day.txt", "w"))
    file:write(dayMath)
    file:close()
end

-- START of KOREADER-specific FUNCTIONS

local FlashcardViewer = WidgetContainer:extend{
    name = "flashcard_Viewer",
    is_doc_only = false,
}

function FlashcardViewer:onDispatcherRegisterActions()
    Dispatcher:registerAction("flashcard_viewer_action", {category="none", event="FlashcardViewer", title=_("Flashcard viewer"), general=true,})
    Dispatcher:registerAction("flashcard_adding_action", {category="none", event="AddFlashcard", title=_("Add flashcard"), general=true,})
end

function FlashcardViewer:init()
    self:onDispatcherRegisterActions()
    self.ui.menu:registerToMainMenu(self)
end

function FlashcardViewer:addToMainMenu(menu_items)
    menu_items.flashcard_viewer = {
        text = _("Flashcard utilities"),
        -- in which menu this should be appended
        sorting_hint = "tools",
        -- a callback when tapping
        sub_item_table = {
        --[[
        {
            text = _("Test"),
            callback = function()
                local path_chooser = PathChooser:new{
                    select_directory = false,
                    onConfirm = function(file_path)
                        IMAGE_PATH = file_path
                    end
                }
                UIManager:show(path_chooser)
            end,
        },
        --]]
        {
            text = _("Add flashcard"),
            callback = function()
            FlashcardViewer.inputScreen(self)
            end,
        },
        {
            text = _("Edit flashcards"),
            callback = function()
            FlashcardViewer.askForBox(self)
            end,
        },
        {
            text = _("Study flashcards"),
            callback = function()
                FlashcardViewer:onFlashcardViewer()
            end,
        },
        {
            text = _("Settings"),
            sub_item_table = {
            {
                text = _("Enable background"),
                checked_func = function()
                    return G_reader_settings:readSetting("flashcard_background")
                end,
                callback = function()
                    background_boolean = G_reader_settings:readSetting("flashcard_background")
                    if background_boolean == true then
                        G_reader_settings:saveSetting("flashcard_background", false)
                    else
                        G_reader_settings:saveSetting("flashcard_background", true)
                    end
                end,
            },
            {
                text = _("Choose background"),
                callback = function()
                    local path_chooser = PathChooser:new{
                        select_directory = false,
                        onConfirm = function(file_path)
                        IMAGE_PATH = file_path
                        G_reader_settings:saveSetting("flashcard_background_path", file_path)
                        end,
                    }
                    UIManager:show(path_chooser)
                    end
                },
            },
            },
        },
    }
end

-- START OF REVIEWING FLASHCARDS SECTION

function leitner_logic(day)

    -- This is intended to say the Flashcard Viewer screen which boxes are to be enabled according to the day

    local m = "Day "..day..": "
    local b7 = false
    local b6 = false
    local b5 = false
    local b4 = false
    local b3 = false
    local b2 = false
    local b1 = true

    if day == "56" then
        --FlashcardViewer:study("7")
        m = m .. "• box 7 "
        b7 = true
    end

    if day == "59" or day == "24" then
        --FlashcardViewer:study("6")
        m = m .. "• box 6 "
        b6 = true
    end

    if day == "12" or day == "28" or day == "44" or day == "60" then
        --FlashcardViewer:study("5")
        m = m .. "• box 5 "
        b5 = true
    end

    if day == "4" or day == "13" or day == "20" or day == "29" or day == "36" or day == "45" or day == "52" or day == "61" then
        --FlashcardViewer:study("4")
        m = m .. "• box 4 "
        b4 = true
    end

    if (((day + 2) % 4) == 0) then  -- do something
        --FlashcardViewer:study("3")
        m = m .. "• box 3 "
        b3 = true
    end

    if (((day + 1) % 2) == 0) then  -- do something
        --FlashcardViewer:study("2")
        m = m .. "• box 2 "
        b2 = true
    end

    if 1 then
        --FlashcardViewer:study("1")
        m = m .. "• box 1"
    end
    return m, b7, b6, b5, b4, b3, b2, b1
end

--[[
timeleft = 0

function leitner_ETA(day)
    local box_1, box_2, box_3, box_4, box_5, boc_6, box_7 = countSilent()
    if day == "56" then
    timeleft = self_sum(timeleft, box_7)
    end
    if day == "59" or day == "24" then
    timeleft = self_sum(timeleft, box_6)
    end
    if day == "12" or day == "28" or day == "44" or day == "60" then
    timeleft = self_sum(timeleft, box_5)
    end
    if day == "4" or day == "13" or day == "20" or day == "29" or day == "36" or day == "45" or day == "52" or day == "61" then
    timeleft = self_sum(timeleft, box_4)
    end
    if (((day + 2) % 4) == 0) then  -- do something
    timeleft = self_sum(timeleft, box_3)
    end
    if (((day + 1) % 2) == 0) then  -- do something
    timeleft = self_sum(timeleft, box_2)
    end
    if 1 then
    timeleft = self_sum(timeleft, box_1)
    end
end
--]]

--timeleft_final = timeleft/2

--[[
function nextBox(day, actual_box)
    actual_box = actual_box or "0"
    if day == "56" then
        return "7"
    end
    if day == "59" or day == "24" then
        return "6"
    end
    if day == "12" or day == "28" or day == "44" or day == "60" then
        return "5"
    end
    if day == "4" or day == "13" or day == "20" or day == "29" or day == "36" or day == "45" or day == "52" or day == "61" then
        return "4"
    end
    if (((day + 2) % 4) == 0) then  -- do something
        return "3"
    end
    if (((day + 1) % 2) == 0) then  -- do something
        return "2"
    end
    if 1 then
        return "1"
    end

end
]]

function FlashcardViewer:study(caja)

    local bg_image = G_reader_settings:readSetting("flashcard_background_path")
    local background_boolean = G_reader_settings:readSetting("flashcard_background")
    local flashcard, headers = ftcsv.parse(DATA_PATH)
    local key = nextOneOnTheBox(caja,1)

    logger.info("=== Key = "..key)

    local remaining = 0

    for key, value in pairs(flashcard) do
        if flashcard[key].box == caja then
            remaining = remaining + 1
        end
    end

    if key > 0 then

    if background_boolean == true then
    background_widget = ImageViewer:new{
        file = bg_image,
        fullscreen = true,
        with_title_bar = false,
        scale_factor = nil,
    }
    end

    --background_widget.main_frame.background = Blitbuffer.COLOR_BLACK

    button_dialog2 = ButtonDialog:new{
        title = _("box " .. flashcard[key].box .. " • " .. remaining.." cards left".."\n\n" .. flashcard[key].front.."\n"),
        title_align = "left",
        tap_close_callback = function()
            if background_boolean == true then
            --background_widget.hide = true
                UIManager:close(background_widget)
            end
        end,
        buttons = {
        {
        {
        text = "See answer",
        callback = function()
            back_dialog = ButtonDialog:new{
                title = _("box " .. flashcard[key].box .. " • " .. remaining.." cards left".."\n\n" .. flashcard[key].front.."\n──────────────\n"..flashcard[key].back.."\n"),
                title_align = "left",
                buttons = {
                    {
                    {
                        text = "Again",
                        callback = function()
                            UIManager:close(back_dialog)
                            if caja == "1" then
                                front2 = flashcard[key].front
                                back2 = flashcard[key].back
                                box2 = flashcard[key].box
                                keyToDelete = key
                                table.remove(flashcard, tonumber(keyToDelete))
                                save(flashcard, DATA_PATH)
                                --logger.info(front2)
                                tabla = {front = front2, back = back2, box = "1"}
                                table.insert(flashcard, tabla)
                                save(flashcard, DATA_PATH)
                                key = nextOneOnTheBox(caja,key-1)
                                if key > 0 then
                                    button_dialog2:setTitle(_("box " .. flashcard[key].box .. " • " .. remaining.." cards left".."\n\n" .. flashcard[key].front.."\n"))
                                else
                                    UIManager:close(button_dialog2)
                                    local popup = InfoMessage:new({
                                        text = _("No cards due in box "..caja),
                                    })
                                    UIManager:show(popup)
                                    FlashcardViewer:boxChooser()
                                end
                            else
                                front2 = flashcard[key].front
                                --logger.info(front2)
                                back2 = flashcard[key].back
                                --logger.info(back2)
                                box2 = flashcard[key].box
                                --logger.info(box2)
                                keyToDelete = key
                                table.remove(flashcard, tonumber(keyToDelete))
                                save(flashcard, DATA_PATH)
                                --logger.info(front2)
                                tabla = {front = front2, back = back2, box = "1"}
                                table.insert(flashcard, tabla)
                                save(flashcard, DATA_PATH)
                                remaining = remaining - 1
                                key = nextOneOnTheBox(caja,key-1)
                                if key > 0 then
                                    button_dialog2:setTitle(_("box " .. flashcard[key].box .. " • " .. remaining.." cards left".."\n\n" .. flashcard[key].front.."\n"))
                                else
                                    UIManager:close(button_dialog2)
                                    local popup = InfoMessage:new({
                                        text = _("No cards due in box "..caja),
                                    })
                                    UIManager:show(popup)
                                    FlashcardViewer:boxChooser()
                                end
                            end
                        end,
                    },
                    {
                        text = "Good",
                        callback = function()
                        UIManager:close(back_dialog)
                        boxNew = tostring(tonumber(flashcard[key].box) + 1)
                        flashcard[key].box = boxNew
                        save(flashcard, DATA_PATH)
                        key = nextOneOnTheBox(caja,key)
                        remaining = remaining - 1
                        if key > 0 then
                        button_dialog2:setTitle(_("box " .. flashcard[key].box .. " • " .. remaining.." cards left".."\n\n" .. flashcard[key].front.."\n"))
                        else
                        UIManager:close(button_dialog2)
                        local popup = InfoMessage:new({
                            text = _("No cards due in box "..caja),
                        })
                        UIManager:show(popup)
                        FlashcardViewer:boxChooser()
                        end
                        end
                    },
                    {
                        text = "Edit",
                        enabled = true,
                        callback = function()
                        UIManager:close(back_dialog)
                        UIManager:close(button_dialog2)
			if background_boolean == true then
			UIManager:close(background_widget)
			end
                        FlashcardViewer:editScreenWhileStudying(flashcard[key].front, flashcard[key].box)
                        end,
                    },
                    --},
                    --{
                    {
                        text = "Delete",
                        callback = function()
                        keyToDelete = key
                        UIManager:show(ConfirmBox:new{
                            text = _("You sure you want to delete this flashcard?"),
                            ok_text = _("Remove"),
                            ok_callback = function()
                                table.remove(flashcard, tonumber(keyToDelete))
                                save(flashcard, DATA_PATH)
                                remaining = remaining - 1
                                key = nextOneOnTheBox(caja,key)
                                UIManager:close(back_dialog)
                                if key > 0 then
                                    button_dialog2:setTitle(_("box " .. flashcard[key].box .. " • " .. remaining.." cards left".."\n\n" .. flashcard[key].front.."\n"))
                                else
                                    UIManager:close(button_dialog2)
                                    local popup = InfoMessage:new({
                                        text = _("No cards due in box "..caja),
                                    })
                                    UIManager:show(popup)
                                    FlashcardViewer:boxChooser()
                                end
                            end,
                        })
                        end
                    },
                    {
                        text = "Jump",
                        callback = function()
                        UIManager:close(back_dialog)
                        key = nextOneOnTheBox(caja,key)
                        button_dialog2:setTitle(_("box " .. flashcard[key].box .. " • " .. remaining.." cards left".."\n\n" .. flashcard[key].front.."\n"))
                        end
                    },
                    },
                },
            }
            UIManager:show(back_dialog)
        end,
        },
        },
        },
    }

    if background_boolean == true then
        UIManager:show(background_widget)
    end
    UIManager:show(button_dialog2)
    else
        local popup = InfoMessage:new({
            text = _("No cards due in box "..caja),
        })
        UIManager:show(popup)
        FlashcardViewer:boxChooser()
    end
end

function writeDay(day)
dayMath = tostring(tonumber(day) + 1)
local file = assert(io.open(DAY_PATH, "w"))
file:write(dayMath)
file:close()
end

function FlashcardViewer:boxChooser()

    local day = know_which_day()

    local m, b7, b6, b5, b4, b3, b2, b1 = leitner_logic(day)

    box_dialog = ButtonDialog:new{
        title = _("Day "..day),
        title_align = "center",
        buttons = {

        {
        {
            text = "Box 7",
            enabled = b7,
            callback = function()
            UIManager:close(box_dialog)
            FlashcardViewer:study("7")
            end,
        },
        },

        {
        {
            text = "Box 6",
            enabled = b6,
            callback = function()
            UIManager:close(box_dialog)
            FlashcardViewer:study("6")
            end,
        },
        },

        {
        {
            text = "Box 5",
            enabled = b5,
            callback = function()
            UIManager:close(box_dialog)
            FlashcardViewer:study("5")
            end,
        },
        },

        {
        {
            text = "Box 4",
            enabled = b4,
            callback = function()
            UIManager:close(box_dialog)
            FlashcardViewer:study("4")
            end,
        },
        },

        {
        {
            text = "Box 3",
            enabled = b3,
            callback = function()
            UIManager:close(box_dialog)
            FlashcardViewer:study("3")
            end,
        },
        },

        {
        {
            text = "Box 2",
            enabled = b2,
            callback = function()
            UIManager:close(box_dialog)
            FlashcardViewer:study("2")
            end,
        },
        },

        {
        {
            text = "Box 1",
            callback = function()
            UIManager:close(box_dialog)
            FlashcardViewer:study("1")
            end,
        },
        },

        {
        {
            text = "Finish day",
            callback = function()
            UIManager:close(box_dialog)
            writeDay(day)
            end,
        },
        },


        },
    }

    UIManager:show(box_dialog)
end

function nextOneOnTheBox(which_box, key)
    local flashcard, headers = ftcsv.parse(DATA_PATH)
    key = key or 1
    logger.info("=== Started function nextOneOnTheBox", which_box, key)
    local box_1, box_2, box_3, box_4, box_5, box_6, box_7, other_cards = countSilent()
    local all_cards_count = box_1 + box_2 + box_3 + box_4 + box_5 + box_6 + box_7 + other_cards
    logger.info("=== Cards counted", all_cards_count)
    if which_box == "1" then
        box_count = box_1
        logger.info("=== Box 1!")
    elseif which_box == "2" then
        box_count = box_2
        logger.info("=== Box 2!")
    elseif which_box == "3" then
        box_count = box_3
        logger.info("=== Box 3!")
    elseif which_box == "4" then
        box_count = box_4
        logger.info("=== Box 4!")
    elseif which_box == "5" then
        box_count = box_5
        logger.info("=== Box 5!")
    elseif which_box == "6" then
        box_count = box_6
        logger.info("=== Box 6!")
    elseif which_box == "7" then
        box_count = box_7
        logger.info("=== Box 7!")
    end
    logger.info("=== Box count = ", box_count)
    local working = 0
    while working == 0 do
        if box_count >= 1 then
            if key < all_cards_count then
                key = key + 1
                --logger.info("=== trying key "..key)
            --[[elseif key == all_cards_count then
                logger.info("=== BOX = ", flashcard[key].box)
                if flashcard[key].box == which_box then
                    logger.info("=== Found a match! = ", key)
                    working = 1
                    return key
                else
                    key = 1
                    logger.info("=== Started again counting from 1 again")
                end]]
            else
                key = 1
                logger.info("=== Started again counting from 1 again")
            end
            if flashcard[key].box == which_box then
                logger.info("=== Found a match! = ", key)
                working = 1
                return key
            end
            --local box_1, box_2, box_3, box_4, box_5, boc_6, box_7 = countSilent()
        else
            working = 1
            logger.info("=== Exited")
            return 0
        end
    end
end

function FlashcardViewer:onFlashcardViewer()
    logger.info(KO_PATH)
    logger.info(DATA_PATH)
    importCards()
    FlashcardViewer:boxChooser()
end

-- START OF ADDMING FLASHCARDS SECTION

function FlashcardViewer:onAddFlashcard()
    FlashcardViewer:inputScreen()
end

function FlashcardViewer:inputScreen()
    local the_input
    the_input = MultiInputDialog:new{
        title = _("Add flashcard"),
        fields = {
        {
            text = "",
            hint = _("Front"),
        },
        {
            text = "",
            hint = _("Back"),
        },
        },
        buttons = {
            {
            {
                text = _("Add"),
                callback = function()
                    local fields = the_input:getFields()
                    --UIManager:close(the_input)
                    addFlashcard(fields[1],fields[2])
                    local popup = InfoMessage:new({
                        text = _(fields[1] .. "\n" .. fields[2]),
                    })
                    UIManager:show(popup)
                end,
            },
            {
                text = _("Cancel"),
                id = "close",
                callback = function()
                    UIManager:close(the_input)
                end,
            },
            },
            --{
                --{
                    --text = _("Edit"),
                    --callback = function()
                    --    UIManager:close(file_input)
                    --end,
                --},
            --},
        },
    }
    UIManager:show(the_input)
    the_input:onShowKeyboard()
end


-- START OF EDITING FLASHCARDS SECTION

function FlashcardViewer:onEditFlashcard()
    FlashcardViewer:askForBox()
end

function FlashcardViewer:askForBox()
    local boxInput
    boxInput = InputDialog:new{
        title = _("Pick a box number"),
        input = "",
        input_hint = _("1-7"),
        buttons = {
        {
        {
            text = _("Cancel"),
            --background = Blitbuffer.COLOR_WHITE,
            callback = function()
                UIManager:close(boxInput)
            end,
        },
        {
            text = _("Go"),
            callback = function()
                local box_input = boxInput:getInputText() or ""
                UIManager:close(boxInput)
                FlashcardViewer:listBox(box_input)
            end
        },
        },
        },
    }
    UIManager:show(boxInput)
    boxInput:onShowKeyboard()
end

function FlashcardViewer:listBox(box)
    local file = DATA_PATH
    local item__table = {}
    local flashcard, headers = ftcsv.parse(file)

    for key, value in pairs(flashcard) do
        if flashcard[key].box == box then
            entry = FlashcardViewer:buildResultMenuEntry(flashcard[key].front)
            if entry then
                table.insert(item__table, entry)
            end
        end
    end


    results_menu = Menu:new {
        title = string.format(_("Box %s…"), box),
        item_table = item__table,
        is_borderless = true,
    }

    UIManager:show(results_menu)

end


function FlashcardViewer:buildResultMenuEntry(data)
    return {
        text = data,
        callback = function()
            FlashcardViewer:editScreen(data)
        end,
        hold_keep_menu_open = true,
    }
end

function FlashcardViewer:editScreen(front)

    local file = DATA_PATH
    local flashcard, headers = ftcsv.parse(file)
    local frontEdit
    local backEdit
    local boxEdit
    local editingKey

    for key, value in pairs(flashcard) do
        if flashcard[key].front == front then
            frontEdit = flashcard[key].front
            backEdit = flashcard[key].back
            boxEdit = flashcard[key].box
            editingKey = key
        end
    end

    local the_input
    the_input = MultiInputDialog:new{
        title = _("Edit flashcard"),
        fields = {
        {
            text = frontEdit,
            hint = _("Front"),
        },
        {
            text = backEdit,
            hint = _("Back"),
        },
        },
        buttons = {
            {
            {
                text = _("Edit"),
                callback = function()
                    local fields = the_input:getFields()
                    UIManager:close(the_input)
                    table.remove(flashcard, tonumber(editingKey))
                    --flashcard[editingKey].front = fields[1]
                    --flashcard[editingKey].back = fields[2]
                    save(flashcard, DATA_PATH)
                    addFlashcard(fields[1],fields[2],boxEdit)
                    local popup = InfoMessage:new({
                        text = _(fields[1] .. "\n" .. fields[2]),
                    })
                    UIManager:show(popup)
                end,
            },
            --},
            --{
            {
                text = _("Cancel"),
                id = "close",
                callback = function()
                UIManager:close(the_input)
                end,
            },
            },
        },
    }
    UIManager:show(the_input)
    the_input:onShowKeyboard()
end

function FlashcardViewer:editScreenWhileStudying(front, boxToGoBack)

    local file = DATA_PATH
    local flashcard, headers = ftcsv.parse(file)
    local frontEdit
    local backEdit
    local boxEdit
    local editingKey

    for key, value in pairs(flashcard) do
        if flashcard[key].front == front then
            frontEdit = flashcard[key].front
            backEdit = flashcard[key].back
            boxEdit = flashcard[key].box
            editingKey = key
        end
    end

    local the_input
    the_input = MultiInputDialog:new{
        title = _("Edit flashcard"),
        fields = {
        {
            text = frontEdit,
            hint = _("Front"),
        },
        {
            text = backEdit,
            hint = _("Back"),
        },
        },
        buttons = {
            {
            {
                text = _("Edit"),
                callback = function()
                    local fields = the_input:getFields()
                    UIManager:close(the_input)
                    table.remove(flashcard, tonumber(editingKey))
                    --flashcard[editingKey].front = fields[1]
                    --flashcard[editingKey].back = fields[2]
                    save(flashcard, DATA_PATH)
                    addFlashcard(fields[1],fields[2],boxEdit)
                    FlashcardViewer:study(boxToGoBack)
                    local popup = InfoMessage:new({
                        text = _(fields[1] .. "\n" .. fields[2]),
                    })
                    UIManager:show(popup)
                end,
            },
            --},
            --{
            {
                text = _("Cancel"),
                id = "close",
                callback = function()
                UIManager:close(the_input)
                FlashcardViewer:study(boxToGoBack)
                end,
            },
            },
        },
    }
    UIManager:show(the_input)
    the_input:onShowKeyboard()
end

-- END OF EDITING SECTION

return FlashcardViewer
