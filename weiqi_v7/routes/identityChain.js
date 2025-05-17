//import
var express = require('express');
var router = express.Router();
var passport = require('passport');
var LocalStrategy = require('passport-local');

var fs = require('fs');
var Web3 = require('web3');
//import end


//init
var config = JSON.parse(fs.readFileSync('./config/server_config.json', 'utf-8'));
var web3 = new Web3(new Web3.providers.HttpProvider(config.web3_provider));
var contract_address = config.contracts.identityManagerAddress;
var identityManger = JSON.parse(fs.readFileSync('./contracts/identityChain/IdentityManager.json', 'utf-8'));

var Organization = require("../controllers/organization");
var User = require("../controllers/user");
var apiOrganization = require('./sub_routes/apiOrganization');
var apiUser = require('./sub_routes/apiUser')

var require_signature = "DID";
//init end

var isAuthenticated = function (req, res, next) {
    if (req.isAuthenticated()) {
        next();
    } else {
        req.flash('info', 'Login first.');
        res.redirect('/identityChain');
    }
};
passport.use('org', new LocalStrategy(
    {
        usernameField: 'organizationName',
        passwordField: 'uniformNumber',
        passReqToCallback: true,
    },
    async function(req, organizationName, uniformNumber, done){
        let option = {
            'organizationName': organizationName,
            'UniformNumbers' : uniformNumber,
        }
        let organization = await Organization.findOne(option);
        if(organization){
            return done(null,{"identity":organization.hashed , "type":"org"});
        }
        else{
            req.flash('info', 'User is not exist.');
            return done(null,false)
        }
    }
));
passport.use('user', new LocalStrategy(
    {
        usernameField: 'userName',
        passwordField: 'IDNumber',
        passReqToCallback: true
    },
    async function(req, userName, IDNumber , done){
        let option = {
            'IDNumber': IDNumber,
            'userName' : userName
        }
        let user = await User.findOne(option);
        if(user){
            return done(null,{"identity":user.hashed,"type":"user"});
        }
        else{
            req.flash('info', 'User is not exist.');
            return done(null,false)
        }
    }
));
passport.use('verifySign', new LocalStrategy( {
    // Override those field if you don't need it
    // https://stackoverflow.com/questions/35079795/passport-login-authentication-without-password-field
    usernameField: 'account',
    passwordField: 'signature',
    passReqToCallback: true
},
    async function (req, username, password, done) {
        let account = username.toUpperCase()
        let signature = password;
        signingAccount = web3.eth.accounts.recover(require_signature, signature).toUpperCase();
        if(signingAccount==account){
            return done(null,{"identity":account});
        }
        else{
            return done(null,false);
        }
    }
));

router.use('/api/organization', apiOrganization);
router.use('/api/user', apiUser);

router.get('/', async function(req,res){
    if(req.user){
        res.redirect("/identityChain/profile")
    }
    else{
        res.render('identityChain/home', {title: "DID Chain", 'require_signature':require_signature ,'info':req.flash('info')});
    }
});
router.post('/loginOrg',passport.authenticate('org',{
    failureRedirect: '/identityChain'
    }), async function(req,res){
    res.redirect('/identityChain/profile')
});
router.post('/login',passport.authenticate('user',{
    failureRedirect: '/identityChain'
    }), async function(req,res){
    res.redirect('/identityChain/profile')
});
router.get('/profile',isAuthenticated, async function(req,res){
    let option = {
        'hashed': req.user.identity
    }
    let user;
    let portfolioOrg;
    if(req.user.type=="org")
    {
        user = await Organization.findOne(option)
    }
    else{
        user = await User.findOne(option);
        portfolioOrg =  await Organization.findAll({"type":"E-portfolio"})
    }
    res.render('identityChain/profile.ejs',{title: "DID | Profile", 'user':user, 'type':req.user.type, 'portfolioOrg':portfolioOrg, 'contract_address':contract_address });
});
router.get('/audit',isAuthenticated , async function(req,res){
    //let option = {"status":"false"};
    //let users = await User.findAll(option);
    res.render('identityChain/audit',{title: "DID | Audit", 'user':true});
});
router.post('/addUser',async function(req,res){
    let {type,IDNumber,Name} = req.body;
    let user;
    if(type=="person"){
        let option = {
            'IDNUmber': IDNumber,
            'userName' : Name,
        }
        user = await User.findOne(option);
    }
    else{
        let option = {
            'UniformNumbers': IDNumber,
            'organizationName' : Name,
        }
        user = await Organization.findOne(option);
    }

    
    if(!user){
        return res.send({
            msg: `user ${Name} is not exist.`
        });
    }
    let hashed = user.hashed;
    let contractInstance = new web3.eth.Contract(identityManger.abi, contract_address);

    let txHash;
    let signedTxObj;
    let tx_builder = contractInstance.methods.addUser(hashed,0);
    let encode_tx = tx_builder.encodeABI();
    let transactionObject = {
        gas: 6721975,
        data: encode_tx,
        from: config.identityChain.address,
        to: contract_address
    }

    await web3.eth.accounts.signTransaction(transactionObject, config.identityChain.key, async function (error, signedTx) {

        if (error) {
            console.log("sign error");
        } else {
            signedTxObj = signedTx;
        }
    })

    web3.eth.sendSignedTransaction(signedTxObj.rawTransaction)
    .on('receipt',async function (receipt) {
        user.set({
            status: "true",
        });
        await user.save();
        return res.send({
            msg: `${Name}-${receipt.transactionHash}`
        });
    })
    .on('error', function (error) {
        console.log(`Send signed transaction failed.`);
        console.log(error)
        return res.status(500).send({
            msg: "error"
        });
    })
    .catch((error) => {
        console.error(error);
        return res.send({
            msg:error
        })
    })
});
router.post('/bindAccount',isAuthenticated, async function(req,res){
    let {address,IDNumber,pubkey} = req.body;
    let type = req.user.type;
    console.log(pubkey)
    let hashed = req.user.identity;
    
    let user;
    if(type=="org"){
        
        if(pubkey == undefined)
        {
            console.log(1244)
            return res.send({
                msg: `User is not exist.`
            })
            
        }
        let option = {
            'hashed' : hashed,
        }
        user = await Organization.findOne(option);
        console.log(user)
    }
    else
    {
        let option = {
            'IDNUmber': IDNumber,
            'hashed' : hashed,
        }
        user = await User.findOne(option);
    }
    
    if(!user){
        return res.send({
            msg: `User is not exist.`
        })
    }
    let contractInstance = new web3.eth.Contract(identityManger.abi, contract_address);

    let txHash;
    let signedTxObj;
    let tx_builder = contractInstance.methods.bindAccount(hashed, address);
    let encode_tx = tx_builder.encodeABI();
    let transactionObject = {
        gas: 6721975,
        data: encode_tx,
        from: config.admin_address,
        to: contract_address
    }
    await web3.eth.accounts.signTransaction(transactionObject, config.identityChain.key, async function (error, signedTx) {
        if (error) {
            console.log("sign error");
        } else {
            signedTxObj = signedTx;
        }
    })

    web3.eth.sendSignedTransaction(signedTxObj.rawTransaction)
    .on('receipt', async function (receipt) {
        user.set({
            address: address,
            pubkey: pubkey
        });
        await user.save();
        return res.send({
            msg: `${IDNumber}-${receipt.transactionHash}`
        });
    })
    .catch((error) => {
        console.log(`Send signed transaction failed.`);
        return res.send({
            msg: "This address already binded."
        })
    })
});
router.get('/logout', function(req, res) {
    req.logOut();
    res.redirect('/identityChain/');
});

module.exports = router;