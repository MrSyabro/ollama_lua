local REST = require "rest"
local obj = require "obj"

local ollama = REST:new("http://127.0.0.1:11434/api")

---@alias message {role: string, content: string}

---@class OllamaToolParameter
---@field type string
---@field description string
---@field enum string[]?

---@class OllamaTool
---@field name string
---@field description string
---@field parameters {type: string, properties: table<string, OllamaToolParameter>, required: string[]?}

---@class OllamaChat : Object
---@field model string
---@field messages message[]
---@field protected stream false
---@field tools table?
local ollama_chat = obj:new "OllamaChat"

---@param tools table
---@param name string
---@return table?
local function search_tool(tools, name)
    for _, tool in ipairs(tools) do
        if tool["function"].name == name then
            return tool
        end
    end
end

---Отправить чат на обработку
---@return string
function ollama_chat:request()
    local response = ollama.chat.POST(self)
    if not response.message then error(require"serialize".serialize(response, true)) end
    table.insert(self.messages, response.message)
    local tool_calls = response.message.tool_calls
    if tool_calls then
        for _, tool_call in ipairs(tool_calls) do
            local tool_name = tool_call["function"].name
            local tool = search_tool(self.tools, tool_name)
            local success, result = pcall(tool, tool_call["function"].arguments)
            if not success then result = "error" end
            table.insert(self.messages, {
                role = "tool",
                content = result
            })
            return self:request()
        end
    else
        return response.message.content
    end
end

---Отправляет сообщение и возвращает ответ
---@param message string
---@return string
function ollama_chat:send(message)
    assert(type(message) == "string", "message must be string")
    table.insert(self.messages, {
        role = "user",
        content = message
    })
    return self:request()
end

---Устанавливает системное сообщение
---@param message any
function ollama_chat:set_system(message)
    assert(type(message) == "string", "message must be string")
    table.insert(self.messages, 1, {
        role = "system",
        content = message
    })
end

---Добавляет инструмент в чат
---@param tool OllamaTool
---@param callback function
function ollama_chat:add_tool(tool, callback)
    if not self.tools then self.tools = {} end
    local tool = {
        type = "function",
        ["function"] = tool
    }
    setmetatable(tool, {__call = function(tool, args)
        return callback(args)
    end})
    table.insert(self.tools, tool)
end

---@param model string
---@return OllamaChat
function ollama_chat:new(model)
    assert(type(model) == "string", "Model must be string")
    local new_chat = obj.new(self)
    new_chat.model = model
    new_chat.messages = {}
    new_chat.stream = false

    return new_chat
end


---@class OllamaGenerate : Object
---@field model string
---@field protected stream false
---@field system string?
---@field context number[]?
local ollama_generate = obj:new "OllamaGenerate"

---Отправить моделе промпт
---@param prompt string
---@return string
function ollama_generate:send(prompt)
    assert(type(prompt) == "string", "prompt must be string")
    self.prompt = prompt
    local result = ollama.generate.POST(self)
    self.context = result.context

    return result.response
end

---Создать новый экземпляр генератора ответов
---@param model string
---@return OllamaGenerate
function ollama_generate:new(model)
    assert(type(model) == "string", "Model must be string")
    local new_generate = obj.new(self)
    new_generate.model = model
    new_generate.stream = false

    return new_generate
end


---Несуществующие поля транслируются в REST запрос
---@class Ollama : REST
local M = {
    chat = ollama_chat,
    generate = ollama_generate,
    __index = function(M, key)
        return ollama[key].POST
    end
}

return setmetatable(M, M)