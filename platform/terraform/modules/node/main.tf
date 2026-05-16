resource "libvirt_volume" "vm" {
  name           = "${var.name}.qcow2"
  base_volume_id = var.ubuntu_image_base_volume_id
  pool           = var.storage_pool
  size           = var.vm.disk_size_gb * 1024 * 1024 * 1024
}

resource "libvirt_cloudinit_disk" "init" {
  name           = "${var.name}-init.iso"
  pool           = var.storage_pool
  user_data      = var.user_data
  network_config = var.network_config
}

resource "libvirt_domain" "vm" {
  name      = var.name
  memory    = var.vm.memory_mib
  vcpu      = var.vm.cpus
  autostart = true

  disk {
    volume_id = libvirt_volume.vm.id
  }

  cloudinit = libvirt_cloudinit_disk.init.id

  network_interface {
    network_id = var.network_id
  }

  xml {
    xslt = <<-EOT
      <?xml version="1.0" ?>
      <xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform">
        <xsl:output omit-xml-declaration="yes" indent="yes"/>
        <xsl:template match="node()|@*">
          <xsl:copy>
            <xsl:apply-templates select="node()|@*"/>
          </xsl:copy>
        </xsl:template>
        <xsl:template match="/domain/cpu">
          <cpu mode="host-passthrough" check="none"/>
        </xsl:template>
      </xsl:stylesheet>
    EOT
  }
}