# AccoReboot - Infrastructure

## Projet
Mise en place de l'infrastructure de production pour AccoReboot.

## Stack technique
- **Backend** : Node.js (replicas Docker)
- **Base de donnees** : PostgreSQL manage OVH (PG17 max) + TimescaleDB (positions GPS)
- **MQTT Broker** : EMQX (a confirmer vs alternatives)
- **Sync** : PowerSync
- **Reverse proxy** : Caddy (SSL automatique via Let's Encrypt)
- **IaC** : Terraform (provisioning OVH) + Ansible (configuration serveurs)
- **Secrets** : SOPS + age (chiffrement des credentials dans Git)

## Architecture cible
- 1 projet OVH Public Cloud par environnement (accoreboot-test, accoreboot-preprod, accoreboot-prod)
- Instance compute b3-8 : Caddy + backend Node.js (replicas) + EMQX + PowerSync
- Instance PostgreSQL managee OVH db1-4 (separee)
- Reseau prive OVH (vRack/VLAN) pour communication backend <-> PostgreSQL
- Preprod : PostgreSQL managee demarrable/arretable a la demande

## Flux de donnees
```
Traceurs GPS  --MQTT-->  EMQX (broker)  --SQL-->  PostgreSQL + TimescaleDB
                           |
                           +--->  Backend Node.js (temps reel)

Client HTTPS  --->  Caddy (reverse proxy + SSL)  --->  Backend Node.js
```

## Contraintes connues
- TimescaleDB non disponible sur PG18, rester sur PG17 max
- Extensions PG disponibles : voir https://github.com/ovh/docs/blob/develop/pages/public_cloud/public_cloud_databases/postgresql_02_extensions/guide.en-ca.md
- State Terraform contient des secrets en clair -> state remote S3 obligatoire (chiffre au repos)

## Checklist infra
- [x] Comprehension PostgreSQL + TimescaleDB (supporte par OVH)
- [x] Structure infra IaC (Terraform + Ansible)
- [x] Gestion des secrets (SOPS + age)
- [x] Terraform remote state (S3 OVH)
- [x] Credentials par environnement (1 projet OVH par env)
- [ ] Comparatif MQTT : EMQX vs alternatives
- [x] Generer cle age et configurer .sops.yaml
- [ ] Creer les projets OVH (test, preprod, prod) et remplir les credentials
- [ ] Bootstrap du bucket S3 (make bootstrap)
- [ ] Premier make plan ENV=test
- [ ] Test reboot sans perte de donnees (= premier test d'integration)

## Structure du repo
```
.
├── CLAUDE.md
├── README.md
├── Makefile                         # Facade unique (toutes les commandes passent par la)
├── .sops.yaml                       # Regles de chiffrement SOPS
├── .gitignore
│
├── credentials/                     # Secrets chiffres par SOPS (commites dans Git)
│   ├── common.enc.env              # Cles API OVH + SSH (partagees entre envs)
│   ├── common.enc.env.example      # Template
│   ├── test.enc.env                # Project ID + OpenStack du projet test
│   ├── test.enc.env.example        # Template
│   ├── preprod.enc.env
│   └── prod.enc.env
│
├── scripts/
│   └── with-secrets.sh              # Wrapper : dechiffre SOPS + exporte en env vars + exec
│
├── terraform/
│   ├── bootstrap/                   # Cree le bucket S3 pour les states (state local, une seule fois)
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── outputs.tf
│   ├── modules/
│   │   ├── compute/                 # Instance OpenStack (keypair, secgroup, instance)
│   │   └── managed_db/              # PostgreSQL manage OVH
│   └── environments/
│       ├── test/                    # b3-8 compute + db1-4 PostgreSQL
│       │   ├── main.tf              # Backend S3 + modules compute + managed_db
│       │   ├── variables.tf
│       │   ├── outputs.tf
│       │   └── templates/inventory.tpl
│       ├── preprod/
│       └── prod/
│
└── ansible/
    ├── ansible.cfg
    ├── inventory/                   # Genere par Terraform
    ├── group_vars/
    │   ├── all/main.yml
    │   └── test/main.yml
    ├── roles/
    └── playbooks/
```

## Gestion des secrets (SOPS)
- Backend de cle : age (simple, zero dependance cloud)
- Fichiers chiffres commites dans Git (clés lisibles, valeurs chiffrées)
- 1 fichier common (cles API OVH, SSH, S3) + 1 fichier par env (project ID, OpenStack)
- Wrapper `scripts/with-secrets.sh` dechiffre et exporte en TF_VAR_* / OS_*
- Pas de provider SOPS dans Terraform (evite d'ajouter des secrets dans le state)
- ADR secrets : SOPS pour le moment, vault si besoin apres audit secu

## Terraform state
- Remote S3 sur OVH Object Storage pour TOUS les envs (y compris test)
- Un bucket `accoreboot-tfstate` par projet OVH (1 bucket par env, isolation complete)
- Bucket cree par `terraform/bootstrap/` (state local, une fois par env: `make bootstrap ENV=test`)
- S3 endpoint : `https://s3.eu-west-par.io.cloud.ovh.net/`
- Credentials S3 passees via env vars AWS_ACCESS_KEY_ID / AWS_SECRET_ACCESS_KEY
- Config backend S3 OVH testee et fonctionnelle dans test-manager

## Projets OVH (1 par environnement)
- Chaque env = un projet OVH Public Cloud separe (isolation complete)
- Cles API OVH partagees (liees au compte, pas au projet)
- Credentials OpenStack specifiques par projet (user, password, tenant_id)
- Credentials stockees dans credentials/<env>.enc.env (chiffre SOPS)

## Makefile targets
```
make help                   # Aide
make bootstrap ENV=test     # Cree le bucket S3 dans le projet OVH de l'env (une fois par env)
make init ENV=test          # terraform init (connecte au backend S3)
make plan ENV=test          # terraform plan
make apply ENV=test         # terraform apply -auto-approve
make destroy ENV=test       # terraform destroy -auto-approve
make output ENV=test        # terraform output
make deploy ENV=test        # ansible-playbook
make check ENV=test         # ansible dry-run
make stop ENV=test         # openstack server stop
make start ENV=test       # openstack server start
make state ENV=test         # openstack server show status
make ssh ENV=test           # ssh vers le backend
make up ENV=test            # init + apply + deploy (tout construire)
make down ENV=test          # destroy + clean
make sops-edit-common       # editer les credentials communs
make sops-edit-env ENV=test # editer les credentials d'un env
```

## Patterns a reprendre de test-manager (~/src/test-manager branch feature/TM-1234-cloud-init)

### Cloud-init (terraform user_data)
- Installation Docker au boot via `curl -fsSL https://get.docker.com | sh`
- Script de policy routing Docker pour reseau dual public/prive OVH
- Marqueur de fin cloud-init (`touch /var/lib/cloud/instance/boot-finished-docker`)

### Deploy script avec polling
1. terraform apply
2. Poll SSH (15 tentatives, 5s interval)
3. Poll marqueur cloud-init (30 tentatives, 10s interval)
4. SCP fichiers config (docker-compose, Caddyfile, .env)
5. docker compose up -d --pull always
6. Verification SSL/HTTPS

### Caddy comme reverse proxy
- Generation dynamique du Caddyfile avec le subdomain de l'env
- SSL automatique Let's Encrypt
- Docker compose : caddy -> backend

### DNS automatique Cloudflare
- Terraform cree un record DNS A pointant vers l'IP de l'instance

### Packer (alternative au cloud-init)
- Pre-bake image Debian avec Docker
- Plus rapide au boot mais plus lourd a maintenir

## Decisions prises
- **IaC plutot que UI** : reproductibilite, tests de reboot, onboarding
- **Terraform** pour le provisioning des ressources OVH
- **Ansible** pour la configuration des services sur les instances
- **Caddy** comme reverse proxy (SSL auto, config simple)
- **Makefile** comme facade (universel, suffisant pour ~15 targets)
- **Dossiers par env** plutot que Terraform workspaces (isolation state, configs differentes)
- **1 projet OVH par env** : isolation complete des ressources
- **SOPS + age** pour les secrets (zero infra, secrets dans Git, ADR accepte)
- **State remote S3** pour tous les envs (secrets dans le state -> chiffrement au repos)
- **Gabarits test** : b3-8 (compute) + db1-4 (PostgreSQL manage)
- **stop/start via OpenStack CLI** pour mettre en pause sans detruire l'infra
- **terraform auto-approve** sur apply et destroy (pas de confirmation interactive)
- **1 bucket S3 par projet OVH** : isolation complete des states entre envs
- **Env test = MVP** : le test de reboot necessite un flux complet donc c'est le MVP

## Conventions
- Makefile comme facade unique pour toutes les commandes infra
- Un dossier par environnement dans terraform/environments/
- Secrets chiffres SOPS dans credentials/ (commites dans Git)
- Nommage instances : `<env>-backend` (compute), `<env>-postgresql` (managed db)
- Inventaire Ansible genere automatiquement par Terraform (outputs -> .ini)
