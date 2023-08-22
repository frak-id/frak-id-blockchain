import { defineConfig } from "@wagmi/cli"
import { foundry, react } from '@wagmi/cli/plugins'

export default defineConfig({
    out: "abi/generated-react.ts",
    contracts: [],
    plugins: [
        foundry({
            project: './',
            artifacts: 'out/',
            include: [
                'ContentPool.json',
                'FrakToken.json',
                'FraktionTokens.json',
                'FrakTreasuryWallet.json',
                'Minter.json',
                'Rewarder.json',
                'MultiVestingWallets.json',
                'VestingWalletFactory.json',
                'Multicallable.json',
                'PushPullReward.json',
                'ReferralPool.json',
                'Rewarder.json',
                'MonoPool.json'
            ]
        }),
        react({
            useContractItemEvent: false,
            useContractEvent: false,
        })
    ],
})
