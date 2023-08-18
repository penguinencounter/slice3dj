local args = {...}
if #args ~= 1 then
    printError("usage: printall <dir>")
    return
end

local dir = args[1]
if not dir:find("^/") then dir = shell.dir() .. "/" .. dir end
if not dir:find("^/") then dir = "/" .. dir end
if not dir:find("/$") then dir = dir .. "/" end

local files = fs.list(dir)
for _, file in ipairs(files) do
    shell.run("print3d " .. dir .. file)
end
