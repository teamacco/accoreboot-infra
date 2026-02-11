# AccoReboot - Infrastructure

## Projet
Mise en place de l'infrastructure de production pour AccoReboot.
Ce repo contient l'IaC (Terraform + Ansible) ainsi que les POC de test.

## Stack technique
- **Backend** : Node.js
- **Base de donnees** : PostgreSQL manage OVH (PG17 max) + TimescaleDB (positions GPS)
- **MQTT Broker** : EMQX (a confirmer vs alternatives)
- **Sync** : PowerSync
- **IaC** : Terraform (provisioning OVH) + Ansible (configuration serveurs)

## Architecture cible
- 1 projet OVH par environnement (test, preprod, prod)
- Instance compute : backend Node.js + EMQX + PowerSync
- Instance PostgreSQL managee OVH (separee)
- Preprod : PostgreSQL managee demarrable/arretable a la demande

## Flux de donnees
```
Traceurs GPS  --MQTT-->  EMQX (broker)  --SQL-->  PostgreSQL + TimescaleDB
                           |
                           +--->  Backend Node.js (temps reel)
```

## Contraintes connues
- TimescaleDB non disponible sur PG18, rester sur PG17 max
- Extensions PG disponibles : voir https://github.com/ovh/docs/blob/develop/pages/public_cloud/public_cloud_databases/postgresql_02_extensions/guide.en-ca.md

## Structure cible infra/
```
infra/
├── Makefile                    # Point d'entree unique (facade)
├── credentials.sh.example      # Template des secrets OVH/OpenStack
├── credentials.sh              # Secrets OVH/OpenStack (gitignore)
├── .gitignore
├── README.md
│
├── terraform/
│   ├── bootstrap/              # Cree le bucket S3 pour les states (state local, une seule fois)
│   │   └── main.tf
│   ├── modules/                # Modules reutilisables (instance / secgroup / keypair / managed_db)
│   └── environments/           # Chaque env a son propre state isole dans le bucket S3
│       ├── test/               # main.tf, variables.tf, outputs.tf, backend.tf
│       ├── preprod/
│       └── prod/
│
└── ansible/
    ├── ansible.cfg
    ├── inventory/              # Inventaires generes par Terraform (outputs -> inventory)
    ├── group_vars/
    │   ├── all/main.yml        # Variables communes
    │   ├── test/main.yml       # Overrides test
    │   ├── preprod/main.yml
    │   └── prod/main.yml
    ├── roles/                  # Roles : node, emqx, powersync, common...
    └── playbooks/              # Orchestration
```

## Terraform state
- Un seul bucket S3 OVH (Object Storage) pour tous les envs
- Chaque env a son propre fichier state isole (key: `<env>/terraform.tfstate`)
- Le bucket est cree par `terraform/bootstrap/` (state local, probleme oeuf-poule)
- Locking automatique : un seul apply a la fois par env

## Strategie
- **Env test = MVP fonctionnel** : le test de reboot necessite un flux complet de bout en bout
  donc l'env test est aussi le premier MVP (meme infra, memes services)
- Commencer par `terraform/environments/test/` uniquement
- Dupliquer pour preprod/prod une fois le flux valide
- Pas de clustering EMQX, SSL, ou CI/CD en phase test

## Makefile (facade)
```makefile
ENV ?= test
bootstrap:    # Cree le bucket S3 (une seule fois)
init:         # terraform init sur l'env
plan:         # terraform plan sur l'env
apply:        # terraform apply sur l'env
destroy:      # terraform destroy sur l'env
configure:    # ansible-playbook sur l'env
deploy:       # apply + configure
```

## Decisions prises
- **IaC plutot que UI** : reproductibilite, tests de reboot, onboarding
- **Terraform** pour le provisioning des ressources OVH
- **Ansible** pour la configuration des services sur les instances
- **Makefile** comme facade (universel, suffisant pour de l'infra)
- **Dossiers par env** plutot que Terraform workspaces (isolation state, configs differentes par env)
- **Phase exploration via UI** d'abord, puis codification en Terraform

## Conventions
- Makefile comme facade unique pour toutes les commandes infra
- Un dossier par environnement dans terraform/environments/
- Secrets dans credentials.sh (jamais commites)
