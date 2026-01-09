# Projekat 2 — Automatizovani deploy i (delimicno) monitoring

Ovo je projekat za automatizaciju deployment-a Java dummy servisa na Azure koristeci Terraform i Ansible.

Sadrzaj repozitorijuma (kljucni fajlovi):

- `terraform/` — Terraform konfiguracija (Resource Group, VNet, NSG, Public IP, NIC, 2x VM)
- `ansible/` — Ansible playbook, inventory, systemd template i JAR u `ansible/files/`
- `automatic_deploy.sh` — glavna skripta za orkestraciju: `--provision`, `--deploy`, `--check-status`, `--monitor`, `--teardown`

Brzi pregled arhitekture

- Terraform kreira infrastrukturu u Azure: resource group, virtual network, subnet, network security group (otvoren port 22), public ip-ove, nic-ove i dva linux VM-a (jedan za aplikaciju, drugi za monitoring).
- Terraform takodje generise SSH kljuc (`tls_private_key`) i Terraform output `ansible_inventory_ini` koji se koristi za kreiranje Ansible inventory-a.
- Ansible playbook instalira OpenJDK 17, kopira JAR u `/opt/dummyapp/` i postavlja systemd servis koji pokrece JAR.
- `automatic_deploy.sh` orkestrira ceo workflow i cuva `ansible/id_rsa` i `ansible/inventory.ini` lokalno.

Kako pokrenuti

1) Provision (kreira infrastrukturu na Azure):

```bash
./automatic_deploy.sh --provision
```

Ovo izvrsava `terraform init` + `terraform apply`, save privatni SSH kljuc u `ansible/id_rsa` i generise `ansible/inventory.ini`.

2) Deploy aplikacije (Ansible):

```bash
./automatic_deploy.sh --deploy
```

Proverava (postojanje `ansible/inventory.ini`, `ansible/id_rsa` i JAR fajla). Playbook ce instalirati OpenJDK 17, kopirati JAR i postaviti systemd servis.

3) Provera statusa:

```bash
./automatic_deploy.sh --check-status
```

Izvodi `systemctl is-active dummyapp` i prikazuje poslednjih 20 linija loga servisa.

4) Teardown (brisanje resursa):

```bash
./automatic_deploy.sh --teardown
```

Napomene

- Inventory i host key checking: projekat sadrzi `ansible.cfg` sa `host_key_checking = False` da bi se izbegle interaktivne SSH potvrde prilikom reprovision-a.
- Ocekivano ime JAR-a: `ansible/files/project2_dummy_service-1.0-SNAPSHOT.jar`


