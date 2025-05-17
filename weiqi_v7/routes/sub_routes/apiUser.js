var express = require('express');
var router = express.Router();

const User = require("../../controllers/user");

router.post("/", async function(req,res){
    let user = await User.create(req.body);
    if(user){
        req.flash('info', 'Created successfully.');
        res.redirect('/identityChain');
    }
    else
    {
        req.flash('info', 'Created incorrectly.');
        res.redirect('/identityChain');
    }
});

module.exports = router;