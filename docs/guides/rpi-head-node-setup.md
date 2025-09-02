# Raspberry Pi Head Node Setup

This guide explains how to use the `rpi_head_node` Ansible role to configure a Raspberry Pi as a Kubernetes cluster head node. This role automates the installation of Kubernetes, configures the `containerd` runtime, and enables access to the Raspberry Pi camera from within containers.

## Prerequisites

Before you begin, ensure you have the following:

- A Raspberry Pi (3B+ or newer recommended) with a fresh installation of Raspberry Pi OS.
- The Raspberry Pi camera module connected.
- SSH access to the Raspberry Pi from your Ansible control machine.
- Your Raspberry Pi is included in your Ansible inventory file.

## 1. Update Your Ansible Inventory

In your Ansible inventory file (e.g., `inventory.ini`), define a host group named `rpi_head` and add your Raspberry Pi's connection details.

```ini
[rpi_head]
my-rpi ansible_host=192.168.1.100 ansible_user=pi
```

Replace `192.168.1.100` with your Raspberry Pi's IP address and `pi` with your SSH username.

## 2. Run the Playbook

Execute the `rpi-head-playbook.yml` playbook to apply the role to your Raspberry Pi. This will install all necessary components and initialize the Kubernetes cluster.

```bash
ansible-playbook -i <your_inventory_file> ansible/rpi-head-playbook.yml
```

During the execution, the playbook will perform the following key steps:

- Install `containerd`, `kubeadm`, `kubelet`, and `kubectl`.
- Enable the camera module via `raspi-config` and reboot the device.
- Configure `containerd` to allow camera device passthrough (`/dev/video*`).
- Initialize the Kubernetes cluster using `kubeadm`.
- Set up a `kubeconfig` file at `/home/<user>/.kube/config` for cluster administration.
- Deploy the Flannel CNI for cluster networking.

## 3. Join Worker Nodes

The playbook will output a `kubeadm join` command upon successful cluster initialization. Copy this command and run it on any other nodes you wish to add to the cluster as workers.

Example output:

```
TASK [rpi_head_node : Display join command] ************************************
ok: [my-rpi] => {
    "msg": "Run this command on worker nodes to join the cluster: kubeadm join <control-plane-host>:<control-plane-port> --token <token> --discovery-token-ca-cert-hash sha256:<hash>"
}
```

## 4. Verify the Setup

Once the playbook is finished, you can verify that the head node is ready by running:

```bash
kubectl get nodes
```

You should see your Raspberry Pi listed with the `Ready` status.

### Testing Camera Access

To test if containers can access the camera, you can deploy a simple pod that includes the `v4l-utils` package.

Create a file named `camera-test-pod.yml`:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: camera-test
spec:
  containers:
  - name: camera-container
    image: ubuntu:20.04
    command: ["/bin/bash", "-c", "--"]
    args: ["apt-get update && apt-get install -y v4l-utils && ls /dev/video* && sleep 3600"]
```

Deploy the pod:

```bash
kubectl apply -f camera-test-pod.yml
```

Check the pod's logs to see if the video devices are listed:

```bash
kubectl logs camera-test
```

If the output lists devices like `/dev/video0`, the camera is successfully exposed to the container.
