//import
var express = require('express');
var bodyParser = require('body-parser');
var path = require('path');

//session
var passport = require('passport');
var session = require('express-session');
var flash = require("connect-flash");

const db = require("./models/index");
db.sequelize.sync();
/*
db.sequelize.sync({ force: true }).then( () => {
    console.log('\x1b[36m%s\x1b[0m', 'Drop and re-sync db.');  //cyan
});
*/

var app = express();

app.use(session({
    secret: 'secret',
    saveUninitialized: true,
    resave: true,
}));
app.use(passport.initialize());
app.use(passport.session());
app.use(flash());

passport.serializeUser(function(user, done) {
    done(null, user);
});
passport.deserializeUser(function(user, done) {
    done(null, user);
});

app.set("view engine", "ejs");
app.set('views', path.join(__dirname, 'views'));
app.use('/identityChain', express.static(path.join(__dirname, 'public')));
//app.use('/appChain', express.static(path.join(__dirname, 'public')));
app.use(express.static(path.join(__dirname,'public')));
app.use('/contracts', express.static(__dirname + '/contracts/identityChain/'));
app.use(bodyParser.json());
app.use(bodyParser.urlencoded({ extended: true }));


app.use(express.urlencoded({extended: false}));
app.use(express.json());
app.use((req, res, next) => {
    res.locals.message = req.session.message;
    delete req.session.message;
    next();
});


//route prefix
var identityChain = require('./routes/identityChain');
var appChain = require('./routes/appChain');
const user = require('./models/user');
app.use('/identityChain', identityChain);
app.use('/appChain', appChain);


module.exports = app;