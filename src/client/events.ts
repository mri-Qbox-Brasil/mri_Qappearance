export enum Send {
    visible = 'appearance:visible',
    data = 'appearance:data',
}

export enum Receive {
    toggleItem = 'appearance:toggleItem',

    save = 'appearance:save',
    cancel = 'appearance:cancel',

    camZoom = 'appearance:camZoom',
    camMove = 'appearance:camMove',
    camSection = 'appearance:camSection',


    setModel = 'appearance:setModel',
    setHeadStructure = 'appearance:setHeadStructure',
    setHeadOverlay = 'appearance:setHeadOverlay',
    setHeadBlend = 'appearance:setHeadBlend',
    setProp = 'appearance:setProp',
    setDrawable = 'appearance:setDrawable',
    setTattoos = 'appearance:setTattoos',
    getModelTattoos = 'appearance:getModelTattoos',

    useOutfit = 'appearance:useOutfit',
    itemOutfit = 'appearance:itemOutfit',
    renameOutfit = 'appearance:renameOutfit',
    deleteOutfit = 'appearance:deleteOutfit',
    saveOutfit = 'appearance:saveOutfit',
    importOutfit = 'appearance:importOutfit',
    fetchOutfit = 'appearance:fetchOutfit',
}
