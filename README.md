# Welcome to the SaaS show

This is a repository containing code and definitions for maintaining my home kubernetes cluster. It contains helm deployments, service definitions, and other information to re-create my homelab in the event of accidental death and dismemberment or the less accidental yearly lab upgrades.

## Overview

- [Introduction](https://github.com/onedr0p/flux-cluster-template#-introduction)
- [Prerequisites](https://github.com/onedr0p/flux-cluster-template#-prerequisites)
- [Repository structure](https://github.com/onedr0p/flux-cluster-template#-repository-structure)
- [Lets go!](https://github.com/onedr0p/flux-cluster-template#-lets-go)
- [Post installation](https://github.com/onedr0p/flux-cluster-template#-post-installation)
- [Troubleshooting](https://github.com/onedr0p/flux-cluster-template#-troubleshooting)
- [What's next](https://github.com/onedr0p/flux-cluster-template#-whats-next)
- [Thanks](https://github.com/onedr0p/flux-cluster-template#-thanks)

## 👋 Introduction

The following components are installed on the cluster for networking and mechanics. Most are only included to get a minimum viable cluster up and running.

- [flux](https://toolkit.fluxcd.io/) - GitOps operator for managing Kubernetes clusters from a Git repository
- [metallb](https://metallb.universe.tf/) - Load balancer for Kubernetes services
- [cert-manager](https://cert-manager.io/) - Operator to request SSL certificates and store them as Kubernetes resources
- [calico](https://www.tigera.io/project-calico/) - Container networking interface for inter pod and service networking
- [external-dns](https://github.com/kubernetes-sigs/external-dns) - Operator to publish DNS records to Cloudflare (and other providers) based on Kubernetes ingresses
- [k8s_gateway](https://github.com/ori-edge/k8s_gateway) - DNS resolver that provides local DNS to your Kubernetes ingresses
- [ingress-nginx](https://kubernetes.github.io/ingress-nginx/) - Kubernetes ingress controller used for a HTTP reverse proxy of Kubernetes ingresses
- [local-path-provisioner](https://github.com/rancher/local-path-provisioner) - provision persistent local storage with Kubernetes (try not to use this, it makes upgrading hard)

_Additional applications include [hajimari](https://github.com/toboshii/hajimari), [error-pages](https://github.com/tarampampam/error-pages), [echo-server](https://github.com/Ealenn/Echo-Server), [reloader](https://github.com/stakater/Reloader)

For provisioning the following tools will be used:

- [Ansible](https://www.ansible.com) - Sets up the operating system and installs k3s
- [Terraform](https://www.terraform.io) - Provisions an existing Cloudflare domain and certain DNS records that need to exist before being used with your Kubernetes cluster

### 📚 Reading material

- [Organizing Cluster Access Using kubeconfig Files](https://kubernetes.io/docs/concepts/configuration/organize-cluster-access-kubeconfig/)

### 💻 Systems

- 8 nodes with [Ubuntu 22.04 Server](https://ubuntu.com/download/server).
  - 3 node control plane nodes (Poweredge R610's -- yeesh on the power bill. Hoping to upgrade these by 2025)
  - 5 worker nodes (Poweredge R730xd's -- these can do a lot of heavy lifting, more than I'm asking them to at the moment.)

## 📂 Repository structure

The Git repository contains the following directories under `kubernetes` and are ordered below by how Flux will apply them.

```sh
📁 kubernetes      # Kubernetes cluster defined as code
├─📁 bootstrap     # Flux installation (break only in case of cluster already on fire)
├─📁 flux          # Main Flux configuration of repository (put git/helm/oci sources here)
└─📁 apps          # Apps deployed into the cluster grouped by namespace (put dumb things to run on the network here)
```

### 🔧 Workstation Tools

📍 Install the **most recent version** of the CLI tools below. If you are **having trouble with future steps**, it is very likely you don't have the most recent version of these CLI tools, **!especially sops AND yq!**.

1. Install the following CLI tools on your workstation, if you are **NOT** using [Homebrew](https://brew.sh/) on MacOS or Linux **ignore** steps 4 and 5.

    * Required: [age](https://github.com/FiloSottile/age), [ansible](https://www.ansible.com), [flux](https://toolkit.fluxcd.io/), [weave-gitops](https://docs.gitops.weave.works/docs/installation/weave-gitops/), [go-task](https://github.com/go-task/task), [direnv](https://github.com/direnv/direnv), [ipcalc](http://jodies.de/ipcalc), [jq](https://stedolan.github.io/jq/), [kubectl](https://kubernetes.io/docs/tasks/tools/), [python-pip3](https://pypi.org/project/pip/), [pre-commit](https://github.com/pre-commit/pre-commit), [sops v3](https://github.com/mozilla/sops), [terraform](https://www.terraform.io), [yq v4](https://github.com/mikefarah/yq)

    * Recommended: [helm](https://helm.sh/), [kustomize](https://github.com/kubernetes-sigs/kustomize), [stern](https://github.com/stern/stern), [yamllint](https://github.com/adrienverge/yamllint)

2. This guide heavily relies on [go-task](https://github.com/go-task/task) as a framework for setting things up. It is advised to learn and understand the commands it is running under the hood.

3. Install Python 3 and pip3 using your Linux OS package manager, or Homebrew if using MacOS.
    - Ensure `pip3` is working on your command line by running `pip3 --version`

4. [Homebrew] Install [go-task](https://github.com/go-task/task)

    ```sh
    brew install go-task/tap/go-task
    ```

5. [Homebrew] Install workstation dependencies

    ```sh
    task init
    ```

### ⚠️ pre-commit

It is advisable to install [pre-commit](https://pre-commit.com/) and the pre-commit hooks that come with this repository.

1. Enable Pre-Commit

    ```sh
    task precommit:init
    ```

2. Update Pre-Commit, though it will occasionally make mistakes, so verify its results.

    ```sh
    task precommit:update
    ```

### 🔐 Setting up Age

📍 Here we will create a Age Private and Public key. Using [SOPS](https://github.com/mozilla/sops) with [Age](https://github.com/FiloSottile/age) allows us to encrypt secrets and use them in Ansible, Terraform and Flux.

1. Create a Age Private / Public Key

    ```sh
    age-keygen -o age.agekey
    ```

2. Set up the directory for the Age key and move the Age file to it

    ```sh
    mkdir -p ~/.config/sops/age
    mv age.agekey ~/.config/sops/age/keys.txt
    ```

3. Export the `SOPS_AGE_KEY_FILE` variable in your `bashrc`, `zshrc` or `config.fish` and source it, e.g.

    ```sh
    export SOPS_AGE_KEY_FILE=~/.config/sops/age/keys.txt
    source ~/.bashrc
    ```

4. Fill out the Age public key in the appropriate variable in configuration section below, **note** the public key should start with `age`...

### ☁️ Global Cloudflare API Key

In order to use Terraform and `cert-manager` with the Cloudflare DNS challenge you will need to create a API key.

1. Head over to Cloudflare and create a API key by going [here](https://dash.cloudflare.com/profile/api-tokens).

2. Under the `API Keys` section, create a global API Key.

3. Use the API Key in the appropriate variable in configuration section below.

📍 You may wish to update this later on to a Cloudflare **API Token** which can be scoped to certain resources. I do not recommend using a Cloudflare **API Key**, however for the purposes of this template it is easier getting started without having to define which scopes and resources are needed. For more information see the [Cloudflare docs on API Keys and Tokens](https://developers.cloudflare.com/api/).

### 📄 Configuration

📍 The `.config.env` file contains necessary configuration that is needed by Ansible, Terraform and Flux.

1. Copy the `.config.sample.env` to `.config.env` and start filling out all the environment variables.

    **All are required** unless otherwise noted in the comments.

    ```sh
    cp .config.sample.env .config.env
    ```

2. Once that is done, verify the configuration is correct by running:

    ```sh
    task verify
    ```

3. If you do not encounter any errors run start having the script wire up the templated files and place them where they need to be.

    ```sh
    task configure
    ```

### ☁️ Configuring Cloudflare DNS with Terraform

📍 Review the Terraform scripts under `./terraform/cloudflare/` and make sure you understand what it's doing (no really review it).

If your domain already has existing DNS records **be sure to export those DNS settings before you continue**.

1. Pull in the Terraform deps

    ```sh
    task terraform:init
    ```

2. Review the changes Terraform will make to your Cloudflare domain

    ```sh
    task terraform:plan
    ```

3. Have Terraform apply your Cloudflare settings

    ```sh
    task terraform:apply
    ```

If Terraform was ran successfully you can log into Cloudflare and validate the DNS records are present.

The cluster application [external-dns](https://github.com/kubernetes-sigs/external-dns) will be managing the rest of the DNS records you will need.

### 🔹 GitOps with Flux

📍 Here we will be installing [flux](https://toolkit.fluxcd.io/) after some quick bootstrap steps.

1. Verify Flux can be installed

    ```sh
    task cluster:verify
    # ► checking prerequisites
    # ✔ kubectl 1.21.5 >=1.18.0-0
    # ✔ Kubernetes 1.21.5+k3s1 >=1.16.0-0
    # ✔ prerequisites checks passed
    ```

2. Push you changes to git

    📍 **Verify** all the `*.sops.yaml` and `*.sops.yml` files under the `./ansible`, `./kubernetes`, and `./terraform` folders are **encrypted** with SOPS

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
    ```

4. Verify Flux components are running in the cluster

    ```sh
    task cluster:pods -- -n flux-system
    # NAME                                       READY   STATUS    RESTARTS   AGE
    # helm-controller-5bbd94c75-89sb4            1/1     Running   0          1h
    # kustomize-controller-7b67b6b77d-nqc67      1/1     Running   0          1h
    # notification-controller-7c46575844-k4bvr   1/1     Running   0          1h
    # source-controller-7d6875bcb4-zqw9f         1/1     Running   0          1h
    ```

### 🎤 Verification Steps

_Mic check, 1, 2_ - In a few moments applications should be lighting up like a Christmas tree 🎄

You are able to run all the commands below with one task

```sh
task cluster:resources
```

1. View the Flux Git Repositories

    ```sh
    task cluster:gitrepositories
    ```

2. View the Flux kustomizations

    ```sh
    task cluster:kustomizations
    ```

3. View all the Flux Helm Releases

    ```sh
    task cluster:helmreleases
    ```

4. View all the Flux Helm Repositories

    ```sh
    task cluster:helmrepositories
    ```

5. View all the Pods

    ```sh
    task cluster:pods
    ```

6. View all the certificates and certificate requests

    ```sh
    task cluster:certificates
    ```

7. View all the ingresses

    ```sh
    task cluster:ingresses
    ```

🏆 **Congratulations** if all goes smooth you'll have a Kubernetes cluster managed by Flux, your Git repository is driving the state of your cluster.

☢️ If you run into problems, you can run `task ansible:nuke` to destroy the k3s cluster and start over.

🧠 Now it's time to pause and go get some coffee ☕ because next is describing how DNS is handled.

## 📣 Post installation

### 🌱 Environment

[direnv](https://direnv.net/) will make it so anytime you `cd` to your repo's directory it export the required environment variables (e.g. `KUBECONFIG`). To set this up make sure you [hook it into your shell](https://direnv.net/docs/hook.html) and after that is done, run `direnv allow` while in your repos directory.

### 🌐 DNS

📍 The [external-dns](https://github.com/kubernetes-sigs/external-dns) application created in the `networking` namespace will handle creating public DNS records. By default, `echo-server` and the `flux-webhook` are the only public domain exposed on your Cloudflare domain. In order to make additional applications public you must set an ingress annotation (`external-dns.alpha.kubernetes.io/target`) like done in the `HelmRelease` for `echo-server`. You do not need to use Terraform to create additional DNS records unless you need a record outside the purposes of your Kubernetes cluster (e.g. setting up MX records).

[k8s_gateway](https://github.com/ori-edge/k8s_gateway) is deployed on the IP choosen for `${BOOTSTRAP_METALLB_K8S_GATEWAY_ADDR}`. Inorder to test DNS you can point your clients DNS to the `${BOOTSTRAP_METALLB_K8S_GATEWAY_ADDR}` IP address and load `https://hajimari.${BOOTSTRAP_CLOUDFLARE_DOMAIN}` in your browser.

You can also try debugging with the command `dig`, e.g. `dig @${BOOTSTRAP_METALLB_K8S_GATEWAY_ADDR} hajimari.${BOOTSTRAP_CLOUDFLARE_DOMAIN}` and you should get a valid answer containing your `${BOOTSTRAP_METALLB_INGRESS_ADDR}` IP address.

If your router (or Pi-Hole, Adguard Home or whatever) supports conditional DNS forwarding (also know as split-horizon DNS) you may have DNS requests for `${SECRET_DOMAIN}` only point to the  `${BOOTSTRAP_METALLB_K8S_GATEWAY_ADDR}` IP address. This will ensure only DNS requests for `${SECRET_DOMAIN}` will only get routed to your [k8s_gateway](https://github.com/ori-edge/k8s_gateway) service thus providing DNS resolution to your cluster applications/ingresses.

To access services from the outside world port forwarded `80` and `443` in your router to the `${BOOTSTRAP_METALLB_INGRESS_ADDR}` IP, in a few moments head over to your browser and you _should_ be able to access `https://echo-server.${BOOTSTRAP_CLOUDFLARE_DOMAIN}` from a device outside your LAN.

Now if nothing is working, that is expected. This is DNS after all!

### 🤖 Renovatebot

[Renovatebot](https://www.mend.io/free-developer-tools/renovate/) will scan your repository and offer PRs when it finds dependencies out of date. Common dependencies it will discover and update are Flux, Ansible Galaxy Roles, Terraform Providers, Kubernetes Helm Charts, Kubernetes Container Images, Pre-commit hooks updates, and more!

The base Renovate configuration provided in your repository can be view at [.github/renovate.json5](https://github.com/onedr0p/flux-cluster-template/blob/main/.github/renovate.json5). If you notice this only runs on weekends and you can [change the schedule to anything you want](https://docs.renovatebot.com/presets-schedule/) or simply remove it.

To enable Renovate on your repository, click the 'Configure' button over at their [Github app page](https://github.com/apps/renovate) and choose your repository. Over time Renovate will create PRs for out-of-date dependencies it finds. Any merged PRs that are in the kubernetes directory Flux will deploy.

### 🪝 Github Webhook

Flux is pull-based by design meaning it will periodically check your git repository for changes, using a webhook you can enable Flux to update your cluster on `git push`. In order to configure Github to send `push` events from your repository to the Flux webhook receiver you will need two things:

1. Webhook URL - Your webhook receiver will be deployed on `https://flux-webhook.${BOOTSTRAP_CLOUDFLARE_DOMAIN}/hook/:hookId`. In order to find out your hook id you can run the following command:

    ```sh
    kubectl -n flux-system get receiver/github-receiver
    # NAME              AGE    READY   STATUS
    # github-receiver   6h8m   True    Receiver initialized with URL: /hook/12ebd1e363c641dc3c2e430ecf3cee2b3c7a5ac9e1234506f6f5f3ce1230e123
    ```

    So if my domain was `onedr0p.com` the full url would look like this:

    ```text
    https://flux-webhook.onedr0p.com/hook/12ebd1e363c641dc3c2e430ecf3cee2b3c7a5ac9e1234506f6f5f3ce1230e123
    ```

2. Webhook secret - Your webhook secret can be found by decrypting the `secret.sops.yaml` using the following command:

    ```sh
    sops -d ./kubernetes/apps/flux-system/addons/webhooks/github/secret.sops.yaml | yq .stringData.token
    ```

    **Note:** Don't forget to update the `BOOTSTRAP_FLUX_GITHUB_WEBHOOK_SECRET` variable in your `.config.env` file so it matches the generated secret if applicable

Now that you have the webhook url and secret, it's time to set everything up on the Github repository side. Navigate to the settings of your repository on Github, under "Settings/Webhooks" press the "Add webhook" button. Fill in the webhook url and your secret.

### 💾 Storage

Rancher's `local-path-provisioner` is a great start for storage but soon you might find you need more features like replicated block storage, or to connect to a NFS/SMB/iSCSI server. Check out the projects below to read up more on some storage solutions that might work for you.

- [rook-ceph](https://github.com/rook/rook)
- [longhorn](https://github.com/longhorn/longhorn)
- [openebs](https://github.com/openebs/openebs)
- [nfs-subdir-external-provisioner](https://github.com/kubernetes-sigs/nfs-subdir-external-provisioner)
- [democratic-csi](https://github.com/democratic-csi/democratic-csi)
- [csi-driver-nfs](https://github.com/kubernetes-csi/csi-driver-nfs)
- [synology-csi](https://github.com/SynologyOpenSource/synology-csi)

### 🔏 Authenticate Flux over SSH

Authenticating Flux to your git repository has a couple benefits like using a private git repository and/or using the Flux [Image Automation Controllers](https://fluxcd.io/docs/components/image/).

By default this template only works on a public GitHub repository, it is advised to keep your repository public.

The benefits of a public repository include:

* Debugging or asking for help, you can provide a link to a resource you are having issues with.
* Adding a topic to your repository of `k8s-at-home` to be included in the [k8s-at-home-search](https://whazor.github.io/k8s-at-home-search/). This search helps people discover different configurations of Helm charts across others Flux based repositories.

<details>
  <summary>Expand to read guide on adding Flux SSH authentication</summary>

  1. Generate new SSH key:
      ```sh
      ssh-keygen -t ecdsa -b 521 -C "github-deploy-key" -f ./kubernetes/bootstrap/github-deploy.key -q -P ""
      ```
  2. Paste public key in the deploy keys section of your repository settings
  3. Create sops secret in `./kubernetes/bootstrap/github-deploy-key.sops.yaml` with the contents of:
      ```yaml
      apiVersion: v1
      kind: Secret
      metadata:
          name: github-deploy-key
          namespace: flux-system
      stringData:
          # 3a. Contents of github-deploy-key
          identity: |
              -----BEGIN OPENSSH PRIVATE KEY-----
                  ...
              -----END OPENSSH PRIVATE KEY-----
          # 3b. Output of curl --silent https://api.github.com/meta | jq --raw-output '"github.com "+.ssh_keys[]'
          known_hosts: |
              github.com ssh-ed25519 ...
              github.com ecdsa-sha2-nistp256 ...
              github.com ssh-rsa ...
      ```
  4. Encrypt secret:
      ```sh
      sops --encrypt --in-place ./kubernetes/bootstrap/github-deploy-key.sops.yaml
      ```
  5. Apply secret to cluster:
      ```sh
      sops --decrypt ./kubernetes/bootstrap/github-deploy-key.sops.yaml | kubectl apply -f -
      ```
  6.  Update `./kubernetes/flux/config/cluster.yaml`:
      ```yaml
      apiVersion: source.toolkit.fluxcd.io/v1beta2
      kind: GitRepository
      metadata:
        name: home-kubernetes
        namespace: flux-system
      spec:
        interval: 20m
        # 6a: Change this to your user and repo names
        url: ssh://git@github.com/$user/$repo
        ref:
          branch: master
        secretRef:
          name: github-deploy-key
      ```
  7. Commit and push changes
  8. Force flux to reconcile your changes
     ```sh
     task cluster:reconcile
     ```
  9. Verify git repository is now using SSH:
      ```sh
      task cluster:gitrepositories
      ```
  10. Optionally set your repository to Private in your repository settings.
</details>

### 💨 Kubernetes Dashboard

Included in your cluster is the [Kubernetes Dashboard](https://kubernetes.io/docs/tasks/access-application-cluster/web-ui-dashboard/). Inorder to log into this you will have to get the secret token from the cluster using the command below.

```sh
kubectl -n monitoring get secret kubernetes-dashboard -o jsonpath='{.data.token}' | base64 -d
```

You should be able to access the dashboard at `https://kubernetes.${SECRET_DOMAIN}`

## 🐛 Debugging

Below is a general guide on trying to debug an issue with an resource or application. For example, if a workload/resource is not showing up or a pod has started but in a `CrashLoopBackOff` or `Pending` state.

1. Start by checking all Flux Kustomizations and verify they are healthy.
  - `flux get ks -A`
2. Then check all the Flux Helm Releases and verify they are healthy.
  - `flux get hr -A`
3. Then check the if the pod is present.
  - `kubectl -n <namespace> get pods`
4. Then check the logs of the pod if its there.
  - `kubectl -n <namespace> logs <pod-name> -f`

Note: If a resource exists, running `kubectl -n <namespace> describe <resource> <name>` might give you insight into what the problem(s) could be.

Resolving problems that you have could take some tweaking of your YAML manifests in order to get things working, other times it could be a external factor like permissions on NFS. If you are unable to figure out your problem see the help section below.

## 👉 Help

- Make a post in this repository's GitHub [Discussions](https://github.com/onedr0p/flux-cluster-template/discussions).
- Start a thread in the `support` or `flux-cluster-template` channel in the [k8s@home](https://discord.gg/k8s-at-home) Discord server.

## 🤝 Thanks

Big shout out to all the authors and contributors to the projects that we are using in this repository.

[@whazor](https://github.com/whazor) created [this website](https://nanne.dev/k8s-at-home-search/) as a creative way to search Helm Releases across GitHub. You may use it as a means to get ideas on how to configure an applications' Helm values.
