# Workshop

Sample Quorum application using Quorum Maker.

## Structure

### API

A simple express API using web3js to communicate with Quorum.

### Smart Contracts

Several Smart Contracts to test the network.

### Quorum Maker

A modified fork of https://github.com/synechron-finlabs/quorum-maker to allow connections from the host to correctly use web3js.

## Usage

Clone this repo and create the quorum network tailored to your requirements.

````
git clone https://github.com/CatedraKairosDs/Workshop.git

cd quorum-maker

./setup.sh
````


Deploy the smart contracts using your favourite method (we recommend [Truffle](http://truffleframework.com)) and run the API to accept requests. 
Several parameters such as node urls and contract directions need to be configured. The ABIs of the smart contracts need to be stored on the abi folder as well. 

`````
cd API
npm start
`````

## API endpoints

+ ### Enroll in the network

  #### URL

    `/users`

  #### Method

    `POST`

  #### URL Params
  
   *Required:*
   
  JSON with the following fields on the body of the request:
   
   ````
   username
   roleType
   ```` 
   
+ ### Invoke a method on the chain

  #### URL

    `/send`

  #### Method

    `POST`

  #### URL Params
  
  *Required:*
   
   JSON with the following fields on the body of the request:
   
   ````
   userAccount
   userAccountPass
   userRole
   methodName
   methodArgs
   ```` 

+ ### Query a method on the chain

  #### URL

    `/call`

  #### Method

    `GET`
    
  #### URL Params
  
    *Required:*
  
  The following fields on the params of the request are required:
   
  ````
  userAccount
  userRole
  method
  ```` 
  `method` is a JSON with the field `name` and `args` field encoded with URLEncoding.
   
  

