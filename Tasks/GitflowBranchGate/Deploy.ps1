#Install tfx-cli using npm
#npm install -g tfx-cli

# tfx login --help
# tfx login --service-url "http://devtfs/DefaultCollection" --authType pat --token "6ec7zcyb6i2fbzas3o57uqtlctydduba2xpatb5sj4rm2furrdiq"
# tfx login --service-url "http://devtfs" --authType pat --token "6ec7zcyb6i2fbzas3o57uqtlctydduba2xpatb5sj4rm2furrdiq"
tfx login --service-url "http://devtfs/DefaultCollection" --authType basic --username "devit\kerwinc" --password ""
# tfx build tasks list
# tfx build tasks upload --task-path .\SSDT.GenerateDeployReport
tfx build tasks upload --task-path .\Task
# tfx extension create --manifest-globs vss-extension.json
