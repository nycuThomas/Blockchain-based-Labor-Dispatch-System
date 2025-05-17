var express = require('express');
var router = express.Router();

const Organization = require("../../controllers/organization");

router.post("/", async function(req,res){
    console.log(req.body);
    let organization = await Organization.create(req.body);
    
    if(organization){
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
