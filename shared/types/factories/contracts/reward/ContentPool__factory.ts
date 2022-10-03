/* Autogenerated file. Do not edit manually. */
/* tslint:disable */
/* eslint-disable */
import {
  Signer,
  utils,
  Contract,
  ContractFactory,
  BigNumberish,
  Overrides,
} from "ethers";
import type { Provider, TransactionRequest } from "@ethersproject/providers";
import type { PromiseOrValue } from "../../../common";
import type {
  ContentPool,
  ContentPoolInterface,
} from "../../../contracts/reward/ContentPool";

const _abi = [
  {
    inputs: [
      {
        internalType: "address",
        name: "sybelTokenAddr",
        type: "address",
      },
      {
        internalType: "uint256",
        name: "id",
        type: "uint256",
      },
    ],
    stateMutability: "nonpayable",
    type: "constructor",
  },
  {
    anonymous: false,
    inputs: [
      {
        indexed: false,
        internalType: "uint256",
        name: "podcastId",
        type: "uint256",
      },
      {
        indexed: false,
        internalType: "address",
        name: "user",
        type: "address",
      },
    ],
    name: "PoolParticipantAdded",
    type: "event",
  },
  {
    anonymous: false,
    inputs: [
      {
        indexed: false,
        internalType: "uint256",
        name: "podcastId",
        type: "uint256",
      },
      {
        indexed: false,
        internalType: "address",
        name: "user",
        type: "address",
      },
    ],
    name: "PoolParticipantRemoved",
    type: "event",
  },
  {
    anonymous: false,
    inputs: [
      {
        indexed: false,
        internalType: "uint256",
        name: "podcastId",
        type: "uint256",
      },
      {
        indexed: false,
        internalType: "address",
        name: "user",
        type: "address",
      },
      {
        indexed: false,
        internalType: "uint256",
        name: "share",
        type: "uint256",
      },
    ],
    name: "PoolParticipantShareUpdated",
    type: "event",
  },
  {
    anonymous: false,
    inputs: [
      {
        indexed: false,
        internalType: "uint256",
        name: "podcastId",
        type: "uint256",
      },
      {
        indexed: false,
        internalType: "uint256",
        name: "amount",
        type: "uint256",
      },
    ],
    name: "PoolProvisionned",
    type: "event",
  },
  {
    anonymous: false,
    inputs: [
      {
        indexed: false,
        internalType: "uint256",
        name: "podcastId",
        type: "uint256",
      },
      {
        indexed: false,
        internalType: "address",
        name: "user",
        type: "address",
      },
      {
        indexed: false,
        internalType: "uint256",
        name: "amount",
        type: "uint256",
      },
    ],
    name: "PoolWithdraw",
    type: "event",
  },
  {
    anonymous: false,
    inputs: [
      {
        indexed: false,
        internalType: "address",
        name: "user",
        type: "address",
      },
      {
        indexed: false,
        internalType: "uint256",
        name: "amount",
        type: "uint256",
      },
    ],
    name: "ReferralRewardWithdrawed",
    type: "event",
  },
  {
    inputs: [
      {
        internalType: "address",
        name: "user",
        type: "address",
      },
      {
        internalType: "uint256",
        name: "shareToAdd",
        type: "uint256",
      },
    ],
    name: "addUserShare",
    outputs: [],
    stateMutability: "nonpayable",
    type: "function",
  },
  {
    inputs: [
      {
        internalType: "uint256",
        name: "rewardAmount",
        type: "uint256",
      },
    ],
    name: "computeRewardForUser",
    outputs: [],
    stateMutability: "nonpayable",
    type: "function",
  },
  {
    inputs: [
      {
        internalType: "address",
        name: "user",
        type: "address",
      },
      {
        internalType: "uint256",
        name: "shareToRemove",
        type: "uint256",
      },
    ],
    name: "removeUserShare",
    outputs: [],
    stateMutability: "nonpayable",
    type: "function",
  },
  {
    inputs: [
      {
        internalType: "address",
        name: "user",
        type: "address",
      },
    ],
    name: "withdrawFounds",
    outputs: [],
    stateMutability: "nonpayable",
    type: "function",
  },
];

const _bytecode =
  "0x60806040523480156200001157600080fd5b50604051620015913803806200159183398181016040528101906200003791906200012b565b80600581905550816000806101000a81548173ffffffffffffffffffffffffffffffffffffffff021916908373ffffffffffffffffffffffffffffffffffffffff160217905550505062000172565b600080fd5b600073ffffffffffffffffffffffffffffffffffffffff82169050919050565b6000620000b8826200008b565b9050919050565b620000ca81620000ab565b8114620000d657600080fd5b50565b600081519050620000ea81620000bf565b92915050565b6000819050919050565b6200010581620000f0565b81146200011157600080fd5b50565b6000815190506200012581620000fa565b92915050565b6000806040838503121562000145576200014462000086565b5b60006200015585828601620000d9565b9250506020620001688582860162000114565b9150509250929050565b61140f80620001826000396000f3fe608060405234801561001057600080fd5b506004361061004c5760003560e01c80633aa4ee7d146100515780639148f6221461006d578063d17139db14610089578063ebfa3553146100a5575b600080fd5b61006b60048036038101906100669190610c48565b6100c1565b005b61008760048036038101906100829190610c48565b6101f8565b005b6100a3600480360381019061009e9190610c88565b61037c565b005b6100bf60048036038101906100ba9190610cb5565b61047b565b005b600073ffffffffffffffffffffffffffffffffffffffff168273ffffffffffffffffffffffffffffffffffffffff1603610130576040517f08c379a000000000000000000000000000000000000000000000000000000000815260040161012790610d65565b60405180910390fd5b60008111610173576040517f08c379a000000000000000000000000000000000000000000000000000000000815260040161016a90610df7565b60405180910390fd5b60008061018a84600161073b90919063ffffffff16565b9150915081156101c157600083826101a29190610e46565b90506101ba8582600161077d9092919063ffffffff16565b50506101d9565b6101d78484600161077d9092919063ffffffff16565b505b82600660008282546101eb9190610e46565b9250508190555050505050565b600073ffffffffffffffffffffffffffffffffffffffff168273ffffffffffffffffffffffffffffffffffffffff1603610267576040517f08c379a000000000000000000000000000000000000000000000000000000000815260040161025e90610d65565b60405180910390fd5b600081116102aa576040517f08c379a00000000000000000000000000000000000000000000000000000000081526004016102a190610eec565b60405180910390fd5b6000806102c184600161073b90919063ffffffff16565b915091508180156102dd5750600083826102db9190610f0c565b115b1561032857600083826102f09190610f0c565b90506103088582600161077d9092919063ffffffff16565b50836006600082825461031b9190610f0c565b9250508190555050610376565b81801561034157506000838261033e9190610f0c565b11155b156103755761035a8460016107b290919063ffffffff16565b50806006600082825461036d9190610f0c565b925050819055505b5b50505050565b600081116103bf576040517f08c379a00000000000000000000000000000000000000000000000000000000081526004016103b690610f8c565b60405180910390fd5b60005b6103cc60016107e2565b811015610477576000806103ea8360016107f790919063ffffffff16565b91509150600060065482866103ff9190610fac565b610409919061101d565b905080600460008573ffffffffffffffffffffffffffffffffffffffff1673ffffffffffffffffffffffffffffffffffffffff168152602001908152602001600020600082825461045a9190610e46565b92505081905550505050808061046f9061104e565b9150506103c2565b5050565b600073ffffffffffffffffffffffffffffffffffffffff168173ffffffffffffffffffffffffffffffffffffffff16036104ea576040517f08c379a00000000000000000000000000000000000000000000000000000000081526004016104e190611108565b60405180910390fd5b6000600460008373ffffffffffffffffffffffffffffffffffffffff1673ffffffffffffffffffffffffffffffffffffffff16815260200190815260200160002054905060008111610571576040517f08c379a00000000000000000000000000000000000000000000000000000000081526004016105689061119a565b60405180910390fd5b60008060009054906101000a900473ffffffffffffffffffffffffffffffffffffffff1673ffffffffffffffffffffffffffffffffffffffff166370a08231306040518263ffffffff1660e01b81526004016105cd91906111c9565b602060405180830381865afa1580156105ea573d6000803e3d6000fd5b505050506040513d601f19601f8201168201806040525081019061060e91906111f9565b9050818111610652576040517f08c379a0000000000000000000000000000000000000000000000000000000008152600401610649906112be565b60405180910390fd5b6000600460008573ffffffffffffffffffffffffffffffffffffffff1673ffffffffffffffffffffffffffffffffffffffff1681526020019081526020016000208190555060008054906101000a900473ffffffffffffffffffffffffffffffffffffffff1673ffffffffffffffffffffffffffffffffffffffff1663a9059cbb84846040518363ffffffff1660e01b81526004016106f29291906112ed565b6020604051808303816000875af1158015610711573d6000803e3d6000fd5b505050506040513d601f19601f82011682018060405250810190610735919061134e565b50505050565b600080600080610767866000018673ffffffffffffffffffffffffffffffffffffffff1660001b610823565b91509150818160001c9350935050509250929050565b60006107a9846000018473ffffffffffffffffffffffffffffffffffffffff1660001b8460001b610872565b90509392505050565b60006107da836000018373ffffffffffffffffffffffffffffffffffffffff1660001b6108ad565b905092915050565b60006107f0826000016108e6565b9050919050565b60008060008061080a86600001866108fb565b915091508160001c8160001c9350935050509250929050565b60008060008460020160008581526020019081526020016000205490506000801b810361086257610854858561093b565b6000801b925092505061086b565b60018192509250505b9250929050565b600081846002016000858152602001908152602001600020819055506108a4838560000161095b90919063ffffffff16565b90509392505050565b6000826002016000838152602001908152602001600020600090556108de828460000161097290919063ffffffff16565b905092915050565b60006108f482600001610989565b9050919050565b6000806000610916848660000161099e90919063ffffffff16565b9050808560020160008381526020019081526020016000205492509250509250929050565b600061095382846000016109b590919063ffffffff16565b905092915050565b600061096a83600001836109cc565b905092915050565b60006109818360000183610a3c565b905092915050565b600061099782600001610b50565b9050919050565b60006109ad8360000183610b61565b905092915050565b60006109c48360000183610b8c565b905092915050565b60006109d88383610b8c565b610a31578260000182908060018154018082558091505060019003906000526020600020016000909190919091505582600001805490508360010160008481526020019081526020016000208190555060019050610a36565b600090505b92915050565b60008083600101600084815260200190815260200160002054905060008114610b44576000600182610a6e9190610f0c565b9050600060018660000180549050610a869190610f0c565b9050818114610af5576000866000018281548110610aa757610aa661137b565b5b9060005260206000200154905080876000018481548110610acb57610aca61137b565b5b90600052602060002001819055508387600101600083815260200190815260200160002081905550505b85600001805480610b0957610b086113aa565b5b600190038181906000526020600020016000905590558560010160008681526020019081526020016000206000905560019350505050610b4a565b60009150505b92915050565b600081600001805490509050919050565b6000826000018281548110610b7957610b7861137b565b5b9060005260206000200154905092915050565b600080836001016000848152602001908152602001600020541415905092915050565b600080fd5b600073ffffffffffffffffffffffffffffffffffffffff82169050919050565b6000610bdf82610bb4565b9050919050565b610bef81610bd4565b8114610bfa57600080fd5b50565b600081359050610c0c81610be6565b92915050565b6000819050919050565b610c2581610c12565b8114610c3057600080fd5b50565b600081359050610c4281610c1c565b92915050565b60008060408385031215610c5f57610c5e610baf565b5b6000610c6d85828601610bfd565b9250506020610c7e85828601610c33565b9150509250929050565b600060208284031215610c9e57610c9d610baf565b5b6000610cac84828501610c33565b91505092915050565b600060208284031215610ccb57610cca610baf565b5b6000610cd984828501610bfd565b91505092915050565b600082825260208201905092915050565b7f5359423a2043616e27742075706461746520736861726573206f66207468652060008201527f3020616464726573730000000000000000000000000000000000000000000000602082015250565b6000610d4f602983610ce2565b9150610d5a82610cf3565b604082019050919050565b60006020820190508181036000830152610d7e81610d42565b9050919050565b7f5359423a2043616e277420616464203020736861726520746f2074686520757360008201527f6572000000000000000000000000000000000000000000000000000000000000602082015250565b6000610de1602283610ce2565b9150610dec82610d85565b604082019050919050565b60006020820190508181036000830152610e1081610dd4565b9050919050565b7f4e487b7100000000000000000000000000000000000000000000000000000000600052601160045260246000fd5b6000610e5182610c12565b9150610e5c83610c12565b9250828201905080821115610e7457610e73610e17565b5b92915050565b7f5359423a2043616e27742072656d6f7665203020736861726520746f2074686560008201527f2075736572000000000000000000000000000000000000000000000000000000602082015250565b6000610ed6602583610ce2565b9150610ee182610e7a565b604082019050919050565b60006020820190508181036000830152610f0581610ec9565b9050919050565b6000610f1782610c12565b9150610f2283610c12565b9250828203905081811115610f3a57610f39610e17565b5b92915050565b7f5359423a2043616e277420616464203020617320726577617264000000000000600082015250565b6000610f76601a83610ce2565b9150610f8182610f40565b602082019050919050565b60006020820190508181036000830152610fa581610f69565b9050919050565b6000610fb782610c12565b9150610fc283610c12565b9250828202610fd081610c12565b91508282048414831517610fe757610fe6610e17565b5b5092915050565b7f4e487b7100000000000000000000000000000000000000000000000000000000600052601260045260246000fd5b600061102882610c12565b915061103383610c12565b92508261104357611042610fee565b5b828204905092915050565b600061105982610c12565b91507fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff820361108b5761108a610e17565b5b600182019050919050565b7f5359423a2043616e277420776974686472617720636f6e74656e7420706f6f6c60008201527f20666f756e647320666f72207468652030206164647265737300000000000000602082015250565b60006110f2603983610ce2565b91506110fd82611096565b604082019050919050565b60006020820190508181036000830152611121816110e5565b9050919050565b7f5359423a205468652075736572206861766e277420616e792070656e64696e6760008201527f2072657761726400000000000000000000000000000000000000000000000000602082015250565b6000611184602783610ce2565b915061118f82611128565b604082019050919050565b600060208201905081810360008301526111b381611177565b9050919050565b6111c381610bd4565b82525050565b60006020820190506111de60008301846111ba565b92915050565b6000815190506111f381610c1c565b92915050565b60006020828403121561120f5761120e610baf565b5b600061121d848285016111e4565b91505092915050565b7f5359423a2054686520726566657272616c20636f6e7472616374206861736e2760008201527f742074686520726571756972656420666f756e647320746f207061792074686560208201527f2075736572000000000000000000000000000000000000000000000000000000604082015250565b60006112a8604583610ce2565b91506112b382611226565b606082019050919050565b600060208201905081810360008301526112d78161129b565b9050919050565b6112e781610c12565b82525050565b600060408201905061130260008301856111ba565b61130f60208301846112de565b9392505050565b60008115159050919050565b61132b81611316565b811461133657600080fd5b50565b60008151905061134881611322565b92915050565b60006020828403121561136457611363610baf565b5b600061137284828501611339565b91505092915050565b7f4e487b7100000000000000000000000000000000000000000000000000000000600052603260045260246000fd5b7f4e487b7100000000000000000000000000000000000000000000000000000000600052603160045260246000fdfea26469706673582212206cf528409571de1b0dfa5fcfa5054f6508df3fe43d678fdf061bf073843164f364736f6c63430008110033";

type ContentPoolConstructorParams =
  | [signer?: Signer]
  | ConstructorParameters<typeof ContractFactory>;

const isSuperArgs = (
  xs: ContentPoolConstructorParams
): xs is ConstructorParameters<typeof ContractFactory> => xs.length > 1;

export class ContentPool__factory extends ContractFactory {
  constructor(...args: ContentPoolConstructorParams) {
    if (isSuperArgs(args)) {
      super(...args);
    } else {
      super(_abi, _bytecode, args[0]);
    }
  }

  override deploy(
    sybelTokenAddr: PromiseOrValue<string>,
    id: PromiseOrValue<BigNumberish>,
    overrides?: Overrides & { from?: PromiseOrValue<string> }
  ): Promise<ContentPool> {
    return super.deploy(
      sybelTokenAddr,
      id,
      overrides || {}
    ) as Promise<ContentPool>;
  }
  override getDeployTransaction(
    sybelTokenAddr: PromiseOrValue<string>,
    id: PromiseOrValue<BigNumberish>,
    overrides?: Overrides & { from?: PromiseOrValue<string> }
  ): TransactionRequest {
    return super.getDeployTransaction(sybelTokenAddr, id, overrides || {});
  }
  override attach(address: string): ContentPool {
    return super.attach(address) as ContentPool;
  }
  override connect(signer: Signer): ContentPool__factory {
    return super.connect(signer) as ContentPool__factory;
  }

  static readonly bytecode = _bytecode;
  static readonly abi = _abi;
  static createInterface(): ContentPoolInterface {
    return new utils.Interface(_abi) as ContentPoolInterface;
  }
  static connect(
    address: string,
    signerOrProvider: Signer | Provider
  ): ContentPool {
    return new Contract(address, _abi, signerOrProvider) as ContentPool;
  }
}
