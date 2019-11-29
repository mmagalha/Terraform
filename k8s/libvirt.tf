provider "libvirt" {
  uri   = "qemu+ssh://root@172.32.0.98/system"
}

resource "libvirt_volume" "ubuntu-cloud" {
  name = "ubuntu-cloud"
  source = "bionic-server-cloudimg-amd64.img"
  format = "qcow2"
}


resource "libvirt_volume" "k8smaster-qcow2" {
  name = "k8smaster.qcow2"
  base_volume_id = libvirt_volume.ubuntu-cloud.id
  pool = "default"
  format = "qcow2"
  size = 10000000000
}

resource "libvirt_volume" "k8snode-vol" {
  name = "k8snode${count.index}.qcow2"
  pool = "default"
  base_volume_id = libvirt_volume.ubuntu-cloud.id
  count = "${var.k8s_num_nodes}"
  format = "qcow2"
  size = 10000000000
}

data "template_file" "user_data" {
  template = "${file("${path.module}/cloud_init.cfg")}"
}

# Use CloudInit to add the instance
resource "libvirt_cloudinit_disk" "commoninit" {
  name = "commoninit.iso"
  user_data      = "${data.template_file.user_data.rendered}"
}

# Define KVM master
resource "libvirt_domain" "k8smaster" {
  name   = "k8smaster"
  memory = "2048"
  vcpu   = 2

  network_interface {
    network_name = "default"
    wait_for_lease = true
    hostname = "k8smaster"
  }

  disk {
    volume_id = "${libvirt_volume.k8smaster-qcow2.id}"
  }

  cloudinit = "${libvirt_cloudinit_disk.commoninit.id}"

  console {
    type = "pty"
    target_type = "serial"
    target_port = "0"
  }

  graphics {
    type = "spice"
    listen_type = "address"
    autoport = true
  }
}

# Define KVM node
resource "libvirt_domain" "k8node" {
  name   = "k8node${count.index}"
  memory = "2048"
  vcpu   = 2
  count = "${var.k8s_num_nodes}"

  network_interface {
    network_name = "default"
    wait_for_lease = true
    hostname = "k8snode${count.index + 1}"
  }

  disk {
    volume_id = "${element(libvirt_volume.k8snode-vol.*.id, count.index)}"
  }

  cloudinit = "${libvirt_cloudinit_disk.commoninit.id}"

  console {
    type = "pty"
    target_type = "serial"
    target_port = "0"
  }

  graphics {
    type = "spice"
    listen_type = "address"
    autoport = true
  }
}
