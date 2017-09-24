#Install tfx-cli using npm
#npm install -g tfx-cli

# tfx login --help
# tfx login --service-url "http://devtfs02/DefaultCollection" --authType pat --token "m36nxou47z7myfq3hj3zk2m5pjfx5kqino2kjhmwjywlz3wqs7kq"
# tfx build tasks list

tfx extension create --manifest vss-extension.json --output-path .\build\
