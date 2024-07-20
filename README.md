# PVC Storage Class Migration Script

This script automates the process of migrating a Persistent Volume Claim (PVC) to a new storage class in Kubernetes. It creates a temporary PVC, migrates data, replaces the original PVC, and then migrates the data back.

## Requirements

### Ubuntu

- kubectl
- yq (version 4.x)
- jq
- [pv-migrate](https://github.com/utkuozdemir/pv-migrate)

To install the requirements on Ubuntu:

```bash
# Install kubectl
sudo apt-get update && sudo apt-get install -y apt-transport-https
curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key add -
echo "deb https://apt.kubernetes.io/ kubernetes-xenial main" | sudo tee -a /etc/apt/sources.list.d/kubernetes.list
sudo apt-get update
sudo apt-get install -y kubectl

# Install yq
sudo wget https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64 -O /usr/bin/yq && sudo chmod +x /usr/bin/yq

# Install jq
sudo apt-get install -y jq

# Install pv-migrate
curl -L https://github.com/utkuozdemir/pv-migrate/releases/latest/download/pv-migrate_Linux_x86_64.tar.gz | tar xz
sudo mv pv-migrate /usr/local/bin
```

### macOS

- kubectl
- yq (version 4.x)
- jq
- [pv-migrate](https://github.com/utkuozdemir/pv-migrate)

To install the requirements on macOS:

```bash
# Install kubectl
brew install kubectl

# Install yq
brew install yq

# Install jq
brew install jq

# Install pv-migrate
brew install utkuozdemir/pv-migrate/pv-migrate
```

## Usage

```bash
git clone https://github.com/chris2k20/k8s-pvc-storageclass-migrator
cd k8s-pvc-storageclass-migrator
bash k8s-pvc-storageclass-migrator.sh <pvc-name>
```

Replace `<pvc-name>` with the name of the PVC you want to migrate.

## Demo Output

```
⇡56% ➜ bash k8s-pvc-storageclass-migrator.sh --dest-sc=hcloud-volumes data-wp-www-example-com-mariadb-0
Creating new temporary PVC: data-wp-www-example-com-mariadb-0-tmp
persistentvolumeclaim/data-wp-www-example-com-mariadb-0-tmp created
Migrating data from data-wp-www-example-com-mariadb-0 to data-wp-www-example-com-mariadb-0-tmp...
🚀 Starting migration
💭 Will attempt 1 strategies: svc
🚁 Attempting strategy: svc
🔑 Generating SSH key pair
📂 Copying data... 100% |████████████████████████████████████████████████████████████████████████| (187 MB/s)
📂 Copying data...   0% |                                                                                  |  [0s:0s]
🧹 Cleaning up
📂 Copying data... 100% |██████████████████████████████████████████████████████████████████████████████████|
✨ Cleanup done
✅ Migration succeeded
Waiting for the original PVC data-wp-www-example-com-mariadb-0 to be unbound...
PVC data-wp-www-example-com-mariadb-0 is bound to pod pv-migrate-acdeb-sshd-65cb56c6d9-wtcwc.
PVC is still bound. Waiting 10 seconds...
PVC data-wp-www-example-com-mariadb-0 is bound to pod pv-migrate-acdeb-sshd-65cb56c6d9-wtcwc.
PVC is still bound. Waiting 10 seconds...
PVC data-wp-www-example-com-mariadb-0 is bound to pod pv-migrate-acdeb-sshd-65cb56c6d9-wtcwc.
PVC is still bound. Waiting 10 seconds...
Replacing original PVC: data-wp-www-example-com-mariadb-0
persistentvolumeclaim "data-wp-www-example-com-mariadb-0" deleted
persistentvolumeclaim/data-wp-www-example-com-mariadb-0 created
Performing final data migration from data-wp-www-example-com-mariadb-0-tmp to data-wp-www-example-com-mariadb-0...
🚀 Starting migration
💭 Will attempt 1 strategies: svc
🚁 Attempting strategy: svc
🔑 Generating SSH key pair
📂 Copying data... 100% |████████████████████████████████████████████████████████████████████████| (106 MB/s)
📂 Copying data...   0% |                                                                                  |  [0s:0s]
🧹 Cleaning up
📂 Copying data... 100% |██████████████████████████████████████████████████████████████████████████████████|
✨ Cleanup done
✅ Migration succeeded
Cleaning up: Deleting temporary PVC data-wp-www-example-com-mariadb-0-tmp
persistentvolumeclaim "data-wp-www-example-com-mariadb-0-tmp" deleted
PVC migration completed successfully.
```

## Notes

- Ensure you have the necessary permissions to manage PVCs in your Kubernetes cluster.
- The script assumes that the `pv-migrate` tool is available in your system PATH.
- Make sure to test the script in a non-production environment before using it on critical data.

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.
