var express = require('express');
// tool
var router = express.Router();

//sub router
var agency = require("./agency/agency")
var client = require("./client/client")
//var labor = require("./labor/labor")

router.use('/agency',agency);
router.use('/client',client);
//router.use('/labor',labor);


module.exports = router;