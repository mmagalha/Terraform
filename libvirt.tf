provider "libvirt" {
  uri = "qemu:///system"
}

#provider "libvirt" {
#  alias = "server2"
#  uri   = "qemu+ssh://root@192.168.100.10/system"
#}

resource "libvirt_volume" "ubuntu-qcow2" {
  name = "db.qcow2"
  pool = "default"
  #source = "http://cloud-images.ubuntu.com/bionic/current/bionic-server-cloudimg-amd64.img"
  source = "./bionic-server-cloudimg-amd64.img"
  format = "qcow2"
}

resource "libvirt_volume" "ubuntu-bootstrap" {
  name = "db.ubuntu-bootstrap.qcow"
  pool = "default"
  format = "qcow2"
}

data "template_file" "user_data" {
  template = "${file("${path.module}/cloud_init.cfg")}"
}

# Use CloudInit to add the instance
resource "libvirt_cloudinit_disk" "commoninit" {
  name = "commoninit.iso"
  user_data      = "${data.template_file.user_data.rendered}"
}

# Define KVM domain to create
resource "libvirt_domain" "db1" {
  name   = "db1"
  memory = "2048"
  vcpu   = 1

  network_interface {
    network_name = "default"
  }

  disk {
    volume_id = "${libvirt_volume.ubuntu-qcow2.id}"
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

# Output Server IP
output "ip" {
  value = "${libvirt_domain.db1.network_interface.0.addresses.0}"
}