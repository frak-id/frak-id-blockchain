/* Autogenerated file. Do not edit manually. */
/* tslint:disable */
/* eslint-disable */
import { Signer, utils, Contract, ContractFactory, Overrides } from "ethers";
import type { Provider, TransactionRequest } from "@ethersproject/providers";
import type { PromiseOrValue } from "../../../../common";
import type {
  ContentPoolReview,
  ContentPoolReviewInterface,
} from "../../../../contracts/reward/ContentPoolReview2.sol/ContentPoolReview";

const _abi = [
  {
    inputs: [],
    stateMutability: "nonpayable",
    type: "constructor",
  },
  {
    inputs: [
      {
        internalType: "uint256",
        name: "rewardAmount",
        type: "uint256",
      },
    ],
    name: "addReward",
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
    name: "claimReward",
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
        name: "shares",
        type: "uint256",
      },
    ],
    name: "updateParticipant",
    outputs: [],
    stateMutability: "nonpayable",
    type: "function",
  },
];

const _bytecode =
  "0x608060405234801561001057600080fd5b5060006003819055506000600460006101000a81548160ff021916908315150217905550610c27806100436000396000f3fe608060405234801561001057600080fd5b50600436106100415760003560e01c806349847c7a1461004657806374de4ec414610062578063d279c1911461007e575b600080fd5b610060600480360381019061005b91906106e2565b61009a565b005b61007c60048036038101906100779190610722565b610305565b005b6100986004803603810190610093919061074f565b61042f565b005b600460009054906101000a900460ff16156100ea576040517f08c379a00000000000000000000000000000000000000000000000000000000081526004016100e1906107d9565b60405180910390fd5b600073ffffffffffffffffffffffffffffffffffffffff168273ffffffffffffffffffffffffffffffffffffffff1603610159576040517f08c379a00000000000000000000000000000000000000000000000000000000081526004016101509061086b565b60405180910390fd5b600080600354815481106101705761016f61088b565b5b9060005260206000209060040201905060008160030160006101000a81548160ff0219169083151502179055506000600160008573ffffffffffffffffffffffffffffffffffffffff1673ffffffffffffffffffffffffffffffffffffffff1681526020019081526020016000209050600081600301600354815481106101fa576101f961088b565b5b90600052602060002001548461021091906108e9565b90508382600001819055506003600081548092919061022e9061091d565b91905055506040518060800160405280828560000160008282546102529190610965565b92505081905581526020016000815260200160008152602001600115158152506000600354815481106102885761028761088b565b5b906000526020600020906004020160008201518160000155602082015181600101556040820151816002015560608201518160030160006101000a81548160ff0219169083151502179055509050508382600301600354815481106102f0576102ef61088b565b5b90600052602060002001819055505050505050565b600460009054906101000a900460ff1615610355576040517f08c379a000000000000000000000000000000000000000000000000000000000815260040161034c906107d9565b60405180910390fd5b60008111610398576040517f08c379a000000000000000000000000000000000000000000000000000000000815260040161038f90610a0b565b60405180910390fd5b600080600354815481106103af576103ae61088b565b5b906000526020600020906004020190508060030160009054906101000a900460ff16610410576040517f08c379a000000000000000000000000000000000000000000000000000000000815260040161040790610a9d565b60405180910390fd5b818160010160008282546104249190610965565b925050819055505050565b600460009054906101000a900460ff161561047f576040517f08c379a0000000000000000000000000000000000000000000000000000000008152600401610476906107d9565b60405180910390fd5b600073ffffffffffffffffffffffffffffffffffffffff168173ffffffffffffffffffffffffffffffffffffffff16036104ee576040517f08c379a00000000000000000000000000000000000000000000000000000000081526004016104e590610b2f565b60405180910390fd5b6000600160008373ffffffffffffffffffffffffffffffffffffffff1673ffffffffffffffffffffffffffffffffffffffff1681526020019081526020016000209050600080826002015490505b6003548110156106385760006002600083815260200190815260200160002060008673ffffffffffffffffffffffffffffffffffffffff1673ffffffffffffffffffffffffffffffffffffffff16815260200190815260200160002054905060008460030183815481106105b3576105b261088b565b5b9060005260206000200154905060008084815481106105d5576105d461088b565b5b90600052602060002090600402019050600081600001548383600101546105fc9190610b4f565b6106069190610bc0565b9050838161061491906108e9565b8661061f9190610965565b95505050505080806106309061091d565b91505061053c565b506003548260020181905550505050565b600080fd5b600073ffffffffffffffffffffffffffffffffffffffff82169050919050565b60006106798261064e565b9050919050565b6106898161066e565b811461069457600080fd5b50565b6000813590506106a681610680565b92915050565b6000819050919050565b6106bf816106ac565b81146106ca57600080fd5b50565b6000813590506106dc816106b6565b92915050565b600080604083850312156106f9576106f8610649565b5b600061070785828601610697565b9250506020610718858286016106cd565b9150509250929050565b60006020828403121561073857610737610649565b5b6000610746848285016106cd565b91505092915050565b60006020828403121561076557610764610649565b5b600061077384828501610697565b91505092915050565b600082825260208201905092915050565b7f5359423a2043757272656e7420726577617264207374617465206c6f636b6564600082015250565b60006107c360208361077c565b91506107ce8261078d565b602082019050919050565b600060208201905081810360008301526107f2816107b6565b9050919050565b7f5359424c3a2043616e277420757064617465207368617265206f6e207468652060008201527f3020616464726573730000000000000000000000000000000000000000000000602082015250565b600061085560298361077c565b9150610860826107f9565b604082019050919050565b6000602082019050818103600083015261088481610848565b9050919050565b7f4e487b7100000000000000000000000000000000000000000000000000000000600052603260045260246000fd5b7f4e487b7100000000000000000000000000000000000000000000000000000000600052601160045260246000fd5b60006108f4826106ac565b91506108ff836106ac565b9250828203905081811115610917576109166108ba565b5b92915050565b6000610928826106ac565b91507fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff820361095a576109596108ba565b5b600182019050919050565b6000610970826106ac565b915061097b836106ac565b9250828201905080821115610993576109926108ba565b5b92915050565b7f5359423a2043616e27742061646420302072657761726420746f20746865207060008201527f6f6f6c0000000000000000000000000000000000000000000000000000000000602082015250565b60006109f560238361077c565b9150610a0082610999565b604082019050919050565b60006020820190508181036000830152610a24816109e8565b9050919050565b7f5359423a205468652063757272656e742072657761726420737461746520697360008201527f6e2774206f70656e000000000000000000000000000000000000000000000000602082015250565b6000610a8760288361077c565b9150610a9282610a2b565b604082019050919050565b60006020820190508181036000830152610ab681610a7a565b9050919050565b7f5359424c3a2043616e277420636c61696d20726577617264206f6e207468652060008201527f3020616464726573730000000000000000000000000000000000000000000000602082015250565b6000610b1960298361077c565b9150610b2482610abd565b604082019050919050565b60006020820190508181036000830152610b4881610b0c565b9050919050565b6000610b5a826106ac565b9150610b65836106ac565b9250828202610b73816106ac565b91508282048414831517610b8a57610b896108ba565b5b5092915050565b7f4e487b7100000000000000000000000000000000000000000000000000000000600052601260045260246000fd5b6000610bcb826106ac565b9150610bd6836106ac565b925082610be657610be5610b91565b5b82820490509291505056fea2646970667358221220ac188595e01a39204c210b50a224d7444512d2d2519a65a4124504bbbccc981064736f6c63430008110033";

type ContentPoolReviewConstructorParams =
  | [signer?: Signer]
  | ConstructorParameters<typeof ContractFactory>;

const isSuperArgs = (
  xs: ContentPoolReviewConstructorParams
): xs is ConstructorParameters<typeof ContractFactory> => xs.length > 1;

export class ContentPoolReview__factory extends ContractFactory {
  constructor(...args: ContentPoolReviewConstructorParams) {
    if (isSuperArgs(args)) {
      super(...args);
    } else {
      super(_abi, _bytecode, args[0]);
    }
  }

  override deploy(
    overrides?: Overrides & { from?: PromiseOrValue<string> }
  ): Promise<ContentPoolReview> {
    return super.deploy(overrides || {}) as Promise<ContentPoolReview>;
  }
  override getDeployTransaction(
    overrides?: Overrides & { from?: PromiseOrValue<string> }
  ): TransactionRequest {
    return super.getDeployTransaction(overrides || {});
  }
  override attach(address: string): ContentPoolReview {
    return super.attach(address) as ContentPoolReview;
  }
  override connect(signer: Signer): ContentPoolReview__factory {
    return super.connect(signer) as ContentPoolReview__factory;
  }

  static readonly bytecode = _bytecode;
  static readonly abi = _abi;
  static createInterface(): ContentPoolReviewInterface {
    return new utils.Interface(_abi) as ContentPoolReviewInterface;
  }
  static connect(
    address: string,
    signerOrProvider: Signer | Provider
  ): ContentPoolReview {
    return new Contract(address, _abi, signerOrProvider) as ContentPoolReview;
  }
}
