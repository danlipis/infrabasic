### Provider OIC
provider "oci" {
  tenancy_ocid          = ""
  region                = ""
  user_ocid             = ""
  fingerprint           = ""
  private_key_path      = "/home/DANIEL_BAS/.oci/oci_api_key.pem"
}

data "oci_identity_compartment" "compartment_oci" {
  id = ""
}

### Criar VCN
resource "oci_core_vcn" "vcn" {
  cidr_blocks    = ["10.0.0.0/24"]
  dns_label      = "vcn"
  compartment_id = data.oci_identity_compartment.compartment_oci.id
  display_name   = "vcn-terraform"
}


### Criar Sunet
resource oci_core_subnet "regional_subnet" {
  cidr_block        = "10.0.0.0/24"
  display_name      = "regionalSubnet"
  dns_label         = "regionalsubnet"
  compartment_id    = data.oci_identity_compartment.compartment_oci.id
  vcn_id            = oci_core_vcn.vcn.id
  security_list_ids = [oci_core_security_list.public_security_list.id]
  route_table_id    = oci_core_route_table.route_table.id
}


### Criar Security-List
resource "oci_core_security_list" "public_security_list" {
  compartment_id = data.oci_identity_compartment.compartment_oci.id
  vcn_id         = oci_core_vcn.vcn.id
  display_name   = "SecurityListTerraform"

  // Permitir saida para qualquer destino
  egress_security_rules {
    destination = "0.0.0.0/0"
    protocol    = "6"
   }

  // Permitir trafego de entrada de endereco especifico
  ingress_security_rules {
    protocol  = "6" // tcp
    source    = "0.0.0.0/0"
    stateless = false
  }

  // permitri trafego inbound de icmp de endereco especifico
  ingress_security_rules {
    protocol    = 1
    source      = "0.0.0.0/0"
    stateless   = true
    }
}


### Criar Route-Table
resource "oci_core_internet_gateway" "ig" {
  compartment_id = data.oci_identity_compartment.compartment_oci.id
  display_name   = "IGTerraform"
  vcn_id         = oci_core_vcn.vcn.id
}

resource "oci_core_route_table" "route_table" {
  compartment_id = data.oci_identity_compartment.compartment_oci.id
  vcn_id         = oci_core_vcn.vcn.id
  display_name   = "RouteTableTerraform"

  route_rules {
    destination       = "0.0.0.0/0"
    destination_type  = "CIDR_BLOCK"
    network_entity_id = oci_core_internet_gateway.ig.id
  }
}

### Atachar IG na Route-Table
resource "oci_core_route_table_attachment" "route_table_attachment" {
  subnet_id      = oci_core_subnet.regional_subnet.id
  route_table_id = oci_core_route_table.route_table.id
}

##### Criar instancia
data "oci_identity_availability_domain" "ad" {
  compartment_id = ""
  ad_number      = 1
}

resource "oci_core_instance" "test_instance" {
  compartment_id      = data.oci_identity_compartment.compartment_oci.id
  availability_domain = data.oci_identity_availability_domain.ad.name
  display_name        = "instance_terraform"
  shape               = "VM.Standard.E3.Flex"

  shape_config {
    ocpus = 1
    memory_in_gbs = 1
  }

  create_vnic_details {
    subnet_id                 = oci_core_subnet.regional_subnet.id
    display_name              = "Primaryvnic"
    assign_public_ip          = true
  }

  source_details {
   source_type          = "image"
   source_id            = "ocid1.image.oc1.iad.aaaaaaaa6tp7lhyrcokdtf7vrbmxyp2pctgg4uxvt4jz4vc47qoc2ec4anha"
  }

  metadata = {
    ssh_authorized-keys = file("public_key")
  }
}

## Outputs
output "vcn_id" {
  value = oci_core_vcn.vcn.id
}

output "public_security_list_id" {
  value = oci_core_security_list.public_security_list.id
}

output "public_subnet_id" {
  value = oci_core_subnet.regional_subnet.id
}
