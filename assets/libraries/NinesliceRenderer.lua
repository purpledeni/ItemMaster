---@class NinesliceRenderer: LoamRenderer
---@field nineslice Nineslice
---@field part ModelPart
---@field depth number
local NinesliceRenderer = {}
NinesliceRenderer.__index = NinesliceRenderer

---@class Nineslice
---@field texture Texture
---@field slice_size number

---@param part ModelPart
---@param nineslice Nineslice
function NinesliceRenderer.new(part, nineslice)
    local self = setmetatable({}, NinesliceRenderer)
    self.nineslice = nineslice
    self.part = part
    self.depth = 0
    self.to_draw = {}
    self.rendering = {}
    self.last_frame = {}
    return self
end

function NinesliceRenderer:draw_rect(pos, size, colour, slice_index, depth)
    local index = table.concat({ pos.x, pos.y, size.x, size.y, colour.x, colour.y, colour.z, slice_index, depth })

    local to_draw = self.to_draw
    local rendering = self.rendering

    to_draw[index] = function()
        local texture = self.nineslice.texture
        local slice = self.nineslice.slice_size

        local inner_width = size.x - (slice * 2)
        local inner_height = size.y - (slice * 2)

        local slice_offset = slice_index * slice * 3

        for i = 0, 2 do
            for j = 0, 2 do
                local uv_x = j * slice + slice_offset
                local uv_y = i * slice

                local pos_x = (j == 1) and slice or (j == 2 and size.x - slice or 0)
                local pos_y = (i == 1) and slice or (i == 2 and size.y - slice or 0)

                local scale_x = (j == 1) and inner_width / slice or 1
                local scale_y = (i == 1) and inner_height / slice or 1

                if size.x > slice and size.y > slice then
                    rendering[self.part:newSprite(index .. i .. j)
                        :texture(texture)
                        :size(slice, slice)
                        :uvPixels(uv_x, uv_y)
                        :region(slice, slice)
                        :pos(-pos.x - pos_x, -pos.y - pos_y, -depth)
                        :scale(scale_x, scale_y)
                        :renderType("CUTOUT_EMISSIVE_SOLID")
                        :color(colour)] = index
                end
            end
        end
    end
end

function NinesliceRenderer:draw_text(pos, text, text_scale, text_width, depth)
    local index = table.concat({ pos.x, pos.y, text, text_scale, text_width or 0, depth })

    local to_draw = self.to_draw
    local rendering = self.rendering

    to_draw[index] = function()
        rendering[self.part:newText(index)
            :text(text)
            :shadow(true)
            :scale(text_scale)
            :width(text_width)
            :pos(-pos.x, -pos.y, -depth)] = index
    end
end

function NinesliceRenderer:draw_item(pos, size, item, depth)
    local index = table.concat({ pos.x, pos.y, size.x, size.y, item, depth })

    local to_draw = self.to_draw
    local rendering = self.rendering

    to_draw[index] = function()
        rendering[self.part:newItem(index)
            :item(item)
            :displayMode("GUI")
            :scale(size.x / 16, size.y / 16, 1)
            :overlay(0, 15)
            :pos(-pos.x - size.x / 2, -pos.y - size.y / 2, -depth - 10)] = index
    end
end

function NinesliceRenderer:draw_texture(pos, size, texture, depth)
    local index = table.concat({ pos.x, pos.y, size.x, size.y, tostring(texture), depth })

    local to_draw = self.to_draw
    local rendering = self.rendering

    to_draw[index] = function()
        local texture_size = texture.texture:getDimensions()
        local tile = texture.tile
        local region = tile
            and vec(texture.region.x * (size.x / texture_size.x), texture.region.y * (size.y / texture_size.y))
            or texture.region

        rendering[self.part:newSprite(index)
            :texture(texture.texture)
            :region(region)
            :uvPixels(texture.uv.x, texture.uv.y)
            :pos(-pos.x, -pos.y, -depth)
            :scale(size.x / texture_size.x, size.y / texture_size.y)
            :renderType(texture.render_type or "CUTOUT")] = index
    end
end

function NinesliceRenderer:draw_all()
    local to_draw = self.to_draw
    local rendering = self.rendering
    local last_frame = self.last_frame

    for index, func in pairs(to_draw) do
        if not last_frame[index] then
            func()
        end
    end

    for task, index in pairs(rendering) do
        if not to_draw[index] then
            task:remove()
            rendering[task] = nil
        end
    end

    self.last_frame = to_draw
    self.to_draw = {}
end

function NinesliceRenderer:clear()
    for task in pairs(self.rendering) do
        task:remove()
    end
    self.rendering = {}
    self.last_frame = {}
    self.to_draw = {}
end

return NinesliceRenderer