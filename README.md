# Home Operations

## 💻 Machine Preparation

### System requirements

- Debian 12 nodes built by Terraform
  - 1 master
  - 2 workers

## 🚀 Getting Started

Once you have installed Debian on your nodes, there are six stages to getting a Flux-managed cluster up and runnning.

### 🌱 Setup workstation environment


1. Install the most recent version of [task](https://taskfile.dev/)

    ```sh
    sh -c "$(curl --location https://taskfile.dev/install.sh)" -- -d
    ```

3. Setup a Python virual env and install Ansible by running the following task command.

    📍 _This commands requires Python 3.8+ to be installed_

    ```sh
    # Platform agnostic
    task deps
    ```

4. Install the required tools: [age](https://github.com/FiloSottile/age), [flux](https://toolkit.fluxcd.io/), [cloudflared](https://github.com/cloudflare/cloudflared), [kubectl](https://kubernetes.io/docs/tasks/tools/), [sops](https://github.com/getsops/sops)

### 🔧 Stage 3: Do bootstrap configuration

1. Generate the `bootstrap/vars/config.yaml` and `bootstrap/vars/addons.yaml` configuration files.

    ```sh
    task init
    ```

2. Setup Age private / public key

    📍 _Using [SOPS](https://github.com/getsops/sops) with [Age](https://github.com/FiloSottile/age) allows us to encrypt secrets and use them in Ansible and Flux._

    2a. Create a Age private / public key (this file is gitignored)

      ```sh
      age-keygen -o age.key
      ```

    2b. Fill out the `age` vars in `bootstrap/vars/config.yaml`

3. Create Cloudflare API Token

    Fill out the appropriate vars in `bootstrap/vars/config.yaml`

4. Complete filling out the rest of the `bootstrap/vars/config.yaml` configuration file.

    5a. Ensure `bootstrap_acme_production_enabled` is set to `false`.

    5b. [Optional] Update `bootstrap/vars/addons.yaml` and enable applications you would like included.

6. Once done run the following command which will verify and generate all the files needed to continue.

    ```sh
    task configure
    ```

📍 _The configure task will create a `./ansible` directory and the following directories under `./kubernetes`._

```sh
📁 kubernetes      # Kubernetes cluster defined as code
├─📁 bootstrap     # Flux installation (not tracked by Flux)
├─📁 flux          # Main Flux configuration of repository
└─📁 apps          # Apps deployed into the cluster grouped by namespace
```

### ⚡ Stage 4: Prepare your nodes for k3s

📍 _Here we will be running an Ansible playbook to prepare your nodes for running a Kubernetes cluster._

1. Ensure you are able to SSH into your nodes from your workstation using a private SSH key **without a passphrase** (for example using a SSH agent). This lets Ansible interact with your nodes.

2. Verify Ansible can view your config

    ```sh
    task ansible:list
    ```

3. Verify Ansible can ping your nodes

    ```sh
    task ansible:ping
    ```

4. Run the Ansible prepare playbook (nodes wil reboot when done)

    ```sh
    task ansible:prepare
    ```

### ⛵ Stage 5: Use Ansible to install k3s

📍 _Here we will be running a Ansible Playbook to install [k3s](https://k3s.io/) with [this](https://galaxy.ansible.com/xanmanning/k3s) Ansible galaxy role. If you run into problems, you can run `task ansible:nuke` to destroy the k3s cluster and start over from this point._

1. Verify Ansible can view your config

    ```sh
    task ansible:list
    ```

2. Verify Ansible can ping your nodes

    ```sh
    task ansible:ping
    ```

3. Install k3s with Ansible

    ```sh
    task ansible:install
    ```

4. Verify the nodes are online

    📍 _If this command **fails** you likely haven't configured `direnv` as mentioned previously in the guide._

    ```sh
    kubectl get nodes -o wide
    # NAME           STATUS   ROLES                       AGE     VERSION
    # k8s-0          Ready    control-plane,etcd,master   1h      v1.27.3+k3s1
    # k8s-1          Ready    worker                      1h      v1.27.3+k3s1
    ```

5. The `kubeconfig` for interacting with your cluster should have been created in the root of your repository.

### 🔹 Stage 6: Install Flux in your cluster

📍 _Here we will be installing [flux](https://fluxcd.io/flux/) after some quick bootstrap steps._

1. Verify Flux can be installed

    ```sh
    flux check --pre
    # ► checking prerequisites
    # ✔ kubectl 1.27.3 >=1.18.0-0
    # ✔ Kubernetes 1.27.3+k3s1 >=1.16.0-0
    # ✔ prerequisites checks passed
    ```

2. Push you changes to git

   📍 **Verify** all the `*.sops.yaml` and `*.sops.yaml` files under the `./ansible`, and `./kubernetes` directories are **encrypted** with SOPS

    ```sh
    git add -A
    git commit -m "Initial commit :rocket:"
    git push
    ```

3. Install Flux and sync the cluster to the Git repository

    ```sh
    task cluster:install
    # namespace/flux-system configured
    # customresourcedefinition.apiextensions.k8s.io/alerts.notification.toolkit.fluxcd.io created
    # ...
    ```

4. Verify Flux components are running in the cluster

    ```sh
    kubectl -n flux-system get pods -o wide
    # NAME                                       READY   STATUS    RESTARTS   AGE
    # helm-controller-5bbd94c75-89sb4            1/1     Running   0          1h
    # kustomize-controller-7b67b6b77d-nqc67      1/1     Running   0          1h
    # notification-controller-7c46575844-k4bvr   1/1     Running   0          1h
    # source-controller-7d6875bcb4-zqw9f         1/1     Running   0          1h
    ```

### 🎤 Verification Steps

_Mic check, 1, 2_ - In a few moments applications should be lighting up like Christmas in July 🎄

1. Output all the common resources in your cluster.

    📍 _Feel free to use the provided [cluster tasks](.taskfiles/ClusterTasks.yaml) for validation of cluster resources or continue to get familiar with the `kubectl` and `flux` CLI tools._


    ```sh
    task cluster:resources
    ```

2. ⚠️ It might take `cert-manager` awhile to generate certificates, this is normal so be patient.

3. 🏆 **Congratulations** if all goes smooth you will have a Kubernetes cluster managed by Flux and your Git repository is driving the state of your cluster.

4. 🧠 Now it's time to pause and go get some motel motor oil ☕ and admire you made it this far!

## 📣 Post installation

#### 🌐 Public DNS

The `external-dns` application created in the `networking` namespace will handle creating public DNS records. By default, `echo-server` and the `flux-webhook` are the only subdomains reachable from the public internet. In order to make additional applications public you must set set the correct ingress class name and ingress annotations like in the HelmRelease for `echo-server`.

#### 🏠 Home DNS

`k8s_gateway` will provide DNS resolution to external Kubernetes resources (i.e. points of entry to the cluster) from any device that uses your home DNS server. For this to work, your home DNS server must be configured to forward DNS queries for `${bootstrap_cloudflare_domain}` to `${bootstrap_k8s_gateway_addr}` instead of the upstream DNS server(s) it normally uses. This is a form of **split DNS** (aka split-horizon DNS / conditional forwarding).

📍 _Below is how to configure a Pi-hole for split DNS. Other platforms should be similar._

1. Apply this file on the server

   ```sh
   # /etc/dnsmasq.d/99-k8s-gateway-forward.conf
   server=/${bootstrap_cloudflare_domain}/${bootstrap_k8s_gateway_addr}
   ```

2. Restart dnsmasq on the server.

3. Query an internal-only subdomain from your workstation: `dig @${home-dns-server-ip} echo-server.${bootstrap_cloudflare_domain}`. It should resolve to `${bootstrap_internal_ingress_addr}`.


## 🐛 Debugging

1. Start by checking all Flux Kustomizations & Git Repository & OCI Repository and verify they are healthy.

    ```sh
    flux get sources oci -A
    flux get sources git -A
    flux get ks -A
    ```

2. Then check all the Flux Helm Releases and verify they are healthy.

    ```sh
    flux get hr -A
    ```

3. Then check the if the pod is present.

    ```sh
    kubectl -n <namespace> get pods -o wide
    ```

4. Then check the logs of the pod if its there.

    ```sh
    kubectl -n <namespace> logs <pod-name> -f
    # or
    stern -n <namespace> <fuzzy-name>
    ```

5. If a resource exists try to describe it to see what problems it might have.

    ```sh
    kubectl -n <namespace> describe <resource> <name>
    ```

6. Check the namespace events

    ```sh
    kubectl -n <namespace> get events --sort-by='.metadata.creationTimestamp'
    ```
