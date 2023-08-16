import { defineConfig } from "@wagmi/cli"
import { foundry } from '@wagmi/cli/plugins'

export default defineConfig({
    out: "abi/wagmiGenerated.ts",
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
    ],
})
