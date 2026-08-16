local assets =
{
    Asset("ANIM", "anim/book_fossil.zip"),
    Asset("ANIM", "anim/swap_book_fossil.zip"),
    Asset("ATLAS", "images/inventoryimages/book_fossil.xml"),
    Asset("IMAGE", "images/inventoryimages/book_fossil.tex"),
}

local prefabs = {}

local function onread_server(inst, reader)
    inst:PushEvent("atlas_book_read", { reader = reader })
    return true
end

local function fn()
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddSoundEmitter()
    inst.entity:AddNetwork()

    MakeInventoryPhysics(inst)

    inst.AnimState:SetBank("book_fossil")
    inst.AnimState:SetBuild("book_fossil")
    inst.AnimState:PlayAnimation("book_fossil")

    MakeInventoryFloatable(inst, "med", nil, 0.75)

    inst:AddTag("atlas_book")
    inst:AddTag("book")

    inst.entity:SetPristine()

    if not TheWorld.ismastersim then
        return inst
    end

    inst:AddComponent("inspectable")
    inst.components.inspectable:SetDescription(STRINGS.RECIPE_DESC and STRINGS.RECIPE_DESC.ATLAS_BOOK or "包含丰富知识的指南书")

    inst:AddComponent("book")
    inst.components.book.onread = onread_server
    inst.components.book.oncanread = function(inst, reader) return true end

    inst:AddComponent("inventoryitem")
    inst.components.inventoryitem.imagename = "book_fossil"
    inst.components.inventoryitem.atlasname = "images/inventoryimages/book_fossil.xml"

    inst:AddComponent("fuel")
    inst.components.fuel.fuelvalue = TUNING.MED_FUEL
    MakeSmallBurnable(inst, TUNING.MED_BURNTIME)
    MakeSmallPropagator(inst)
    MakeHauntableLaunch(inst)

    return inst
end

return Prefab("atlas_book", fn, assets, prefabs)