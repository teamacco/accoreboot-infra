# AccoReboot - Infrastructure

## Projet
Infrastructure de production pour AccoReboot — deploye et operationnel sur OVH Public Cloud.

## Stack technique
- **Backend** : NestJS (Docker, image privee Docker Hub `accodock/accoreboot-api`)
- **Base de donnees** : PostgreSQL manage OVH (PG17) + TimescaleDB (positions GPS)
- **MQTT Broker** : EMQX 5.8 (auth HTTP via API)
- **Sync** : PowerSync (PostgreSQL bucket storage)
- **Reverse proxy** : Caddy (HTTP :80 sans domaine, SSL quand domaine ajoute)
- **IaC** : Terraform (provisioning OVH) + Ansible (configuration serveurs)
- **Task runner** : justfile (facade unique, remplace le Makefile — ADR-002 accepte)
- **Secrets** : SOPS + age (chiffrement des credentials dans Git, dechiffrement inline dans justfile)
- **Docker** : installe via cloud-init (pas Ansible)

## Architecture deployee (test)
- **1 instance compute** b3-8 (Ubuntu 24.04) : `57.128.7.134`
- **4 containers Docker** sur cette instance (aucune redondance)
- **1 PostgreSQL manage** OVH db1-4 (externe, sslmode=require)
- **IP restriction** : seule l'IP de l'instance compute peut acceder a la DB
- **Databases** : `accoreboot` (app) + `powersync_storage` (sync) — creees par Terraform
- **Pas de domaine** pour l'instant (acces IP only, HTTP :80)

## Architecture single-instance (pas de redondance)
```
Internet
   |
   +-- :80/:443 --> Caddy (1 container) --> reverse proxy
   |                    +-- /api/*        --> API NestJS (127.0.0.1:3000)
   |                    +-- /powersync/*  --> PowerSync (127.0.0.1:8080)
   |                    +-- /mqtt         --> EMQX WS (8083)
   |
   +-- :1883 --> EMQX (1 container) -- MQTT direct

Chaine de dependances : API doit etre healthy avant EMQX, PowerSync, Caddy
restart: unless-stopped sur chaque container (Docker relance auto les crashs)
DB = PostgreSQL manage OVH (externe, pas sur l'instance)
```

## Services et ports
| Service    | Image                          | Ports                                     |
|------------|--------------------------------|-------------------------------------------|
| Caddy      | caddy:2                        | 80, 443                                   |
| API NestJS | accodock/accoreboot-api:latest | 127.0.0.1:3000 (via Caddy)                |
| EMQX       | emqx/emqx:5.8                 | 1883 (MQTT), 8083 (WS), 18083 (test only) |
| PowerSync  | journeyapps/powersync-service  | 127.0.0.1:8080 (via Caddy)                |

## Endpoints de verification
```bash
curl http://<IP>/health                    # -> {"status":"ok"}
curl http://<IP>/.well-known/jwks.json     # -> cle publique RSA
```

## Contraintes connues
- TimescaleDB non disponible sur PG18, rester sur PG17 max
- OVH PG manage utilise des certificats auto-signes -> NODE_TLS_REJECT_UNAUTHORIZED=0 necessaire
- State Terraform contient des secrets en clair -> state remote S3 obligatoire (chiffre au repos)
- Ansible 2.19 ne charge pas les group_vars automatiquement pour les playbooks dans un sous-dossier -> vars_files explicite + target_env en extra var
- OpenStack region pour compute = GRA9 (pas GRA)
- OVH PG manage ne permet pas CREATE DATABASE via psql -> utiliser les ressources Terraform

## Checklist infra
- [x] Comprehension PostgreSQL + TimescaleDB (supporte par OVH)
- [x] Structure infra IaC (Terraform + Ansible)
- [x] Gestion des secrets (SOPS + age)
- [x] Terraform remote state (S3 OVH)
- [x] Credentials par environnement (1 projet OVH par env)
- [x] Cloud-init (Docker via user_data)
- [x] Playbooks Ansible (site.yml + templates)
- [x] Justfile (facade unique, inline SOPS, remplace Makefile)
- [x] Premier deploiement test (just env=test up)
- [x] Health check OK (http://<IP>/health)
- [x] JWKS OK (http://<IP>/.well-known/jwks.json)
- [x] 4 containers running
- [ ] Tests de resilience (crash container, reboot instance, recreate instance)
- [ ] Ajouter preprod/prod
- [ ] Ajouter un domaine + HTTPS

## Structure du repo
```
.
├── CLAUDE.md
├── README.md
├── justfile                         # Facade unique (remplace Makefile)
├── Makefile                         # Legacy (garde pour comparaison ADR-002)
├── .sops.yaml                       # Regles de chiffrement SOPS
├── .gitignore
│
├── credentials/                     # Secrets chiffres par SOPS (commites dans Git)
│   ├── common.enc.env              # Cles API OVH + SSH + Docker Hub + S3
│   ├── common.enc.env.example
│   ├── test.enc.env                # Project ID + OpenStack + EMQX password
│   ├── test.enc.env.example
│   ├── preprod.enc.env
│   └── prod.enc.env
│
├── terraform/
│   ├── bootstrap/                   # Bucket S3 pour les states (une fois par env)
│   ├── modules/
│   │   ├── compute/                 # Instance OpenStack + cloud-init + secgroup
│   │   └── managed_db/              # PostgreSQL manage + databases + IP restriction + user
│   └── environments/
│       ├── test/                    # b3-8 compute + db1-4 PostgreSQL
│       ├── preprod/
│       └── prod/
│
├── ansible/
│   ├── ansible.cfg
│   ├── inventory/                   # Genere par Terraform (inclut db_host, db_password)
│   ├── group_vars/
│   │   ├── all/main.yml             # Images Docker, ports, db_name, jwt_expires_in
│   │   └── test/main.yml            # node_env, emqx_dashboard_port_exposed
│   └── playbooks/
│       ├── site.yml                 # Playbook principal
│       └── templates/               # 7 fichiers Jinja2
│           ├── docker-compose.yml.j2
│           ├── env.j2
│           ├── emqx.conf.j2
│           ├── powersync.yaml.j2
│           ├── sync_rules.yaml.j2
│           ├── Caddyfile.j2
│           └── Makefile.j2          # Commandes sur l'instance (make up/down/logs)
│
└── docs/
    └── architecture.svg
```

## Justfile (facade unique)
```bash
just env=test up           # Full deploy (build + push + init + apply + deploy)
just env=test down         # Destroy + clean
just env=test deploy       # Ansible seulement
just env=test plan         # Terraform plan
just env=test apply        # Terraform apply
just env=test ssh          # SSH sur le serveur
just env=test status       # Docker ps sur le serveur
just env=test stop/start   # OpenStack stop/start instance
just build                 # Build Docker image API
just push                  # Push image vers Docker Hub
just sops-edit-common      # Editer credentials communs
just sops-edit-env env=test  # Editer credentials d'un env
just infra                 # Overview de tous les envs
```

## Gestion des secrets (SOPS)
- Backend de cle : age (simple, zero dependance cloud)
- Dechiffrement inline dans le justfile (shebang recipes + while IFS='=' read)
- Plus besoin de scripts/with-secrets.sh (garde pour compatibilite Makefile)
- 1 fichier common (cles API OVH, SSH, S3, Docker Hub) + 1 fichier par env
- Pas de provider SOPS dans Terraform (evite d'ajouter des secrets dans le state)

## Deploiement Ansible (playbook site.yml)

Le playbook effectue dans l'ordre :
1. Wait cloud-init marker (`/var/lib/cloud/instance/boot-finished-docker`)
2. Cree les repertoires dans `/opt/accoreboot` (emqx, powersync, caddy, keys)
3. Genere les cles JWT RS256 (idempotent, openssl)
4. Docker Hub login (image API privee)
5. Deploie les 7 fichiers de config (templates Jinja2)
6. `docker compose up -d --pull always`
7. Wait API /health (via Caddy sur :80)
8. Affiche le status des containers

Note : les databases `accoreboot` et `powersync_storage` sont creees par Terraform, pas par Ansible.

## Decisions prises
- **IaC plutot que UI** : reproductibilite, tests de reboot, onboarding
- **Terraform** pour le provisioning des ressources OVH
- **Ansible** pour la configuration des services sur les instances
- **justfile** comme facade (ADR-002, remplace Makefile — inline SOPS, confirmations, arguments positionnels)
- **Caddy** comme reverse proxy (SSL auto, config simple)
- **Dossiers par env** plutot que Terraform workspaces (isolation state, configs differentes)
- **1 projet OVH par env** : isolation complete des ressources
- **SOPS + age** pour les secrets (zero infra, secrets dans Git)
- **State remote S3** pour tous les envs (secrets dans le state -> chiffrement au repos)
- **Docker via cloud-init** (pas Ansible) : simplifie le playbook, Docker dispo avant Ansible
- **Docker Hub** : registry prive `accodock` pour l'API, images publiques pour emqx/powersync/caddy
- **JWT RS256** : cles generees sur l'instance par Ansible (idempotent)
- **IP restriction DB** : Terraform autorise uniquement l'IP de l'instance compute sur le PG manage
- **Databases par Terraform** : OVH PG manage ne permet pas CREATE DATABASE via psql, utiliser les ressources Terraform
- **NODE_TLS_REJECT_UNAUTHORIZED=0** : OVH utilise des certificats auto-signes sur le PG manage
- **Ansible vars_files explicite** : workaround Ansible 2.19 qui ne charge pas les group_vars automatiquement pour les playbooks dans playbooks/

## Conventions
- justfile comme facade unique pour toutes les commandes infra
- Un dossier par environnement dans terraform/environments/
- Secrets chiffres SOPS dans credentials/ (commites dans Git)
- Nommage instances : `<env>-backend` (compute), `<env>-postgresql` (managed db)
- Inventaire Ansible genere automatiquement par Terraform (outputs -> .ini)
- Docker image API : `accodock/accoreboot-api:latest`
