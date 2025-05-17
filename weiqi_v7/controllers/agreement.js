const db = require("../models");
const Agrmt = db.agreement;
const Op = db.Sequelize.Op;

exports.create = async (option) => {
    const {senderName, senderID, receiverName, receiverID} = option;
    console.log(option)
    if (!senderName || !senderID || !receiverName || !receiverID) {
        console.log('d')
        return null
    }
    let agreement = {
        senderName : senderName,
        senderID : senderID,
        receiverName : receiverName,
        receiverID : receiverID,
        status : "false"
    }
    try{
        let create_agreement = await Agrmt.create(agreement);
        return create_agreement;
    }
    catch
    {
        return null;
    }
}