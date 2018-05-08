/**
 * Copyright 2017 IBM All Rights Reserved.
 *
 * Licensed under the Apache License, Version 2.0 (the 'License');
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *    http://www.apache.org/licenses/LICENSE-2.0
 *
 *  Unless required by applicable law or agreed to in writing, software
 *  distributed under the License is distributed on an 'AS IS' BASIS,
 *  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 *  See the License for the specific language governing permissions and
 *  limitations under the License.
 */
'use strict';

var log4js = require('log4js');
var logger = log4js.getLogger('SampleWebApp');
var express = require('express');
var session = require('express-session');
var cookieParser = require('cookie-parser');
var bodyParser = require('body-parser');
var http = require('http');
var util = require('util');
var app = express();
var expressJWT = require('express-jwt');
var jwt = require('jsonwebtoken');
var bearerToken = require('express-bearer-token');
var cors = require('cors');

var Web3 = require('web3');


var host = process.env.HOST || 'localhost';
var port = process.env.PORT || '4000';

///////////////////////////////////////////////////////////////////////////////
//////////////////////////////// WEB3 CONFIGURATONS ///////////////////////////
///////////////////////////////////////////////////////////////////////////////

var OrderHandlerInterface = require('./abi/OrderHandler.json');

const PROVIDER_URL = {
  ADMIN: 'http://0.0.0.0:22000',
  LAB: 'http://0.0.0.0:22001',
  DOCTOR: 'http://0.0.0.0:22002',
  PHAR: 'http://0.0.0.0:22003',
  TRACKER: 'http://0.0.0.0:22004'
};

const CONTRACT_ADDRESS =
  process.env.CONTRACT_ADDRESS || '0xe95c85688fed92a0b39fd95e205d0fcc61485250';

var web3 = new Web3(new Web3.providers.HttpProvider(PROVIDER_URL.ADMIN));

//Instance contract as is the only one being used.
let OrderHandler = new web3.eth.Contract(OrderHandlerInterface.abi, CONTRACT_ADDRESS);

///////////////////////////////////////////////////////////////////////////////
//////////////////////////////// SET CONFIGURATONS ////////////////////////////
///////////////////////////////////////////////////////////////////////////////
app.options('*', cors());
app.use(cors());
//support parsing of application/json type post data
app.use(bodyParser.json());
//support parsing of application/x-www-form-urlencoded post data
app.use(
  bodyParser.urlencoded({
    extended: false
  })
);
// set secret variable
app.set('secret', 'thisismysecret');
app.use(
  expressJWT({
    secret: 'thisismysecret'
  }).unless({
    path: ['/users']
  })
);
app.use(bearerToken());
app.use(function(req, res, next) {
  logger.debug(' ------>>>>>> new request for %s', req.originalUrl);
  if (req.originalUrl.indexOf('/users') >= 0) {
    return next();
  }

  var token = req.token;
  jwt.verify(token, app.get('secret'), function(err, decoded) {
    if (err) {
      res.send({
        success: false,
        message:
          'Failed to authenticate token. Make sure to include the ' +
          'token returned from /users call in the authorization header ' +
          ' as a Bearer token'
      });
      return;
    } else {
      // add the decoded user name and org name to the request object
      // for the downstream code to use
      req.username = decoded.username;
      req.orgname = decoded.orgName;
      logger.debug(
        util.format(
          'Decoded from JWT token: username - %s, orgname - %s',
          decoded.username,
          decoded.orgName
        )
      );
      return next();
    }
  });
});

///////////////////////////////////////////////////////////////////////////////
//////////////////////////////// START SERVER /////////////////////////////////
///////////////////////////////////////////////////////////////////////////////
var server = http.createServer(app).listen(port, function() {});
logger.info('****************** SERVER STARTED ************************');
logger.info('***************  http://%s:%s  ******************', host, port);
server.timeout = 240000;

function getErrorMessage(field) {
  var response = {
    success: false,
    message: field + ' field is missing or Invalid in the request'
  };
  return response;
}

///////////////////////////////////////////////////////////////////////////////
///////////////////////// REST ENDPOINTS START HERE ///////////////////////////
///////////////////////////////////////////////////////////////////////////////
// Register and enroll user
app.post('/users', async function(req, res) {
  var username = req.body.username;
  var rolType = req.body.rolType;
  logger.debug('End point : /users');
  logger.debug('User name : ' + username);
  logger.debug('Rol type : ' + rolType);
  if (!username) {
    res.json(getErrorMessage("'username'"));
    return;
  }
  if (!rolType) {
    res.json(getErrorMessage("'rolType'"));
    return;
  }
  var token = jwt.sign(
    {
      exp: Math.floor(Date.now() / 1000) + 36000,
      username: username,
      rolType: rolType
    },
    app.get('secret')
  );

  let response = {};
  response.token = token;

  res.json(response);
});

// Invoke transaction on chaincode on target peers
app.post('/send', async function(req, res) {
  logger.debug('==================== SEND TRANSACTION ==================');
  var method = req.body.methodName;
  var args = req.body.methodArgs;
  var userRole = req.body.userRole;
  var userAccount = req.body.userAccount;
  var userAccountPass = req.body.userAccountPass;


  logger.debug('userRole  : ' + userRole);
  logger.debug('userAccount  : ' + userAccount);
  logger.debug('method : ' + method);
  logger.debug('args  : ' + args);
  if (!method) {
    res.json(getErrorMessage("'methodName'"));
    return;
  }
  if (!userRole) {
    res.json(getErrorMessage("'userRole'"));
    return;
  }
  if (!args) {
    res.json(getErrorMessage("'args'"));
    return;
  }
  if (!userAccount) {
    res.json(getErrorMessage("'userAccount'"));
    return;
  }

  web3.eth.personal
    .unlockAccount(userAccount, userAccountPass)
    .catch(reject => {
      logger.debug(reject);
      res.status(503);
      logger.debug('There was an error unlocking the account');
    })
    .then(result => {
      OrderHandler.methods[method](...args)
        .send(
          {
            from: userAccount,
            gas: 100000000
          },
          (error, result) => {
            if (error) {
              logger.debug(error);
              res.status(500);
              res.send('There was an error when processing the transaction');
            } else {
              logger.debug('Transaction succesful. Transaction hash: ' + result);
            }
          }
        )
        .then(() => {
          web3.eth.personal
            .lockAccount(userAccount)
            .catch(reject => {
              logger.debug('There was a problem when trying to lock the account');
              logger.debug(reject);
              res.send('There was a problem when trying to lock the account');
            })
            .then(result => {
              if (result) {
                res.status(200);
                res.send('Ok');
              } else {
                logger.debug('Account not locked');
                res.send('Account not locked');
              }
            });
        });
    });
});

// Query on chaincode on target peers
app.get('/call', async function(req, res) {
  logger.debug('==================== CALL ==================');
  var method = JSON.parse(req.query.method).name;
  var args = JSON.parse(req.query.method).args;
  var userRole = req.query.userRole;
  var userAccount = req.query.userAccount;

  logger.debug('userRole  : ' + userRole);
  logger.debug('userAccount  : ' + userAccount);
  logger.debug('method : ' + method);
  logger.debug('args  : ' + args);
  if (!method) {
    res.json(getErrorMessage("'method'"));
    return;
  }
  if (!userRole) {
    res.json(getErrorMessage("'userRole'"));
    return;
  }
  // if (!args) {
  //   res.json(getErrorMessage("'args'"));
  //   return;
  // }
  if (!userAccount) {
    res.json(getErrorMessage("'userAccount'"));
    return;
  }
  OrderHandler.methods[method](...args).call(
    {
      from: userAccount
    },
    (error, result) => {
      if (error) {
        logger.debug(error);
        res.status(500);
        res.send('There was an error when processing the query');
      } else {
        logger.debug(result);
        res.status(200);
        res.send(result);
      }
    }
  );
});
