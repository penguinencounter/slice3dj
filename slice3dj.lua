local args = { ... }

if #args < 1 then
    printError("Usage: slice3dj <file> [outputFolder]")
    return
end

---@type string
local file = args[1]
if not file:find("%.3dj$") then
    printError("File must be a .3dj file")
    return
end
local originalFileName = file:match("([^/]+)%.3dj$")
if not originalFileName then
    print("Failed to extract original file name, using 'model'")
    originalFileName = "model"
end
if not file:find("^/") then
    file = shell.dir() .. "/" .. file
end
local f = fs.open(file, "rb")
if f == nil then
    printError("File not found")
    return
end
local info = textutils.unserialiseJSON(f.readAll() --[[@as string]], { parse_empty_array = true })
f.close()
if info == nil then
    printError("Failed to parse file")
    return
end

---@type string
local outputFolder = "multiblock/"
if #args > 1 then
    outputFolder = args[2]
else
    print("No output folder specified, using " .. outputFolder)
end
if not outputFolder:find("^/") then
    outputFolder = shell.dir() .. "/" .. outputFolder
end
if not outputFolder:find("/$") then
    outputFolder = outputFolder .. "/"
end
if not fs.exists(outputFolder) then
    print("creating output folder " .. outputFolder)
    fs.makeDir(outputFolder)
end

---@class Shape.Bounds
---@field [1] number
---@field [2] number
---@field [3] number
---@field [4] number
---@field [5] number
---@field [6] number

---@class Shape
---@field public bounds Shape.Bounds
---@field public texture string
---@field public tint string

---@class MBShape : Shape
---@field public mbX integer
---@field public mbY integer
---@field public mbZ integer

---Slice a shape.
---@param shape Shape
---@return MBShape[]
local function sliceShape(shape)
    local minMultiBlock = {
        math.floor(math.min(shape.bounds[1], shape.bounds[4]) / 16),
        math.floor(math.min(shape.bounds[2], shape.bounds[5]) / 16),
        math.floor(math.min(shape.bounds[3], shape.bounds[6]) / 16)
    }
    -- basically it only starts extending into other blocks if the shape is at least 1/16th of a block into the next block
    local maxMultiBlock = {
        math.floor((math.max(shape.bounds[1], shape.bounds[4]) - 1) / 16),
        math.floor((math.max(shape.bounds[2], shape.bounds[5]) - 1) / 16),
        math.floor((math.max(shape.bounds[3], shape.bounds[6]) - 1) / 16)
    }
    local slices = {}
    for mbX = minMultiBlock[1], maxMultiBlock[1] do
        for mbY = minMultiBlock[2], maxMultiBlock[2] do
            for mbZ = minMultiBlock[3], maxMultiBlock[3] do
                local blockBounds = {
                    mbX * 16,
                    mbY * 16,
                    mbZ * 16,
                    mbX * 16 + 16,
                    mbY * 16 + 16,
                    mbZ * 16 + 16
                }
                blockBounds[1] = math.max(shape.bounds[1], blockBounds[1])
                blockBounds[2] = math.max(shape.bounds[2], blockBounds[2])
                blockBounds[3] = math.max(shape.bounds[3], blockBounds[3])
                blockBounds[4] = math.min(shape.bounds[4], blockBounds[4])
                blockBounds[5] = math.min(shape.bounds[5], blockBounds[5])
                blockBounds[6] = math.min(shape.bounds[6], blockBounds[6])
                table.insert(slices, {
                    bounds = blockBounds,
                    texture = shape.texture,
                    tint = shape.tint,
                    mbX = mbX,
                    mbY = mbY,
                    mbZ = mbZ
                })
            end
        end
    end
    return slices
end

---Align a multiblock shape.
---@param mbshape MBShape
local function align(mbshape)
    mbshape.bounds[1] = mbshape.bounds[1] - mbshape.mbX * 16
    mbshape.bounds[2] = mbshape.bounds[2] - mbshape.mbY * 16
    mbshape.bounds[3] = mbshape.bounds[3] - mbshape.mbZ * 16
    mbshape.bounds[4] = mbshape.bounds[4] - mbshape.mbX * 16
    mbshape.bounds[5] = mbshape.bounds[5] - mbshape.mbY * 16
    mbshape.bounds[6] = mbshape.bounds[6] - mbshape.mbZ * 16
end

local fieldsToCopy = {
    "label",
    "isButton",
    "collideWhenOn",
    "collideWhenOff",
    "lightLevel",
    "redstoneLevel",
}

---@class MultiblockPart
---@field public label string
---@field public isButton boolean
---@field public collideWhenOn boolean
---@field public collideWhenOff boolean
---@field public lightLevel integer
---@field public redstoneLevel integer
---@field public positionX integer
---@field public positionY integer
---@field public positionZ integer
---@field public tooltip string
---@field public shapesOff MBShape[]
---@field public shapesOn MBShape[]

---@type MultiblockPart[]
local multiblock = {}
---@type table<integer, {x: integer, y: integer, z: integer}>
local multiblockIndex = {}

local function findExistingPart(x, y, z)
    for i, pos in ipairs(multiblockIndex) do
        if pos.x == x and pos.y == y and pos.z == z then
            return i
        end
    end
    return nil
end

local function slice(source, name)
    local startX, startY = term.getCursorPos()
    local i = 0
    for _, shape in ipairs(source) do
        term.setCursorPos(1, startY)
        term.clearLine()
        i = i + 1
        term.write("slicing " .. name .. " " .. i .. " of " .. #source)
        local slices = sliceShape(shape)
        for _, slice in ipairs(slices) do
            local part = findExistingPart(slice.mbX, slice.mbY, slice.mbZ)
            if part == nil then
                ---@type MultiblockPart
                local builder = {}
                for _, field in ipairs(fieldsToCopy) do
                    builder[field] = info[field]
                end
                builder.positionX = slice.mbX
                builder.positionY = slice.mbY
                builder.positionZ = slice.mbZ
                builder.tooltip = "§3multiblock: " .. slice.mbX .. ", " .. slice.mbY .. ", " .. slice.mbZ
                builder.shapesOff = {}
                builder.shapesOn = {}
                local index = #multiblock + 1
                multiblock[index] = builder
                multiblockIndex[index] = {
                    x = slice.mbX,
                    y = slice.mbY,
                    z = slice.mbZ
                }
                part = index
            end
            table.insert(multiblock[part][name], slice)
        end
    end
end
slice(info.shapesOff, "shapesOff")
term.clearLine()
slice(info.shapesOn, "shapesOn")
term.clearLine()
local _, startY = term.getCursorPos()
term.setCursorPos(1, startY)

print("generating output files")
for _, part in ipairs(multiblock) do
    for _, shape in ipairs(part.shapesOff) do
        align(shape)
    end
    for _, shape in ipairs(part.shapesOn) do
        align(shape)
    end
    local path = outputFolder ..
        originalFileName .. "_" .. part.positionX .. "_" .. part.positionY .. "_" .. part.positionZ .. ".3dj"
    local handle, errormsg = fs.open(path, "w")
    if handle == nil then
        printError("can't write " .. path .. " : " .. errormsg)
    else
        handle.write(textutils.serializeJSON(part))
        handle.close()
    end
end
print("done: output " .. #multiblock .. " parts :)")
