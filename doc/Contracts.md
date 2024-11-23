# Smart contracts

## Contract: BCAServiceToken

This contract implements an ERC20 token following the definitions from OpenZeppelin:

Source file: [BCA_ERC20_nf.sol](../bca-token-solidity/contracts/BCA_ERC20_nf.sol)

Implements interfaces:
- `import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol"`
    - the `constructor(string memory setName, string memory setSymbol, address setMinter, address setBurner)`

- `import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol"`
    - implements access control
    - we restrict minting to the indicated minter address as given to the constructor of updated using `setMinterAddress()`
    - we restrict burning to the indicated burner address as given to the constructor of updated using `setBurnerAddress()`

The contract has public fields:
- `address public serviceAddress`
- `address public minterAddress`
- `address public burnerAddress`

## Contract: BCAServiceManager

The service manager contract is at the top of the hierarchy of contracts and serves as an entry point. It is parameterized by the ERC20 or stable-coin address that is used throughout the dependent contracts. It stores the addresses of provider controller contracts.

Source file: [BCA_ServiceManager.sol](../bca-token-solidity/contracts/BCA_ServiceManager.sol)

Implements interfaces:
- [IServiceManager](../bca-token-solidity/contracts/Iface_ServiceManager.sol)
- [ReentrancyGuard](https://docs.openzeppelin.com/contracts/4.x/api/security#ReentrancyGuard)

The contract has public fields:
- `IERC20 public immutable tokToken`
    * address of the ERC20 token as stable-coin
- `address[] public providerControllers`
    * array of addresses of linked service controllers (see [BCA_ServiceController.sol](#bca_servicecontrollersol))
- `mapping (address => ControllerStruct) public deployedControllers`
    * mapping of a provider's address to the setup controller
    * ControllerStruct is: 
    ```sol
        struct ControllerStruct {
          address addrContract;
          bool isDeployed;
        }
    ```

The contract has public methods:
- `constructor(address tokAddress)`
    * only parameter is the common ERC20/stable-coin
- `function getControllerAddress(address providerAddress) public view returns(address addrController)`
    * returns the controller address for a provider's address
- `function isDeployed(address providerAddress) public view returns(bool isdeployed)`
    * returns true when the controller is deployed
- `function newController(address providerAddress) external nonReentrant`
    * deploys a provider's controller
- `function countServiceControllers() public view returns (uint)`
    * returns the number of known controllers by this service manager

## Contract: BCAServiceController

The service controller contract is deployed for every provider.
It keeps a list of addresses for the services that the provider offers.

Source file: [BCA_ServiceController.sol](../bca-token-solidity/contracts/BCA_ServiceController.sol)

Implements interfaces:
- [IServiceController](../bca-token-solidity/contracts/Iface_ServiceController.sol)
- [ReentrancyGuard](https://docs.openzeppelin.com/contracts/4.x/api/security#ReentrancyGuard)

The contract has public fields:
- `IERC20 public immutable tokToken`
    * the common ERC20 or stable-coin
- `address public immutable providerAddress`
    * the provider's address
- `address[] public deployedServices`
    * an array of linked services

The contract has public methods:
- `constructor(address setProviderAddress, address tokAddress)`
- `function newService(uint16 maxInstances, uint256 dayPrice) external nonReentrant returns (address)`
    * deploys a new service contract with the given parameterization
- `function countServiceContracts() public view returns (uint)`
    * returns the number of services in the array, necessary to enumerate the array entries

## Contract: BCAService

A service references a provider and the common ERC20/stable-coin and is parameterized with the maximal number of instances and the price of the service per day.

Source file: [BCA_Service.sol](../bca-token-solidity/contracts/BCA_Service.sol)

Implements interfaces:
- [IService](../bca-token-solidity/contracts/Iface_Service.sol)
- [ReentrancyGuard](https://docs.openzeppelin.com/contracts/4.x/api/security#ReentrancyGuard)

The contract has public fields:
- `IERC20 public immutable tokToken`
- `uint256 public immutable dayPrice`
- `address public immutable providerAddress`
- `uint16 public immutable maxInstances`
- `address[] public deployedInstances`

The contract has public methods:
- `constructor(address setProviderAddress, address tokAddress, 
                uint16 setMaxInstances, uint256 setDayPrice)`
- `function newInstance(address userAddress) external nonReentrant returns (address)`
- `function countServiceInstances() public view returns (uint)`

## Contract: BCAServiceInstance

This contract is at the heart of the market and represents a service instance. A user subscribes to a service with a first deposit of funds. This sets the start time of the contract from which the balances are calculated.

Source file: [BCA_ServiceInstance.sol](../bca-token-solidity/contracts/BCA_ServiceInstance.sol)

Implements interfaces:
- [IServiceInstance](../bca-token-solidity/contracts/Iface_ServiceInstance.sol)
- [ReentrancyGuard](https://docs.openzeppelin.com/contracts/4.x/api/security#ReentrancyGuard)

The contract has public fields:
- `IERC20 public immutable tokToken`
    * the common ERC20/stable-coin
- `uint256 public immutable dayPrice`
    * the price of the service for 24 hours; minimizes rounding errors
- `address public immutable providerAddress`
    * the address of the provider
- `address public immutable userAddress`
    * the address of the user
- `uint256 public deposit`
    * the amount of deposits made by the user
- `uint256 public retracted`
    * the amount of withdrawals made by the provider
- `uint256 public startTime`
    * when the contract has been started
- `uint256 public endTime`
    * when it has been stopped

The contract has public methods:
- `constructor(address setProviderAddress, address tokAddress,
                address setUserAddress,
                uint256 setDayPrice)`
- `function makeDeposit(uint256 amount) external nonReentrant`
    * deposits can only be made from the user's address
- `function stop() external nonReentrant`
    * both parties may call stop() at any time
- `function balanceUser() public view returns (uint256)`
    * calculates the user's balance
- `function balanceProvider() public view returns (uint256)`
    * calculates the provider's balance
- `function withdrawUser(uint256 amount) external nonReentrant`
    * the user may withdraw from his balance; this will affect the deposit
- `function withdrawProvider(uint256 amount) external nonReentrant`
    * the provider may withdraw up to his calculated balance


## Contract: BCAServiceFunding24

This contract automates the funding of a service contract by transferring the required funds to run the service every 24 hours. The contract is guaranteed to only transfer the said amount at most every 24 hours. It requires an external transaction to `deposit()` which is sent from a bot.

Source file: [BCA_Funding24.sol](../bca-token-solidity/contracts/BCA_Funding24.sol)

Implements interfaces:
- [IFunding24](../bca-token-solidity/contracts/Iface_Funding24.sol)
- [Ownable](https://docs.openzeppelin.com/contracts/4.x/api/access#Ownable)

The contract has public fields:
- `address public immutable targetContract`
    * the target contract
- `uint256 public immutable dailyAmount`
    * the amount to deposit every 24 hours
- `IERC20 public immutable token`
    * the common ERC20/stable-coin
- `uint256 public lastDepositTime`
    * remembers the last time a deposit was made

The contract has public methods:
- `constructor(
        address initialOwner,
        address setTargetContract,
        address setToken,
        uint256 setDailyAmount`
    * the parameterization of the contract is done in the constructor. The owner is set to the service user.
- `function deposit() external`
    * this method triggers the transfer of funds and makes the deposit to the service contract
- `function canDeposit() external view returns (bool)`
    * returns true if a deposit can be make