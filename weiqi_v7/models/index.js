const dbConfig = require("../config/db_config");

const Sequelize = require('sequelize');
const sequelize = new Sequelize({
    dialect: dbConfig.dialect,
    storage: dbConfig.storage,
});

const db = {};

db.Sequelize = Sequelize;
db.sequelize = sequelize;


//db.applyCert = require("./applyCert.model.js")(sequelize, Sequelize);
db.mapping = require("./mapping.js")(sequelize,Sequelize);
db.organization = require("./organization.js")(sequelize,Sequelize);
db.user = require("./user.js")(sequelize,Sequelize);

db.nonce = require("./nonce.js")(sequelize, Sequelize);
db.token = require("./tokens.js")(sequelize, Sequelize);
//db.reviewer = require("./reviewer.model.js")(sequelize, Sequelize);

//db.grade = require("./grade.model.js")(sequelize, Sequelize);
//db.rank = require("./rank.model.js")(sequelize, Sequelize);
//db.studentInfo = require("./studentInfo.model.js")(sequelize, Sequelize);
//db.awards = require("./awards.model.js")(sequelize, Sequelize);

db.agreement = require("./agreement.js")(sequelize, Sequelize);


module.exports = db;