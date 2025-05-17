/*
 SPDX-License-Identifier: Apache-2.0
*/

package main

import (
	"bytes"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"log"
	"time"

	"github.com/golang/protobuf/ptypes"
	"github.com/hyperledger/fabric-chaincode-go/pkg/statebased"
	"github.com/hyperledger/fabric-chaincode-go/shim"
	"github.com/hyperledger/fabric-contract-api-go/contractapi"
)

const (
	typeAgrmtForSend     = "S"
	typeAgrmtForBack     = "B"
	typeAgrmtSaleReceipt = "SR"
	typeAgrmtBuyReceipt  = "BR"
)

type SmartContract struct {
	contractapi.Contract
}

// Agrmt struct and properties must be exported (start with capitals) to work with contract api metadata
type Agrmt struct {
	ObjectType        string `json:"objectType"` // ObjectType is used to distinguish different object types in the same chaincode namespace
	ID                string `json:"agrmtID"`
	OwnerOrg          string `json:"ownerOrg"`
	PublicDescription string `json:"publicDescription"`
}

type receipt struct {
	verCode     string
	timestamp time.Time
}

// !!!CreateAgrmt creates an agrmt, sets it as owned by the client's org and returns its id
// the id of the agrmt corresponds to the hash of the properties of the agrmt that are  passed by transiet field
func (s *SmartContract) CreateAgrmt(ctx contractapi.TransactionContextInterface, publicDescription string) (string, error) {
	transientMap, err := ctx.GetStub().GetTransient()
	if err != nil {
		return "", fmt.Errorf("error getting transient: %v", err)
	}

	// Agrmt properties must be retrieved from the transient field as they are private
	immutablePropertiesJSON, ok := transientMap["agrmt_properties"]
	if !ok {
		return "", fmt.Errorf("agrmt_properties key not found in the transient map")
	}

	// AgrmtID will be the hash of the agrmt's properties
	hash := sha256.New()
	hash.Write(immutablePropertiesJSON)
	agrmtID := hex.EncodeToString(hash.Sum(nil))

	// Get the clientOrgId from the input, will be used for implicit collection, owner, and state-based endorsement policy
	clientOrgID, err := getClientOrgID(ctx)
	if err != nil {
		return "", err
	}

	// In this scenario, client is only authorized to read/write private data from its own peer, therefore verify client org id matches peer org id.
	err = verifyClientOrgMatchesPeerOrg(clientOrgID)
	if err != nil {
		return "", err
	}

	agrmt := Agrmt{//public
		ObjectType:        "agrmt",
		ID:                agrmtID,
		OwnerOrg:          clientOrgID,
		PublicDescription: publicDescription,
	}
	agrmtBytes, err := json.Marshal(agrmt)
	if err != nil {
		return "", fmt.Errorf("failed to create agrmt JSON: %v", err)
	}

	err = ctx.GetStub().PutState(agrmtID, agrmtBytes)
	if err != nil {
		return "", fmt.Errorf("failed to put agrmt in public data: %v", err)
	}

	// Set the endorsement policy such that an owner org peer is required to endorse future updates.
	// In practice, consider additional endorsers such as a trusted third party to further secure transfers.
	endorsingOrgs := []string{clientOrgID}
	err = setAgrmtStateBasedEndorsement(ctx, agrmt.ID, endorsingOrgs)
	if err != nil {
		return "", fmt.Errorf("failed setting state based endorsement for receiver and sender: %v", err)
	}

	// Persist private immutable agrmt properties to owner's private data collection
	collection := buildCollectionName(clientOrgID)
	err = ctx.GetStub().PutPrivateData(collection, agrmtID, immutablePropertiesJSON)
	if err != nil {
		return "", fmt.Errorf("failed to put Agrmt private details: %v", err)
	}

	return agrmtID, nil
}

// UpdateAgrmt updates the agrmt private description. Only the current owner can update the private description
func (s *SmartContract) UpdateAgrmt(ctx contractapi.TransactionContextInterface, agrmtID string, message string) (string, error) {

	clientOrgID, err := getClientOrgID(ctx)
	if err != nil {
		return "", err
	}

	agrmt_public, err := s.ReadAgrmt(ctx, agrmtID)//public
	if err != nil {
		return "", fmt.Errorf("failed to get public agrmt: %v", err)
	}

	// Auth check to ensure that client's org actually owns the agrmt
	if clientOrgID != agrmt_public.OwnerOrg {
		return "", fmt.Errorf("a client from %s cannot update the description of a agrmt owned by %s", clientOrgID, agrmt_public.OwnerOrg)
	}

	agrmt_private, err := s.GetAgrmtPrivateProperties(ctx, agrmtID)
	if err != nil {
		return "", fmt.Errorf("failed to get private agrmt: %v", err)
	}

	var data map[string]interface{}
	
	err = json.Unmarshal([]byte(agrmt_private), &data)
	if err != nil {
		return "", fmt.Errorf("JSON parsing error: %v", err)
	}

	data["message"] = message

	updatedJSON, err := json.Marshal(data)
	if err != nil {
		return "", fmt.Errorf("JSON marshaling error: %v", err)
	}

	// Persist private agrmt properties to owner's private data collection
	collection := buildCollectionName(clientOrgID)
	err = ctx.GetStub().PutPrivateData(collection, agrmtID, updatedJSON)
	if err != nil {
		return "", fmt.Errorf("failed to put Agrmt private details: %v", err)
	}

	/*
	asset.PublicDescription = message
	updatedAssetJSON, err := json.Marshal(asset)
	if err != nil {
		return fmt.Errorf("failed to marshal asset: %v", err)
	}
	*/

	return string(updatedJSON), nil
}

// !!!AgreeToSend adds sender's asking verCode to sender's implicit private data collection.
func (s *SmartContract) AgreeToSend(ctx contractapi.TransactionContextInterface, agrmtID string) error {
	agrmt, err := s.ReadAgrmt(ctx, agrmtID)
	if err != nil {
		return err
	}

	clientOrgID, err := getClientOrgID(ctx)
	if err != nil {
		return err
	}

	// Verify that this client belongs to the peer's org
	err = verifyClientOrgMatchesPeerOrg(clientOrgID)
	if err != nil {
		return err
	}

	// Verify that this clientOrgId actually owns the agrmt.
	if clientOrgID != agrmt.OwnerOrg {
		return fmt.Errorf("a client from %s cannot send an agrmt owned by %s", clientOrgID, agrmt.OwnerOrg)
	}

	return agreeToVerCode(ctx, agrmtID, typeAgrmtForSend)
}

// !!!AgreeToSign adds receiver's agrmt_key to receiver's implicit private data collection
func (s *SmartContract) AgreeToSign(ctx contractapi.TransactionContextInterface, agrmtID string) error {
	transientMap, err := ctx.GetStub().GetTransient()
	if err != nil {
		return fmt.Errorf("error getting transient: %v", err)
	}

	clientOrgID, err := getClientOrgID(ctx)
	if err != nil {
		return err
	}

	// Verify that this client belongs to the peer's org
	err = verifyClientOrgMatchesPeerOrg(clientOrgID)
	if err != nil {
		return err
	}

	// Agrmt properties must be retrieved from the transient field as they are private
	immutablePropertiesJSON, ok := transientMap["agrmt_properties"]
	if !ok {
		return fmt.Errorf("agrmt_properties key not found in the transient map")
	}
	fmt.Print("hash of agrmt_properties: ", immutablePropertiesJSON)//!!!

	// Persist private immutable agrmt properties to sender's private data collection
	collection := buildCollectionName(clientOrgID)
	err = ctx.GetStub().PutPrivateData(collection, agrmtID, immutablePropertiesJSON)
	if err != nil {
		return fmt.Errorf("failed to put agrmt private details: %v", err)
	}

	return agreeToVerCode(ctx, agrmtID, typeAgrmtForBack)
}

// !!!agreeToVerCode adds a bid or ask verCode to caller's implicit private data collection
func agreeToVerCode(ctx contractapi.TransactionContextInterface, agrmtID string, verCodeType string) error {
	// In this scenario, both receiver and sender are authoried to read/write private about transfer after sender agrees to sell.
	clientOrgID, err := getClientOrgID(ctx)
	if err != nil {
		return err
	}

	transMap, err := ctx.GetStub().GetTransient()
	if err != nil {
		return fmt.Errorf("error getting transient: %v", err)
	}

	// Agrmt verCode must be retrieved from the transient field as they are private
	verCode, ok := transMap["agrmt_key"]
	if !ok {
		return fmt.Errorf("agrmt_key not found in the transient map")
	}

	collection := buildCollectionName(clientOrgID)

	// Persist the agreed to verCode in a collection sub-namespace based on verCodeType key prefix,
	// to avoid collisions between private agrmt properties and verCode
	agrmtVerCode, err := ctx.GetStub().CreateCompositeKey(verCodeType, []string{agrmtID})
	if err != nil {
		return fmt.Errorf("failed to create composite key: %v", err)
	}

	// The verCode hash will be verified later, therefore always pass and persist verCode bytes as is,
	// so that there is no risk of nondeterministic marshaling.
	err = ctx.GetStub().PutPrivateData(collection, agrmtVerCode, verCode)
	if err != nil {
		return fmt.Errorf("failed to put agrmt verCode: %v", err)
	}

	return nil
}


// TransferAgrmt checks transfer conditions and then transfers agrmt state to receiver.
// !!!TransferAgrmt can only be called by current owner
func (s *SmartContract) TransferAgrmt(ctx contractapi.TransactionContextInterface, agrmtID string, receiverOrgID string) error {
	clientOrgID, err := getClientOrgID(ctx)
	if err != nil {
		return err
	}

	transMap, err := ctx.GetStub().GetTransient()
	if err != nil {
		return fmt.Errorf("error getting transient data: %v", err)
	}

	verCodeJSON, ok := transMap["agrmt_key"]
	if !ok {
		return fmt.Errorf("agrmt_key key not found in the transient map")
	}

	var agreement Agreement
	err = json.Unmarshal(verCodeJSON, &agreement)
	if err != nil {
		return fmt.Errorf("failed to unmarshal verCode JSON: %v", err)
	}

	
	agrmt, err := s.ReadAgrmt(ctx, agrmtID)
	if err != nil {
		return fmt.Errorf("failed to get agrmt: %v", err)
	}
	

	err = verifyTransferConditions(ctx, agrmt, clientOrgID, receiverOrgID, verCodeJSON)
	if err != nil {
		return fmt.Errorf("failed transfer verification: %v", err)
	}

	err = transferAgrmtState(ctx, agrmt, clientOrgID, receiverOrgID, agreement.VerCode)
	if err != nil {
		return fmt.Errorf("failed agrmt transfer: %v", err)
	}

	return nil

}


// !!!verifyTransferConditions checks that client org currently owns agrmt and that both parties have agreed on verCode
func verifyTransferConditions(ctx contractapi.TransactionContextInterface,
	agrmt *Agrmt,
	clientOrgID string,
	receiverOrgID string,
	verCodeJSON []byte) error {

	// CHECK1: Auth check to ensure that client's org actually owns the agrmt

	if clientOrgID != agrmt.OwnerOrg {
		return fmt.Errorf("a client from %s cannot transfer a agrmt owned by %s", clientOrgID, agrmt.OwnerOrg)
	}

	// CHECK2: Verify that receiver and sender on-chain agrmt defintion hash matches

	collectionSender := buildCollectionName(clientOrgID)
	collectionReceiver := buildCollectionName(receiverOrgID)
	senderPropertiesOnChainHash, err := ctx.GetStub().GetPrivateDataHash(collectionSender, agrmt.ID)
	if err != nil {
		return fmt.Errorf("failed to read agrmt private properties hash from sender's collection: %v", err)
	}
	if senderPropertiesOnChainHash == nil {
		return fmt.Errorf("agrmt private properties hash does not exist: %s", agrmt.ID)
	}
	receiverPropertiesOnChainHash, err := ctx.GetStub().GetPrivateDataHash(collectionReceiver, agrmt.ID)
	if err != nil {
		return fmt.Errorf("failed to read agrmt private properties hash from sender's collection: %v", err)
	}
	if receiverPropertiesOnChainHash == nil {
		return fmt.Errorf("agrmt private properties hash does not exist: %s", agrmt.ID)
	}

	// verify that receiver and sender on-chain agrmt defintion hash matches
	if !bytes.Equal(senderPropertiesOnChainHash, receiverPropertiesOnChainHash) {
		return fmt.Errorf("on chain hash of sender %x does not match on-chain hash of receiver %x",
			senderPropertiesOnChainHash,
			receiverPropertiesOnChainHash,
		)
	}

	// CHECK3: Verify that sender and receiver agreed on the same verCode

	// Get sender asking verCode
	agrmtForSaleKey, err := ctx.GetStub().CreateCompositeKey(typeAgrmtForSend, []string{agrmt.ID})
	if err != nil {
		return fmt.Errorf("failed to create composite key: %v", err)
	}
	senderVerCodeHash, err := ctx.GetStub().GetPrivateDataHash(collectionSender, agrmtForSaleKey)
	if err != nil {
		return fmt.Errorf("failed to get sender verCode hash: %v", err)
	}
	if senderVerCodeHash == nil {
		return fmt.Errorf("sender verCode for %s does not exist", agrmt.ID)
	}

	// Get receiver bid verCode
	agrmtBidKey, err := ctx.GetStub().CreateCompositeKey(typeAgrmtForBack, []string{agrmt.ID})
	if err != nil {
		return fmt.Errorf("failed to create composite key: %v", err)
	}
	receiverVerCodeHash, err := ctx.GetStub().GetPrivateDataHash(collectionReceiver, agrmtBidKey)
	if err != nil {
		return fmt.Errorf("failed to get receiver verCode hash: %v", err)
	}
	if receiverVerCodeHash == nil {
		return fmt.Errorf("receiver verCode for %s does not exist", agrmt.ID)
	}

	hash := sha256.New()
	hash.Write(verCodeJSON)
	calculatedVerCodeHash := hash.Sum(nil)

	// Verify that the hash of the passed verCode matches the on-chain sender verCode hash
	if !bytes.Equal(calculatedVerCodeHash, senderVerCodeHash) {
		return fmt.Errorf("hash %x for passed verCode JSON %s does not match on-chain hash %x, sender hasn't agreed to the passed tradeID and verCode",
			calculatedVerCodeHash,
			verCodeJSON,
			senderVerCodeHash,
		)
	}

	// Verify that the hash of the passed verCode matches the on-chain receiver verCode hash
	if !bytes.Equal(calculatedVerCodeHash, receiverVerCodeHash) {
		return fmt.Errorf("hash %x for passed verCode JSON %s does not match on-chain hash %x, receiver hasn't agreed to the passed tradeID and verCode",
			calculatedVerCodeHash,
			verCodeJSON,
			receiverVerCodeHash,
		)
	}

	return nil
}



// !!!transferAgrmtState performs the public and private state updates for the transferred agrmt
// changes the endorsement for the transferred agrmt sbe to the new owner org
func transferAgrmtState(ctx contractapi.TransactionContextInterface, agrmt *Agrmt, clientOrgID string, receiverOrgID string, verCode string) error {

	// Update ownership in public state
	agrmt.OwnerOrg = receiverOrgID
	updatedAgrmt, err := json.Marshal(agrmt)
	if err != nil {
		return err
	}
	err = ctx.GetStub().PutState(agrmt.ID, updatedAgrmt)
	if err != nil {
		return fmt.Errorf("failed to write agrmt for receiver: %v", err)
	}

	// Changes the endorsement policy to the new owner org
	endorsingOrgs := []string{receiverOrgID}
	err = setAgrmtStateBasedEndorsement(ctx, agrmt.ID, endorsingOrgs)
	if err != nil {
		return fmt.Errorf("failed setting state based endorsement for new owner: %v", err)
	}

	// Delete agrmt description from sender collection
	collectionSender := buildCollectionName(clientOrgID)
	err = ctx.GetStub().DelPrivateData(collectionSender, agrmt.ID)
	if err != nil {
		return fmt.Errorf("failed to delete Agrmt private details from sender: %v", err)
	}

	// Delete the verCode records for sender
	agrmtVerCodeKey, err := ctx.GetStub().CreateCompositeKey(typeAgrmtForSend, []string{agrmt.ID})
	if err != nil {
		return fmt.Errorf("failed to create composite key for sender: %v", err)
	}
	err = ctx.GetStub().DelPrivateData(collectionSender, agrmtVerCodeKey)
	if err != nil {
		return fmt.Errorf("failed to delete agrmt verCode from implicit private data collection for sender: %v", err)
	}

	// Delete the verCode records for receiver
	collectionReceiver := buildCollectionName(receiverOrgID)
	agrmtVerCodeKey, err = ctx.GetStub().CreateCompositeKey(typeAgrmtForBack, []string{agrmt.ID})
	if err != nil {
		return fmt.Errorf("failed to create composite key for receiver: %v", err)
	}
	err = ctx.GetStub().DelPrivateData(collectionReceiver, agrmtVerCodeKey)
	if err != nil {
		return fmt.Errorf("failed to delete agrmt verCode from implicit private data collection for receiver: %v", err)
	}

	// Keep record for a 'receipt' in both receivers and senders private data collection to record the verCode and date.
	// Persist the agreed to verCode in a collection sub-namespace based on receipt key prefix.
	receiptBuyKey, err := ctx.GetStub().CreateCompositeKey(typeAgrmtBuyReceipt, []string{agrmt.ID, ctx.GetStub().GetTxID()})
	if err != nil {
		return fmt.Errorf("failed to create composite key for receipt: %v", err)
	}

	txTimestamp, err := ctx.GetStub().GetTxTimestamp()
	if err != nil {
		return fmt.Errorf("failed to create timestamp for receipt: %v", err)
	}

	timestamp, err := ptypes.Timestamp(txTimestamp)
	if err != nil {
		return err
	}
	agrmtReceipt := receipt{
		verCode:     verCode,
		timestamp: timestamp,
	}
	receipt, err := json.Marshal(agrmtReceipt)
	if err != nil {
		return fmt.Errorf("failed to marshal receipt: %v", err)
	}

	err = ctx.GetStub().PutPrivateData(collectionReceiver, receiptBuyKey, receipt)
	if err != nil {
		return fmt.Errorf("failed to put private agrmt receipt for receiver: %v", err)
	}

	receiptSaleKey, err := ctx.GetStub().CreateCompositeKey(typeAgrmtSaleReceipt, []string{ctx.GetStub().GetTxID(), agrmt.ID})
	if err != nil {
		return fmt.Errorf("failed to create composite key for receipt: %v", err)
	}

	err = ctx.GetStub().PutPrivateData(collectionSender, receiptSaleKey, receipt)
	if err != nil {
		return fmt.Errorf("failed to put private agrmt receipt for sender: %v", err)
	}

	return nil
}


// getClientOrgID gets the client org ID.
func getClientOrgID(ctx contractapi.TransactionContextInterface) (string, error) {
	clientOrgID, err := ctx.GetClientIdentity().GetMSPID()
	if err != nil {
		return "", fmt.Errorf("failed getting client's orgID: %v", err)
	}

	return clientOrgID, nil
}

// getClientImplicitCollectionNameAndVerifyClientOrg gets the implicit collection for the client and checks that the client is from the same org as the peer
func getClientImplicitCollectionNameAndVerifyClientOrg(ctx contractapi.TransactionContextInterface) (string, error) {
	clientOrgID, err := getClientOrgID(ctx)
	if err != nil {
		return "", err
	}

	err = verifyClientOrgMatchesPeerOrg(clientOrgID)
	if err != nil {
		return "", err
	}

	return buildCollectionName(clientOrgID), nil
}

// !!!verifyClientOrgMatchesPeerOrg checks that the client is from the same org as the peer
func verifyClientOrgMatchesPeerOrg(clientOrgID string) error {
	peerOrgID, err := shim.GetMSPID()
	if err != nil {
		return fmt.Errorf("failed getting peer's orgID: %v", err)
	}

	if clientOrgID != peerOrgID {
		return fmt.Errorf("client from org %s is not authorized to read or write private data from an org %s peer",
			clientOrgID,
			peerOrgID,
		)
	}

	return nil
}

// buildCollectionName returns the implicit collection name for an org
func buildCollectionName(clientOrgID string) string {
	return fmt.Sprintf("_implicit_org_%s", clientOrgID)
}

// !!!setAgrmtStateBasedEndorsement adds an endorsement policy to an agrmt so that the passed orgs need to agree upon transfer
func setAgrmtStateBasedEndorsement(ctx contractapi.TransactionContextInterface, agrmtID string, orgsToEndorse []string) error {
	endorsementPolicy, err := statebased.NewStateEP(nil)
	if err != nil {
		return err
	}
	err = endorsementPolicy.AddOrgs(statebased.RoleTypePeer, orgsToEndorse...)
	if err != nil {
		return fmt.Errorf("failed to add org to endorsement policy: %v", err)
	}
	policy, err := endorsementPolicy.Policy()
	if err != nil {
		return fmt.Errorf("failed to create endorsement policy bytes from org: %v", err)
	}
	err = ctx.GetStub().SetStateValidationParameter(agrmtID, policy)
	if err != nil {
		return fmt.Errorf("failed to set validation parameter on agrmt: %v", err)
	}

	return nil
}

func main() {
	chaincode, err := contractapi.NewChaincode(new(SmartContract))
	if err != nil {
		log.Panicf("Error create transfer agrmt chaincode: %v", err)
	}

	if err := chaincode.Start(); err != nil {
		log.Panicf("Error starting agrmt chaincode: %v", err)
	}
}
