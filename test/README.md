# Test

To have a gas fee estimation when running the unit test, be sure to have the **gasReporter** enabled in the **hardhat.config.ts**

## Run all the unit test locally

```shell
npm run test
```

## Setup EC2 for tools testing

```shell
sudo yum update -y
sudo yum install docker -y
curl --silent --location https://rpm.nodesource.com/setup_16.x | sudo bash -
sudo yum install -y nodejs
sudo service docker start
sudo usermod -a -G docker ec2-user
sudo yum install git
mkdir sybel
cd sybel/
git clone https://**PersonalGitAccessToken**@github.com/sybel-app/frak-id-blockchain.git
cd frak-id-blockchain/
git status
git pull
npm i
nohup sh tools/run-all-nohup.sh
```
