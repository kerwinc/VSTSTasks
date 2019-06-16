#Install tfx-cli using npm
#npm install -g tfx-cli

# tfx login --help
# tfx login --service-url "http://devads/DefaultCollection" --authType pat --token "dk26fcbmrkf6nq4tkiedm3fopdegscheeb257ufoc7uzrwp67yra"
tfx login --service-url "http://devads/DefaultCollection" --authType basic --username "devit\kerwinc"
# tfx build tasks list
# tfx build tasks upload --task-path .\SSDT.GenerateDeployReport
tfx build tasks upload --task-path .\Task
# tfx extension create --manifest-globs vss-extension.json
