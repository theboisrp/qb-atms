local dailyWithdraws = {}
local QBCore = exports['qb-core']:GetCoreObject()

-- Thread

Citizen.CreateThread(function()
    while true do
        Wait(3600000)
        dailyWithdraws = {}
        TriggerClientEvent('QBCore:Notify', -1, "Daily Withdraw Limit Reset", "success")
    end
end)

-- Command

RegisterCommand('atm', function(source)
    local src = source
    local xPlayer = QBCore.Functions.GetPlayer(src)
    local visas = xPlayer.Functions.GetItemsByName('visa')
    local masters = xPlayer.Functions.GetItemsByName('mastercard')
    local cards = {}

    if visas ~= nil and masters ~= nil then
        for _, v in pairs(visas) do
            local info = v.info
            local cardNum = info.cardNumber
            local cardHolder = info.citizenid
            local xCH = QBCore.Functions.GetPlayerByCitizenId(cardHolder)
            if info.bizacc == nil then
                if xCH ~= nil then
                    if xCH.PlayerData.charinfo.card.cardNumber ~= cardNum then
                        info.cardActive = false
                    end
                else
                    local player = exports.oxmysql:executeSync('SELECT charinfo FROM players WHERE citizenid = ?', { info.citizenid })
                    local xCH = json.decode(player[1].charinfo)
                    if xCH.card.cardNumber ~= cardNum then
                        info.cardActive = false
                    end
                end
            else
                local dbdata = exports.oxmysql:executeSync('SELECT card FROM bank_accounts WHERE buisnessid = ?', { info.citizenid })
                local bizacc = json.decode(dbdata[1].card)
                if bizacc.cardNumber ~= cardNum then
                    info.cardActive = false
                end
            end
            cards[#cards+1] = v.info
        end
        for _, v in pairs(masters) do
            local info = v.info
            local cardNum = info.cardNumber
            local cardHolder = info.citizenid
            local xCH = QBCore.Functions.GetPlayerByCitizenId(cardHolder)
            if info.bizacc == true then
                local dbdata = exports.oxmysql:executeSync('SELECT * FROM `bank_accounts` WHERE buisnessid = ?;', { info.citizenid })
                local bizacc = json.decode(dbdata[1].card)
                if bizacc.cardNumber ~= cardNum then
                    info.cardActive = false
                end
            else
                if xCH ~= nil then
                    if xCH.PlayerData.charinfo.card.cardNumber ~= cardNum then
                        info.cardActive = false
                    end
                else
                    local player = exports.oxmysql:executeSync('SELECT charinfo FROM players WHERE citizenid = ?', { info.citizenid })
                    xCH = json.decode(player[1].charinfo)
                    if xCH.card.cardNumber ~= cardNum then
                        info.cardActive = false
                    end
                end
            end
            cards[#cards+1] = v.info
        end
    end
    TriggerClientEvent('qb-atms:client:loadATM', src, cards)
end)

-- Event

RegisterServerEvent('qb-atms:server:doAccountWithdraw')
AddEventHandler('qb-atms:server:doAccountWithdraw', function(data)
    if data ~= nil then
        local src = source
        local xPlayer = QBCore.Functions.GetPlayer(src)
        local cardHolder = data.cid
        local xCH = QBCore.Functions.GetPlayerByCitizenId(cardHolder)

        if not dailyWithdraws[cardHolder] then
            dailyWithdraws[cardHolder] = 0
        end

        local dailyWith = tonumber(dailyWithdraws[cardHolder]) + tonumber(data.amount)
        if isbizacc == false then
            if dailyWith < Config.DailyLimit and xCH.PlayerData.charinfo.card.cardLocked ~= true then
                local banking = {}
                if xCH ~= nil then
                    local bank = xCH.Functions.GetMoney('bank')
                    local bankCount = xCH.Functions.GetMoney('bank') - tonumber(data.amount)
                    if bankCount > 0 then
                        xCH.Functions.RemoveMoney('bank', tonumber(data.amount))
                        xPlayer.Functions.AddMoney('cash', tonumber(data.amount))
                        dailyWithdraws[cardHolder] = dailyWithdraws[cardHolder] + tonumber(data.amount)
                        TriggerClientEvent('QBCore:Notify', src, "Withdraw $" .. data.amount .. ' from credit card. Daily Withdraws: ' .. dailyWithdraws[cardHolder], "success")
                    else
                        TriggerClientEvent('QBCore:Notify', src, "Not Enough Money", "error")
                    end

                    banking['online'] = true
                    banking['name'] = xCH.PlayerData.charinfo.firstname .. ' ' .. xCH.PlayerData.charinfo.lastname
                    banking['bankbalance'] = xCH.Functions.GetMoney('bank')
                    banking['accountinfo'] = xCH.PlayerData.charinfo.account
                    banking['cash'] = xPlayer.Functions.GetMoney('cash')
                else
                    local player = exports.oxmysql:executeSync('SELECT * FROM players WHERE citizenid = ?', { cardHolder })
                    local xCH = json.decode(player[1])
                    local bankCount = tonumber(xCH.money.bank) - tonumber(data.amount)
                    if bankCount > 0  then
                        xPlayer.Functions.AddMoney('cash', tonumber(data.amount))
                        xCH.money.bank = bankCount
                        exports.oxmysql:execute('UPDATE players SET money = ? WHERE citizenid = ?', { xCH.money, cardHolder })
                        dailyWithdraws[cardHolder] = dailyWithdraws[cardHolder] + tonumber(data.amount)
                        TriggerClientEvent('QBCore:Notify', src, "Withdraw $" .. data.amount .. ' from credit card. Daily Withdraws: ' .. dailyWithdraws[cardHolder], "success")
                    else
                        TriggerClientEvent('QBCore:Notify', src, "Not Enough Money", "error")
                    end

                    banking['online'] = false
                    banking['name'] = xCH.charinfo.firstname .. ' ' .. xCH.charinfo.lastname
                    banking['bankbalance'] = xCH.money.bank
                    banking['accountinfo'] = xCH.charinfo.account
                    banking['cash'] = xPlayer.Functions.GetMoney('cash')
                end
                TriggerClientEvent('qb-atms:client:updateBankInformation', src, banking)
            else
                TriggerClientEvent('QBCore:Notify', src, "You have reached the daily limit or card locked", "error")
            end
        else
            --biz
            local dbdata = exports.oxmysql:executeSync('SELECT * FROM `bank_accounts` WHERE buisnessid = ?;', { cardHolder })
            if dailyWith < Config.DailyLimit and json.decode(dbdata[1]["card"]).cardLocked ~= true then
                local banking = {}
                local bank = dbdata[1]["amount"]
                local bankCount = dbdata[1]["amount"] - tonumber(data.amount)
                if bankCount > 0 then
                    endresult = dbdata[1]["amount"] - tonumber(data.amount)
                    xPlayer.Functions.AddMoney('cash', tonumber(data.amount))
                    setmoneybiz(endresult, dbdata[1]["buisnessid"])
                    dailyWithdraws[cardHolder] = dailyWithdraws[cardHolder] + tonumber(data.amount)
                    TriggerClientEvent('QBCore:Notify', src, "Withdraw $" .. data.amount .. ' from credit card. Daily Withdraws: ' .. dailyWithdraws[cardHolder], "success")
                else
                    TriggerClientEvent('QBCore:Notify', src, "Not Enough Money", "error")
                end

                banking['online'] = true
                banking['name'] = dbdata[1]["buisness"]
                banking['bankbalance'] = dbdata[1]["amount"]
                banking['accountinfo'] = dbdata[1]["accountnumber"]
                banking['cash'] = xPlayer.Functions.GetMoney('cash')
                TriggerClientEvent('qb-atms:client:updateBankInformation', src, banking)
            else
                TriggerClientEvent('QBCore:Notify', src, "You have reached the daily limit or card locked", "error")
            end
            --biz

        end
    end
end)

-- Callbacks

QBCore.Functions.CreateCallback('qb-debitcard:server:requestCards', function(source, cb)
    local src = source
    local xPlayer = QBCore.Functions.GetPlayer(src)
    local visas = self.Functions.GetItemsByName('visa')
    local masters = self.Functions.GetItemsByName('mastercard')
    local cards = {}

    if visas ~= nil and masters ~= nil then
        for _, v in visas do
            cards[#cards+1] = v.info
        end
        for _, v in masters do
            cards[#cards+1] = v.info
        end
    end
    return cards
end)

QBCore.Functions.CreateCallback('qb-debitcard:server:deleteCard', function(source, cb, data)
    local cn = data.cardNumber
    local ct = data.cardType
    local src = source
    local xPlayer = QBCore.Functions.GetPlayer(src)
    local found = xPlayer.Functions.GetCardSlot(cn, ct)
    if found ~= nil then
        xPlayer.Functions.RemoveItem(ct, 1, found)
        cb(true)
    else
        cb(false)
    end
end)

function setmoneybiz(amount, bizacc)
    exports.oxmysql:executeSync("UPDATE `bank_accounts` SET `amount` = :amount WHERE `bank_accounts`.`buisnessid` = :bid;",{
        bid = bizacc,
        amount = amount
    })
end

local function isbanklocked(xPlayer, cb)
    local citizenid = xPlayer.PlayerData.citizenid
    exports.oxmysql:single('SELECT * FROM players where citizenid = ?', { citizenid }, function(result)
        if result then
            cb(result.banklocked)
        else
            cb("false")
        end
    end)
end

local function bizisbanklocked(bizid, cb)
    exports.oxmysql:single('SELECT * FROM bank_accounts where buisnessid = ?', { bizid }, function(result)
        if result then
            print(result.banklocked)
            cb(result.banklocked)
        else
            cb("false")
        end
    end)
end

QBCore.Functions.CreateCallback('qb-atms:server:loadBankAccount', function(source, cb, cid, cardnumber, isbizacc)
    local src = source
    local xPlayer = QBCore.Functions.GetPlayer(src)
    local cardHolder = cid
    local xCH = QBCore.Functions.GetPlayerByCitizenId(cardHolder)
    local banking = {}
    if isbizacc == false then
        if xCH ~= nil then
            isbanklocked(xCH, function(result)
                if (result == "true") then
                    print("Online Acc locked")
                    banking['online'] = true
                    banking['name'] = "ACCOUNT LOCKED"
                    banking['bankbalance'] = 0
                    banking['accountinfo'] = ""
                    banking['cash'] = xPlayer.Functions.GetMoney('cash')
                    cb(banking)
                elseif xCH.PlayerData.charinfo.card.cardLocked ~= true then
                    print("normal normal")
                    banking['online'] = true
                    banking['name'] = xCH.PlayerData.charinfo.firstname .. ' ' .. xCH.PlayerData.charinfo.lastname
                    banking['bankbalance'] = xCH.Functions.GetMoney('bank')
                    banking['accountinfo'] = xCH.PlayerData.charinfo.account
                    banking['cash'] = xPlayer.Functions.GetMoney('cash')
                    cb(banking)
                else
                    print("online locked")
                    banking['online'] = true
                    banking['name'] = "CARD LOCKED"
                    banking['bankbalance'] = 0
                    banking['accountinfo'] = ""
                    banking['cash'] = xPlayer.Functions.GetMoney('cash')
                    cb(banking)
                end
            end)
            print(banking['name'])
        else
            local player = exports.oxmysql:executeSync('SELECT * FROM players WHERE citizenid = ?', { cardHolder })
            local xCH = json.decode(player[1])
            isbanklocked(xCH, function(result)
                if result == "true" then
                    print("offline Acc locked")
                    banking['online'] = false
                    banking['name'] = "ACCOUNT LOCKED"
                    banking['bankbalance'] = 0
                    banking['accountinfo'] = ""
                    banking['cash'] = xPlayer.Functions.GetMoney('cash')
                    cb(banking)
                elseif xCH.PlayerData.charinfo.card.cardLocked == false then
                    print("offline normal")
                    banking['online'] = false
                    banking['name'] = xCH.charinfo.firstname .. ' ' .. xCH.charinfo.lastname
                    banking['bankbalance'] = xCH.money.bank
                    banking['accountinfo'] = xCH.charinfo.account
                    banking['cash'] = xPlayer.Functions.GetMoney('cash')
                    cb(banking)
                else 
                    print("offline locked")
                    banking['online'] = false
                    banking['name'] = "CARD LOCKED"
                    banking['bankbalance'] = 0
                    banking['accountinfo'] = ""
                    banking['cash'] = xPlayer.Functions.GetMoney('cash')
                    cb(banking)
                end
            end)
        end
    else
        local dbdata = exports.oxmysql:executeSync('SELECT * FROM `bank_accounts` WHERE buisnessid = ?;', { cardHolder })
        bizisbanklocked(cardHolder, function(result)
            if result == "true" then
                print("biz acc locked")
                banking['online'] = false
                banking['name'] = "Account LOCKED"
                banking['bankbalance'] = 0
                banking['accountinfo'] = ""
                banking['cash'] = xPlayer.Functions.GetMoney('cash')
                cb(banking)
            elseif json.decode(dbdata[1]["card"]).cardLocked == false then
                print("biz normal")
                banking['online'] = true
                banking['name'] = dbdata[1]["buisness"]
                banking['bankbalance'] = dbdata[1]["amount"]
                banking['accountinfo'] = dbdata[1]["accountnumber"]
                banking['cash'] = xPlayer.Functions.GetMoney('cash')
                cb(banking)
            else 
                print("biz locked")
                banking['online'] = false
                banking['name'] = "CARD LOCKED"
                banking['bankbalance'] = 0
                banking['accountinfo'] = ""
                banking['cash'] = xPlayer.Functions.GetMoney('cash')
                cb(banking)
            end
        end)
    end
end)
