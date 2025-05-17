'use strict';

//import
var express = require('express');
var router = express.Router();
var passport = require('passport');
var LocalStrategy = require('passport-local');
var fs = require('fs');
var Web3 = require('web3');
var path = require('path');
var openssl = require('openssl-nodejs');
var crypto = require("crypto");
var jwt = require('jsonwebtoken');
//import end

//init

// config and abi 
var config = JSON.parse(fs.readFileSync('./config/server_config.json', 'utf-8'));
var identityManager = JSON.parse(fs.readFileSync('./contracts/identityChain/IdentityManager.json', 'utf-8'));
var personalIdentity = JSON.parse(fs.readFileSync('./contracts/identityChain/PersonalIdentity.json', 'utf-8'));
var clientAddress = config.org_info.client.address;
var contract_address = config.contracts.identityManagerAddress;
var privateKey = config.org_info.client.key
var web3 = new Web3(new Web3.providers.HttpProvider(config.web3_provider));

var Organization = require("../../controllers/organization");
var User = require("../../controllers/user");
var Agrmt = require("../../controllers/agreement");
var Mapping = require("../../controllers/mapping");
var fabric_common = require("fabric-common");
var { Gateway, Wallets} = require('fabric-network');
var { buildCAClient, registerAndEnrollUser, enrollAdmin, getAdminIdentity, buildCertUser} = require('../../Util/CAUtil');
var { buildCCPOrg1, buildWallet } = require('../../Util/AppUtil');
var FabricCAServices = require('fabric-ca-client');
var FabricCAServices_1 = require('../../Util/FabricCAService_1');
var ccpOrg, caOrgClient, walletOrg, adminUser, gatewayOrg;
var mainChannel, accChannel, IRerInstance, certInstance, agrmtInstance, accInstance;
var transaction, agrmtID;
//init end

//encrypt 
var { ethers } = require("ethers")
var { decrypt, encrypt } = require("eth-sig-util")

//ecdsa
const elliptic = require('elliptic');
const e = require('express');
const EC = elliptic.ec;
const ecdsaCurve = elliptic.curves['p256'];
const ecdsa = new EC(ecdsaCurve);

//hash function
var cryptoSuite = fabric_common.Utils.newCryptoSuite()
var hashFunction = cryptoSuite.hash.bind(cryptoSuite)

//database connection
var sqlite3 = require("sqlite3").verbose();
var db = new sqlite3.Database("database.sqlite", sqlite3.OPEN_READWRITE, (err) => {
    if(err) return console.error(err.message);
});

/*
const sql = `DELETE FROM mappings`;
db.run(sql, function(err){
    if(err) return console.error(err.message);
});
*/



var organizations = `SELECT * FROM organizations`;
var users = `SELECT * FROM users`;
var agreements = `SELECT * FROM agreements`;

//connection end

let orgMSP = 'Org2MSP';
let OrgUserId = 'client';

var require_signature = "APP";
let GREEN = '\x1b[32m\n';
let RESET = '\x1b[0m';

var addAttribte = {};
var upatePermission ={};
var revokePermission = {};


async function init(){
    
    // build an in memory object with the network configuration (also known as a connection profile)
	ccpOrg = buildCCPOrg2();

    // build an instance of the fabric ca services client based on
	// the information in the network configuration
    caOrgClient = await buildCAClient(FabricCAServices, ccpOrg, 'ca.org2.example.com');

    // setup the wallet to cache the credentials of the application user, on the app server locally
    let walletPathOrg = path.join(__dirname, '..', '..', 'wallet', 'client'); 
    walletOrg = await buildWallet(Wallets, walletPathOrg);    
    
    // in a real application this would be done on an administrative flow, and only once
	// stores admin identity in local wallet, if needed
    await enrollAdmin(caOrgClient, walletOrg, orgMSP);
    adminUser = await getAdminIdentity(caOrgClient, walletOrg);

    
    // register & enroll application user with CA, which is used as client identify to make chaincode calls
	// and stores app user identity in local wallet
	// In a real application this would be done only when a new user was required to be added
	// and would be part of an administrative flow
    //await registerAndEnrollUser(caOrgClient, walletOrg, orgMSP, OrgUserId, 'org1.department1');
    
    
    // Create a new gateway for connecting to Org's peer node.
    gatewayOrg = new Gateway();
    //connect using Discovery enabled
    await gatewayOrg.connect(ccpOrg,
        { wallet: walletOrg, identity: 'admin', discovery: { enabled: true, asLocalhost: true } });

    //networkOrg = await gatewayOrg.getNetwork(channelName);
    //contractOrg = await networkOrg.getContract(chaincodeName);

    mainChannel = await gatewayOrg.getNetwork('main-channel');
    accChannel = await gatewayOrg.getNetwork('acc-channel');

    IRerInstance = await mainChannel.getContract('issuerReviewer');
    certInstance = await mainChannel.getContract('certManager');
    agrmtInstance = await mainChannel.getContract('agrmtManager');
    accInstance = await accChannel.getContract('accessControl');
    
}
init();


var isAuthenticated = function (req, res, next) {
    if (req.isAuthenticated()) {
        next();
    } else {
        req.flash('info', 'Login first.');
        res.redirect('/appChain');
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
passport.use('local',new LocalStrategy({
    usernameField: 'account',
    passwordField: 'signature',
    passReqToCallback: true
},
    async function (req, username, password, done) {
        console.log(req.hashed)
        console.log("un:",username)
        if(req.hashed && req.pubkey ){
            return done(null,{'identity':username.toLowerCase(),'pubkey':req.pubkey});
        }
    }
));
async function opensslDecode(buffer_input){
    return new Promise(function(reslove,reject){
        openssl(['req', '-text','-in', { name:'key.csr',buffer:buffer_input } ,'-pubkey'], function(err,result){
            reslove(result.toString())
        })
    })
};

router.get('/', async (req, res) => {
    if(req.user){
        res.redirect("/appChain/client/lobby");
    }
    else{
        res.render('appChain/client/home', {title: "App Chain", 'info':req.flash('info'), "require_signature":require_signature});
    }
});
router.post('/loginOrg',passport.authenticate('org',{
    failureRedirect: '/appChain'
    }), async function(req,res){
    res.redirect('/appChain/lobby')
});
router.post('/login',passport.authenticate('user',{
    failureRedirect: '/appChain/client'
    }), async function(req,res){
        
        res.redirect('/appChain/client/lobby');

});
router.post('/loginWithMetamask', async function(req,res,next){
    let {account,signature} = req.body
    let signingAccount = web3.eth.accounts.recover(require_signature, signature).toLowerCase();
    if(signingAccount != account.toLowerCase()){
        return res.send({'msg':'Failed to verify signature'});
    }
    let identityManagerInstance = new web3.eth.Contract(identityManager.abi, contract_address);
    let DID = await identityManagerInstance.methods.getId().call({from: account});

    if(DID){
        var pubkey;
        try{
            //Confirm from DB that the user has logged in
            let result = await Mapping.findOne({address: account.toLowerCase()});
            pubkey = result.dataValues.pubkey
            console.log("pubkey: " + pubkey)
        }
        catch{
            pubkey = null
        }
       
        if(pubkey){
            req.hashed = DID;
            req.pubkey = pubkey;
            next();
        }
        else{
            // access control is not exist create one (in ethereum address store lowerCase in ledger.)
            let PIContractAddress = await identityManagerInstance.methods.getAccessManagerAddress(account).call({from: account});
            let personalIdentityInstance = new web3.eth.Contract(personalIdentity.abi, PIContractAddress);
            let EncryptCSRHex = await personalIdentityInstance.methods.getEncryptMaterial("HLFCSR").call({from: account})
            let EncryptCSR = JSON.parse(ethers.utils.toUtf8String(EncryptCSRHex))
            let CSR = decrypt(EncryptCSR, privateKey)
            let CSRDecode = await opensslDecode(Buffer.from(CSR))
            //console.log("CSRDecode: " + CSRDecode);
            
            // Decode CSR to get CN and pubkey.
            let CN = CSRDecode.substr(CSRDecode.indexOf('CN=')+3,account.length);
            let start_index = '-----BEGIN PUBLIC KEY-----'.length 
            let end_index = CSRDecode.indexOf('-----END PUBLIC KEY-----')
            let pubkey_base64 = CSRDecode.substring(start_index,end_index).replace(/\n/g,'');
            //console.log("pubkey_base64: " + pubkey_base64);
            let pubkey_hex = Buffer.from(pubkey_base64, 'base64').toString('hex');
            //console.log("pubkey_hex: " + pubkey_hex);
            // exist useless prefix 3059301306072a8648ce3d020106082a8648ce3d030107034200
            pubkey_hex = pubkey_hex.substr('3059301306072a8648ce3d020106082a8648ce3d030107034200'.length)
            console.log("pubkey_hex: " + pubkey_hex);
            //check CN and account
            console.log("CN: " + CN);
            console.log("ACCOUT:" + account);
            if(CN.toLowerCase()== account.toLowerCase()){
                try{

                    /*
                    // Check if user is already enrolled
                    let userExists = await walletOrg.get(CN);
                    if (userExists) {
                        console.log(`An identity for the user ${CN} already exists in the wallet`);
                        return;
                    }
                    */

                    // Register user with Fabric-CA server
                    let secret = await caOrgClient.register({
                        enrollmentID: CN,
                        role: 'client',
                    }, adminUser);

                    // Enroll user with Fabric-CA server
                    let enrollment = await caOrgClient.enroll({
                        'csr':CSR ,
                        'enrollmentID':CN ,
                        'enrollmentSecret': secret
                    })

                    const x509Identity = {
                        credentials: {
                            certificate: enrollment.certificate,
                        },
                        mspId: orgMSP,
                        type: 'X.509',
                    };
    
                    await walletOrg.put(CN, x509Identity);
                    
                    console.log('\x1b[33m%s\x1b[0m', "create x509 cert successfully."); 

                }
                catch(error){
                    console.error(`Failed to register user : ${error}`);
                }

                
                try{
                    console.log("pubkey_hex: " + pubkey_hex);
                    await Mapping.create({address:account.toLowerCase(), pubkey:pubkey_hex});
                    req.hashed = DID;
                    req.pubkey = pubkey_hex;
                    next();
                }
                catch(error){
                    console.error(error);
                }
                
                
            }
            else{
                console.log("CN and account are different.")
                return res.send({'msg':'CN and account are different.'});
            }
        }
    }
    else{
        return res.send({'msg':'DID dose not exist.'});
    }
},
    passport.authenticate('local'),
    async function(req,res){
        res.send({url: "/appChain/client/lobby"});
});

router.get('/lobby', isAuthenticated, (req, res) => {
    db.all(organizations, [], (err, orgs) => {
        if(err){
            return console.error(err.message);
        }
        else{
            
            orgs.forEach((row) => {
                console.log(row);
            });

            db.all(users, [], (err, urs) => {
                if(err){
                    return console.error(err.message);
                }
                else{
                    
                    urs.forEach((row) => {
                        console.log(row);
                    });

                    res.render("appChain/client/lobby", {
                        title: "App Chain | Lobby",
                        org: orgs,
                        user: urs,
                        'info':req.flash('info')
                    });
                }
            });
        }
    });
});
router.get('/myAgreement', isAuthenticated, async (req, res) => {

    db.all(agreements, [], (err, agrmts) => {
        if(err){
            return console.error(err.message);
        }
        else{
            
            agrmts.forEach((row) => {
                console.log(row);
            });

            res.render("appChain/client/myAgreement", {
                title: "App Chain | My Agreement",
                agrmt: agrmts,
                'user':true,
                'info':req.flash('info')
            });

        }
    });
});
router.post('/lobby/createAgrmt', isAuthenticated, async (req, res, next) => {

    console.log(`${GREEN}===createAgrmt from ${orgMSP}===${RESET}`);


    let agreement = await Agrmt.create(req.body);

    let {senderName, senderID, receiverName, receiverID, message, salt} = req.body;

    try{
        let agrmt_properties = {
            object_type: 'agrmt_properties',
            senderName: senderName,
            senderID: senderID,
            receiverName: receiverName,
            receiverID: receiverID,
            message: message,
            salt: salt
        };
        let agrmt_properties_string = JSON.stringify(agrmt_properties);
        console.log(`agrmt_properties: ${agrmt_properties_string}`);
        transaction = agrmtInstance.createTransaction('CreateAgrmt');
        transaction.setEndorsingOrganizations(orgMSP);
        transaction.setTransient({
            agrmt_properties: Buffer.from(agrmt_properties_string)
        });
        agrmtID = await transaction.submit( `This is agrmt for labor dispatch.`);
        console.log(`Success to createAgrmt: agrmt ${agrmtID} is owned by Org1`);
        //return res.send({msg:`Success to createAgrmt: agrmt ${agrmtID} is owned by Org1`});

        req.flash('info', 'Created successfully.');
        res.send({url: "myAgreement"});
    }
    catch(createError){
        console.error(`Failed to createAgrmt : ${createError}`);

        req.flash('info', 'Created incorrectly.');
        res.send({url: "myAgreement"});
    }
    
    
});

router.post('/myAgreement/updateAgrmt', isAuthenticated, async (req, res) => {

    console.log(`${GREEN}===updateAgrmt from ${orgMSP}===${RESET}`);

    let {message, agrmtID} = req.body;

    try {
        // This is an update to the private state and requires only the owner to endorse.
        //console.log(`${GREEN}--> Submit Transaction: ChangePublicDescription ${assetKey}, as Org1 - endorse by Org1${RESET}`);
        transaction = agrmtInstance.createTransaction('UpdateAgrmt');
        transaction.setEndorsingOrganizations(orgMSP);
        let resultBuffer = await transaction.submit(agrmtID, message);
        console.log(`Success to updateAgrmt: ${resultBuffer}`);

    } catch (error) {
        console.log(`Failed to updateAgrmt: ${error}`);
    }


});

router.post('/myAgreement/readAgrmt', isAuthenticated, async (req, res) => {

    console.log(`${GREEN}===readAgrmt from ${orgMSP}===${RESET}`);//read private

    let data = JSON.stringify(req.body);    
    agrmtID = JSON.parse(data).agrmtID

    
    try {
		let resultBuffer = await agrmtInstance.evaluateTransaction('GetAgrmtPrivateProperties', agrmtID);
		let agrmt = JSON.parse(resultBuffer.toString('utf8'));
		console.log(`Success to readAgrmt: ${JSON.stringify(agrmt)}`);
        //return res.send({msg:`Success to readAgrmt: ${JSON.stringify(agrmt)}`});

        resultBuffer = await agrmtInstance.evaluateTransaction('ReadAgrmt', agrmtID);
        agrmt = JSON.parse(resultBuffer.toString('utf8'));
        console.log(`Agrmt ${agrmt.agrmtID} is owned by ${agrmt.ownerOrg}`);

	} catch (error) {
		console.log(`Failed to readAgrmt: ${error}`);
	}
    

});
router.post('/myAgreement/sendAgrmt', isAuthenticated, async (req, res) => {
    
    console.log(`${GREEN}===sendAgrmt from ${orgMSP}===${RESET}`);

    let {agrmtID, tradeID, verCode} = req.body;
    
    try{
        let agrmt_key = {
            agrmt_id: agrmtID.toString(),
            trade_id: tradeID.toString(),
            ver_code: verCode.toString()
        };
        let agrmt_key_string = JSON.stringify(agrmt_key);
        console.log(`agrmt_key: ${agrmt_key_string}`);
        transaction = agrmtInstance.createTransaction('AgreeToSend');
        transaction.setEndorsingOrganizations(orgMSP);
        transaction.setTransient({
            agrmt_key: Buffer.from(agrmt_key_string)
        });
        await transaction.submit(agrmtID);
        console.log(`Success to sendAgrmt: agree to send agrmt ${agrmtID}`);
        //return res.send({msg:`Success to sendAgrmt: agree to send agrmt ${agrmtID}`});
    }
    catch(error){
		console.log(`Failed to sendAgrmt: ${error}`);
    }
    
    
});
router.post('/myAgreement/signAgrmt', isAuthenticated, async (req, res) => {
   
    console.log(`${GREEN}===signAgrmt from ${orgMSP}===${RESET}`);

    let {agrmtID, tradeID, verCode} = req.body;
    
    console.log("agrmtID: " + agrmtID);
    console.log("tradeID: " + tradeID);
    console.log("verCode: " + verCode);

    
    try{
        let agrmt_key = {
            agrmt_id: agrmtID.toString(),
            trade_id: tradeID.toString(),
            ver_code: verCode.toString()
        };
        let agrmt_key_string = JSON.stringify(agrmt_key);
        console.log(`agrmt_key: ${agrmt_key_string}`);

        let resultBuffer = await agrmtInstance.evaluateTransaction('GetAgrmtPrivateProperties', agrmtID);
		let agrmt = JSON.parse(resultBuffer);
        let agrmt_properties = {
            object_type: 'agrmt_properties',
            senderName: agrmt.senderName,
            senderID: agrmt.senderID,
            receiverName: agrmt.receiverName,
            receiverID: agrmt.receiverID,
            message: agrmt.message,
            salt: agrmt.salt
        };
        let agrmt_properties_string = JSON.stringify(agrmt_properties);
        console.log(`agrmt_properties: ${agrmt_properties_string}`);

        transaction = agrmtInstance.createTransaction('AgreeToSign');
        transaction.setEndorsingOrganizations(orgMSP);
        transaction.setTransient({
            agrmt_key: Buffer.from(agrmt_key_string),
            agrmt_properties: Buffer.from(agrmt_properties_string)
        });
        await transaction.submit(agrmtID);
        console.log(`Success to signAgrmt: agree to sign agrmt ${agrmtID}`);
        //return res.send({msg:`Success to signAgrmt: agree to sign agrmt ${agrmtID}`});
    }
    catch(error){
        console.log(`Failed to signAgrmt: ${error}`);
    }
    
    
});
router.post('/myAgreement/enableAgrmt', isAuthenticated, async (req, res) => {
 
    console.log(`${GREEN}===enableAgrmt from ${orgMSP}===${RESET}`);

    let {agrmtID, tradeID, verCode} = req.body;

    try{
        let agrmt_key = {
            agrmt_id: agrmtID.toString(),
            trade_id: tradeID.toString(),
            ver_code: verCode.toString()
        };
        let agrmt_key_string = JSON.stringify(agrmt_key);
        console.log(`agrmt_key: ${agrmt_key_string}`);

        transaction = agrmtInstance.createTransaction('TransferAgrmt');
        console.log("success_1");
        transaction.setEndorsingOrganizations(orgMSP);
        console.log("success_2");
        transaction.setTransient({
            agrmt_key: Buffer.from(agrmt_key_string)
        });
        console.log("success_3");
        await transaction.submit(agrmtID, 'Org2MSP');//receiver's orgMSP

        console.log(`Success to enableAgrmt: agree to enable agrmt ${agrmtID}`);
        //return res.send({msg:`Success to enableAgrmt: agree to enable agrmt ${agrmtID}`});

    }
    catch(error){
        console.log(`Failed to enableAgrmt: ${error}`);
    }
});


router.get('/myCertificate', isAuthenticated, async (req, res) => {  
    res.render("appChain/client/myCertificate", {title: "App Chain | My Certificate", 'user':true});
});
router.get('/logout', function(req, res) {
    req.logOut();
    res.redirect('/appChain/client/');
});




module.exports = router;