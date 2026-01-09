#!/bin/bash


# Provera argumenta
if [ $# -lt 1 ]; then
  echo "Upotreba: $0 --provision|--deploy|--check-status|--monitor|--teardown"
  exit 1
fi

# Ulazak u direktorijum projekta (root repozitorijuma) radi relativnih putanja
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$PROJECT_ROOT" || exit 1

COMMAND=$1

case "$COMMAND" in
  --provision)
    echo "=== Provisioning infrastrukture na Azure putem Terraform-a... ==="
    cd terraform || exit 1
    terraform init -input=false
    terraform apply -auto-approve
    if [ $? -ne 0 ]; then
      echo "Greska: Terraform provisioning nije uspeo."
      exit 1
    fi

    # Ubacivanje private key u ansible/ (da ga i ansible i SSH koriste)
    ADMIN_USER=$(terraform output -raw vm_admin_username)
    terraform output -raw vm_ssh_private_key > ../ansible/id_rsa
    chmod 600 ../ansible/id_rsa

    # Generisanje ansible inventory direktno iz terraform output
    terraform output -raw ansible_inventory_ini > ../ansible/inventory.ini

    # IP adrese
    APP_IP=$(terraform output -raw vm_app_ip)
    MON_IP=$(terraform output -raw vm_monitor_ip)
    cd ..

    
    # Escape putanju da bi sed radio i kad ima / u stringu
    KEY_PATH_ESCAPED=$(printf '%s' "${PROJECT_ROOT}/ansible/id_rsa" | sed 's/[\/&]/\\&/g')
    sed -i "s/ansible_user=${ADMIN_USER}/ansible_user=${ADMIN_USER} ansible_private_key_file=${KEY_PATH_ESCAPED}/g" ansible/inventory.ini

    echo "Provisioning zavrseno. Kreirane su VM instance: $APP_IP (app), $MON_IP (monitor)."
    ;;

  --deploy)
    echo "=== Deploy aplikacije na app server putem Ansible-a... ==="

    # Koristi repo level ansible.cfg (host_key_checking=false)
    export ANSIBLE_CONFIG="$PROJECT_ROOT/ansible.cfg"

    # Provere
    if ! command -v ansible-playbook >/dev/null 2>&1; then
      echo "Greska: ansible-playbook nije pronadjen. Instalirajte Ansible (npr. apt install ansible) i pokusajte ponovo."
      exit 1
    fi
    if [ ! -f ansible/inventory.ini ]; then
      echo "Greska: ansible/inventory.ini ne postoji. Pokrenite --provision da se inventory generise."
      exit 1
    fi
    if [ ! -f ansible/id_rsa ]; then
      echo "Greska: ansible/id_rsa ne postoji. Pokrenite --provision da se SSH kljuc sacuva."
      exit 1
    fi
    # Ocekujemo originalni JAR 
    if [ ! -f ansible/files/project2_dummy_service-1.0-SNAPSHOT.jar ]; then
      echo "Greska: nije pronadjen JAR fajl 'ansible/files/project2_dummy_service-1.0-SNAPSHOT.jar'."
      exit 1
    fi

    chmod 600 ansible/id_rsa 2>/dev/null || true

    # Pokretanje ansible playbook-a
    ansible-playbook -i ansible/inventory.ini ansible/playbook.yml
    if [ $? -ne 0 ]; then
      echo "Greska: Deploy nije uspeo. Proverite izvestaj ansible-a."
      exit 1
    fi
    echo "Deploy zavrsen. Java aplikacija je instalirana i pokrenuta kao servis na VM-u."
    ;;

  --check-status)
    echo "=== Provera statusa aplikacije na serveru... ==="
    # Koristi isti ansible.cfg kao i deploy 
    export ANSIBLE_CONFIG="$PROJECT_ROOT/ansible.cfg"
    # Dohvati IP iz terraform output (ako postoji state) inace iz inventara.
    APP_IP=$(terraform -chdir=terraform output -no-color -raw vm_app_ip 2>/dev/null || true)
    if printf '%s' "$APP_IP" | grep -qi '^warning:'; then
      APP_IP=""
    fi
    if [ -z "$APP_IP" ] && [ -f ansible/inventory.ini ]; then
      APP_IP=$(awk 'BEGIN{in_app=0} $0 ~ /^\[app\]/{in_app=1; next} /^\[/{in_app=0} in_app && NF>0 {print $1; exit}' ansible/inventory.ini)
    fi
    if [ -z "$APP_IP" ] || printf '%s' "$APP_IP" | grep -qi '^warning:'; then
      echo "Greska: Nije pronadjena adresa app servera. Pokrenite --provision pa --deploy, pa tek onda --check-status."
      exit 1
    fi

    ADMIN_USER=$(terraform -chdir=terraform output -no-color -raw vm_admin_username 2>/dev/null || true)
    if [ -z "$ADMIN_USER" ] || printf '%s' "$ADMIN_USER" | grep -qi '^warning:'; then
      ADMIN_USER="azureuser"
    fi

    if [ ! -f ansible/id_rsa ]; then
      echo "Greska: ansible/id_rsa ne postoji. Pokrenite --provision pa --deploy, pa tek onda --check-status."
      exit 1
    fi
  # Izvrsi komande na udaljenom serveru da proveri servis i prikupi log
    echo "Status servisa 'dummyapp':"
    ssh -o StrictHostKeyChecking=no -i ansible/id_rsa ${ADMIN_USER}@$APP_IP "systemctl is-active dummyapp"
    if [ $? -ne 0 ]; then
      echo "Greska: Ne mogu da se povezem na ${ADMIN_USER}@$APP_IP."
      echo "Ako ste uradili --teardown, VM vise ne postoji. Pokrenite ponovo --provision (pa --deploy)."
      exit 1
    fi
  echo "Poslednjih 20 linija loga aplikacije:"
    ssh -o StrictHostKeyChecking=no -i ansible/id_rsa ${ADMIN_USER}@$APP_IP "journalctl -u dummyapp -n 20 --no-pager"
    ;;

  --monitor)
    echo "Monitoring nije implementiran."
    ;;

  --teardown)
    echo "=== Teardown: uklanjanje svih Azure resursa... ==="
    cd terraform || exit 1
    terraform destroy -auto-approve
    cd ..
    echo "Svi resursi su obrisani."
    ;;

  *)
    echo "Nepoznata opcija: $COMMAND"
    echo "Upotreba: $0 --provision|--deploy|--check-status|--monitor|--teardown"
    exit 1
    ;;
esac



exit 0