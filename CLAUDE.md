# AccoReboot - Infrastructure

## Projet
Mise en place de l'infrastructure de production pour AccoReboot.

## Stack technique
- **Backend** : NestJS (Docker, image privee Docker Hub)
- **Base de donnees** : PostgreSQL manage OVH (PG17 max) + TimescaleDB (positions GPS)
- **MQTT Broker** : EMQX 5.8 (auth HTTP via API)
- **Sync** : PowerSync (PostgreSQL bucket storage)
- **Reverse proxy** : Caddy (HTTP :80 sans domaine, SSL quand domaine ajoute)
- **IaC** : Terraform (provisioning OVH) + Ansible (configuration serveurs)
- **Secrets** : SOPS + age (chiffrement des credentials dans Git)
- **Docker** : installe via cloud-init (pas Ansible)

## Architecture cible
- 1 projet OVH Public Cloud par environnement (accoreboot-test, accoreboot-preprod, accoreboot-prod)
- Instance compute b3-8 : Caddy + NestJS API + EMQX + PowerSync (4 containers Docker)
- Instance PostgreSQL managee OVH db1-4 (separee, sslmode=require)
- Pas de domaine pour l'instant (acces IP only, HTTP :80)
- Backend only (pas de frontend React)

## Flux de donnees
```
Traceurs GPS  --MQTT:1883-->  EMQX (broker)
                                |
                                +--auth/acl-->  API NestJS
                                                    |
Clients  --HTTP:80-->  Caddy  --reverse proxy-->    +--SQL-->  PostgreSQL (OVH manage)
                         |
                         +--/powersync/*-->  PowerSync  --replication-->  PostgreSQL
```

## Services et ports
| Service    | Image                          | Ports                                     |
|------------|--------------------------------|-------------------------------------------|
| Caddy      | caddy:2                        | 80, 443                                   |
| API NestJS | privee Docker Hub              | 127.0.0.1:3000 (via Caddy)                |
| EMQX       | emqx/emqx:5.8                 | 1883 (MQTT), 8083 (WS), 18083 (test only) |
| PowerSync  | journeyapps/powersync-service  | 127.0.0.1:8080 (via Caddy)                |

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
- [x] Generer cle age et configurer .sops.yaml
- [x] Cloud-init (Docker via user_data)
- [x] Playbooks Ansible (site.yml + templates)
- [ ] Creer les projets OVH (test, preprod, prod) et remplir les credentials
- [ ] Bootstrap du bucket S3 (make bootstrap)
- [ ] Premier make plan ENV=test
- [ ] Premier make up ENV=test (deploiement complet)
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
│   ├── common.enc.env              # Cles API OVH + SSH + Docker Hub (partagees entre envs)
│   ├── common.enc.env.example      # Template
│   ├── test.enc.env                # Project ID + OpenStack + EMQX password du projet test
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
│   │   ├── compute/                 # Instance OpenStack (keypair, secgroup, instance, cloud-init)
│   │   │   └── templates/cloud-init.yml  # Installe Docker, cree /opt/accoreboot
│   │   └── managed_db/              # PostgreSQL manage OVH
│   └── environments/
│       ├── test/                    # b3-8 compute + db1-4 PostgreSQL
│       │   ├── main.tf              # Backend S3 + modules compute + managed_db
│       │   ├── variables.tf
│       │   ├── outputs.tf
│       │   └── templates/inventory.tpl  # Inclut db_user/db_password
│       ├── preprod/
│       └── prod/
│
└── ansible/
    ├── ansible.cfg
    ├── inventory/                   # Genere par Terraform
    ├── group_vars/
    │   ├── all/main.yml             # Images Docker, ports, db_name, jwt_expires_in
    │   └── test/main.yml            # node_env, emqx_dashboard_port_exposed
    ├── roles/
    └── playbooks/
        ├── site.yml                 # Playbook principal (deploy complet)
        └── templates/
            ├── docker-compose.yml.j2  # 4 services : api, emqx, powersync, caddy
            ├── env.j2                 # Variables d'environnement (.env)
            ├── emqx.conf.j2           # Config EMQX (auth/ACL HTTP)
            ├── powersync.yaml.j2      # Config PowerSync (sslmode=verify-ca)
            ├── sync_rules.yaml.j2     # Regles de sync PowerSync
            ├── Caddyfile.j2           # Reverse proxy (:80, IP-only)
            └── Makefile.j2            # Commandes sur l'instance (up, down, logs, ps)
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
- Bucket + credentials S3 crees par `terraform/bootstrap/` (state local, une fois par env: `make bootstrap ENV=test`)
- S3 endpoint : `https://s3.gra.io.cloud.ovh.net/`
- Credentials S3 generees via `ovh_cloud_project_user_s3_credential` (bootstrap), stockees dans common.enc.env
- Credentials S3 passees via env vars AWS_ACCESS_KEY_ID / AWS_SECRET_ACCESS_KEY

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

## Deploiement Ansible (playbook site.yml)

Le playbook `ansible/playbooks/site.yml` effectue dans l'ordre :
1. Wait cloud-init marker (`/var/lib/cloud/instance/boot-finished-docker`)
2. Cree les repertoires dans `/opt/accoreboot` (emqx, powersync, caddy, keys)
3. Genere les cles JWT RS256 (idempotent, openssl)
4. Docker Hub login (image API privee)
5. Deploie les 7 fichiers de config (templates Jinja2)
6. Cree la database `powersync_storage` sur le PG manage (via docker run postgres psql)
7. `docker compose up -d --pull always`
8. Wait API /health (via Caddy sur :80)
9. Affiche le status des containers

### Caddy comme reverse proxy
- IP-only `:80` (pas de HTTPS sans domaine)
- Routes : `/api/*`, `/.well-known/*`, `/health` → api:3000
- `/powersync/*` → powersync:8080 (strip prefix)
- `/mqtt` → emqx:8083 (WebSocket)

### Credentials necessaires (SOPS)
- `common.enc.env` : DOCKERHUB_USERNAME, DOCKERHUB_TOKEN
- `<env>.enc.env` : EMQX_DASHBOARD_PASSWORD

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
- **Docker via cloud-init** (pas Ansible) : simplifie le playbook, Docker dispo avant Ansible
- **Images Docker Hub** : registry prive pour l'API, images publiques pour emqx/powersync/caddy
- **Pas de domaine** pour l'instant : Caddy en mode IP-only (:80), HTTPS quand domaine ajoute
- **Backend only** : pas de frontend React deploye (acces API uniquement)
- **EMQX 5.8** : broker MQTT avec auth/ACL HTTP via l'API NestJS
- **PowerSync PostgreSQL storage** : bucket storage dans une DB separee sur le meme PG manage
- **JWT RS256** : cles generees sur l'instance par Ansible (idempotent)

## Conventions
- Makefile comme facade unique pour toutes les commandes infra
- Un dossier par environnement dans terraform/environments/
- Secrets chiffres SOPS dans credentials/ (commites dans Git)
- Nommage instances : `<env>-backend` (compute), `<env>-postgresql` (managed db)
- Inventaire Ansible genere automatiquement par Terraform (outputs -> .ini)
