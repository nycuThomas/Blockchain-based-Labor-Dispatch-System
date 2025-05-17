module.exports = (sequelize, Sequelize) => {
    const agreement = sequelize.define("agreement", {
      senderName :{
        type: Sequelize.STRING
      },
      senderID :{
        type: Sequelize.STRING
      },
      receiverName :{
        type: Sequelize.STRING
      },
      receiverID :{
        type: Sequelize.STRING
      },
      status :{
        type: Sequelize.STRING
      }
    });
    return agreement;
};