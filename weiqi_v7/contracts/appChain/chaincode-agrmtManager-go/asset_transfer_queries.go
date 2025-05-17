/*
 SPDX-License-Identifier: Apache-2.0
*/

package main

import (
	"encoding/json"
	"fmt"

	"github.com/hyperledger/fabric-contract-api-go/contractapi"
)

type Agreement struct {
	ID      string `json:"agrmt_id"`
	VerCode   string    `json:"ver_code"`
	TradeID string `json:"trade_id"`
}


// !!!ReadAgrmt returns the public agrmt data
func (s *SmartContract) ReadAgrmt(ctx contractapi.TransactionContextInterface, agrmtID string) (*Agrmt, error) {
	// Since only public data is accessed in this function, no access control is required
	agrmtJSON, err := ctx.GetStub().GetState(agrmtID)
	if err != nil {
		return nil, fmt.Errorf("failed to read from world state: %v", err)
	}
	if agrmtJSON == nil {
		return nil, fmt.Errorf("%s does not exist", agrmtID)
	}

	var agrmt *Agrmt
	err = json.Unmarshal(agrmtJSON, &agrmt)
	if err != nil {
		return nil, err
	}
	return agrmt, nil
}


// !!!GetAgrmtPrivateProperties returns the immutable agrmt properties from owner's private data collection
func (s *SmartContract) GetAgrmtPrivateProperties(ctx contractapi.TransactionContextInterface, agrmtID string) (string, error) {

	collection, err := getClientImplicitCollectionNameAndVerifyClientOrg(ctx)
	if err != nil {
		return "", err
	}

	immutableProperties, err := ctx.GetStub().GetPrivateData(collection, agrmtID)
	if err != nil {
		return "", fmt.Errorf("failed to read agrmt private properties from client org's collection: %v", err)
	}
	if immutableProperties == nil {
		return "", fmt.Errorf("agrmt private details does not exist in client org's collection: %s", agrmtID)
	}

	return string(immutableProperties), nil
}
