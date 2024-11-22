# Smart contracts

## BCA_ERC20_nf.sol

This contract implements an ERC20 token following the definitions from OpenZeppelin:

Source file: [BCA_ERC20_nf.sol](../bca-token-solidity/contracts/BCA_ERC20_nf.sol)

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

## BCA_ServiceManager.sol

The service manager contract is at the top of the hierarchy of contracts and serves as an entry point. It is parameterized by the ERC20 or stable-coin address that is used throughout the dependent contracts. It stores the addresses of provider controller contracts.

Source file: [BCA_ServiceManager.sol](../bca-token-solidity/contracts/BCA_ServiceManager.sol)

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

## BCA_ServiceController.sol

The service controller contract is deployed for every provider.
It keeps a list of addresses for the services that the provider offers.

Source file: [BCA_ServiceController.sol](../bca-token-solidity/contracts/BCA_ServiceController.sol)

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

## BCA_Service.sol

A service references a provider and the common ERC20/stable-coin and is parameterized with the maximal number of instances and the price of the service per day.

Source file: [BCA_Service.sol](../bca-token-solidity/contracts/BCA_Service.sol)

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

## BCA_ServiceInstance.sol

Source file: [BCA_ServiceInstance.sol](../bca-token-solidity/contracts/BCA_ServiceInstance.sol)

The contract has public fields:
- `IERC20 public immutable tokToken`
- `uint256 public immutable dayPrice`
- `address public immutable providerAddress`
- `address public immutable userAddress`
- `uint256 public deposit`
- `uint256 public retracted`
- `uint256 public startTime`
- `uint256 public endTime`

The contract has public methods:
- `constructor(address setProviderAddress, address tokAddress,
                address setUserAddress,
                uint256 setDayPrice)`
- `function makeDeposit(uint256 amount) external nonReentrant`
- `function stop() external nonReentrant`
- `function balanceUser() public view returns (uint256)`
- `function balanceProvider() public view returns (uint256)`
- `function withdrawUser(uint256 amount) external nonReentrant`
- `function withdrawProvider(uint256 amount) external nonReentrant`


## BCA_Funding24.sol

Source file: [BCA_Funding24.sol](../bca-token-solidity/contracts/BCA_Funding24.sol)

The contract has public fields:
- `address public immutable targetContract`
- `uint256 public immutable dailyAmount`
- `IERC20 public immutable token`
- `uint256 public lastDepositTime`

The contract has public methods:
- `constructor(
        address initialOwner,
        address setTargetContract,
        address setToken,
        uint256 setDailyAmount`
- `function deposit() external`
- `function canDeposit() external view returns (bool)`