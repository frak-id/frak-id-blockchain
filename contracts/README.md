# Setup EC2

sudo yum update -y
sudo yum install docker -y
curl --silent --location https://rpm.nodesource.com/setup_16.x | sudo bash -
sudo yum install -y nodejs
sudo service docker start
sudo usermod -a -G docker ec2-user
sudo yum install git
mkdir sybel
cd sybel/
git clone https://**PersonalGitAccessToken**@github.com/sybel-app/sybel-io.git
cd sybel-io/
git status
git checkout security/setting-up-security-tools
git pull
cd blockchain/ 
npm i
nohup sh tools/manticore/manticore.sh > manticore-sybel-token.log 2>&1 &