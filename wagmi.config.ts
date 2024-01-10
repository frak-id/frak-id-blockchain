import { defineConfig } from "@wagmi/cli"
import { foundry } from '@wagmi/cli/plugins'

export default defineConfig(
    [
        // Main config
        {
            out: "abi/generated.ts",
            plugins: [
                foundry({
                    project: './',
                    artifacts: 'out/',
                    include: [
                        'FrakToken.json',
                        'FraktionTokens.json',
                        'FrakTreasuryWallet.json',
                        'ContentPool.json',
                        'Minter.json',
                        'Rewarder.json',
                        'MultiVestingWallets.json',
                        'VestingWalletFactory.json',
                        'Multicallable.json',
                        'PushPullReward.json',
                        'ReferralPool.json',
                        'Rewarder.json',
                        'WalletMigrator.json',
                        'MonoPool.json'
                    ]
                }),
            ],
        },
        // Poc specific contracts config
        {
            out: "abi/frak-poc-abis.ts",
            plugins: [
                foundry({
                    project: './',
                    artifacts: 'out/',
                    include: [
                        'FrakToken.json',
                        'FraktionTokens.json',
                        'Paywall.json'
                    ]
                }),
            ],
        }
    ]
)
