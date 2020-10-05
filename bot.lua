local discordia = require("discordia")
local json = require("json")
local timer = require("timer")
local coro = require("coro-http")
local client = discordia.Client()
local Prefix = "L!"

local PaydayWait = {}

function IsCooldown(id, c)
    for i,v in pairs(PaydayWait) do
        if type(v) == "table" then
            if v.memberid == id then
                if v.cmd == c then
                    return true, v
                end
            end
        end
    end
    return false
end

local Payday = function(message)
    local member = message.member
    local memberid = member.id
    local isCool, Table = IsCooldown(memberid, "payday")
    if isCool == false then
        local open = io.open("eco.json", "r")
        local parse = json.parse(open:read())
        local earned = 50
        table.insert(PaydayWait, {memberid = member.id, cmd = "payday", time = 120})
        open:close()
        if parse[memberid] then
            parse[memberid] = parse[memberid] + earned
        else
            parse[memberid] = earned
        end
        message:reply("<@!"..memberid.."> has earned $"..earned.."!")
        open = io.open("eco.json", "w")
        open:write(json.stringify(parse))
        open:close()
    elseif Table ~= nil then
        message:reply("<@!"..memberid.."> sorry but you still have to wait "..Table.time.." seconds left!")
    end
end

local CheckBalance = function(message)
    local mentioned = message.mentionedUsers
    if #mentioned == 1 then
        local member = message.guild:getMember(mentioned[1][1])
        local open = io.open("eco.json", "r")
        local parse = json.parse(open:read())
        if parse[member.id] then
            message:reply("<@!"..message.member.id..">, <@!"..member.id.."> has $"..parse[member.id].."!")
        else
            message:reply("They have no money!")
        end
        open:close()
    elseif #mentioned == 0 then
        local member = message.member
        local memberid = member.id
        local open = io.open("eco.json", "r")
        local parse = json.parse(open:read())
        message:reply("<@!"..memberid.."> You have $"..parse[memberid].."!")
        open:close()
    end
end

local GambleChances = {
    {value = -1, Min = 1, Max = 20};
    {value = -.5, Min = 21, Max = 45};
    {value = 0, Min = 46, Max = 55};
    {value = .25, Min = 56, Max = 65};
    {value = .5, Min = 66, Max = 80};
    {value = 1, Min = 80, Max = 95};
    {value = 2, Min = 96, Max = 100};
}
local GambleMoney = function(message)
    local content = message.content
    local member = message.member
    local memberid = member.id
    local CommandStart, CommandEnd = string.find(content, "Gamble")
    local newString = string.sub(content, CommandEnd+1)
    local isNumber = tonumber(newString)
    local open = io.open("eco.json", "r")
    local parse = json.parse(open:read())
    open:close()
    if parse[memberid] then
        if isNumber and parse[memberid] >= isNumber then
            local Chance = math.random(1,100)
            for i,v in pairs(GambleChances) do
                if v.Min <= Chance and Chance <= v.Max then
                    isNumber = isNumber * v.value
                    parse[memberid] = parse[memberid] + isNumber
                    message:reply("You gained "..isNumber.. " by gambling.")
                    open = io.open("eco.json", "w")
                    open:write(json.stringify(parse))
                    open:close()
                end
            end
        end
    else
        message:reply("Please enter a valid number")
    end
end

local GiftMoney = function(message)
    local content = message.content
    local member = message.member
    local memberid = member.id

    local mentioned = message.mentionedUsers
    if #mentioned == 1 and mentioned[1][1] ~= memberid then
        local recieve = message.guild:getMember(mentioned[1][1])
        local mentionedStart, mentionedEnd = string.find(content, recieve.id)
        local newString = string.sub(content, mentionedEnd+2)
        local isNumber = tonumber(newString)
        local open = io.open("eco.json", "r")
        local parse = json.parse(open:read())
        open:close()
        if isNumber and parse[memberid] >= isNumber then
            if not parse[recieve.id] then parse[recieve.id] = 0 end
            open = io.open("eco.json", "w")
            parse[memberid] = parse[memberid] - isNumber
            parse[recieve.id] = parse[recieve.id] + isNumber
            open:write(json.stringify(parse))
            open:close()
            message:reply("Money tranferred.")
        else
            message:reply("<@!"..memberid.."> Please enter a valid amount.")
        end
    else
        message:reply("<@!"..memberid.."> Please tag the member who you are trying to give money to.")
    end
end

local Commands = {
    Economy = {
        {name = "Payday", func = Payday, description = "Recieve your income. *Available every two minutes*", help = "Use the command "..Prefix.."Payday to get your income."};
        {name = "Balance", func = CheckBalance, description = "Check your balance.", help = "Use the command "..Prefix.."Balance **[Person]** *(Optional)* to get your or someone elses current balance."};
        {name = "Gamble", func = GambleMoney, description = "Gamble with your money.", help = "Use the command "..Prefix.."Gamble **[Amount]** to have a chance to gain or lose money."};
        {name = "Gift", func = GiftMoney, description = "Gift money to another person.", help = "Use the command "..Prefix.."Gift **[Person]** **[Amount]** to give some of your money to another person."}
    };
}

for i,v in pairs(Commands) do
    print(i,v)
end

local GetCateg = function(Categ)
    local List = {}
    for i,v in pairs(Categ) do
        local newAdd = {name = v.name, value = v.description}
        table.insert(List,i,newAdd)
    end
    return List
end

client:on("messageCreate", function(message)
    local content = message.content
    local member = message.member
    local memberid = member.id

    local PreStart,PreEnd = string.find(content, Prefix)
    if PreStart == 1 and PreEnd == #Prefix then
        local CommandStart, CommandEnd = string.find(content,"Commands")
        local HelpStart, HelpEnd = string.find(content,"Help")
        if CommandStart == #Prefix+1 and CommandEnd == #Prefix + #"Commands" then
            message:reply{
                embed = {
                    title = "Help";
                    fields = {
                        {name = "Commands", value = "Get a list of all the commands."};
                        {name = "Help", value = "Get a description on how to use a command."}
                    }
                }
            }
            for i,Categ in pairs(Commands) do
                local passFields = GetCateg(Categ)
                message:reply{
                    embed = {
                        title = i,
                        fields = passFields
                    }
                }
            end
        elseif HelpStart == #Prefix+1 and HelpEnd == #Prefix + #"Help" then
            for i,v in pairs(Commands) do
                for _,Categ in pairs(v) do
                    if string.find(content, Categ.name) and Categ.name ~= "Help" then
                        message:reply(Categ.help)
                    end
                end
            end
        else
            for i,v in pairs(Commands) do
                for _,Categ in pairs(v) do
                    local NameStart, NameEnd = string.find(content, Categ.name)
                    if NameStart == #Prefix+1 and NameEnd == #Prefix+#Categ.name then
                        Categ.func(message)
                    end
                end
            end
        end
    end
end)

timer.setInterval(1000, function()
    for i,v in pairs(PaydayWait) do
        if type(v) == "table" then
            if v.time > 0 then
                PaydayWait[i].time = PaydayWait[i].time - 1
            else
                PaydayWait[i] = nil
            end
        end
    end
end)

client:run("Bot NzYxMzM3OTYxMjk5MTgxNTk4.X3ZJOg.YCZCyt48jl6W2icJtf41QF9raKg")