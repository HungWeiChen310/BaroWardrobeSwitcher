return function(name)
    local values, readIndex = {}, 1
    local buffer = { name = name, LengthBits = 0, BitPosition = 0 }

    local function bitLength(kind, value)
        if kind == "u16" then return 16 end
        if kind == "u32" then return 32 end
        if kind == "byte" then return 8 end
        if kind == "bool" then return 1 end
        if kind == "string" then return 16 + #(tostring(value or "")) * 8 end
        return 0
    end

    local function write(kind, value)
        values[#values + 1] = { kind = kind, value = value }
        buffer.LengthBits = buffer.LengthBits + bitLength(kind, value)
    end

    local function read(kind)
        local entry = assert(values[readIndex], "read beyond test buffer")
        assert(entry.kind == kind, "expected " .. kind .. ", got " .. tostring(entry.kind))
        readIndex = readIndex + 1
        buffer.BitPosition = buffer.BitPosition + bitLength(kind, entry.value)
        return entry.value
    end

    buffer.WriteUInt16 = function(value) write("u16", value) end
    buffer.ReadUInt16 = function() return read("u16") end
    buffer.WriteUInt32 = function(value) write("u32", value) end
    buffer.ReadUInt32 = function() return read("u32") end
    buffer.WriteByte = function(value) write("byte", value) end
    buffer.ReadByte = function() return read("byte") end
    buffer.WriteBoolean = function(value) write("bool", value) end
    buffer.ReadBoolean = function() return read("bool") end
    buffer.WriteString = function(value) write("string", value) end
    buffer.ReadString = function() return read("string") end
    buffer.FinalizeForTransport = function()
        buffer.LengthBits = math.ceil(buffer.LengthBits / 8) * 8
        return buffer
    end
    return buffer
end
