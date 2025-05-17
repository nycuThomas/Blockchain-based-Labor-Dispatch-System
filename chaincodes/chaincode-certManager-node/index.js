/*
 * Copyright IBM Corp. All Rights Reserved.
 *
 * SPDX-License-Identifier: Apache-2.0
 */

'use strict';

const { Contract } = require('fabric-contract-api');
const tls = require('tls');
const net = require('net');
const crypto = require("crypto");

function uint8arrayToStringMethod(myUint8Arr){
    return String.fromCharCode.apply(null, myUint8Arr);
}

class certManager extends Contract {
    async IssueAwardForUser(ctx, issueAddress, activityName, userPubkey, activityType, number, accessLink){
        
        let org = ctx.clientIdentity.getMSPID();
        let pubkey = await this.GetIdentity(ctx);

        let activityList = await this.get(ctx,issueAddress);
        if(activityList.success){
            activityList = JSON.parse(activityList.success.toString())
            console.log(activityList)
        }
        else{
            activityList = [];
        }

        if(!activityList.includes(activityName)){
            activityList.push(activityName);
            let key = issueAddress + activityName;
            let issueInfo = {
                issuerAddress: issueAddress,
                activityName : activityName,
                type : activityType,
                number: number,
                licenseAgency : org,
                licenseAgencyPubkey : pubkey,
            }
            
            await this.put(ctx, issueAddress, JSON.stringify(activityList));
            await this.put(ctx, key, JSON.stringify(issueInfo));

            console.log("execute applyIssueCert successfully.");
        }
        else{
            throw new Error(`activityName exist.`);
        }

        //const userHash = crypto.createHash("sha256").update(userAddress).digest("hex");
        let award = {
            student : userPubkey,
            accessLink : accessLink,
            activityName : activityName
        }
        const awardBuffer = Buffer.from(JSON.stringify(award));
        ctx.stub.setEvent('certManager', awardBuffer);

        let key = ctx.stub.createCompositeKey(userPubkey,[activityName])
        //console.log(key)
        //console.log(accessLink)
        await this.put(ctx,key,accessLink)

        return { success: "200" };
       
    }
    async put(ctx, key, value) {
        await ctx.stub.putState(key, Buffer.from(value));
        return { success: "OK" };
    }
    async getAccessLink(ctx,pubkey){
        const results = await ctx.stub.getStateByPartialCompositeKeyWithPagination(
            pubkey, [], 100, undefined);
        let iterator = results.iterator;
        let result = await iterator.next();
        let accessLink = []

        while (!result.done) {
            const value = Buffer.from(result.value.value.toString()).toString('utf8');
            let keyValue = {
                key: result.value.key,
                value : value
            }
            accessLink.push(keyValue)
            result = await iterator.next();
        }
        //console.log(accessLink);
        return JSON.stringify(accessLink)
    }
    async get(ctx, key) {
        const buffer = await ctx.stub.getState(key);
        if (!buffer || !buffer.length) return { error: "NOT_FOUND" };
        return { success: buffer.toString() };
    }
    async put(ctx, key, value) {
        await ctx.stub.putState(key, Buffer.from(value));
        return { success: "OK" };
    }
    async GetIdentity(ctx) {
        let IDBytes = ctx.clientIdentity.getIDBytes();
      
        let secureContext = tls.createSecureContext({
            cert: uint8arrayToStringMethod(IDBytes)
        });
        let secureSocket = new tls.TLSSocket(new net.Socket(), { secureContext });
        let cert = secureSocket.getCertificate();
        let pubkey = cert.pubkey.toString('hex');
        
        return pubkey
    }
}

exports.contracts = [certManager];
